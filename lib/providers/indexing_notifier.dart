import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/equalizer_notifier.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/services/indexing_service.dart';
import 'package:music_wave_player/services/metadata_repair_service.dart';
import 'package:music_wave_player/services/favorites_service.dart';
import 'package:music_wave_player/services/track_repository.dart';

export 'package:music_wave_player/services/track_repository.dart'
    show TrackEditResult, TrackEditSuccess, TrackEditFailure;

part 'indexing_notifier.g.dart';

const String _kRootDirectoryKey = 'rootDirectoryPath';
const String _kLastScanDateKey = 'lastScanDate';

enum IndexingStatus {
  idle,
  scanning,
  processingMetadata,
  calculatingLoudness,
  complete,
  error,
}

/// Estado imutável da biblioteca indexada e do progresso de varredura.
class IndexingState {
  final String? rootDirectory;
  final DateTime? lastScanDate;
  final IndexingStatus indexingStatus;
  final List<MusicTrack> indexedTracks;
  final int indexedFileCount;
  final int indexedFileTotal;
  final String? processingStage;
  final int loudnessDone;
  final int loudnessTotal;

  const IndexingState({
    this.rootDirectory,
    this.lastScanDate,
    this.indexingStatus = IndexingStatus.idle,
    this.indexedTracks = const [],
    this.indexedFileCount = 0,
    this.indexedFileTotal = 0,
    this.processingStage,
    this.loudnessDone = 0,
    this.loudnessTotal = 0,
  });

  bool get isBusy =>
      indexingStatus == IndexingStatus.scanning ||
      indexingStatus == IndexingStatus.processingMetadata ||
      indexingStatus == IndexingStatus.calculatingLoudness;

  IndexingState copyWith({
    String? rootDirectory,
    DateTime? lastScanDate,
    IndexingStatus? indexingStatus,
    List<MusicTrack>? indexedTracks,
    int? indexedFileCount,
    int? indexedFileTotal,
    String? processingStage,
    bool clearProcessingStage = false,
    int? loudnessDone,
    int? loudnessTotal,
  }) {
    return IndexingState(
      rootDirectory: rootDirectory ?? this.rootDirectory,
      lastScanDate: lastScanDate ?? this.lastScanDate,
      indexingStatus: indexingStatus ?? this.indexingStatus,
      indexedTracks: indexedTracks ?? this.indexedTracks,
      indexedFileCount: indexedFileCount ?? this.indexedFileCount,
      indexedFileTotal: indexedFileTotal ?? this.indexedFileTotal,
      processingStage: clearProcessingStage
          ? null
          : (processingStage ?? this.processingStage),
      loudnessDone: loudnessDone ?? this.loudnessDone,
      loudnessTotal: loudnessTotal ?? this.loudnessTotal,
    );
  }
}

/// Gerencia a biblioteca de faixas indexadas: diretório raiz, varredura,
/// ocultar/reexibir, avaliação e edição de metadados. Substitui a parte
/// de indexação do antigo [Configuration].
@Riverpod(keepAlive: true)
class IndexingNotifier extends _$IndexingNotifier {
  @override
  Future<IndexingState> build() async {
    await MetadataRepairService.runIfNeeded();
    await FavoritesService.ensurePlaylist();

    final prefs = await SharedPreferences.getInstance();
    final rootDirectory = prefs.getString(_kRootDirectoryKey);
    final ts = prefs.getInt(_kLastScanDateKey);
    final lastScanDate = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : null;

    final tracks = await MusicDatabase.instance.readAllTracks();
    final status = tracks.isNotEmpty
        ? IndexingStatus.complete
        : IndexingStatus.idle;

    // Espera o PlaybackNotifier carregar antes de regenerar a fila inicial,
    // para que a faixa/posição restauradas da última sessão sejam
    // respeitadas — mesma ordem de inicialização do Configuration original.
    final playbackState = await ref.read(playbackNotifierProvider.future);
    if (tracks.isNotEmpty) {
      ref
          .read(queueNotifierProvider.notifier)
          .regenerate(
            tracks: tracks,
            shuffleActive: playbackState.isShuffleActive,
            currentTrackId: playbackState.lastPlayedMusicId,
          );
    }

    // Aplica crossfade/fade/equalizador salvos assim que o app abre —
    // antes disso o audio handler está com os valores padrão (desligado).
    final audioHandler = ref.read(musicAudioHandlerProvider);
    final playerSettings = await ref.read(
      playerSettingsNotifierProvider.future,
    );
    audioHandler.updateCrossfade(playerSettings.crossfadeDuration);
    audioHandler.updateFadeOnPauseResume(playerSettings.fadeOnPauseResume);

    final eqState = await ref.read(equalizerNotifierProvider.future);
    await audioHandler.applyEqualizer(
      eqState.enabled,
      eqState.superequalizerParams,
    );

    // Restaura a faixa da última sessão — só carrega do zero se o player
    // não estiver com algo já tocando (evita interromper reprodução em
    // andamento após swipe-to-kill + reabrir).
    final lastTrack = tracks
        .where((t) => t.id == playbackState.lastPlayedMusicId)
        .firstOrNull;
    if (lastTrack != null) {
      final isAlreadyPlaying = audioHandler.player.state.playing;
      if (!isAlreadyPlaying) {
        await audioHandler.loadTrack(lastTrack.path);
      } else {
        ref.read(playbackNotifierProvider.notifier).syncPlayingState(true);
      }
    }

    return IndexingState(
      rootDirectory: rootDirectory,
      lastScanDate: lastScanDate,
      indexingStatus: status,
      indexedTracks: tracks,
      indexedFileCount: tracks.length,
    );
  }

  // ── Diretório raiz ────────────────────────────────────────────────────────

  Future<void> setRootDirectory(String path) async {
    final current = state.valueOrNull;
    if (current == null || current.rootDirectory == path) return;
    state = AsyncData(
      current.copyWith(
        rootDirectory: path,
        indexingStatus: IndexingStatus.idle,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRootDirectoryKey, path);
  }

  // ── Indexação ─────────────────────────────────────────────────────────────

  Future<void> loadIndexedTracks() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final tracks = await MusicDatabase.instance.readAllTracks();
      IndexingStatus status = current.indexingStatus;
      if (tracks.isNotEmpty) {
        status = IndexingStatus.complete;
        _regenerateQueue(tracks);
      } else if (current.rootDirectory != null) {
        status = IndexingStatus.idle;
      }
      state = AsyncData(
        current.copyWith(
          indexedTracks: tracks,
          indexedFileCount: tracks.length,
          indexingStatus: status,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(indexingStatus: IndexingStatus.error));
    }
  }

  Future<void> startIndexing() async {
    final current = state.valueOrNull;
    if (current == null || current.rootDirectory == null || current.isBusy) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        indexingStatus: IndexingStatus.scanning,
        indexedTracks: [],
        indexedFileCount: 0,
        indexedFileTotal: 0,
        clearProcessingStage: true,
        loudnessDone: 0,
        loudnessTotal: 0,
      ),
    );

    await IndexingService.startIndexing(
      rootDirectory: current.rootDirectory!,
      onProgress: (done, total) {
        final c = state.valueOrNull;
        if (c == null) return;
        state = AsyncData(
          c.copyWith(indexedFileCount: done, indexedFileTotal: total),
        );
      },
      onMetadataStage: (stage) {
        final c = state.valueOrNull;
        if (c == null) return;
        state = AsyncData(
          c.copyWith(
            indexingStatus: IndexingStatus.processingMetadata,
            processingStage: stage,
          ),
        );
      },
      onLoudnessProgress: (done, total) {
        final c = state.valueOrNull;
        if (c == null) return;
        state = AsyncData(
          c.copyWith(
            indexingStatus: IndexingStatus.calculatingLoudness,
            loudnessDone: done,
            loudnessTotal: total,
          ),
        );
      },
      onComplete: (tracks, scanDate) {
        final c = state.valueOrNull;
        if (c == null) return;
        state = AsyncData(
          c.copyWith(
            indexedTracks: tracks,
            indexedFileCount: tracks.length,
            indexedFileTotal: tracks.length,
            indexingStatus: IndexingStatus.complete,
            lastScanDate: scanDate,
          ),
        );
        _regenerateQueue(tracks);
        _saveLastScanDate(scanDate);
      },
      onError: (e) {
        final c = state.valueOrNull;
        if (c == null) return;
        state = AsyncData(c.copyWith(indexingStatus: IndexingStatus.error));
      },
    );
  }

  void _regenerateQueue(List<MusicTrack> tracks) {
    final playbackState = ref.read(playbackNotifierProvider).valueOrNull;
    ref
        .read(queueNotifierProvider.notifier)
        .regenerate(
          tracks: tracks,
          shuffleActive: playbackState?.isShuffleActive ?? false,
          currentTrackId: playbackState?.lastPlayedMusicId,
        );
  }

  Future<void> _saveLastScanDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastScanDateKey, date.millisecondsSinceEpoch);
  }

  // ── Ocultar / Reexibir ────────────────────────────────────────────────────

  Future<void> hideTracks(List<int> ids) async {
    if (ids.isEmpty) return;
    final current = state.valueOrNull;
    if (current == null) return;

    await TrackRepository.hideTracks(ids);
    final remaining = current.indexedTracks
        .where((t) => !ids.contains(t.id))
        .toList();

    state = AsyncData(
      current.copyWith(
        indexedTracks: remaining,
        indexedFileCount: remaining.length,
      ),
    );

    ref.read(queueNotifierProvider.notifier).removeTracksById(ids);
    _regenerateQueue(remaining);
  }

  Future<void> unhideTracks(List<int> ids) async {
    await TrackRepository.unhideTracks(ids);
    await loadIndexedTracks();
  }

  Future<void> unhideAllTracks() async {
    await TrackRepository.unhideAllTracks();
    await loadIndexedTracks();
  }

  // ── Avaliação ─────────────────────────────────────────────────────────────

  Future<void> setRating(int trackId, double rating) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexedTracks.indexWhere((t) => t.id == trackId);
    if (idx == -1) return;

    final updated = await TrackRepository.setRating(
      current.indexedTracks[idx],
      rating,
    );
    final tracks = List.of(current.indexedTracks);
    tracks[idx] = updated;
    state = AsyncData(current.copyWith(indexedTracks: tracks));
  }

  // ── Edição de metadados ───────────────────────────────────────────────────

  /// Edita os metadados de uma faixa. Retorna o resultado diretamente
  /// (sem depender de [BuildContext]) — a UI decide como exibir feedback.
  Future<TrackEditResult> editTrack({
    required MusicTrack track,
    required String newTitle,
    required String newArtist,
    required String newAlbum,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return const TrackEditResult.failure('Biblioteca ainda carregando.');
    }

    final result = await TrackRepository.editTrack(
      track: track,
      newTitle: newTitle,
      newArtist: newArtist,
      newAlbum: newAlbum,
    );

    if (result case TrackEditSuccess(:final updatedTrack)) {
      final idx = current.indexedTracks.indexWhere((t) => t.id == track.id);
      if (idx != -1) {
        final tracks = List.of(current.indexedTracks);
        tracks[idx] = updatedTrack;
        tracks.sort(
          (a, b) => MusicDatabase.naturalCompare(
            a.title.toLowerCase(),
            b.title.toLowerCase(),
          ),
        );
        state = AsyncData(current.copyWith(indexedTracks: tracks));
      }

      final playbackState = ref.read(playbackNotifierProvider).valueOrNull;
      if (playbackState?.lastPlayedMusicId == track.id) {
        await ref.read(musicAudioHandlerProvider).loadTrack(track.path);
      }
    }

    return result;
  }
}
