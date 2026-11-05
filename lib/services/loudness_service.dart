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

  /// Tolerância (em LU) para dois scans serem considerados iguais.
  static const _agreement = 0.5;

  /// Escaneia a faixa e só devolve o valor quando dois scans concordam; se
  /// os dois primeiros divergirem, um terceiro desempata. Um scan isolado já
  /// gravou medições erradas (ex.: -24,6 LUFS em vez de -8,5) que nunca eram
  /// revalidadas. Sem consenso devolve null: a faixa fica sem loudness e é
  /// tentada de novo na próxima indexação.
  ///
  /// [scanner] existe para os testes trocarem o scan nativo.
  static Future<double?> scanVerified(
    String path, {
    Future<double?> Function(String path) scanner = scan,
  }) async {
    bool agree(double a, double b) => (a - b).abs() <= _agreement;

    final first = await scanner(path);
    if (first == null) return null;

    final second = await scanner(path);
    if (second != null && agree(first, second)) return second;

    final third = await scanner(path);
    if (third == null) return null;
    if (agree(third, first)) return third;
    if (second != null && agree(third, second)) return third;
    return null;
  }
}
