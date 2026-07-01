import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Calcula o loudness integrado (LUFS, padrão EBU R128) de um arquivo de
/// áudio usando o scanner nativo do MPV.
///
/// O scan decodifica o arquivo inteiro fora do path de reprodução, em
/// velocidade muitas vezes maior que tempo real. O resultado é persistido
/// no banco (ver [MusicDatabase.updateLoudness]) para nunca precisar
/// reescanear a mesma faixa.
class LoudnessService {
  LoudnessService._();

  static const _scanTimeout = Duration(seconds: 15);

  /// Retorna o LUFS integrado do arquivo, ou null se o scan falhar,
  /// for indisponível (ex: streams ao vivo) ou exceder o timeout.
  static Future<double?> scan(String path) async {
    final player = Player(
      configuration: const PlayerConfiguration(autoPlay: false),
    );

    try {
      final completer = Completer<double?>();
      late final StreamSubscription sub;

      sub = player.stream.loudness.listen((scanResult) {
        if (scanResult == null) return;
        if (scanResult.state == LoudnessScanState.ready) {
          if (!completer.isCompleted) {
            completer.complete(scanResult.integrated);
          }
        } else if (scanResult.state == LoudnessScanState.unavailable) {
          if (!completer.isCompleted) completer.complete(null);
        }
      });

      await player.open(Media('file://$path'), play: false);

      final result = await completer.future.timeout(
        _scanTimeout,
        onTimeout: () => null,
      );

      await sub.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
