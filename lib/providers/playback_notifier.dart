import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/services/recently_played_service.dart';

part 'playback_notifier.g.dart';

const String _kLastPlayedMusicIdKey = 'lastPlayedMusicId';
const String _kLastSeekPositionMsKey = 'lastSeekPositionMs';

/// Estado imutável de reprodução: faixa atual, posição, duração, repeat
/// e histórico de reproduzidas recentemente.
class PlaybackState {
  final int? lastPlayedMusicId;
  final int lastSeekPositionMs;
  final int currentPositionMs;
  final int trackDurationMs;
  final bool isPlaying;
  final bool isShuffleActive;
  final String repeatMode;
  final List<int> recentlyPlayedIds;

  const PlaybackState({
    this.lastPlayedMusicId,
    this.lastSeekPositionMs = 0,
    this.currentPositionMs = 0,
    this.trackDurationMs = 0,
    this.isPlaying = false,
    this.isShuffleActive = false,
    this.repeatMode = 'Off',
    this.recentlyPlayedIds = const [],
  });

  PlaybackState copyWith({
    int? lastPlayedMusicId,
    bool clearLastPlayedMusicId = false,
    int? lastSeekPositionMs,
    int? currentPositionMs,
    int? trackDurationMs,
    bool? isPlaying,
    bool? isShuffleActive,
    String? repeatMode,
    List<int>? recentlyPlayedIds,
  }) {
    return PlaybackState(
      lastPlayedMusicId: clearLastPlayedMusicId
          ? null
          : (lastPlayedMusicId ?? this.lastPlayedMusicId),
      lastSeekPositionMs: lastSeekPositionMs ?? this.lastSeekPositionMs,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      trackDurationMs: trackDurationMs ?? this.trackDurationMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffleActive: isShuffleActive ?? this.isShuffleActive,
      repeatMode: repeatMode ?? this.repeatMode,
      recentlyPlayedIds: recentlyPlayedIds ?? this.recentlyPlayedIds,
    );
  }
}

/// Coordena as ações de reprodução: play, pause, next, previous, repeat.
/// Substitui o antigo [PlaybackController] — depende de [QueueNotifier]
/// para navegação na fila e de [musicAudioHandlerProvider] para controle
/// do player de áudio.
@Riverpod(keepAlive: true)
class PlaybackNotifier extends _$PlaybackNotifier {
  @override
  Future<PlaybackState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final recentlyPlayedIds = await RecentlyPlayedService.load();

    return PlaybackState(
      lastPlayedMusicId: prefs.getInt(_kLastPlayedMusicIdKey),
      lastSeekPositionMs: prefs.getInt(_kLastSeekPositionMsKey) ?? 0,
      recentlyPlayedIds: recentlyPlayedIds,
    );
  }

  // ── Reprodução ────────────────────────────────────────────────────────────

  Future<void> playTrack(
    int musicId, {
    required List<MusicTrack> indexedTracks,
    required String? trackPath,
    bool regenerateQueue = true,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final exists = indexedTracks.any((t) => t.id == musicId);
    if (!exists || trackPath == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);
    final queueNotifier = ref.read(queueNotifierProvider.notifier);

    if (current.lastPlayedMusicId != musicId) {
      List<int> recentlyPlayedIds = current.recentlyPlayedIds;
      if (current.lastPlayedMusicId != null) {
        recentlyPlayedIds = await RecentlyPlayedService.push(
          current.lastPlayedMusicId!,
          current.recentlyPlayedIds,
        );
      }

      if (regenerateQueue) {
        queueNotifier.regenerate(
          tracks: indexedTracks,
          shuffleActive: false,
          currentTrackId: musicId,
        );
      }
      queueNotifier.syncCurrentIndex(musicId);

      state = AsyncData(
        current.copyWith(
          lastPlayedMusicId: musicId,
          lastSeekPositionMs: 0,
          currentPositionMs: 0,
          trackDurationMs: 0,
          recentlyPlayedIds: recentlyPlayedIds,
        ),
      );

      await _saveLastPlayedMusicId(musicId);
      await audioHandler.loadTrack(trackPath);

      state = AsyncData(state.valueOrNull!.copyWith(isPlaying: true));
      audioHandler.play();
      return;
    }

    // Mesma faixa que já está carregada: só retoma se estava pausada.
    if (!current.isPlaying) {
      state = AsyncData(current.copyWith(isPlaying: true));
      audioHandler.play();
    }
  }

  Future<void> playPlaylist(
    Playlist playlist, {
    required List<MusicTrack> indexedTracks,
    required bool shuffleActive,
    required String? Function(int id) pathForId,
  }) async {
    if (playlist.trackIds.isEmpty) return;
    final validIds = playlist.trackIds
        .where((id) => indexedTracks.any((t) => t.id == id))
        .toList();
    if (validIds.isEmpty) return;

    ref
        .read(queueNotifierProvider.notifier)
        .setQueue(orderedIds: validIds, shuffleActive: shuffleActive);
    await _startFromQueueTop(pathForId: pathForId);
  }

  Future<void> playTracks(
    List<MusicTrack> tracks, {
    required bool shuffleActive,
    required String? Function(int id) pathForId,
  }) async {
    final visibleIds = tracks
        .where((t) => !t.isHidden)
        .map((t) => t.id!)
        .toList();
    if (visibleIds.isEmpty) return;

    ref
        .read(queueNotifierProvider.notifier)
        .setQueue(orderedIds: visibleIds, shuffleActive: shuffleActive);
    await _startFromQueueTop(pathForId: pathForId);
  }

  Future<void> _startFromQueueTop({
    required String? Function(int id) pathForId,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final queue = ref.read(queueNotifierProvider).playbackQueue;
    final firstId = queue.first;
    final path = pathForId(firstId);
    if (path == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);

    state = AsyncData(
      current.copyWith(
        lastPlayedMusicId: firstId,
        lastSeekPositionMs: 0,
        currentPositionMs: 0,
        trackDurationMs: 0,
      ),
    );

    await _saveLastPlayedMusicId(firstId);
    await audioHandler.loadTrack(path);

    state = AsyncData(state.valueOrNull!.copyWith(isPlaying: true));
    audioHandler.play();
  }

  // ── Controles ─────────────────────────────────────────────────────────────

  void togglePlayPause({
    required List<MusicTrack> indexedTracks,
    required String? currentTrackPath,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);
    final queueNotifier = ref.read(queueNotifierProvider.notifier);

    // Nenhuma faixa carregada — inicia com a primeira da fila
    if (current.lastPlayedMusicId == null && indexedTracks.isNotEmpty) {
      final queue = ref.read(queueNotifierProvider).playbackQueue;
      if (queue.isEmpty) return;

      final id = queue.first;
      queueNotifier.setCurrentIndex(0);
      _saveLastPlayedMusicId(id);

      state = AsyncData(
        current.copyWith(lastPlayedMusicId: id, isPlaying: true),
      );

      if (currentTrackPath != null) {
        audioHandler.loadTrack(currentTrackPath).then((_) {
          audioHandler.play();
        });
      }
      return;
    }

    if (current.lastPlayedMusicId == null) return;

    final nowPlaying = !current.isPlaying;
    state = AsyncData(current.copyWith(isPlaying: nowPlaying));

    if (nowPlaying) {
      // Se a pausa atual veio do temporizador ao fim da faixa, avança para
      // a próxima em vez de retomar do zero.
      final pausedAtEnd = audioHandler.consumePausedAtTrackEnd();
      if (pausedAtEnd) {
        playNextTrack(indexedTracks: indexedTracks);
      } else {
        audioHandler.play();
      }
    } else {
      _saveLastSeekPosition(current.currentPositionMs);
      audioHandler.pause();
    }
  }

  void playNextTrack({required List<MusicTrack> indexedTracks}) {
    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queueState = ref.read(queueNotifierProvider);
    final queue = queueState.playbackQueue;
    if (queue.isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) return;

    int next = queueState.currentQueueIndex + 1;
    if (next >= queue.length) {
      if (current.repeatMode == 'All') {
        next = 0;
      } else {
        ref.read(musicAudioHandlerProvider).pause();
        return;
      }
    }

    queueNotifier.setCurrentIndex(next);
    final trackId = queue[next];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
    );
  }

  void playPreviousTrack({required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queueState = ref.read(queueNotifierProvider);
    final queue = queueState.playbackQueue;
    if (queue.isEmpty) return;

    final audioHandler = ref.read(musicAudioHandlerProvider);

    // Se passou de 3s, volta ao início da faixa atual
    if (current.currentPositionMs > 3000) {
      audioHandler.seek(Duration.zero);
      return;
    }

    int prev = queueState.currentQueueIndex - 1;
    if (prev < 0) {
      if (current.repeatMode == 'All') {
        prev = queue.length - 1;
      } else {
        audioHandler.seek(Duration.zero);
        return;
      }
    }

    queueNotifier.setCurrentIndex(prev);
    final trackId = queue[prev];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
    );
  }

  void trackDidFinish({required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final queue = ref.read(queueNotifierProvider).playbackQueue;
    if (current.lastPlayedMusicId == null || queue.isEmpty) return;

    if (current.repeatMode == 'One') {
      final track = indexedTracks
          .where((t) => t.id == current.lastPlayedMusicId)
          .firstOrNull;
      if (track != null) {
        playTrack(
          current.lastPlayedMusicId!,
          indexedTracks: indexedTracks,
          trackPath: track.path,
        );
      }
      return;
    }
    playNextTrack(indexedTracks: indexedTracks);
  }

  void toggleShuffle() {
    final current = state.valueOrNull;
    if (current == null) return;

    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final nowActive = !current.isShuffleActive;

    if (nowActive) {
      queueNotifier.applyShuffle(
        ref.read(queueNotifierProvider).currentQueueIndex,
      );
    } else {
      queueNotifier.restoreOriginal(current.lastPlayedMusicId);
    }

    state = AsyncData(current.copyWith(isShuffleActive: nowActive));
  }

  // ── Coordenação com a fila ────────────────────────────────────────────────

  /// Remove um item da fila e reage ao resultado: pausa se a faixa
  /// removida era a atual e a fila ficou vazia, ou avança para a próxima
  /// se havia uma. Coordena [QueueNotifier] + reprodução, por isso vive
  /// aqui em vez de só no QueueNotifier.
  void removeFromQueue(int index, {required List<MusicTrack> indexedTracks}) {
    final current = state.valueOrNull;
    if (current == null) return;

    final result = ref
        .read(queueNotifierProvider.notifier)
        .remove(index: index, currentTrackId: current.lastPlayedMusicId);

    switch (result) {
      case QueueRemovePause():
        ref.read(musicAudioHandlerProvider).pause();
      case QueueRemovePlayTrack(:final trackId):
        final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
        playTrack(
          trackId,
          indexedTracks: indexedTracks,
          trackPath: track?.path,
          regenerateQueue: false,
        );
      case QueueRemoveNone():
        break;
    }
  }

  /// Pula para uma posição específica da fila.
  void jumpToQueueIndex(int index, {required List<MusicTrack> indexedTracks}) {
    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final queue = ref.read(queueNotifierProvider).playbackQueue;
    if (index < 0 || index >= queue.length) return;

    queueNotifier.setCurrentIndex(index);
    final trackId = queue[index];
    final track = indexedTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    playTrack(
      trackId,
      indexedTracks: indexedTracks,
      trackPath: track.path,
      regenerateQueue: false,
    );
  }

  void toggleRepeatMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = switch (current.repeatMode) {
      'Off' => 'All',
      'All' => 'One',
      _ => 'Off',
    };
    state = AsyncData(current.copyWith(repeatMode: next));
  }

  // ── Sincronização de estado vindo do player ───────────────────────────────

  void syncPlayingState(bool playing) {
    final current = state.valueOrNull;
    if (current == null || current.isPlaying == playing) return;
    state = AsyncData(current.copyWith(isPlaying: playing));
  }

  void updateCurrentPosition(int ms) {
    final current = state.valueOrNull;
    if (current == null || current.currentPositionMs == ms) return;
    state = AsyncData(current.copyWith(currentPositionMs: ms));
  }

  void updateTrackDuration(int ms) {
    final current = state.valueOrNull;
    if (current == null || current.trackDurationMs == ms) return;
    state = AsyncData(current.copyWith(trackDurationMs: ms));
  }

  Future<void> clearRecentlyPlayed() async {
    await RecentlyPlayedService.clear();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(recentlyPlayedIds: []));
  }

  Future<void> saveCurrentPositionForResume(int ms) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(lastSeekPositionMs: ms));
    }
    await _saveLastSeekPosition(ms);
  }

  /// Setter direto de posição de resume, usado pelo audio handler ao
  /// consumir o valor salvo (equivalente ao antigo `lastSeekPositionMs =`).
  void consumeLastSeekPosition() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(lastSeekPositionMs: 0));
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  Future<void> _saveLastPlayedMusicId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastPlayedMusicIdKey, id);
  }

  Future<void> _saveLastSeekPosition(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeekPositionMsKey, ms);
  }
}
