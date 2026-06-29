import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/services/timer_service.dart';

class MusicAudioHandler {
  final Configuration _config;
  SleepTimerService? _timerService;

  late final Player player;

  // ── Crossfade / fade ──────────────────────────────────────────────────────
  int _crossfadeDuration = 0;
  bool _fadeOnPauseResume = false;

  Timer? _crossfadeTimer;
  bool _crossfadeInProgress = false;
  // Evita disparar o fade out de fim de faixa mais de uma vez por faixa
  bool _endOfTrackFadeStarted = false;

  // Volume base — separado do volume do sistema
  final double _baseVolume = 100.0;

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
    _applyGapless();
  }

  Future<void> _applyGapless() async {
    await player.setGapless(Gapless.yes);
    await player.setPrefetchPlaylist(true);
    // Registra a MediaSession imediatamente para que os controles
    // da notificação persistam mesmo antes de uma faixa ser carregada.
    await player.setMediaSession(const MediaSession());
  }

  void setTimerService(SleepTimerService timerService) {
    _timerService = timerService;
  }

  void updateCrossfade(int durationSeconds) {
    _crossfadeDuration = durationSeconds;
  }

  void updateFadeOnPauseResume(bool enabled) {
    _fadeOnPauseResume = enabled;
  }

  // ── Lógica de fade ────────────────────────────────────────────────────────

  /// Fade out verdadeiramente awaitable via Completer interno.
  /// Só completa quando o volume chega a 0.
  Future<void> _fadeOut(int durationSeconds) async {
    _crossfadeTimer?.cancel();
    _crossfadeInProgress = true;

    final completer = Completer<void>();
    const steps = 20;
    final stepMs = (durationSeconds * 1000) ~/ steps;
    final volumeStep = _baseVolume / steps;
    double current = _baseVolume;

    _crossfadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) async {
      current -= volumeStep;
      if (current <= 0) {
        current = 0;
        t.cancel();
        await player.setVolume(0);
        _crossfadeInProgress = false;
        if (!completer.isCompleted) completer.complete();
      } else {
        await player.setVolume(current);
      }
    });

    await completer.future;
  }

  /// Fade in de 0 até [_baseVolume] ao longo de [durationSeconds].
  Future<void> _fadeIn(int durationSeconds) async {
    _crossfadeTimer?.cancel();
    _crossfadeInProgress = true;
    await player.setVolume(0);

    const steps = 20;
    final stepMs = (durationSeconds * 1000) ~/ steps;
    final volumeStep = _baseVolume / steps;
    double current = 0;

    _crossfadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) async {
      current += volumeStep;
      if (current >= _baseVolume) {
        current = _baseVolume;
        t.cancel();
        await player.setVolume(_baseVolume);
        _crossfadeInProgress = false;
      } else {
        await player.setVolume(current);
      }
    });
    // Não awaita — o fade in corre em paralelo com a reprodução
  }

  /// Fade out e executa [callback] ao terminar.
  /// Usado pelo trackDidFinish para crossfade no fim natural da faixa.
  Future<void> fadeOutThenCall(VoidCallback callback) async {
    if (_crossfadeDuration > 0) {
      await _fadeOut(_crossfadeDuration);
    }
    callback();
  }

  void _initListeners() {
    _positionSub = player.stream.position.listen((pos) {
      _config.updateCurrentPosition(pos.inMilliseconds);

      // Dispara fade out nos últimos X segundos da faixa atual
      if (_crossfadeDuration > 0 &&
          !_endOfTrackFadeStarted &&
          !_crossfadeInProgress &&
          player.state.playing) {
        final duration = player.state.duration;
        if (duration > Duration.zero) {
          final remaining = duration - pos;
          if (remaining.inSeconds <= _crossfadeDuration &&
              remaining.inSeconds > 0) {
            _endOfTrackFadeStarted = true;
            _fadeOut(_crossfadeDuration);
          }
        }
      }
    });

    _durationSub = player.stream.duration.listen((dur) {
      if (dur > Duration.zero) {
        _config.updateTrackDuration(dur.inMilliseconds);
      }
    });

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

    // Quando a faixa termina naturalmente, o fade out já foi feito pelo
    // listener de posição — só avança para a próxima.
    _completedSub = player.stream.completed.listen((completed) {
      if (!completed) return;

      final shouldPause = _timerService?.onTrackFinished() ?? false;
      if (shouldPause) {
        player.pause();
        return;
      }
      _config.trackDidFinish();
    });

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
    // Cancela qualquer fade em andamento e reseta flags para a nova faixa
    _crossfadeTimer?.cancel();
    _crossfadeInProgress = false;
    _endOfTrackFadeStarted = false;

    await _flushSession();

    final track = _config.currentTrack;
    if (track?.id != null) _startSession(track!.id!);

    final uri = 'file://$path';

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

    _config.updateTrackDuration(player.state.duration.inMilliseconds);
    _config.updateCurrentPosition(player.state.position.inMilliseconds);

    // Prepara volume 0 se crossfade ativo — o fade in acontece no play()
    if (_crossfadeDuration > 0) {
      await player.setVolume(0);
    } else {
      await player.setVolume(_baseVolume);
    }
  }

  Future<void> play() async {
    if (_fadeOnPauseResume && !_crossfadeInProgress) {
      // Fade ao retomar: zera volume, toca, sobe gradualmente
      await player.setVolume(0);
      await player.play();
      _fadeIn(1);
    } else if (_crossfadeDuration > 0 && player.state.volume < 1) {
      // Crossfade: faixa nova já está com volume 0, sobe após play
      await player.play();
      _fadeIn(_crossfadeDuration);
    } else {
      await player.setVolume(_baseVolume);
      await player.play();
    }
  }

  Future<void> pause() async {
    if (_fadeOnPauseResume && !_crossfadeInProgress) {
      await _fadeOut(1);
      await player.pause();
      await player.setVolume(_baseVolume);
    } else {
      await player.pause();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setSpeed(double speed) => player.setRate(speed);

  Future<void> skipToNext() async => _config.playNextTrack();

  Future<void> skipToPrevious() async => _config.playPreviousTrack();

  Future<void> stop() async {
    _crossfadeTimer?.cancel();
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
    _crossfadeTimer?.cancel();
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
