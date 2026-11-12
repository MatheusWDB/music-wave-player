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

  static bool? _mp3Supported;

  /// Verifica (uma vez) se este build do ffmpeg tem o encoder MP3 (libmp3lame).
  static Future<bool> supportsMp3() async {
    final cached = _mp3Supported;
    if (cached != null) return cached;
    final session = await FFmpegKit.executeWithArguments([
      '-hide_banner',
      '-encoders',
    ]);
    final output = await session.getOutput() ?? '';
    return _mp3Supported = output.contains('libmp3lame');
  }

  /// Gera um .m4a (ou .mp3, se [mp3]) com tags (e capa quadrada, se houver) a partir de um áudio
  /// baixado. Usa lista de argumentos (sem parsing de string), então títulos
  /// com aspas ou apóstrofos não quebram o comando.
  ///
  /// [copyAudio] true copia o AAC sem recodificar; false converte para AAC.
  /// Com [mp3] o áudio é sempre convertido (ID3v2.3, que o leitor de tags do
  /// app lê sem problemas).
  /// Campos de artista/álbum vazios não são gravados. Se a inclusão da capa
  /// falhar, tenta de novo sem ela. Retorna o caminho temporário gerado, ou
  /// null em caso de erro.
  static Future<String?> buildTaggedAudio({
    required String inputPath,
    required String outputName,
    required String title,
    String artist = '',
    String album = '',
    String? coverPath,
    required bool copyAudio,
    bool mp3 = false,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final output = '${cacheDir.path}/mw_out_$outputName';

    List<String> buildArgs({required bool withCover}) => [
      '-y',
      '-i',
      inputPath,
      if (withCover) ...['-i', coverPath!],
      '-map',
      '0:a:0',
      if (withCover) ...['-map', '1:v:0'],
      ...(mp3
          ? ['-c:a', 'libmp3lame', '-b:a', '192k', '-id3v2_version', '3']
          : copyAudio
          ? ['-c:a', 'copy']
          : ['-c:a', 'aac', '-b:a', '192k']),
      // Recorte central quadrado: a capa do vídeo é 16:9.
      if (withCover) ...[
        '-c:v',
        'mjpeg',
        '-q:v',
        '2',
        '-vf',
        'crop=ih:ih,scale=600:600',
        '-disposition:v:0',
        'attached_pic',
        if (mp3) ...[
          '-metadata:s:v',
          'title=Album cover',
          '-metadata:s:v',
          'comment=Cover (front)',
        ],
      ],
      '-map_metadata',
      '-1',
      '-metadata',
      'title=$title',
      if (artist.isNotEmpty) ...['-metadata', 'artist=$artist'],
      if (album.isNotEmpty) ...['-metadata', 'album=$album'],
      output,
    ];

    for (final withCover in [if (coverPath != null) true, false]) {
      final outFile = File(output);
      if (await outFile.exists()) await outFile.delete();

      final session = await FFmpegKit.executeWithArguments(
        buildArgs(withCover: withCover),
      );
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) return output;

      final log = await session.getOutput();
      // ignore: avoid_print
      print('FfmpegService.buildTaggedAudio (capa=$withCover) erro: $log');
    }
    return null;
  }
}
