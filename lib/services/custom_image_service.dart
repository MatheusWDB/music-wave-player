import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:path_provider/path_provider.dart';

enum CustomImageType { playlist, artist, album }

enum CustomImagePickResult { saved, cancelled, failed }

/// Imagens personalizadas de playlist, artista e álbum.
///
/// Chaves por tipo: playlist = id da playlist (sobrevive a renomeações),
/// artista = nome do artista, álbum = [albumKey]. Os arquivos ficam em
/// Application Support (não no cache, que o Android pode limpar).
class CustomImageService {
  CustomImageService._();

  /// Maior lado da imagem salva, em pixels.
  static const int _maxSide = 800;

  static String albumKey(String album, String artist) => '$album|$artist';

  /// Chave usada no mapa em memória: 'tipo:chave'.
  static String mapKey(CustomImageType type, String key) => '${type.name}:$key';

  static Future<Directory> get _imagesDir async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/custom_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Map<String, String>> loadAll() async {
    final rows = await MusicDatabase.instance.readAllCustomImages();
    return {
      for (final row in rows)
        '${row[MusicDatabase.columnEntityType]}:${row[MusicDatabase.columnEntityKey]}':
            row[MusicDatabase.columnImagePath] as String,
    };
  }

  /// Abre o seletor, redimensiona a imagem escolhida e a associa à entidade.
  static Future<CustomImagePickResult> pickAndSave(
    CustomImageType type,
    String key,
  ) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final source = picked?.files.single.path;
    if (source == null) return CustomImagePickResult.cancelled;

    final dest = await _newFilePath(type);
    if (!await _resizeToJpeg(source, dest)) return CustomImagePickResult.failed;

    await _replace(type, key, dest);
    return CustomImagePickResult.saved;
  }

  /// Grava bytes já prontos (restauração de backup) e associa à entidade.
  static Future<void> saveBytes(
    CustomImageType type,
    String key,
    Uint8List bytes,
  ) async {
    final dest = await _newFilePath(type);
    await File(dest).writeAsBytes(bytes, flush: true);
    await _replace(type, key, dest);
  }

  static Future<void> remove(CustomImageType type, String key) async {
    final old = await MusicDatabase.instance.readCustomImagePath(
      type.name,
      key,
    );
    await MusicDatabase.instance.deleteCustomImage(type.name, key);
    await _deleteFile(old);
  }

  /// Nome único por gravação: o cache de imagens do Flutter é por caminho,
  /// então reaproveitar o nome faria a imagem antiga continuar na tela.
  static Future<String> _newFilePath(CustomImageType type) async {
    final dir = await _imagesDir;
    return '${dir.path}/${type.name}_${DateTime.now().microsecondsSinceEpoch}.jpg';
  }

  static Future<void> _replace(
    CustomImageType type,
    String key,
    String newPath,
  ) async {
    final old = await MusicDatabase.instance.readCustomImagePath(
      type.name,
      key,
    );
    await MusicDatabase.instance.upsertCustomImage(type.name, key, newPath);
    if (old != null && old != newPath) await _deleteFile(old);
  }

  static Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<bool> _resizeToJpeg(String source, String dest) async {
    final size = await _imageSize(source);
    var scale = '';
    if (size != null && size.longestSide > _maxSide) {
      scale = size.width >= size.height
          ? '-vf scale=$_maxSide:-2 '
          : '-vf scale=-2:$_maxSide ';
    }

    final session = await FFmpegKit.execute(
      '-i "$source" $scale-frames:v 1 -q:v 4 -y "$dest"',
    );
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code)) return true;

    debugPrint('[CustomImage] ffmpeg falhou: ${await session.getOutput()}');
    return false;
  }

  /// Lê só o cabeçalho da imagem (sem decodificar), para decidir se precisa
  /// reduzir.
  static Future<ui.Size?> _imageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final size = ui.Size(
          descriptor.width.toDouble(),
          descriptor.height.toDouble(),
        );
        descriptor.dispose();
        return size;
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
