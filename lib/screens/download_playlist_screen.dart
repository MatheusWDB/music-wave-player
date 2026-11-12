import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/download_format_selector.dart';
import 'package:music_wave_player/components/library_folder_access.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/background_task_service.dart';
import 'package:music_wave_player/services/download_service.dart';

enum _Phase { loading, error, ready, running, done }

/// Lista os vídeos de uma playlist, deixa o usuário marcar quais baixar e
/// baixa um por vez para a pasta raiz da biblioteca, com tags automáticas.
class DownloadPlaylistScreen extends ConsumerStatefulWidget {
  final String url;

  const DownloadPlaylistScreen({super.key, required this.url});

  @override
  ConsumerState<DownloadPlaylistScreen> createState() =>
      _DownloadPlaylistScreenState();
}

class _DownloadPlaylistScreenState
    extends ConsumerState<DownloadPlaylistScreen> {
  static const _tagsWarning =
      'As tags são geradas automaticamente a partir do título e do canal do '
      'vídeo. Alguma música pode ficar com título ou artista errado; vale '
      'revisar depois no editor de faixa do app.';

  _Phase _phase = _Phase.loading;
  DownloadPlaylist? _playlist;
  String? _error;
  final Set<String> _selected = {};

  DownloadFormat _format = DownloadFormat.m4a;
  bool _mp3Available = false;

  // Execução do lote
  int _index = 0;
  int _total = 0;
  DownloadVideoInfo? _current;
  int _bytes = 0;
  int _saved = 0;
  final List<DownloadVideoInfo> _skipped = [];
  final List<(DownloadVideoInfo, String)> _failed = [];
  bool _cancelRequested = false;
  bool _leaveAfterCancel = false;

  @override
  void initState() {
    super.initState();
    unawaited(DownloadService.warmUp());
    DownloadService.mp3Available().then((ok) {
      if (mounted) setState(() => _mp3Available = ok);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final playlist = await DownloadService.fetchPlaylist(widget.url);
      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _selected
          ..clear()
          ..addAll(playlist.items.map((i) => i.id));
        _phase = _Phase.ready;
      });
    } on DownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _Phase.error;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _start() async {
    final playlist = _playlist;
    if (playlist == null || _selected.isEmpty) return;

    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (root == null) {
      _showSnack('Configure a pasta da biblioteca primeiro.');
      return;
    }
    if (!await ensureLibraryFolderAccess(context, root) || !mounted) return;

    final queue = playlist.items
        .where((i) => _selected.contains(i.id))
        .toList();
    setState(() {
      _phase = _Phase.running;
      _index = 0;
      _total = queue.length;
      _bytes = 0;
      _saved = 0;
      _skipped.clear();
      _failed.clear();
      _cancelRequested = false;
    });

    await BackgroundTaskService.start(
      title: 'MusicWave Player',
      text: 'Baixando playlist...',
    );

    try {
      for (var i = 0; i < queue.length; i++) {
        if (_cancelRequested || !mounted) break;
        final info = queue[i];
        setState(() {
          _index = i;
          _current = info;
          _bytes = 0;
        });
        unawaited(
          BackgroundTaskService.update(
            title: 'MusicWave Player',
            text: '${i + 1}/${queue.length} · ${info.title}',
          ),
        );

        // Confere duplicata antes de baixar, inclusive contra faixas que o
        // próprio lote acabou de salvar.
        final tags = DownloadService.suggestTags(info);
        final library =
            ref.read(indexingNotifierProvider).valueOrNull?.indexedTracks ??
            const [];
        if (DownloadService.isDuplicate(library, tags.title, tags.artist)) {
          setState(() => _skipped.add(info));
          continue;
        }

        DownloadedMedia? media;
        try {
          media = await DownloadService.download(
            info,
            onProgress: (_, bytes) {
              if (mounted) setState(() => _bytes = bytes);
            },
          );
          final path = await DownloadService.saveToLibrary(
            media: media,
            tags: tags,
            rootDirectory: root,
            format: _format,
          );
          final track = await ref
              .read(indexingNotifierProvider.notifier)
              .addTrackFromPath(path);
          if (track == null) {
            throw const DownloadException(
              'Salva, mas não foi possível indexar. Reindexe a biblioteca.',
            );
          }
          if (mounted) setState(() => _saved++);
        } on DownloadCancelledException {
          break;
        } on DownloadException catch (e) {
          if (mounted) setState(() => _failed.add((info, e.message)));
        } finally {
          if (media != null) await DownloadService.discard(media);
        }
      }
    } finally {
      await BackgroundTaskService.stop();
    }

    if (!mounted) return;
    if (_leaveAfterCancel) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _current = null;
      _phase = _Phase.done;
    });
  }

  void _cancel() {
    if (_cancelRequested) return;
    setState(() => _cancelRequested = true);
    final current = _current;
    if (current != null) unawaited(DownloadService.cancel(current.id));
  }

  Future<bool> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar o download da playlist?'),
        content: const Text(
          'As músicas já salvas continuam na biblioteca. A que está sendo '
          'baixada agora será descartada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _formatMb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Durante o lote, voltar pede confirmação, cancela e só sai quando o
      // loop terminar.
      canPop: _phase != _Phase.running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _phase != _Phase.running || _cancelRequested) return;
        final confirmed = await _confirmCancel();
        if (confirmed && mounted && _phase == _Phase.running) {
          _leaveAfterCancel = true;
          _cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Baixar playlist')),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return _buildError();
      case _Phase.ready:
        return _buildReady();
      case _Phase.running:
        return _buildRunning();
      case _Phase.done:
        return _buildDone();
    }
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error ?? 'Erro ao carregar a playlist.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }

  Widget _buildWarning() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tagsWarning,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReady() {
    final colorScheme = Theme.of(context).colorScheme;
    final playlist = _playlist!;
    final allSelected = _selected.length == playlist.items.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${playlist.author} · ${playlist.items.length} vídeos'
                '${playlist.truncated ? ' (mostrando os primeiros)' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _buildWarning(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${_selected.length} de ${playlist.items.length} selecionados',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected.addAll(playlist.items.map((i) => i.id));
                  }
                }),
                child: Text(allSelected ? 'Nenhum' : 'Todos'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: playlist.items.length,
            itemBuilder: (context, index) {
              final item = playlist.items[index];
              final subtitle = [
                item.channel,
                if (item.duration != null) _formatDuration(item.duration),
              ].join(' · ');
              return CheckboxListTile(
                value: _selected.contains(item.id),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(item.id);
                  } else {
                    _selected.remove(item.id);
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 64,
                    height: 36,
                    child: Image.network(
                      item.thumbnailUrls.last,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DownloadFormatSelector(
                value: _format,
                mp3Available: _mp3Available,
                onChanged: (format) => setState(() => _format = format),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected.isEmpty ? null : _start,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selected.length == 1
                      ? 'Baixar 1 música'
                      : 'Baixar ${_selected.length} músicas',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounters() {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      'Salvas: $_saved · Já existiam: ${_skipped.length} · Falhas: ${_failed.length}',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildRunning() {
    final colorScheme = Theme.of(context).colorScheme;
    final current = _current;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Música ${_index + 1} de $_total',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // O plugin não informa o andamento de cada música, então a barra é
          // animada; o contador "Música X de N" mostra o avanço do lote.
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (current != null)
            Text(
              current.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          const SizedBox(height: 4),
          Text(
            _cancelRequested
                ? 'Cancelando...'
                : (_bytes > 0 ? _formatMb(_bytes) : 'Preparando...'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildCounters(),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _cancelRequested ? null : _cancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_cancelRequested ? 'Cancelando...' : 'Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _cancelRequested ? 'Download cancelado' : 'Concluído',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _buildCounters(),
        const SizedBox(height: 16),
        _buildWarning(),
        if (_skipped.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Já existiam na biblioteca (${_skipped.length})'),
            children: [
              for (final i in _skipped)
                ListTile(dense: true, title: Text(i.title)),
            ],
          ),
        ],
        if (_failed.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Falharam (${_failed.length})'),
            children: [
              for (final (info, reason) in _failed)
                ListTile(
                  dense: true,
                  title: Text(info.title),
                  subtitle: Text(reason),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
