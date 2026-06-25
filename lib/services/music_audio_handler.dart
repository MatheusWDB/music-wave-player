import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/services/timer_service.dart';

class MusicAudioHandler {
  final Configuration _config;
  SleepTimerService? _timerService;

  late final Player player;

  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _mediaCommandSub;

  Timer? _periodicSaveTimer;

  int? _sessionTrackId;
  int _sessionSecondsAccumulated = 0;
  int _sessionSecondsSaved = 0;
  DateTime? _sessionStartedAt;

  MusicAudioHandler(this._config) {
    MpvAudioKit.ensureInitialized();
    player = Player(
      configuration: const PlayerConfiguration(
        autoPlay: false,
        logLevel: LogLevel.warn,
      ),
    );
    _initListeners();
  }

  void setTimerService(SleepTimerService timerService) {
    _timerService = timerService;
  }

  void _initListeners() {
    // Posição e duração
    _positionSub = player.stream.position.listen((pos) {
      _config.updateCurrentPosition(pos.inMilliseconds);
    });

    _durationSub = player.stream.duration.listen((dur) {
      if (dur > Duration.zero) {
        _config.updateTrackDuration(dur.inMilliseconds);
      }
    });

    // Estado de reprodução
    _playingSub = player.stream.playing.listen((playing) {
      if (playing) {
        _resumeSession();
        _startPeriodicSave();
      } else {
        _pauseSession();
        _stopPeriodicSave();
      }
      _config.syncPlayingState(playing);
    });

    // Fim de faixa
    _completedSub = player.stream.completed.listen((completed) {
      if (!completed) return;

      final shouldPause = _timerService?.onTrackFinished() ?? false;
      if (shouldPause) {
        player.pause();
        return;
      }
      _config.trackDidFinish();
    });

    // Comandos da notificação/tela de bloqueio
    _mediaCommandSub = player.stream.mediaSessionCommands.listen((command) {
      switch (command) {
        case MediaSessionCommandNext():
          skipToNext();
        case MediaSessionCommandPrevious():
          skipToPrevious();
        case MediaSessionCommandSeekTo(:final position):
          seek(position);
        default:
          break;
      }
    });
  }

  // ── Controles de reprodução ───────────────────────────────────────────────

  Future<void> loadTrack(String path) async {
    await _flushSession();

    final track = _config.currentTrack;
    if (track?.id != null) _startSession(track!.id!);

    final uri = 'file://$path';

    // Aguarda o MPV carregar o arquivo e expor a duração antes de retornar,
    // garantindo que play() seja chamado depois que o player está pronto.
    final completer = Completer<void>();
    StreamSubscription? sub;
    sub = player.stream.duration.listen((d) {
      if (d > Duration.zero && !completer.isCompleted) {
        completer.complete();
        sub?.cancel();
      }
    });

    await player.open(Media(uri), play: false);

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        sub?.cancel();
      },
    );

    await player.setMediaSession(const MediaSession());

    if (_config.playbackSpeed != 1.0) {
      await player.setRate(_config.playbackSpeed);
    }

    if (_config.lastSeekPositionMs > 0) {
      await player.seek(Duration(milliseconds: _config.lastSeekPositionMs));
      _config.lastSeekPositionMs = 0;
    }

    // Força atualização da duração e posição no config após carregamento
    _config.updateTrackDuration(player.state.duration.inMilliseconds);
    _config.updateCurrentPosition(player.state.position.inMilliseconds);
  }

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setSpeed(double speed) => player.setRate(speed);

  Future<void> skipToNext() async => _config.playNextTrack();

  Future<void> skipToPrevious() async => _config.playPreviousTrack();

  Future<void> stop() async {
    _stopPeriodicSave();
    await _flushSession();
    await _config.saveCurrentPositionForResume(
      player.state.position.inMilliseconds,
    );
    await player.stop();
  }

  // ── Sessão de reprodução ──────────────────────────────────────────────────

  void _resumeSession() {
    if (_sessionTrackId == null) {
      final id = _config.currentTrack?.id;
      if (id == null) return;
      _startSession(id);
    }
    if (_sessionStartedAt != null) return;
    _sessionStartedAt = DateTime.now();
  }

  void _pauseSession() {
    if (_sessionStartedAt == null) return;
    final sinceResume = DateTime.now()
        .difference(_sessionStartedAt!)
        .inMilliseconds;
    if (sinceResume < 1000) return;
    final elapsed = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    _sessionSecondsAccumulated += elapsed;
    _sessionStartedAt = null;
  }

  void _startSession(int trackId) {
    _sessionTrackId = trackId;
    _sessionSecondsAccumulated = 0;
    _sessionSecondsSaved = 0;
    _sessionStartedAt = null;
  }

  Future<void> _saveSessionDelta() async {
    if (_sessionTrackId == null) return;
    int current = _sessionSecondsAccumulated;
    if (_sessionStartedAt != null) {
      current += DateTime.now().difference(_sessionStartedAt!).inSeconds;
    }
    final delta = current - _sessionSecondsSaved;
    if (delta <= 0) return;
    await PlaySessionDatabase.instance.insertSession(
      trackId: _sessionTrackId!,
      secondsPlayed: delta,
    );
    _sessionSecondsSaved += delta;
  }

  Future<void> _flushSession() async {
    _pauseSession();
    final trackId = _sessionTrackId;
    if (trackId != null) {
      final remaining = _sessionSecondsAccumulated - _sessionSecondsSaved;
      if (remaining > 0) {
        await PlaySessionDatabase.instance.insertSession(
          trackId: trackId,
          secondsPlayed: remaining,
        );
      }
    }
    _sessionSecondsAccumulated = 0;
    _sessionSecondsSaved = 0;
    _sessionTrackId = null;
    _sessionStartedAt = null;
  }

  // ── Save periódico ────────────────────────────────────────────────────────

  void _startPeriodicSave() {
    _periodicSaveTimer ??= Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      await _config.saveCurrentPositionForResume(
        player.state.position.inMilliseconds,
      );
      await _saveSessionDelta();
    });
  }

  void _stopPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _stopPeriodicSave();
    await _flushSession();
    await _positionSub?.cancel();
    await _playingSub?.cancel();
    await _completedSub?.cancel();
    await _durationSub?.cancel();
    await _mediaCommandSub?.cancel();
    await player.dispose();
  }
}
