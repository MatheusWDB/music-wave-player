import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

/// Detecta silêncio longo no final de uma faixa usando o filtro
/// `silencedetect` do ffmpeg, decodificando o arquivo inteiro fora do
/// caminho de reprodução (roda em paralelo à primeira reprodução da
/// faixa, ver [MusicAudioHandler]).
///
/// Existe porque, em alguns arquivos (ex: "Haunted"), o decoder de
/// reprodução (mpv) para de decodificar bem antes do fim declarado pelo
/// container, sem motivo claro — em vez de depender do evento nativo de
/// fim de faixa nesses casos, o app passa a saber de antemão onde o
/// conteúdo de áudio real termina e avança sozinho.
class SilenceDetectionService {
  SilenceDetectionService._();

  static const _noiseFloorDb = -30;
  static const _minSilenceSeconds = 5;

  static final _silenceStartRegex = RegExp(r'silence_start:\s*([\d.]+)');
  static final _silenceEndRegex = RegExp(r'silence_end:\s*([\d.]+)');

  /// Retorna o ponto (ms) em que o conteúdo de áudio real termina, ou
  /// [durationMs] se não houver silêncio final relevante (>= 5s) — nesse
  /// caso o valor serve só para marcar a faixa como já analisada.
  static Future<int> detectEffectiveEnd({
    required String path,
    required int durationMs,
  }) async {
    final command =
        '-i "$path" '
        '-af silencedetect=noise=${_noiseFloorDb}dB:d=$_minSilenceSeconds '
        '-f null -';

    final session = await FFmpegKit.execute(command);
    final output = await session.getOutput() ?? '';

    // O silencedetect loga silence_start/silence_end em pares.
    final starts = _silenceStartRegex
        .allMatches(output)
        .map((m) => double.parse(m.group(1)!))
        .toList();
    final ends = _silenceEndRegex
        .allMatches(output)
        .map((m) => double.parse(m.group(1)!))
        .toList();

    if (starts.isEmpty) return durationMs;

    // O ffmpeg às vezes loga um silence_end "artificial" bem no fim do
    // arquivo mesmo quando o silêncio vai até o EOF de verdade — por isso
    // não basta comparar a quantidade de starts/ends. Em vez disso, olha
    // se o end correspondente ao último silêncio está perto o bastante do
    // fim real do arquivo (ali é só o flush do filtro no EOF, não uma
    // pausa de verdade no meio da faixa).
    final durationSec = durationMs / 1000;
    final matchingEnd = ends.length >= starts.length ? ends.last : null;
    final reachesEnd =
        matchingEnd == null || (durationSec - matchingEnd).abs() < 1.5;

    if (!reachesEnd) return durationMs;

    return (starts.last * 1000).round();
  }
}
