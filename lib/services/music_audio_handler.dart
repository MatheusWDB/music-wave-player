import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:rxdart/rxdart.dart'; // Usado para combinar streams

// Esta classe substitui a simulação e lida com o player real e o background.
class MusicAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final Configuration _config;

  // Variável para evitar inicializar o player mais de uma vez ao carregar a faixa
  bool _isPlayerInitialized = false;

  // Construtor
  MusicAudioHandler(this._config) {
    _initPlayerListeners();
  }

  // --- 1. CONEXÃO SERVICE -> CONFIGURATION (Player Real notificando a UI) ---
  void _initPlayerListeners() {
    // Lógica para notificar a UI sobre posição e duração
    // Combina o stream de posição do player e o stream de duração
    Rx.combineLatest2<Duration, Duration?, MediaState>(
      _player.positionStream,
      _player.durationStream,
      (position, duration) => MediaState(position, duration ?? Duration.zero),
    ).listen((mediaState) {
      _config.updateCurrentPosition(mediaState.position.inMilliseconds);
      _config.updateTrackDuration(mediaState.duration.inMilliseconds);
    });

    // Lógica para FIM DA FAIXA e Mudança de Estado
    _player.playerStateStream.listen((state) {
      // 💡 Processamento do FIM DA FAIXA
      if (state.processingState == ProcessingState.completed) {
        if (kDebugMode) {
          print("Player Real: FIM DA FAIXA. Chamando trackDidFinish().");
        }
        _config.trackDidFinish();
      }

      // 💡 Atualizar o MediaItem para notificação (Opcional, mas crucial para Audio Service)
      // O MediaItem deve ser atualizado quando o estado do player muda.
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            // ... (definir controles ativos/inativos)
          ],
          systemActions: const {
            MediaAction.skipToPrevious,
            MediaAction.skipToNext,
            MediaAction.seek,
          },
          androidCompactActionIndices: const [
            0,
            1,
            2,
          ], // 3 botões na notificação
          processingState: _getAudioServiceProcessingState(state),
          playing: state.playing,
        ),
      );
    });
  }

  // Mapeia o estado do Just Audio para o estado do Audio Service
  AudioProcessingState _getAudioServiceProcessingState(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // --- 2. CONEXÃO CONFIGURATION -> SERVICE (Ações da UI) ---
  // Não precisamos de um listener no Service para o Config, pois o Config
  // agora chama diretamente os métodos públicos do AudioHandler (play(), pause(), customAction()).

  // --- 3. MÉTODOS DE CONTROLE E REPRODUÇÃO (AudioHandler Overrides) ---

  // Comando Customizado para carregar a faixa (chamado por config.playTrack)
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? arguments,
  ]) async {
    if (name == 'loadTrack') {
      final String path = arguments!['path'];
      if (kDebugMode) {
        print(
          "AudioHandler: Recebido comando customizado 'loadTrack' para $path",
        );
      }

      // 💡 Carregar a faixa usando o path
      await _player.setFilePath(path);

      // 💡 Atualiza MediaItem para mostrar a música na notificação/controles
      mediaItem.add(
        MediaItem(
          id: path, // Use o path como ID único
          album: _config.currentTrack?.album,
          title: _config.currentTrack?.title ?? 'Título Desconhecido',
          artist: _config.currentTrack?.artist ?? 'Artista Desconhecido',
          artUri: Uri.parse('http://example.com/album_art.png'), // Placeholder
        ),
      );

      // Tenta buscar a posição salva (lastSeekPositionMs)
      if (_config.lastSeekPositionMs > 0) {
        await _player.seek(Duration(milliseconds: _config.lastSeekPositionMs));
        _config.lastSeekPositionMs = 0; // Limpa após o seek
      }
    }
    return null;
  }

  // 💡 Play/Pause/Seek delegados ao Just Audio
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // Skip delegados de volta ao Configuration para manter a lógica de Queue/Repeat
  @override
  Future<void> skipToNext() async {
    // 💡 CORREÇÃO 3: Adicionar await, pois o método retorna Future<void>
    _config.playNextTrack();
  }

  @override
  Future<void> skipToPrevious() async {
    // 💡 CORREÇÃO 4: Adicionar await, pois o método retorna Future<void>
    _config.playPreviousTrack();
  }

  // Limpeza
  @override
  Future<void> stop() async {
    await _player.stop();
    // 💡 IMPORTANTE: Cancelar subscriptions e remover listeners
    // Isso é crucial para evitar vazamentos de memória.
    // ... (As subscriptions deveriam ser salvas em propriedades para serem canceladas aqui)
    return super.stop();
  }
}

// Classe auxiliar para combinar posição e duração
class MediaState {
  final Duration position;
  final Duration duration;

  MediaState(this.position, this.duration);
}
