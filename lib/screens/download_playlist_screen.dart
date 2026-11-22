import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/download_format_selector.dart';
import 'package:music_wave_player/components/library_folder_access.dart';
import 'package:music_wave_player/providers/download_notifier.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/download_service.dart';

/// Etapas locais, antes do lote começar. O andamento do lote (rodando e
/// resumo final) vive no [DownloadNotifier] e continua com a tela fechada.
enum _Phase { loading, error, ready }

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
      'As tags seguem o YouTube: o título do vídeo vira o nome da música e o '
      'canal vira o artista, sem ajustes. Vale revisar depois no editor de '
      'faixa do app.';

  _Phase _phase = _Phase.loading;
  DownloadPlaylist? _playlist;
  String? _error;
  final Set<String> _selected = {};

  DownloadFormat _format = DownloadFormat.m4a;
  bool _mp3Available = false;

  @override
  void initState() {
    super.initState();
    unawaited(DownloadService.warmUp());
    DownloadService.mp3Available().then((ok) {
      if (mounted) setState(() => _mp3Available = ok);
    });
    _load();

    // Resumo de um lote anterior não deve aparecer numa playlist nova.
    Future.microtask(
      () => ref.read(downloadNotifierProvider.notifier).dismissFinished(),
    );
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

    final blocked = ref.read(downloadNotifierProvider).blockedReason;
    if (blocked != null) {
      _showSnack(blocked);
      return;
    }

    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (root == null) {
      _showSnack('Configure a pasta da biblioteca primeiro.');
      return;
    }
    if (!await ensureLibraryFolderAccess(context, root) || !mounted) return;

    final queue = playlist.items
        .where((i) => _selected.contains(i.id))
        .toList();
    unawaited(
      ref
          .read(downloadNotifierProvider.notifier)
          .startPlaylist(queue: queue, format: _format),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Baixar playlist')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (ref.watch(downloadNotifierProvider).phase) {
      case DownloadPhase.playlistRunning:
        return _buildRunning();
      case DownloadPhase.playlistDone:
        return _buildDone();
      default:
        break;
    }

    switch (_phase) {
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return _buildError();
      case _Phase.ready:
        return _buildReady();
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
    final dl = ref.watch(downloadNotifierProvider);
    return Text(
      'Salvas: ${dl.saved} · Já existiam: ${dl.skipped.length} · Falhas: ${dl.failed.length}',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildRunning() {
    final colorScheme = Theme.of(context).colorScheme;
    final dl = ref.watch(downloadNotifierProvider);
    final current = dl.current;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Música ${dl.index + 1} de ${dl.total}',
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
            dl.cancelRequested
                ? 'Cancelando...'
                : (dl.bytes > 0 ? _formatMb(dl.bytes) : 'Preparando...'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildCounters(),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: dl.cancelRequested
                ? null
                : ref.read(downloadNotifierProvider.notifier).cancelCurrent,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(dl.cancelRequested ? 'Cancelando...' : 'Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final colorScheme = Theme.of(context).colorScheme;
    final dl = ref.watch(downloadNotifierProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          dl.cancelRequested ? 'Download cancelado' : 'Concluído',
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
        if (dl.skipped.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Já existiam na biblioteca (${dl.skipped.length})'),
            children: [
              for (final i in dl.skipped)
                ListTile(dense: true, title: Text(i.title)),
            ],
          ),
        ],
        if (dl.failed.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Falharam (${dl.failed.length})'),
            children: [
              for (final (info, reason) in dl.failed)
                ListTile(
                  dense: true,
                  title: Text(info.title),
                  subtitle: Text(reason),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ref.read(downloadNotifierProvider.notifier).dismissFinished();
            Navigator.of(context).pop();
          },
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
