import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/download_format_selector.dart';
import 'package:music_wave_player/components/download_review_sheet.dart';
import 'package:music_wave_player/components/library_folder_access.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/background_task_service.dart';
import 'package:music_wave_player/screens/download_playlist_screen.dart';
import 'package:music_wave_player/services/download_service.dart';

enum _Step { idle, fetching, ready, downloading, downloaded, saving }

/// Baixa o áudio de um link do YouTube, deixa o usuário conferir as tags e
/// salva o arquivo na pasta raiz da biblioteca.
class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  final _linkCtrl = TextEditingController();

  _Step _step = _Step.idle;
  DownloadVideoInfo? _info;
  DownloadedMedia? _media;
  double? _progress;
  int _bytes = 0;
  String? _error;
  DownloadFormat _format = DownloadFormat.m4a;
  bool _leaveAfterCancel = false;
  bool _mp3Available = false;

  bool get _busy =>
      _step == _Step.fetching ||
      _step == _Step.downloading ||
      _step == _Step.saving;

  @override
  void initState() {
    super.initState();
    unawaited(DownloadService.warmUp());
    DownloadService.mp3Available().then((ok) {
      if (mounted) setState(() => _mp3Available = ok);
    });
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    final media = _media;
    if (media != null) unawaited(DownloadService.discard(media));
    super.dispose();
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? colorScheme.primary : colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _linkCtrl.text = text;
  }

  Future<void> _fetch() async {
    final link = _linkCtrl.text.trim();
    if (link.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();

    // Link de playlist abre a tela de seleção de vídeos.
    if (DownloadService.isPlaylistUrl(link)) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DownloadPlaylistScreen(url: link)),
      );
      return;
    }

    setState(() {
      _step = _Step.fetching;
      _error = null;
      _info = null;
    });

    try {
      final info = await DownloadService.fetchInfo(link);
      if (!mounted) return;
      setState(() {
        _info = info;
        _step = _Step.ready;
      });
    } on DownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _step = _Step.idle;
      });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null || _busy) return;

    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (root == null) {
      setState(() => _error = 'Configure a pasta da biblioteca primeiro.');
      return;
    }

    setState(() {
      _step = _Step.downloading;
      _progress = null;
      _bytes = 0;
      _error = null;
    });

    await BackgroundTaskService.start(
      title: 'MusicWave Player',
      text: 'Baixando música...',
    );

    DownloadedMedia? media;
    try {
      media = await DownloadService.download(
        info,
        onProgress: (fraction, bytes) {
          if (!mounted) return;
          setState(() {
            _progress = fraction;
            _bytes = bytes;
          });
          unawaited(
            BackgroundTaskService.update(
              title: 'MusicWave Player',
              text: 'Baixando música... ${_formatMb(bytes)}',
            ),
          );
        },
      );
    } on DownloadCancelledException {
      if (mounted) {
        if (_leaveAfterCancel) {
          Navigator.of(context).pop();
        } else {
          setState(() => _step = _Step.ready);
        }
      }
    } on DownloadException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _step = _Step.ready;
        });
      }
    } finally {
      await BackgroundTaskService.stop();
    }

    if (media == null) return;
    if (!mounted) {
      await DownloadService.discard(media);
      return;
    }

    _media = media;
    setState(() => _step = _Step.downloaded);
    await _review();
  }

  /// Abre a revisão de tags e, se confirmada, salva na biblioteca.
  Future<void> _review() async {
    final info = _info;
    final media = _media;
    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (info == null || media == null || root == null) return;

    final tags = await DownloadReviewSheet.show(
      context,
      initial: DownloadService.suggestTags(info),
      coverPath: media.thumbnailPath,
      isDuplicate: (title, artist) => DownloadService.isDuplicate(
        ref.read(indexingNotifierProvider).valueOrNull?.indexedTracks ?? [],
        title,
        artist,
      ),
    );
    if (tags == null || !mounted) return;

    // Na primeira vez explica o seletor de pasta e só aceita a raiz da biblioteca.
    if (!await ensureLibraryFolderAccess(context, root) || !mounted) return;

    setState(() {
      _step = _Step.saving;
      _error = null;
    });

    await BackgroundTaskService.start(
      title: 'MusicWave Player',
      text: 'Salvando na biblioteca...',
    );

    try {
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
          'O arquivo foi salvo, mas não foi possível indexá-lo. '
          'Reindexe a biblioteca.',
        );
      }

      await DownloadService.discard(media);
      _media = null;
      _showSnack('Música adicionada à biblioteca!', isSuccess: true);
      if (!mounted) return;
      _linkCtrl.clear();
      setState(() {
        _info = null;
        _step = _Step.idle;
      });
    } on DownloadException catch (e) {
      if (!mounted) return;
      // Mantém o download no cache para o usuário tentar salvar de novo.
      setState(() {
        _error = e.message;
        _step = _Step.downloaded;
      });
    } finally {
      await BackgroundTaskService.stop();
    }
  }

  String _formatMb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  void _cancelDownload() {
    final info = _info;
    if (info != null) unawaited(DownloadService.cancel(info.id));
  }

  Future<void> _discard() async {
    final media = _media;
    _media = null;
    if (media != null) await DownloadService.discard(media);
    if (!mounted) return;
    setState(() {
      _step = _Step.ready;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final info = _info;

    return PopScope(
      // Só o salvamento (ffmpeg + cópia SAF) não pode ser interrompido.
      canPop: _step != _Step.downloading && _step != _Step.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _step != _Step.downloading) return;
        // Sai da tela quando o cancelamento terminar (ver _download).
        _leaveAfterCancel = true;
        _cancelDownload();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Baixar músicas')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _linkCtrl,
                  enabled: !_busy && _step != _Step.downloaded,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _fetch(),
                  decoration: InputDecoration(
                    labelText: 'Link do YouTube',
                    prefixIcon: Icon(Icons.link, color: colorScheme.primary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: 'Colar',
                      onPressed: _busy ? null : _paste,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (_busy || _step == _Step.downloaded)
                      ? null
                      : _fetch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _step == _Step.fetching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Buscar'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                  ),
                ],
                if (info != null) ...[
                  const SizedBox(height: 20),
                  _VideoPreview(info: info),
                  const SizedBox(height: 16),
                  if (_step == _Step.ready || _step == _Step.downloaded) ...[
                    DownloadFormatSelector(
                      value: _format,
                      mp3Available: _mp3Available,
                      onChanged: (format) => setState(() => _format = format),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildActions(colorScheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    switch (_step) {
      case _Step.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              _bytes > 0 ? 'Baixando... ${_formatMb(_bytes)}' : 'Preparando...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _cancelDownload,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        );
      case _Step.saving:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Salvando na biblioteca...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        );
      case _Step.downloaded:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _discard,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Descartar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _review,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Revisar e salvar'),
              ),
            ),
          ],
        );
      case _Step.ready:
        return FilledButton.icon(
          onPressed: _download,
          icon: const Icon(Icons.download),
          label: const Text('Baixar'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case _Step.idle:
      case _Step.fetching:
        return const SizedBox.shrink();
    }
  }
}

class _VideoPreview extends StatelessWidget {
  final DownloadVideoInfo info;

  const _VideoPreview({required this.info});

  String? get _durationText {
    final d = info.duration;
    if (d == null) return null;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = [
      info.channel,
      if (_durationText != null) _durationText!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              info.thumbnailUrls.last,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_video_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          info.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}
