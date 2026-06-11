import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Resultado da operação de escrita de metadados.
class MetadataWriteResult {
  final bool success;
  final String? error;
  const MetadataWriteResult({required this.success, this.error});
}

/// Encapsula a chamada ao ffmpeg para reescrever metadados em arquivos de áudio.
///
/// Estratégia:
///   1. ffmpeg lê o arquivo original e escreve numa cópia temporária no
///      cache do app (sem recodificar o áudio — apenas copia os streams).
///   2. O chamador é responsável por mover o temporário de volta ao original
///      via SAF (ver SafService.copyTempToSaf).
class FfmpegService {
  /// Escreve metadados no arquivo de áudio usando ffmpeg.
  ///
  /// [inputPath]  caminho absoluto do arquivo original (leitura direta, pois
  ///              READ_MEDIA_AUDIO já concede leitura).
  /// [title], [artist], [album]  novos metadados.
  ///
  /// Retorna o caminho do arquivo temporário gerado, ou null em caso de erro.
  static Future<String?> writeMetadata({
    required String inputPath,
    required String title,
    required String artist,
    required String album,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = inputPath.split('/').last;
    final tempOutput = '${cacheDir.path}/mw_edit_$fileName';

    // Remove temporário anterior se existir
    final tempFile = File(tempOutput);
    if (await tempFile.exists()) await tempFile.delete();

    // Escapa aspas simples nos valores (evita injeção no comando ffmpeg)
    String esc(String s) => s.replaceAll("'", r"'\''");

    // -c copy: não recodifica o áudio, apenas reescreve o container com novos metadados
    // -map_metadata -1: descarta todos os metadados originais
    // -metadata: define os novos valores
    // -y: sobrescreve o temporário se existir
    final command =
        '-i "$inputPath" '
        '-c copy '
        '-map_metadata -1 '
        '-metadata title="${esc(title)}" '
        '-metadata artist="${esc(artist)}" '
        '-metadata album="${esc(album)}" '
        '-y "$tempOutput"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return tempOutput;
    } else {
      final output = await session.getOutput();
      // ignore: avoid_print
      print('FfmpegService erro: $output');
      return null;
    }
  }
}
