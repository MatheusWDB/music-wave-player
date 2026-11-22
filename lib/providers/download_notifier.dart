import 'dart:async';

import 'package:music_wave_player/main.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/background_task_manager.dart';
import 'package:music_wave_player/services/background_task_service.dart';
import 'package:music_wave_player/services/download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_notifier.g.dart';

enum DownloadPhase {
  idle,
  downloading,

  /// Música única já baixada para o cache, esperando revisão das tags.
  awaitingReview,
  saving,
  playlistRunning,
  playlistDone,
}

/// Estado do download em andamento (música única ou playlist). Só existe um
/// download por vez; os campos de playlist ficam zerados no fluxo único.
class DownloadState {
  const DownloadState({
    this.phase = DownloadPhase.idle,
    this.format = DownloadFormat.m4a,
    this.info,
    this.media,
    this.progress,
    this.bytes = 0,
    this.error,
    this.index = 0,
    this.total = 0,
    this.current,
    this.saved = 0,
    this.skipped = const [],
    this.failed = const [],
    this.cancelRequested = false,
  });

  final DownloadPhase phase;
  final DownloadFormat format;

  // Música única
  final DownloadVideoInfo? info;
  final DownloadedMedia? media;
  final double? progress;
  final int bytes;
  final String? error;

  // Playlist
  final int index;
  final int total;
  final DownloadVideoInfo? current;
  final int saved;
  final List<DownloadVideoInfo> skipped;
  final List<(DownloadVideoInfo, String)> failed;
  final bool cancelRequested;

  bool get isBusy =>
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.saving ||
      phase == DownloadPhase.playlistRunning;

  /// Motivo pelo qual um novo download não pode começar (null se pode).
  String? get blockedReason => switch (phase) {
    DownloadPhase.downloading ||
    DownloadPhase.saving ||
    DownloadPhase.playlistRunning => 'Aguarde o download em andamento.',
    DownloadPhase.awaitingReview =>
      'Revise ou descarte a música já baixada antes de iniciar outro download.',
    DownloadPhase.idle || DownloadPhase.playlistDone => null,
  };

  bool get canStart => blockedReason == null;

  static const _keep = Object();

  DownloadState copyWith({
    DownloadPhase? phase,
    DownloadFormat? format,
    Object? info = _keep,
    Object? media = _keep,
    Object? progress = _keep,
    int? bytes,
    Object? error = _keep,
    int? index,
    int? total,
    Object? current = _keep,
    int? saved,
    List<DownloadVideoInfo>? skipped,
    List<(DownloadVideoInfo, String)>? failed,
    bool? cancelRequested,
  }) {
    return DownloadState(
      phase: phase ?? this.phase,
      format: format ?? this.format,
      info: identical(info, _keep) ? this.info : info as DownloadVideoInfo?,
      media: identical(media, _keep) ? this.media : media as DownloadedMedia?,
      progress: identical(progress, _keep)
          ? this.progress
          : progress as double?,
      bytes: bytes ?? this.bytes,
      error: identical(error, _keep) ? this.error : error as String?,
      index: index ?? this.index,
      total: total ?? this.total,
      current: identical(current, _keep)
          ? this.current
          : current as DownloadVideoInfo?,
      saved: saved ?? this.saved,
      skipped: skipped ?? this.skipped,
      failed: failed ?? this.failed,
      cancelRequested: cancelRequested ?? this.cancelRequested,
    );
  }
}

/// Executa os downloads fora das telas: o usuário pode sair de "Baixar
/// músicas" e usar o app enquanto o progresso aparece no banner da tela
/// inicial e na notificação.
@Riverpod(keepAlive: true)
class DownloadNotifier extends _$DownloadNotifier {
  static const _title = 'MusicWave Player';

  TaskCancelToken? _token;
  String? _currentVideoId;

  @override
  DownloadState build() => const DownloadState();

  // ── Música única ──────────────────────────────────────────────────────────

  /// Baixa o áudio para o cache e, ao terminar, deixa a música aguardando a
  /// revisão das tags ([saveSingle] ou [discardPending]).
  Future<void> startSingle({
    required DownloadVideoInfo info,
    required DownloadFormat format,
  }) async {
    if (!state.canStart) return;

    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (root == null) {
      state = DownloadState(
        format: format,
        error: 'Configure a pasta da biblioteca primeiro.',
      );
      return;
    }

    final token = TaskCancelToken(
      onCancel: () => unawaited(DownloadService.cancel(info.id)),
    );
    _token = token;
    state = DownloadState(
      phase: DownloadPhase.downloading,
      format: format,
      info: info,
    );

    void report(double? fraction, int bytes) {
      final label = fraction != null
          ? 'Baixando música · ${info.title} (${(fraction * 100).round()}%)'
          : bytes > 0
          ? 'Baixando música · ${info.title} · ${_formatMb(bytes)}'
          : 'Baixando música · ${info.title}';
      state = state.copyWith(progress: fraction, bytes: bytes);
      BackgroundTaskManager.update(
        BackgroundTask(
          id: BackgroundTaskIds.download,
          label: label,
          progress: fraction,
          cancelToken: token,
        ),
      );
      unawaited(BackgroundTaskService.update(title: _title, text: label));
    }

    report(null, 0);
    await BackgroundTaskService.start(
      title: _title,
      text: 'Baixando música...',
    );

    DownloadedMedia? media;
    try {
      media = await DownloadService.download(info, onProgress: report);
    } on DownloadCancelledException {
      state = DownloadState(format: format);
      AppMessenger.show('Download cancelado.');
    } on DownloadException catch (e) {
      state = DownloadState(format: format, error: e.message);
    } finally {
      _token = null;
      BackgroundTaskManager.finish(BackgroundTaskIds.download);
      await BackgroundTaskService.stop();
    }

    if (media == null) return;
    state = state.copyWith(
      phase: DownloadPhase.awaitingReview,
      media: media,
      progress: 1.0,
    );
    _publishReview(info);
    AppMessenger.show('Download concluído. Revise as tags para salvar.');
  }

  /// Grava a música revisada na biblioteca. Retorna true se salvou. Em caso
  /// de falha mantém o download no cache para tentar de novo.
  Future<bool> saveSingle(DownloadTags tags) async {
    final info = state.info;
    final media = state.media;
    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (state.phase != DownloadPhase.awaitingReview ||
        info == null ||
        media == null ||
        root == null) {
      return false;
    }

    final format = state.format;
    state = state.copyWith(phase: DownloadPhase.saving, error: null);
    BackgroundTaskManager.finish(BackgroundTaskIds.downloadReview);
    // Salvar (ffmpeg + cópia SAF) não pode ser interrompido: sem token.
    BackgroundTaskManager.update(
      BackgroundTask(
        id: BackgroundTaskIds.download,
        label: 'Salvando na biblioteca · ${info.title}',
      ),
    );
    await BackgroundTaskService.start(
      title: _title,
      text: 'Salvando na biblioteca...',
    );

    try {
      final path = await DownloadService.saveToLibrary(
        media: media,
        tags: tags,
        rootDirectory: root,
        format: format,
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
      state = DownloadState(format: format);
      AppMessenger.show('Música adicionada à biblioteca!');
      return true;
    } on DownloadException catch (e) {
      state = state.copyWith(
        phase: DownloadPhase.awaitingReview,
        error: e.message,
      );
      _publishReview(info);
      AppMessenger.show(e.message, isError: true);
      return false;
    } finally {
      BackgroundTaskManager.finish(BackgroundTaskIds.download);
      await BackgroundTaskService.stop();
    }
  }

  /// Descarta a música baixada que aguardava revisão.
  Future<void> discardPending() async {
    final media = state.media;
    final format = state.format;
    BackgroundTaskManager.finish(BackgroundTaskIds.downloadReview);
    state = DownloadState(format: format);
    if (media != null) await DownloadService.discard(media);
  }

  void setFormat(DownloadFormat format) {
    if (state.phase != DownloadPhase.awaitingReview) return;
    state = state.copyWith(format: format);
  }

  void _publishReview(DownloadVideoInfo info) {
    BackgroundTaskManager.update(
      BackgroundTask(
        id: BackgroundTaskIds.downloadReview,
        label: 'Música baixada · ${info.title} · toque para revisar',
        progress: 1.0,
      ),
    );
  }

  // ── Playlist ──────────────────────────────────────────────────────────────

  /// Baixa e salva, uma por vez, as músicas de [queue] com tags automáticas.
  Future<void> startPlaylist({
    required List<DownloadVideoInfo> queue,
    required DownloadFormat format,
  }) async {
    if (!state.canStart || queue.isEmpty) return;

    final root = ref.read(indexingNotifierProvider).valueOrNull?.rootDirectory;
    if (root == null) {
      AppMessenger.show(
        'Configure a pasta da biblioteca primeiro.',
        isError: true,
      );
      return;
    }

    final token = TaskCancelToken(
      onCancel: () {
        state = state.copyWith(cancelRequested: true);
        final id = _currentVideoId;
        if (id != null) unawaited(DownloadService.cancel(id));
      },
    );
    _token = token;
    final total = queue.length;
    state = DownloadState(
      phase: DownloadPhase.playlistRunning,
      format: format,
      total: total,
    );

    void report(int index, DownloadVideoInfo info, double? fraction) {
      final overall = (index + (fraction ?? 0)) / total;
      final label =
          'Baixando playlist · ${index + 1}/$total '
          '(${(overall * 100).round()}%) · ${info.title}';
      BackgroundTaskManager.update(
        BackgroundTask(
          id: BackgroundTaskIds.downloadPlaylist,
          label: label,
          progress: overall,
          cancelToken: token,
        ),
      );
      unawaited(BackgroundTaskService.update(title: _title, text: label));
    }

    report(0, queue.first, null);
    await BackgroundTaskService.start(
      title: _title,
      text: 'Baixando playlist...',
    );

    try {
      for (var i = 0; i < total; i++) {
        if (token.isCancelled) break;
        final info = queue[i];
        _currentVideoId = info.id;
        state = state.copyWith(index: i, current: info, bytes: 0);
        report(i, info, null);

        // Na playlist as tags ficam como vêm do YouTube (título do vídeo e
        // nome do canal), sem tentar adivinhar o artista: são muitas músicas
        // e uma sugestão errada passaria despercebida.
        final tags = DownloadTags(
          title: info.title,
          artist: info.channel,
          album: '',
        );

        // Confere duplicata antes de baixar, inclusive contra faixas que o
        // próprio lote acabou de salvar.
        final library =
            ref.read(indexingNotifierProvider).valueOrNull?.indexedTracks ??
            const [];
        if (DownloadService.isDuplicate(library, tags.title, tags.artist)) {
          state = state.copyWith(skipped: [...state.skipped, info]);
          continue;
        }

        DownloadedMedia? media;
        try {
          media = await DownloadService.download(
            info,
            onProgress: (fraction, bytes) {
              state = state.copyWith(bytes: bytes);
              report(i, info, fraction);
            },
          );
          final path = await DownloadService.saveToLibrary(
            media: media,
            tags: tags,
            rootDirectory: root,
            format: format,
          );
          final track = await ref
              .read(indexingNotifierProvider.notifier)
              .addTrackFromPath(path);
          if (track == null) {
            throw const DownloadException(
              'Salva, mas não foi possível indexar. Reindexe a biblioteca.',
            );
          }
          state = state.copyWith(saved: state.saved + 1);
        } on DownloadCancelledException {
          break;
        } on DownloadException catch (e) {
          state = state.copyWith(failed: [...state.failed, (info, e.message)]);
        } finally {
          if (media != null) await DownloadService.discard(media);
        }
      }
    } finally {
      _token = null;
      _currentVideoId = null;
      BackgroundTaskManager.finish(BackgroundTaskIds.downloadPlaylist);
      await BackgroundTaskService.stop();
    }

    state = state.copyWith(phase: DownloadPhase.playlistDone, current: null);
    final prefix = state.cancelRequested
        ? 'Download da playlist cancelado'
        : 'Download da playlist concluído';
    AppMessenger.show(
      '$prefix: ${state.saved} salva${state.saved == 1 ? '' : 's'}, '
      '${state.skipped.length} já existia${state.skipped.length == 1 ? '' : 'm'}, '
      '${state.failed.length} falha${state.failed.length == 1 ? '' : 's'}.',
    );
  }

  /// Fecha o resumo de uma playlist já terminada.
  void dismissFinished() {
    if (state.phase != DownloadPhase.playlistDone) return;
    state = DownloadState(format: state.format);
  }

  // ── Comum ─────────────────────────────────────────────────────────────────

  /// Cancela o download de música única ou o lote de playlist em andamento.
  void cancelCurrent() => _token?.cancel();

  String _formatMb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
