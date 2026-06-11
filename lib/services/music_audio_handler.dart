import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:rxdart/rxdart.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final Configuration _config;
  Timer? _periodicSaveTimer;

  MusicAudioHandler(this._config) {
    _emitIdleState();
    _initPlayerListeners();
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
    // Posição e duração → Configuration (para a UI Flutter)
    Rx.combineLatest2<Duration, Duration?, _MediaState>(
      _player.positionStream,
      _player.durationStream,
      (pos, dur) => _MediaState(pos, dur ?? Duration.zero),
    ).throttleTime(const Duration(milliseconds: 250)).listen((s) {
      _config.updateCurrentPosition(s.position.inMilliseconds);
      _config.updateTrackDuration(s.duration.inMilliseconds);
    });

    // Save periódico
    _player.playingStream.listen((playing) {
      playing ? _startPeriodicSave() : _stopPeriodicSave();
    });

    // Estado do player → notificação + sincroniza isPlaying no Configuration
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _config.trackDidFinish();
      }

      // CORREÇÃO: sincroniza _isPlaying no Configuration com o estado real
      // do player. Evita dessincronias quando o player para sozinho (fim da fila).
      final isActuallyPlaying =
          state.playing && state.processingState != ProcessingState.completed;
      _config.syncPlayingState(isActuallyPlaying);

      _pushPlaybackState(state);
    });
  }

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

  void _startPeriodicSave() {
    _periodicSaveTimer ??= Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      await _config.saveCurrentPositionForResume(
        _player.position.inMilliseconds,
      );
    });
  }

  void _stopPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'loadTrack') {
      final path = extras!['path'] as String;
      if (kDebugMode) print("AudioHandler: loadTrack → $path");

      final track = _config.currentTrack;

      // Emite mediaItem sem duração — título/artista aparecem imediatamente
      mediaItem.add(
        MediaItem(
          id: path,
          title: track?.title ?? 'Título Desconhecido',
          artist: track?.artist ?? 'Artista Desconhecido',
          album: track?.album ?? 'Álbum Desconhecido',
        ),
      );

      // Carrega o arquivo — após isso a duração fica disponível
      await _player.setFilePath(path);

      // CORREÇÃO: aguarda a duração real do arquivo e atualiza o mediaItem.
      // Usar await garante que o duration não seja nulo quando emitido.
      final duration = _player.duration;
      if (duration != null && duration.inMilliseconds > 0) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      } else {
        // Se ainda não disponível, espera até 2s pelo primeiro valor não nulo
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
