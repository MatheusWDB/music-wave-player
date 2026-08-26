import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:music_wave_player/providers/music_audio_handler_provider.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';

part 'timer_notifier.g.dart';

enum SleepTimerMode { duration, endOfTrack, endOfQueue }

/// Estado imutável do temporizador de sono.
class TimerState {
  final bool isActive;
  final SleepTimerMode? mode;
  final int remainingSeconds;

  const TimerState({
    this.isActive = false,
    this.mode,
    this.remainingSeconds = 0,
  });

  String get remainingLabel {
    if (!isActive) return '';
    if (mode == SleepTimerMode.endOfTrack) return 'Fim da música';
    if (mode == SleepTimerMode.endOfQueue) return 'Fim da fila';
    final h = remainingSeconds ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    final s = remainingSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }
}

/// Gerencia o temporizador de sono: por duração, fim da música atual ou
/// fim da fila. Substitui o antigo [SleepTimerService] — depende de
/// [QueueNotifier] para saber se a faixa atual é a última da fila, e de
/// [musicAudioHandlerProvider] para pausar quando o timer dispara.
@Riverpod(keepAlive: true)
class TimerNotifier extends _$TimerNotifier {
  Timer? _ticker;

  @override
  TimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const TimerState();
  }

  /// Inicia temporizador por duração em segundos.
  void startDuration(int seconds) {
    _cancelTicker();
    state = TimerState(
      isActive: true,
      mode: SleepTimerMode.duration,
      remainingSeconds: seconds,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Pausa ao fim da música atual.
  void startEndOfTrack() {
    _cancelTicker();
    state = const TimerState(isActive: true, mode: SleepTimerMode.endOfTrack);
  }

  /// Pausa ao fim da fila.
  void startEndOfQueue() {
    _cancelTicker();
    state = const TimerState(isActive: true, mode: SleepTimerMode.endOfQueue);
  }

  /// Cancela o temporizador ativo.
  void cancel() {
    _cancelTicker();
    state = const TimerState();
  }

  /// Chamado pelo audio handler quando uma faixa termina.
  /// Retorna true se o timer foi disparado (deve pausar).
  bool onTrackFinished() {
    if (!state.isActive) return false;

    if (state.mode == SleepTimerMode.endOfTrack) {
      _cancelTicker();
      state = const TimerState();
      return true;
    }

    if (state.mode == SleepTimerMode.endOfQueue) {
      final queueState = ref.read(queueNotifierProvider);
      final isLast =
          queueState.currentQueueIndex >= queueState.playbackQueue.length - 1;
      if (isLast) {
        _cancelTicker();
        state = const TimerState();
        return true;
      }
    }

    return false;
  }

  void _onTick(Timer _) {
    if (state.remainingSeconds <= 1) {
      _cancelTicker();
      state = const TimerState();
      ref.read(musicAudioHandlerProvider).pause();
      return;
    }
    state = TimerState(
      isActive: true,
      mode: state.mode,
      remainingSeconds: state.remainingSeconds - 1,
    );
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
