import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_wave_player/models/configuration.dart';

enum SleepTimerMode { duration, endOfTrack, endOfQueue }

class SleepTimerService extends ChangeNotifier {
  final Configuration _config;

  Timer? _ticker;
  SleepTimerMode? _mode;
  int _remainingSeconds = 0;
  bool _active = false;

  SleepTimerService(this._config);

  bool get isActive => _active;
  SleepTimerMode? get mode => _mode;
  int get remainingSeconds => _remainingSeconds;

  String get remainingLabel {
    if (!_active) return '';
    if (_mode == SleepTimerMode.endOfTrack) return 'Fim da música';
    if (_mode == SleepTimerMode.endOfQueue) return 'Fim da fila';
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// Inicia temporizador por duração em segundos.
  void startDuration(int seconds) {
    _cancel();
    _mode = SleepTimerMode.duration;
    _remainingSeconds = seconds;
    _active = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  /// Pausa ao fim da música atual.
  void startEndOfTrack() {
    _cancel();
    _mode = SleepTimerMode.endOfTrack;
    _active = true;
    notifyListeners();
  }

  /// Pausa ao fim da fila.
  void startEndOfQueue() {
    _cancel();
    _mode = SleepTimerMode.endOfQueue;
    _active = true;
    notifyListeners();
  }

  /// Cancela o temporizador ativo.
  void cancel() {
    _cancel();
    notifyListeners();
  }

  /// Chamado pelo Configuration quando uma faixa termina.
  /// Retorna true se o timer foi disparado (deve pausar).
  bool onTrackFinished() {
    if (!_active) return false;

    if (_mode == SleepTimerMode.endOfTrack) {
      _cancel();
      notifyListeners();
      return true;
    }

    if (_mode == SleepTimerMode.endOfQueue) {
      final isLast =
          _config.currentQueueIndex >= _config.playbackQueue.length - 1;
      if (isLast) {
        _cancel();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  void _onTick(Timer _) {
    if (_remainingSeconds <= 1) {
      _cancel();
      _config.audioHandler?.pause();
      notifyListeners();
      return;
    }
    _remainingSeconds--;
    notifyListeners();
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    _active = false;
    _mode = null;
    _remainingSeconds = 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
