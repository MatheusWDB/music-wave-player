import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';
import 'package:music_wave_player/providers/timer_notifier.dart';

class MusicAudioHandler {
  final Ref _ref;

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

  // Marca quando a pausa atual foi causada pelo temporizador ao atingir o
  // fim natural da faixa (ver _completedSub). Necessário porque o mpv, sem
  // keep-open configurado, reseta position/completed para 0 ao chegar no
  // EOF — tornando esses estados não confiáveis para decidir, num play()
  // manual posterior, se deve retomar a faixa atual ou avançar para a
  // próxima.
  bool _pausedAtTrackEnd = false;

  int? _sessionTrackId;
  int? _sessionRowId;
  int _sessionSecondsAccumulated = 0;
  int _sessionSecondsSaved = 0;
  DateTime? _sessionStartedAt;

  MusicAudioHandler(this._ref) {
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
    // Começa em pauseOnly (nada tocando ainda) — a política é reajustada
    // dinamicamente em _playingSub conforme o estado real de reprodução.
    await player.setMediaSession(_mediaSessionFor(playing: false));
  }

  /// Monta a configuração da MediaSession com a política de interrupção
  /// correta para o momento: [InterruptionPolicy.pauseAndResume] só quando
  /// já havia áudio tocando antes da interrupção (ex: ligação, alarme) —
  /// caso contrário [InterruptionPolicy.pauseOnly], para não iniciar
  /// reprodução do nada quando o app está parado e uma interrupção externa
  /// termina. A política é reenviada dinamicamente a cada mudança real de
  /// estado de reprodução (ver [_playingSub]), não fixada uma vez só.
  MediaSession _mediaSessionFor({required bool playing}) {
    return MediaSession(
      interruptionPolicy: playing
          ? InterruptionPolicy.pauseAndResume
          : InterruptionPolicy.pauseOnly,
    );
  }

  /// Retorna true se a pausa atual foi causada pelo temporizador ao fim da
  /// faixa, e reseta a flag (consumo único). Ver comentário do campo
  /// [_pausedAtTrackEnd].
  bool consumePausedAtTrackEnd() {
    final value = _pausedAtTrackEnd;
    _pausedAtTrackEnd = false;
    return value;
  }

  void updateCrossfade(int durationSeconds) {
    _crossfadeDuration = durationSeconds;
  }

  void updateFadeOnPauseResume(bool enabled) {
    _fadeOnPauseResume = enabled;
  }

  // ── Equalizador ───────────────────────────────────────────────────────────

  /// Aplica o equalizador gráfico (filtro `superequalizer`) com os ganhos
  /// calculados pelo [EqualizerNotifier]. Chamado na inicialização (para
  /// restaurar o estado salvo) e sempre que o usuário altera banda, preset
  /// ou liga/desliga o EQ.
  Future<void> applyEqualizer(bool enabled, Map<String, double> params) async {
    await player.updateAudioEffects(
      (e) => e.copyWith(
        superequalizer: SuperequalizerSettings(
          enabled: enabled,
          params: params,
        ),
      ),
    );
  }

  // ── Normalização de volume ────────────────────────────────────────────────

  /// Aplica o pré-amp (setVolumeGain) calculado a partir do loudness
  /// integrado (LUFS) da faixa atual, usando -18 LUFS como referência
  /// (padrão ReplayGain 2.0).
  ///
  /// Se a faixa ainda não tiver loudness calculado (caso raro: tocada antes
  /// do scan da indexação terminar), o gain é zerado — sem normalização —
  /// para não travar a reprodução.
  Future<void> _applyLoudnessGain() async {
    final lufs = _ref.read(currentTrackProvider)?.loudnessLufs;
    if (lufs == null) {
      await player.setVolumeGain(0.0);
      return;
    }
    const targetLufs = -18.0;
    final gain = (targetLufs - lufs).clamp(-24.0, 24.0);
    await player.setVolumeGain(gain);
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
      _ref
          .read(playbackNotifierProvider.notifier)
          .updateCurrentPosition(pos.inMilliseconds);

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
        _ref
            .read(playbackNotifierProvider.notifier)
            .updateTrackDuration(dur.inMilliseconds);
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
      _ref.read(playbackNotifierProvider.notifier).syncPlayingState(playing);
      player.setMediaSession(_mediaSessionFor(playing: playing));
    });

    // Quando a faixa termina naturalmente, o fade out já foi feito pelo
    // listener de posição — só avança para a próxima.
    //
    // Filtro extra: alguns wrappers do libmpv emitem 'completed=true'
    // residual logo após um open() (ex: ao carregar a faixa seguinte),
    // mesmo sem a faixa ter de fato chegado ao fim. Sem essa checagem,
    // isso causava avanço espúrio de faixa em loop — mais perceptível em
    // faixas curtas, onde a margem entre "carregada" e "fim" é pequena.
    //
    // Margem de 3000ms (era 800ms): dispositivos Bluetooth introduzem
    // latência extra na leitura de posição, fazendo a folga real no fim da
    // faixa passar de 800ms e o evento ser descartado como espúrio —
    // causava pausa incorreta ao fim da faixa e reset ao retomar (bug
    // investigado e confirmado por log: folgas observadas de 600-870ms
    // com fone Bluetooth conectado). O filtro contra o "completed"
    // residual pós-open() continua válido: nesse caso a diferença entre
    // posição e duração é da ordem de segundos inteiros, não milissegundos.
    _completedSub = player.stream.completed.listen((completed) {
      if (!completed) return;

      final duration = player.state.duration;
      final position = player.state.position;
      final isNearEnd =
          duration > Duration.zero &&
          (duration - position).inMilliseconds <= 3000;
      if (!isNearEnd) return;

      final shouldPause = _ref
          .read(timerNotifierProvider.notifier)
          .onTrackFinished();
      if (shouldPause) {
        _pausedAtTrackEnd = true;
        player.pause();
        return;
      }
      _ref
          .read(playbackNotifierProvider.notifier)
          .trackDidFinish(indexedTracks: _indexedTracks);
    });

    _mediaCommandSub = player.stream.mediaSessionCommands.listen((command) {
      switch (command) {
        case MediaSessionCommandNext():
          skipToNext();
        case MediaSessionCommandPrevious():
          skipToPrevious();
        case MediaSessionCommandSeekTo(:final position):
          seek(position);
        case MediaSessionCommandPause():
          // O mpv_audio_kit já auto-aplica pause() no player nativo antes
          // de emitir este evento — nada a fazer aqui além de deixar o
          // caso explícito (evita cair no default silenciosamente e
          // documenta que já foi considerado).
          break;
        case MediaSessionCommandPlay():
        case MediaSessionCommandPlayPause():
          // O mpv_audio_kit auto-aplica play()/pause() no player nativo
          // ANTES de emitir este evento (ver player_media_session.part.dart
          // do pacote), sem passar pelo nosso fluxo (PlaybackNotifier).
          // Se a pausa atual veio do temporizador ao fim da faixa, esse
          // play() nativo só retomou a faixa já finalizada do zero —
          // corrige aqui chamando a mesma lógica de avanço/repetição usada
          // no fim natural da faixa.
          if (consumePausedAtTrackEnd()) {
            _ref
                .read(playbackNotifierProvider.notifier)
                .trackDidFinish(indexedTracks: _indexedTracks);
          }
        default:
          break;
      }
    });
  }

  /// Atalho para a lista de faixas indexadas, usada pelos métodos que
  /// delegam navegação de fila ao [PlaybackNotifier].
  List<MusicTrack> get _indexedTracks =>
      _ref.read(indexingNotifierProvider).valueOrNull?.indexedTracks ??
      const [];

  // ── Controles de reprodução ───────────────────────────────────────────────

  Future<void> loadTrack(String path) async {
    _pausedAtTrackEnd = false;
    // Cancela qualquer fade em andamento e reseta flags para a nova faixa
    _crossfadeTimer?.cancel();
    _crossfadeInProgress = false;
    _endOfTrackFadeStarted = false;

    await _flushSession();

    final track = _ref.read(currentTrackProvider);
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

    final playbackSpeed =
        _ref.read(playerSettingsNotifierProvider).valueOrNull?.playbackSpeed ??
        1.0;
    if (playbackSpeed != 1.0) {
      await player.setRate(playbackSpeed);
    }

    final lastSeekPositionMs =
        _ref.read(playbackNotifierProvider).valueOrNull?.lastSeekPositionMs ??
        0;
    if (lastSeekPositionMs > 0) {
      await player.seek(Duration(milliseconds: lastSeekPositionMs));
      _ref.read(playbackNotifierProvider.notifier).consumeLastSeekPosition();
    }

    _ref
        .read(playbackNotifierProvider.notifier)
        .updateTrackDuration(player.state.duration.inMilliseconds);
    _ref
        .read(playbackNotifierProvider.notifier)
        .updateCurrentPosition(player.state.position.inMilliseconds);

    await _applyLoudnessGain();

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

  Future<void> skipToNext() async => _ref
      .read(playbackNotifierProvider.notifier)
      .playNextTrack(indexedTracks: _indexedTracks);

  Future<void> skipToPrevious() async => _ref
      .read(playbackNotifierProvider.notifier)
      .playPreviousTrack(indexedTracks: _indexedTracks);

  Future<void> stop() async {
    _crossfadeTimer?.cancel();
    _stopPeriodicSave();
    await _flushSession();
    await _ref
        .read(playbackNotifierProvider.notifier)
        .saveCurrentPositionForResume(player.state.position.inMilliseconds);
    await player.stop();
  }

  // ── Sessão de reprodução ──────────────────────────────────────────────────

  void _resumeSession() {
    if (_sessionTrackId == null) {
      final id = _ref.read(currentTrackProvider)?.id;
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
    _sessionRowId = null;
    _sessionSecondsAccumulated = 0;
    _sessionSecondsSaved = 0;
    _sessionStartedAt = null;
  }

  /// Persiste o total acumulado da sessão atual: insere a linha uma única
  /// vez (no primeiro save com segundos > 0) e, dali em diante, apenas
  /// atualiza essa mesma linha — em vez de inserir uma linha nova a cada
  /// save periódico (5s), o que inflava a tabela em sessões longas sem
  /// necessidade (estatísticas usam SUM, então a granularidade por save
  /// nunca foi observável para o usuário).
  Future<void> _saveSessionDelta() async {
    if (_sessionTrackId == null) return;
    int current = _sessionSecondsAccumulated;
    if (_sessionStartedAt != null) {
      current += DateTime.now().difference(_sessionStartedAt!).inSeconds;
    }
    if (current <= 0 || current == _sessionSecondsSaved) return;

    if (_sessionRowId == null) {
      _sessionRowId = await PlaySessionDatabase.instance.insertSession(
        trackId: _sessionTrackId!,
        secondsPlayed: current,
      );
    } else {
      await PlaySessionDatabase.instance.updateSessionSeconds(
        id: _sessionRowId!,
        secondsPlayed: current,
      );
    }
    _sessionSecondsSaved = current;
  }

  Future<void> _flushSession() async {
    _pauseSession();
    final trackId = _sessionTrackId;
    if (trackId != null) {
      final total = _sessionSecondsAccumulated;
      if (total > 0 && total != _sessionSecondsSaved) {
        if (_sessionRowId == null) {
          await PlaySessionDatabase.instance.insertSession(
            trackId: trackId,
            secondsPlayed: total,
          );
        } else {
          await PlaySessionDatabase.instance.updateSessionSeconds(
            id: _sessionRowId!,
            secondsPlayed: total,
          );
        }
      }
    }
    _sessionSecondsAccumulated = 0;
    _sessionSecondsSaved = 0;
    _sessionTrackId = null;
    _sessionRowId = null;
    _sessionStartedAt = null;
  }

  // ── Save periódico ────────────────────────────────────────────────────────

  void _startPeriodicSave() {
    _periodicSaveTimer ??= Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      await _ref
          .read(playbackNotifierProvider.notifier)
          .saveCurrentPositionForResume(player.state.position.inMilliseconds);
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
