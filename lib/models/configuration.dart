import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/services/equalizer_service.dart';
import 'package:music_wave_player/services/favorites_service.dart';
import 'package:music_wave_player/services/indexing_service.dart';
import 'package:music_wave_player/services/metadata_repair_service.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:music_wave_player/services/playback_controller.dart';
import 'package:music_wave_player/services/queue_manager.dart';
import 'package:music_wave_player/services/recently_played_service.dart';
import 'package:music_wave_player/services/sort_service.dart';
import 'package:music_wave_player/services/track_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:music_wave_player/services/sort_service.dart'
    show SortOption, SortOptionLabel;
export 'package:music_wave_player/services/equalizer_service.dart'
    show EqualizerPreset, EqualizerPresetLabel, EqualizerBand;

const String _kRootDirectoryKey = 'rootDirectoryPath';
const String _kLastScanDateKey = 'lastScanDate';
const String _kLastPlayedMusicIdKey = 'lastPlayedMusicId';
const String _kLastSeekPositionMsKey = 'lastSeekPositionMs';
const String _kCrossfadeDurationKey = 'crossfade_duration';
const String _kFadeOnPauseResumeKey = 'fade_on_pause_resume';

enum IndexingStatus {
  idle,
  scanning,
  processingMetadata,
  calculatingLoudness,
  complete,
  error,
}

/// Ponto central de estado da aplicação. Agrega os serviços especializados
/// e expõe uma API unificada para a UI via [ChangeNotifier].
///
/// No Riverpod, esta classe será dissolvida: cada serviço vira seu próprio
/// [Notifier], e a UI observa apenas os providers que precisa.
class Configuration with ChangeNotifier, DiagnosticableTreeMixin {
  // ── Serviços ──────────────────────────────────────────────────────────────

  late final QueueManager _queue;
  late final PlaybackController _playback;
  late final SortService _sort;
  late final EqualizerService _equalizer;

  MusicAudioHandler? _audioHandler;

  // ── Estado local ──────────────────────────────────────────────────────────

  String? _rootDirectory;
  DateTime? _lastScanDate;
  IndexingStatus _indexingStatus = IndexingStatus.idle;
  List<MusicTrack> _indexedTracks = [];
  int _indexedFileCount = 0;
  int _indexedFileTotal = 0;
  String? _processingStage;
  int _loudnessDone = 0;
  int _loudnessTotal = 0;
  bool _isShuffleActive = false;
  bool _isLoading = true;
  double _playbackSpeed = 1.0;
  int _crossfadeDuration = 0;
  bool _fadeOnPauseResume = false;

  // Throttle da aplicação do EQ no áudio durante o arraste do slider —
  // evita reconfigurar a cadeia de filtros do ffmpeg a cada frame.
  Timer? _eqApplyTimer;
  bool _eqApplyPending = false;

  Configuration.empty() {
    _queue = QueueManager();
    _sort = SortService(onStateChanged: notifyListeners);
    _equalizer = EqualizerService(onStateChanged: notifyListeners);
    _playback = PlaybackController(
      queue: _queue,
      onStateChanged: notifyListeners,
      onTrackChanged: (_, __) => notifyListeners(),
    );
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get rootDirectory => _rootDirectory;
  DateTime? get lastScanDate => _lastScanDate;
  IndexingStatus get indexingStatus => _indexingStatus;
  int get indexedFileCount => _indexedFileCount;
  int get indexedFileTotal => _indexedFileTotal;
  String? get processingStage => _processingStage;
  int get loudnessDone => _loudnessDone;
  int get loudnessTotal => _loudnessTotal;
  List<MusicTrack> get indexedTracks => _indexedTracks;
  bool get isLoading => _isLoading;
  bool get isShuffleActive => _isShuffleActive;
  bool get isPlaying => _playback.isPlaying;
  String get repeatMode => _playback.repeatMode;
  int get currentQueueIndex => _queue.currentQueueIndex;
  List<int> get playbackQueue => _queue.playbackQueue;
  int get currentPositionMs => _playback.currentPositionMs;
  int get trackDurationMs => _playback.trackDurationMs;
  int? get lastPlayedMusicId => _playback.lastPlayedMusicId;
  int get lastSeekPositionMs => _playback.lastSeekPositionMs;
  double get playbackSpeed => _playbackSpeed;
  int get crossfadeDuration => _crossfadeDuration;
  bool get fadeOnPauseResume => _fadeOnPauseResume;
  MusicAudioHandler? get audioHandler => _audioHandler;

  SortOption get sortMusics => _sort.sortMusics;
  SortOption get sortPlaylists => _sort.sortPlaylists;
  SortOption get sortAlbums => _sort.sortAlbums;
  SortOption get sortArtists => _sort.sortArtists;

  // ── Equalizador ───────────────────────────────────────────────────────────

  bool get eqEnabled => _equalizer.enabled;
  EqualizerPreset get eqActivePreset => _equalizer.activePreset;
  List<double> get eqBandGains => _equalizer.bandGains;
  List<EqualizerBand> get eqBandDefinitions => EqualizerService.bands;
  double get eqMinGain => EqualizerService.minGain;
  double get eqMaxGain => EqualizerService.maxGain;
  double get eqFlatGain => EqualizerService.flatGain;

  String? get currentTrackPath => currentTrack?.path;

  MusicTrack? get currentTrack {
    final id = _playback.lastPlayedMusicId;
    if (id == null) return null;
    return _indexedTracks.where((t) => t.id == id).firstOrNull;
  }

  List<MusicTrack> get recentlyPlayedTracks => _playback.recentlyPlayedIds
      .map((id) => _indexedTracks.where((t) => t.id == id).firstOrNull)
      .whereType<MusicTrack>()
      .toList();

  // ── Setters ───────────────────────────────────────────────────────────────

  set audioHandler(MusicAudioHandler handler) {
    _audioHandler = handler;
    _playback.audioHandler = handler;
  }

  set lastSeekPositionMs(int ms) => _playback.lastSeekPositionMs = ms;

  set rootDirectory(String path) {
    if (_rootDirectory == path) return;
    _rootDirectory = path;
    _indexingStatus = IndexingStatus.idle;
    notifyListeners();
    _saveRootDirectory(path);
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> loadFromStorageAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rootDirectory = prefs.getString(_kRootDirectoryKey);

      final ts = prefs.getInt(_kLastScanDateKey);
      _lastScanDate = ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : null;

      _playback.initLastPlayed(
        prefs.getInt(_kLastPlayedMusicIdKey),
        prefs.getInt(_kLastSeekPositionMsKey) ?? 0,
      );
      _playback.initRecentlyPlayed(await RecentlyPlayedService.load());

      await FavoritesService.ensurePlaylist();

      _sort.init(
        musics: SortOptionLabel.fromKey(
          prefs.getString('sort_musics') ?? '',
          SortOption.titleAsc,
        ),
        playlists: SortOptionLabel.fromKey(
          prefs.getString('sort_playlists') ?? '',
          SortOption.titleAsc,
        ),
        albums: SortOptionLabel.fromKey(
          prefs.getString('sort_albums') ?? '',
          SortOption.titleAsc,
        ),
        artists: SortOptionLabel.fromKey(
          prefs.getString('sort_artists') ?? '',
          SortOption.titleAsc,
        ),
      );

      _crossfadeDuration = prefs.getInt(_kCrossfadeDurationKey) ?? 0;
      _fadeOnPauseResume = prefs.getBool(_kFadeOnPauseResumeKey) ?? false;

      await _equalizer.loadFromStorage();

      await MetadataRepairService.runIfNeeded();

      await loadIndexedTracks();

      if (_playback.lastPlayedMusicId != null && currentTrackPath != null) {
        // Só restaura a faixa se o player não estiver tocando —
        // evita interromper reprodução em andamento após swipe-to-kill + reabrir.
        final isAlreadyPlaying = _audioHandler?.player.state.playing ?? false;
        if (!isAlreadyPlaying) {
          await _audioHandler?.loadTrack(currentTrackPath!);
        } else {
          syncPlayingState(true);
        }
      }

      _audioHandler?.updateCrossfade(_crossfadeDuration);
      _audioHandler?.updateFadeOnPauseResume(_fadeOnPauseResume);
      await _audioHandler?.applyEqualizer(
        _equalizer.enabled,
        _equalizer.superequalizerParams,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Indexação ─────────────────────────────────────────────────────────────

  Future<void> loadIndexedTracks() async {
    try {
      _indexedTracks = await MusicDatabase.instance.readAllTracks();
      _indexedFileCount = _indexedTracks.length;
      if (_indexedFileCount > 0) {
        _indexingStatus = IndexingStatus.complete;
        _regenerateQueue();
      } else if (_rootDirectory != null) {
        _indexingStatus = IndexingStatus.idle;
      }
    } catch (e) {
      debugPrint('Erro ao carregar faixas: $e');
      _indexingStatus = IndexingStatus.error;
    } finally {
      notifyListeners();
    }
  }

  bool get _isIndexingBusy =>
      _indexingStatus == IndexingStatus.scanning ||
      _indexingStatus == IndexingStatus.processingMetadata ||
      _indexingStatus == IndexingStatus.calculatingLoudness;

  Future<void> startIndexing() async {
    if (_rootDirectory == null || _isIndexingBusy) return;

    _indexingStatus = IndexingStatus.scanning;
    _indexedTracks = [];
    _indexedFileCount = 0;
    _indexedFileTotal = 0;
    _processingStage = null;
    _loudnessDone = 0;
    _loudnessTotal = 0;
    notifyListeners();

    await IndexingService.startIndexing(
      rootDirectory: _rootDirectory!,
      onProgress: (done, total) {
        _indexedFileCount = done;
        _indexedFileTotal = total;
        notifyListeners();
      },
      onMetadataStage: (stage) {
        _indexingStatus = IndexingStatus.processingMetadata;
        _processingStage = stage;
        notifyListeners();
      },
      onLoudnessProgress: (done, total) {
        _indexingStatus = IndexingStatus.calculatingLoudness;
        _loudnessDone = done;
        _loudnessTotal = total;
        notifyListeners();
      },
      onComplete: (tracks, scanDate) {
        _indexedTracks = tracks;
        _indexedFileCount = tracks.length;
        _indexedFileTotal = tracks.length;
        _indexingStatus = IndexingStatus.complete;
        _lastScanDate = scanDate;
        _regenerateQueue();
        notifyListeners();
      },
      onError: (e) {
        _indexingStatus = IndexingStatus.error;
        debugPrint('Erro ao varrer: $e');
        notifyListeners();
      },
    );
  }

  // ── Fila ──────────────────────────────────────────────────────────────────

  void _regenerateQueue() {
    _queue.regenerate(
      tracks: _indexedTracks,
      shuffleActive: _isShuffleActive,
      currentTrackId: _playback.lastPlayedMusicId,
      onCurrentCleared: (_) {
        // A faixa atual foi removida da biblioteca — limpa o estado
      },
    );
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _queue.reorder(oldIndex, newIndex, _playback.lastPlayedMusicId);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    final result = _queue.remove(
      index: index,
      currentTrackId: _playback.lastPlayedMusicId,
    );
    switch (result) {
      case QueueRemovePause():
        _audioHandler?.pause();
      case QueueRemovePlayTrack(:final trackId):
        playTrack(trackId, regenerateQueue: false);
      case QueueRemoveNone():
        break;
    }
    notifyListeners();
  }

  void jumpToQueueIndex(int index) {
    if (index < 0 || index >= _queue.playbackQueue.length) return;
    _queue.setCurrentIndex(index);
    playTrack(_queue.playbackQueue[index], regenerateQueue: false);
  }

  void clearQueue() {
    _queue.clear(_playback.lastPlayedMusicId);
    notifyListeners();
  }

  void insertAfterCurrent(List<int> ids) {
    _queue.insertAfterCurrent(ids);
    notifyListeners();
  }

  void addToEndOfQueue(List<int> ids) {
    _queue.addToEnd(ids);
    notifyListeners();
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  void toggleShuffle() {
    _isShuffleActive = !_isShuffleActive;
    if (_isShuffleActive) {
      _queue.applyShuffle(_queue.currentQueueIndex);
    } else {
      _queue.restoreOriginal(_playback.lastPlayedMusicId);
    }
    notifyListeners();
  }

  // ── Reprodução ────────────────────────────────────────────────────────────

  Future<void> playTrack(int musicId, {bool regenerateQueue = true}) async {
    final track = _indexedTracks.where((t) => t.id == musicId).firstOrNull;
    if (track == null) return;
    await _playback.playTrack(
      musicId,
      indexedTracks: _indexedTracks,
      trackPath: track.path,
      regenerateQueue: regenerateQueue,
    );
  }

  Future<void> playPlaylist(Playlist playlist) async {
    await _playback.playPlaylist(
      playlist,
      indexedTracks: _indexedTracks,
      shuffleActive: _isShuffleActive,
      pathForId: (id) =>
          _indexedTracks.where((t) => t.id == id).firstOrNull?.path,
    );
  }

  Future<void> playTracks(List<MusicTrack> tracks) async {
    await _playback.playTracks(
      tracks,
      shuffleActive: _isShuffleActive,
      pathForId: (id) =>
          _indexedTracks.where((t) => t.id == id).firstOrNull?.path,
    );
  }

  void togglePlayPause() {
    _playback.togglePlayPause(
      indexedTracks: _indexedTracks,
      currentTrackPath: currentTrackPath,
    );
  }

  void playNextTrack() {
    _playback.playNextTrack(indexedTracks: _indexedTracks);
  }

  void playPreviousTrack() {
    _playback.playPreviousTrack(indexedTracks: _indexedTracks);
  }

  void toggleRepeatMode() => _playback.toggleRepeatMode();

  void trackDidFinish() {
    _playback.trackDidFinish(indexedTracks: _indexedTracks);
  }

  void seekTo(int ms) => _audioHandler?.seek(Duration(milliseconds: ms));

  void syncPlayingState(bool playing) => _playback.syncPlayingState(playing);

  void updateCurrentPosition(int ms) => _playback.updateCurrentPosition(ms);

  void updateTrackDuration(int ms) => _playback.updateTrackDuration(ms);

  Future<void> saveCurrentPositionForResume(int ms) =>
      _playback.saveCurrentPositionForResume(ms);

  Future<void> clearRecentlyPlayed() => _playback.clearRecentlyPlayed();

  // ── Ordenação ─────────────────────────────────────────────────────────────

  List<MusicTrack> applySortToTracks(
    List<MusicTrack> tracks,
    SortOption option,
  ) => SortService.apply(tracks, option);

  Future<void> setSortMusics(SortOption option) => _sort.setSortMusics(option);
  Future<void> setSortPlaylists(SortOption option) =>
      _sort.setSortPlaylists(option);
  Future<void> setSortAlbums(SortOption option) => _sort.setSortAlbums(option);
  Future<void> setSortArtists(SortOption option) =>
      _sort.setSortArtists(option);

  // ── Velocidade / Crossfade / Fade ─────────────────────────────────────────

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _audioHandler?.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    _crossfadeDuration = seconds;
    _audioHandler?.updateCrossfade(seconds);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCrossfadeDurationKey, seconds);
  }

  Future<void> setFadeOnPauseResume(bool enabled) async {
    _fadeOnPauseResume = enabled;
    _audioHandler?.updateFadeOnPauseResume(enabled);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFadeOnPauseResumeKey, enabled);
  }

  // ── Equalizador ───────────────────────────────────────────────────────────

  Future<void> setEqEnabled(bool value) async {
    await _equalizer.setEnabled(value);
    await _audioHandler?.applyEqualizer(
      _equalizer.enabled,
      _equalizer.superequalizerParams,
    );
  }

  Future<void> setEqPreset(EqualizerPreset preset) async {
    await _equalizer.setPreset(preset);
    await _audioHandler?.applyEqualizer(
      _equalizer.enabled,
      _equalizer.superequalizerParams,
    );
  }

  /// Chamado a cada movimento do slider (onChanged). Atualiza a banda só em
  /// memória e aplica no áudio com throttle, para manter o arraste fluido
  /// sem sobrecarregar o ffmpeg reconfigurando a cadeia de filtros a cada frame.
  void previewEqBandGain(int index, double gain) {
    _equalizer.previewBandGain(index, gain);
    _throttledApplyEqualizer();
  }

  /// Chamado ao soltar o slider (onChangeEnd). Persiste o valor final e
  /// garante que o áudio reflita exatamente o último valor escolhido.
  Future<void> setEqBandGain(int index, double gain) async {
    _eqApplyTimer?.cancel();
    _eqApplyTimer = null;
    _eqApplyPending = false;
    await _equalizer.setBandGain(index, gain);
    await _applyEqualizerToAudio();
  }

  Future<void> _applyEqualizerToAudio() async {
    await _audioHandler?.applyEqualizer(
      _equalizer.enabled,
      _equalizer.superequalizerParams,
    );
  }

  /// Throttle leading+trailing: aplica imediatamente na primeira chamada,
  /// depois no máximo uma vez a cada 120ms, garantindo que o último valor
  /// arrastado sempre seja aplicado ao final (chamada trailing).
  void _throttledApplyEqualizer() {
    if (_eqApplyTimer != null) {
      _eqApplyPending = true;
      return;
    }
    _applyEqualizerToAudio();
    _eqApplyTimer = Timer(const Duration(milliseconds: 120), () {
      _eqApplyTimer = null;
      if (_eqApplyPending) {
        _eqApplyPending = false;
        _throttledApplyEqualizer();
      }
    });
  }

  Future<void> resetEqualizer() async {
    await _equalizer.reset();
    await _audioHandler?.applyEqualizer(
      _equalizer.enabled,
      _equalizer.superequalizerParams,
    );
  }

  // ── Avaliação ─────────────────────────────────────────────────────────────

  Future<void> setRating(int trackId, double rating) async {
    final idx = _indexedTracks.indexWhere((t) => t.id == trackId);
    if (idx == -1) return;
    final updated = await TrackRepository.setRating(
      _indexedTracks[idx],
      rating,
    );
    _indexedTracks[idx] = updated;
    notifyListeners();
  }

  // ── Ocultar / Reexibir ────────────────────────────────────────────────────

  Future<void> hideTracks(List<int> ids) async {
    if (ids.isEmpty) return;
    await TrackRepository.hideTracks(ids);
    _indexedTracks.removeWhere((t) => ids.contains(t.id));
    _queue.removeTracksById(ids);
    _regenerateQueue();
    notifyListeners();
  }

  Future<void> unhideTracks(List<int> ids) async {
    await TrackRepository.unhideTracks(ids);
    await loadIndexedTracks();
  }

  Future<void> unhideAllTracks() async {
    await TrackRepository.unhideAllTracks();
    await loadIndexedTracks();
  }

  // ── Edição de metadados ───────────────────────────────────────────────────

  Future<bool> editTrack({
    required MusicTrack track,
    required String newTitle,
    required String newArtist,
    required String newAlbum,
    required BuildContext context,
  }) async {
    final result = await TrackRepository.editTrack(
      track: track,
      newTitle: newTitle,
      newArtist: newArtist,
      newAlbum: newAlbum,
    );

    switch (result) {
      case TrackEditSuccess(:final updatedTrack):
        final idx = _indexedTracks.indexWhere((t) => t.id == track.id);
        if (idx != -1) {
          _indexedTracks[idx] = updatedTrack;
          _indexedTracks.sort(
            (a, b) => MusicDatabase.naturalCompare(
              a.title.toLowerCase(),
              b.title.toLowerCase(),
            ),
          );
          notifyListeners();
        }
        if (_playback.lastPlayedMusicId == track.id) {
          await _audioHandler?.loadTrack(track.path);
        }
        if (context.mounted) {
          _showSnack(
            context,
            'Informações salvas com sucesso!',
            isSuccess: true,
          );
        }
        return true;

      case TrackEditFailure(:final reason):
        if (context.mounted) _showSnack(context, reason);
        return false;
    }
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Persistência local ────────────────────────────────────────────────────

  Future<void> _saveRootDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRootDirectoryKey, path);
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('rootDirectory', _rootDirectory));
    properties.add(EnumProperty('indexingStatus', _indexingStatus));
    properties.add(IntProperty('indexedFileCount', _indexedFileCount));
    properties.add(IntProperty('indexedFileTotal', _indexedFileTotal));
    properties.add(StringProperty('processingStage', _processingStage));
    properties.add(IntProperty('loudnessDone', _loudnessDone));
    properties.add(IntProperty('loudnessTotal', _loudnessTotal));
  }
}
