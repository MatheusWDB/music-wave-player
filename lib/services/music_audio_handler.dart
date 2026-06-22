import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/services/timer_service.dart';
import 'package:rxdart/rxdart.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final Configuration _config;
  SleepTimerService? _timerService;

  Timer? _periodicSaveTimer;

  int? _sessionTrackId;
  int _sessionSecondsAccumulated = 0;
  int _sessionSecondsSaved = 0;
  DateTime? _sessionStartedAt;

  MusicAudioHandler(this._config) {
    _emitIdleState();
    _initPlayerListeners();
  }

  /// Injeta o SleepTimerService após a criação (evita dependência circular).
  void setTimerService(SleepTimerService timerService) {
    _timerService = timerService;
  }

  void _emitIdleState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  void _initPlayerListeners() {
    Rx.combineLatest2<Duration, Duration?, _MediaState>(
      _player.positionStream,
      _player.durationStream,
      (pos, dur) => _MediaState(pos, dur ?? Duration.zero),
    ).throttleTime(const Duration(milliseconds: 250)).listen((s) {
      _config.updateCurrentPosition(s.position.inMilliseconds);
      _config.updateTrackDuration(s.duration.inMilliseconds);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Verifica se o timer deve pausar antes de avançar
        final shouldPause = _timerService?.onTrackFinished() ?? false;
        if (shouldPause) {
          _player.pause();
          return;
        }
        _config.trackDidFinish();
      }

      final isActuallyPlaying =
          state.playing && state.processingState != ProcessingState.completed;

      final isTransitioning =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      if (!isTransitioning) {
        if (isActuallyPlaying) {
          _resumeSession();
          _startPeriodicSave();
        } else {
          _pauseSession();
          _stopPeriodicSave();
        }
      }

      _config.syncPlayingState(isActuallyPlaying);
      _pushPlaybackState(state);
    });
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

    int currentAccumulated = _sessionSecondsAccumulated;
    if (_sessionStartedAt != null) {
      currentAccumulated += DateTime.now()
          .difference(_sessionStartedAt!)
          .inSeconds;
    }

    final delta = currentAccumulated - _sessionSecondsSaved;
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
        _player.position.inMilliseconds,
      );
      await _saveSessionDelta();
    });
  }

  void _stopPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  // ── Playback state ────────────────────────────────────────────────────────

  void _pushPlaybackState(PlayerState state) {
    final playing =
        state.playing && state.processingState != ProcessingState.completed;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _toServiceState(state.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _toServiceState(ProcessingState s) => switch (s) {
    ProcessingState.idle => AudioProcessingState.idle,
    ProcessingState.loading => AudioProcessingState.loading,
    ProcessingState.buffering => AudioProcessingState.buffering,
    ProcessingState.ready => AudioProcessingState.ready,
    ProcessingState.completed => AudioProcessingState.completed,
  };

  // ── Overrides ─────────────────────────────────────────────────────────────

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'loadTrack') {
      final path = extras!['path'] as String;
      if (kDebugMode) print('AudioHandler: loadTrack → $path');

      await _flushSession();

      final track = _config.currentTrack;

      if (track?.id != null) _startSession(track!.id!);

      Uri? artUri;
      if (track?.coverPath != null) {
        final coverFile = File(track!.coverPath!);
        if (await coverFile.exists()) {
          artUri = coverFile.uri;
        }
      }

      mediaItem.add(
        MediaItem(
          id: path,
          title: track?.title ?? 'Título Desconhecido',
          artist: track?.artist ?? 'Artista Desconhecido',
          album: track?.album ?? 'Álbum Desconhecido',
          artUri: artUri,
        ),
      );

      await _player.setFilePath(path);

      final duration = _player.duration;
      if (duration != null && duration.inMilliseconds > 0) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      } else {
        _player.durationStream
            .where((d) => d != null && d.inMilliseconds > 0)
            .take(1)
            .timeout(const Duration(seconds: 2), onTimeout: (_) {})
            .listen((d) {
              if (d != null && mediaItem.value != null) {
                mediaItem.add(mediaItem.value!.copyWith(duration: d));
              }
            });
      }

      if (_config.lastSeekPositionMs > 0) {
        await _player.seek(Duration(milliseconds: _config.lastSeekPositionMs));
        _config.lastSeekPositionMs = 0;
      }
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => _config.playNextTrack();

  @override
  Future<void> skipToPrevious() async => _config.playPreviousTrack();

  @override
  Future<void> stop() async {
    _stopPeriodicSave();
    await _flushSession();
    await _config.saveCurrentPositionForResume(_player.position.inMilliseconds);
    await _player.stop();
    await super.stop();
  }
}

class _MediaState {
  final Duration position;
  final Duration duration;
  _MediaState(this.position, this.duration);
}
