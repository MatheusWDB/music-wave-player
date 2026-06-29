import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:music_wave_player/services/queue_manager.dart';
import 'package:music_wave_player/services/recently_played_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLastPlayedMusicIdKey = 'lastPlayedMusicId';
const String _kLastSeekPositionMsKey = 'lastSeekPositionMs';

/// Coordena as ações de reprodução: play, pause, next, previous, repeat.
///
/// Depende de [QueueManager] para navegação na fila e de [MusicAudioHandler]
/// para controle do player de áudio. Comunica mudanças de estado via [onStateChanged].
/// No Riverpod, vira um [Notifier] que expõe estado imutável de reprodução.
class PlaybackController {
  final QueueManager _queue;
  MusicAudioHandler? _audioHandler;

  int? _lastPlayedMusicId;
  int _lastSeekPositionMs = 0;
  int _currentPositionMs = 0;
  int _trackDurationMs = 0;
  bool _isPlaying = false;
  String _repeatMode = 'Off';
  List<int> _recentlyPlayedIds = [];

  /// Chamado sempre que o estado de reprodução muda, para que o
  /// [Configuration] possa emitir [notifyListeners].
  final void Function() onStateChanged;

  /// Chamado quando a faixa atual muda, passando o novo [trackId] e [trackPath].
  final void Function(int trackId, String trackPath) onTrackChanged;

  PlaybackController({
    required QueueManager queue,
    required this.onStateChanged,
    required this.onTrackChanged,
  }) : _queue = queue;

  // ── Getters ───────────────────────────────────────────────────────────────

  int? get lastPlayedMusicId => _lastPlayedMusicId;
  int get lastSeekPositionMs => _lastSeekPositionMs;
  int get currentPositionMs => _currentPositionMs;
  int get trackDurationMs => _trackDurationMs;
  bool get isPlaying => _isPlaying;
  String get repeatMode => _repeatMode;
  List<int> get recentlyPlayedIds => List.unmodifiable(_recentlyPlayedIds);

  set audioHandler(MusicAudioHandler handler) => _audioHandler = handler;
  set lastSeekPositionMs(int ms) => _lastSeekPositionMs = ms;

  // ── Inicialização ─────────────────────────────────────────────────────────

  void initRecentlyPlayed(List<int> ids) => _recentlyPlayedIds = ids;

  void initLastPlayed(int? id, int seekMs) {
    _lastPlayedMusicId = id;
    _lastSeekPositionMs = seekMs;
  }

  // ── Reprodução ────────────────────────────────────────────────────────────

  Future<void> playTrack(
    int musicId, {
    required List<MusicTrack> indexedTracks,
    required String? trackPath,
    bool regenerateQueue = true,
  }) async {
    final exists = indexedTracks.any((t) => t.id == musicId);
    if (!exists || trackPath == null) return;

    if (_lastPlayedMusicId != musicId) {
      if (_lastPlayedMusicId != null) {
        _recentlyPlayedIds = await RecentlyPlayedService.push(
          _lastPlayedMusicId!,
          _recentlyPlayedIds,
        );
      }

      if (regenerateQueue) {
        _queue.regenerate(
          tracks: indexedTracks,
          shuffleActive: false,
          currentTrackId: musicId,
          onCurrentCleared: (_) {},
        );
      }

      _queue.syncCurrentIndex(musicId);
      _lastPlayedMusicId = musicId;
      _lastSeekPositionMs = 0;
      _currentPositionMs = 0;
      _trackDurationMs = 0;

      await _saveLastPlayedMusicId(musicId);
      await _audioHandler?.loadTrack(trackPath);
      onTrackChanged(musicId, trackPath);
    }

    _isPlaying = true;
    onStateChanged();
    _audioHandler?.play();
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

    _queue.setQueue(orderedIds: validIds, shuffleActive: shuffleActive);
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

    _queue.setQueue(orderedIds: visibleIds, shuffleActive: shuffleActive);
    await _startFromQueueTop(pathForId: pathForId);
  }

  Future<void> _startFromQueueTop({
    required String? Function(int id) pathForId,
  }) async {
    final firstId = _queue.playbackQueue.first;
    final path = pathForId(firstId);
    if (path == null) return;

    _lastPlayedMusicId = firstId;
    _lastSeekPositionMs = 0;
    _currentPositionMs = 0;
    _trackDurationMs = 0;

    await _saveLastPlayedMusicId(firstId);
    await _audioHandler?.loadTrack(path);
    onTrackChanged(firstId, path);

    _isPlaying = true;
    onStateChanged();
    _audioHandler?.play();
  }

  // ── Controles ─────────────────────────────────────────────────────────────

  void togglePlayPause({
    required List<MusicTrack> indexedTracks,
    required String? currentTrackPath,
  }) {
    // Nenhuma faixa carregada — inicia com a primeira da fila
    if (_lastPlayedMusicId == null && indexedTracks.isNotEmpty) {
      final queue = _queue.playbackQueue;
      if (queue.isEmpty) return;

      final id = queue.first;
      _lastPlayedMusicId = id;
      _queue.setCurrentIndex(0);
      _saveLastPlayedMusicId(id);
      _isPlaying = true;
      onStateChanged();

      if (currentTrackPath != null) {
        _audioHandler?.loadTrack(currentTrackPath).then((_) {
          _audioHandler?.play();
        });
      }
      return;
    }

    if (_lastPlayedMusicId == null) return;

    _isPlaying = !_isPlaying;
    onStateChanged();

    if (_isPlaying) {
      // Se o player completou a faixa (ex: temporizador pausou no fim),
      // avança para a próxima em vez de retomar do zero
      final isCompleted = _audioHandler?.player.state.completed ?? false;
      if (isCompleted) {
        playNextTrack(indexedTracks: indexedTracks);
      } else {
        _audioHandler?.play();
      }
    } else {
      _saveLastSeekPosition(_currentPositionMs);
      _audioHandler?.pause();
    }
  }

  void playNextTrack({required List<MusicTrack> indexedTracks}) {
    final queue = _queue.playbackQueue;
    if (queue.isEmpty) return;

    int next = _queue.currentQueueIndex + 1;
    if (next >= queue.length) {
      if (_repeatMode == 'All') {
        next = 0;
      } else {
        _audioHandler?.pause();
        return;
      }
    }

    _queue.setCurrentIndex(next);
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
    final queue = _queue.playbackQueue;
    if (queue.isEmpty) return;

    // Se passou de 3s, volta ao início da faixa atual
    if (_currentPositionMs > 3000) {
      _audioHandler?.seek(Duration.zero);
      return;
    }

    int prev = _queue.currentQueueIndex - 1;
    if (prev < 0) {
      if (_repeatMode == 'All') {
        prev = queue.length - 1;
      } else {
        _audioHandler?.seek(Duration.zero);
        return;
      }
    }

    _queue.setCurrentIndex(prev);
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
    if (_lastPlayedMusicId == null || _queue.playbackQueue.isEmpty) return;
    if (_repeatMode == 'One') {
      final track = indexedTracks
          .where((t) => t.id == _lastPlayedMusicId)
          .firstOrNull;
      if (track != null) {
        playTrack(
          _lastPlayedMusicId!,
          indexedTracks: indexedTracks,
          trackPath: track.path,
        );
      }
      return;
    }
    playNextTrack(indexedTracks: indexedTracks);
  }

  void toggleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      'Off' => 'All',
      'All' => 'One',
      _ => 'Off',
    };
    onStateChanged();
  }

  // ── Sincronização de estado vindo do player ───────────────────────────────

  void syncPlayingState(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      onStateChanged();
    }
  }

  void updateCurrentPosition(int ms) {
    if (_currentPositionMs != ms) {
      _currentPositionMs = ms;
      onStateChanged();
    }
  }

  void updateTrackDuration(int ms) {
    if (_trackDurationMs != ms) {
      _trackDurationMs = ms;
      onStateChanged();
    }
  }

  Future<void> clearRecentlyPlayed() async {
    await RecentlyPlayedService.clear();
    _recentlyPlayedIds = [];
    onStateChanged();
  }

  Future<void> saveCurrentPositionForResume(int ms) async {
    _lastSeekPositionMs = ms;
    await _saveLastSeekPosition(ms);
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
