import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/download_format_selector.dart';
import 'package:music_wave_player/components/download_review_sheet.dart';
import 'package:music_wave_player/components/library_folder_access.dart';
import 'package:music_wave_player/providers/download_notifier.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/screens/download_playlist_screen.dart';
import 'package:music_wave_player/services/download_service.dart';

/// Etapas locais, antes de o download começar. Do clique em "Baixar" em
/// diante o andamento vive no [DownloadNotifier], que continua rodando com
/// a tela fechada.
enum _Step { idle, fetching, ready }

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
  String? _error;
  DownloadFormat _format = DownloadFormat.m4a;
  bool _mp3Available = false;
  bool _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(DownloadService.warmUp());
    DownloadService.mp3Available().then((ok) {
      if (mounted) setState(() => _mp3Available = ok);
    });

    // Chegou aqui por uma música que já terminou de baixar em segundo plano
    // (aviso da tela inicial): abre a revisão direto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phase = ref.read(downloadNotifierProvider).phase;
      if (phase == DownloadPhase.awaitingReview) unawaited(_review());
    });
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _linkCtrl.text = text;
  }

  Future<void> _fetch() async {
    final link = _linkCtrl.text.trim();
    if (link.isEmpty ||
        _step == _Step.fetching ||
        !ref.read(downloadNotifierProvider).canStart) {
      return;
    }
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

  void _download() {
    final info = _info;
    if (info == null) return;
    setState(() => _error = null);
    unawaited(
      ref
          .read(downloadNotifierProvider.notifier)
          .startSingle(info: info, format: _format),
    );
  }

  /// Abre a revisão de tags e, se confirmada, salva na biblioteca.
  Future<void> _review() async {
    if (_reviewOpen) return;
    final dl = ref.read(downloadNotifierProvider);
    final info = dl.info;
    final media = dl.media;
    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (dl.phase != DownloadPhase.awaitingReview ||
        info == null ||
        media == null ||
        root == null) {
      return;
    }

    _reviewOpen = true;
    try {
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

      final saved = await ref
          .read(downloadNotifierProvider.notifier)
          .saveSingle(tags);
      if (saved && mounted) {
        _linkCtrl.clear();
        setState(() {
          _info = null;
          _step = _Step.idle;
        });
      }
    } finally {
      _reviewOpen = false;
    }
  }

  String _formatMb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _discard() async {
    final notifier = ref.read(downloadNotifierProvider.notifier);
    final info = ref.read(downloadNotifierProvider).info ?? _info;
    await notifier.discardPending();
    if (!mounted) return;
    setState(() {
      _info = info;
      _step = info != null ? _Step.ready : _Step.idle;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dl = ref.watch(downloadNotifierProvider);
    final info = dl.info ?? _info;
    final error = dl.error ?? _error;
    final locked = _step == _Step.fetching || !dl.canStart;

    // Terminou de baixar com a tela aberta: já abre a revisão de tags.
    ref.listen(downloadNotifierProvider.select((s) => s.phase), (prev, next) {
      if (prev == DownloadPhase.downloading &&
          next == DownloadPhase.awaitingReview) {
        unawaited(_review());
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Baixar músicas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkCtrl,
                enabled: !locked,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _fetch(),
                decoration: InputDecoration(
                  labelText: 'Link do YouTube',
                  prefixIcon: Icon(Icons.link, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Colar',
                    onPressed: locked ? null : _paste,
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
                onPressed: locked ? null : _fetch,
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
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              ],
              if (info == null && !dl.canStart) ...[
                const SizedBox(height: 16),
                Text(
                  dl.blockedReason!,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
              if (info != null) ...[
                const SizedBox(height: 20),
                _VideoPreview(info: info),
                const SizedBox(height: 16),
                if ((_step == _Step.ready && dl.canStart) ||
                    dl.phase == DownloadPhase.awaitingReview) ...[
                  DownloadFormatSelector(
                    value: dl.phase == DownloadPhase.awaitingReview
                        ? dl.format
                        : _format,
                    mp3Available: _mp3Available,
                    onChanged: (format) {
                      setState(() => _format = format);
                      ref
                          .read(downloadNotifierProvider.notifier)
                          .setFormat(format);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _buildActions(colorScheme, dl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme, DownloadState dl) {
    switch (dl.phase) {
      case DownloadPhase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: dl.progress),
            const SizedBox(height: 8),
            Text(
              dl.progress != null
                  ? 'Baixando... ${(dl.progress! * 100).round()}%'
                  : (dl.bytes > 0
                        ? 'Baixando... ${_formatMb(dl.bytes)}'
                        : 'Preparando...'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: ref
                  .read(downloadNotifierProvider.notifier)
                  .cancelCurrent,
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
      case DownloadPhase.saving:
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
      case DownloadPhase.awaitingReview:
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
      case DownloadPhase.idle:
      case DownloadPhase.playlistRunning:
      case DownloadPhase.playlistDone:
        if (_step != _Step.ready) return const SizedBox.shrink();
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
