import 'dart:convert';
import 'dart:io';

import 'package:music_wave_player/models/music_track.dart';

/// Responsável por extrair metadados (título, artista, álbum) de arquivos de áudio.
/// Suporta MP3 (ID3v2) e M4A/MP4 (iTunes boxes).
///
/// Todos os métodos são estáticos e sem estado — prontos para uso em isolates
/// e para migração futura para um Provider no Riverpod.
class MetadataParser {
  MetadataParser._();

  /// Extrai metadados de um arquivo de áudio pelo path.
  /// Retorna um [MusicTrack] parcial (sem id, coverPath e durationMs).
  static Future<MusicTrack> extractMetadata(String path) async {
    String title = cleanFilename(path);
    String artist = 'Artista Desconhecido';
    String album = 'Álbum Desconhecido';

    final lower = path.toLowerCase();
    try {
      if (lower.endsWith('.mp3')) {
        final tags = await _readId3v2(File(path));
        if (tags['title'] != null) title = tags['title']!;
        if (tags['artist'] != null) artist = tags['artist']!;
        if (tags['album'] != null) album = tags['album']!;
      } else if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
        final tags = await _readMp4Metadata(path);
        if (tags['title'] != null) title = tags['title']!;
        if (tags['artist'] != null) artist = tags['artist']!;
        if (tags['album'] != null) album = tags['album']!;
      }
    } catch (_) {}

    // CoverArtService não é chamado aqui pois getTemporaryDirectory()
    // não funciona corretamente em isolates no Android.
    // A extração de capa ocorre na thread principal após o compute().
    return MusicTrack(path: path, title: title, artist: artist, album: album);
  }

  /// Remove extensão, numeração de faixa e caracteres indesejados do nome do arquivo.
  static String cleanFilename(String path) {
    String name = path.split(Platform.pathSeparator).last;
    if (name.contains('.')) name = name.substring(0, name.lastIndexOf('.'));
    name = name.replaceFirst(RegExp(r'^\d{1,3}[\s._-]+'), '');
    name = name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? 'Faixa Desconhecida' : name;
  }

  // ── ID3v2 (MP3) ───────────────────────────────────────────────────────────

  static Future<Map<String, String?>> _readId3v2(File file) async {
    final result = <String, String?>{};
    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(10);
      if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
        return result;
      }

      // Tamanho do tag ID3v2 em syncsafe integer
      final tagSize =
          ((header[6] & 0x7F) << 21) |
          ((header[7] & 0x7F) << 14) |
          ((header[8] & 0x7F) << 7) |
          (header[9] & 0x7F);

      final tagData = await raf.read(tagSize);
      int pos = 0;

      while (pos + 10 <= tagData.length) {
        final frameId = String.fromCharCodes(tagData.sublist(pos, pos + 4));
        if (frameId == '\x00\x00\x00\x00') break;

        final frameSize =
            (tagData[pos + 4] << 24) |
            (tagData[pos + 5] << 16) |
            (tagData[pos + 6] << 8) |
            tagData[pos + 7];

        pos += 10;
        if (frameSize <= 0 || pos + frameSize > tagData.length) break;

        if (frameId == 'TIT2' || frameId == 'TPE1' || frameId == 'TALB') {
          final encoding = tagData[pos];
          final contentBytes = tagData.sublist(pos + 1, pos + frameSize);
          final text = _decodeId3Text(encoding, contentBytes).trim();

          if (text.isNotEmpty) {
            if (frameId == 'TIT2') result['title'] = text;
            if (frameId == 'TPE1') result['artist'] = text;
            if (frameId == 'TALB') result['album'] = text;
          }
        }

        pos += frameSize;
      }
    } finally {
      await raf.close();
    }
    return result;
  }

  /// Decodifica o texto de um frame ID3v2 conforme o byte de encoding:
  ///   0 = ISO-8859-1 (Latin-1)
  ///   1 = UTF-16 com BOM
  ///   2 = UTF-16BE sem BOM
  ///   3 = UTF-8
  static String _decodeId3Text(int encoding, List<int> bytes) {
    switch (encoding) {
      case 1:
      case 2:
        final bom = bytes.length >= 2 ? (bytes[0] << 8 | bytes[1]) : 0;
        final start = (bom == 0xFFFE || bom == 0xFEFF) ? 2 : 0;
        return _decodeUtf16(bytes.sublist(start));
      case 3:
        try {
          // Remove terminador nulo, se houver, antes de decodificar
          final trimmed = bytes.where((b) => b != 0).toList();
          return utf8.decode(trimmed, allowMalformed: true);
        } catch (_) {
          return latin1.decode(bytes.where((b) => b != 0).toList());
        }
      case 0:
      default:
        return latin1.decode(bytes.where((b) => b != 0).toList());
    }
  }

  static String _decodeUtf16(List<int> bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final cu = bytes[i] | (bytes[i + 1] << 8);
      if (cu == 0) break;
      buffer.writeCharCode(cu);
    }
    return buffer.toString();
  }

  // ── MP4/M4A (iTunes boxes) ────────────────────────────────────────────────

  static Future<Map<String, String?>> _readMp4Metadata(String path) async {
    final result = <String, String?>{};
    final file = File(path);
    if (!await file.exists()) return result;
    final bytes = await file.readAsBytes();
    _parseMp4Boxes(bytes, 0, bytes.length, result);
    return result;
  }

  static void _parseMp4Boxes(
    List<int> bytes,
    int offset,
    int limit,
    Map<String, String?> result,
  ) {
    int pos = offset;
    while (pos + 8 <= limit) {
      final size = _readUint32BE(bytes, pos);
      if (size < 8 || pos + size > limit) break;

      final name = String.fromCharCodes(
        bytes.sublist(pos + 4, pos + 8).map((b) => b & 0xFF),
      );

      if (name == '\u00A9nam' || name == '©nam') {
        result['title'] = _readItunesStringBox(bytes, pos + 8, pos + size);
      } else if (name == '\u00A9ART' || name == '©ART') {
        result['artist'] = _readItunesStringBox(bytes, pos + 8, pos + size);
      } else if (name == '\u00A9alb' || name == '©alb') {
        result['album'] = _readItunesStringBox(bytes, pos + 8, pos + size);
      }

      if (_isMp4Container(name)) {
        int innerOffset = pos + 8;
        if (name == 'meta') innerOffset += 4;
        _parseMp4Boxes(bytes, innerOffset, pos + size, result);
      }

      pos += size;

      // Para ao encontrar todos os campos necessários
      if (result['title'] != null &&
          result['artist'] != null &&
          result['album'] != null) {
        break;
      }
    }
  }

  /// Lê a caixa `data` dentro de uma caixa de metadado iTunes (ex: ©nam).
  /// O conteúdo textual é sempre UTF-8 pela especificação do formato.
  static String? _readItunesStringBox(List<int> bytes, int offset, int limit) {
    int pos = offset;
    while (pos + 8 <= limit) {
      final size = _readUint32BE(bytes, pos);
      if (size < 8 || pos + size > limit) break;

      final name = String.fromCharCodes(
        bytes.sublist(pos + 4, pos + 8).map((b) => b & 0xFF),
      );

      if (name == 'data' && size > 16) {
        final rawBytes = bytes.sublist(pos + 16, pos + size);
        String text;
        try {
          text = utf8.decode(rawBytes, allowMalformed: true).trim();
        } catch (_) {
          text = latin1.decode(rawBytes).trim();
        }
        return text.isNotEmpty ? text : null;
      }

      pos += size;
    }
    return null;
  }

  static bool _isMp4Container(String name) {
    const containers = {
      'moov',
      'udta',
      'meta',
      'ilst',
      'trak',
      'mdia',
      'minf',
      'stbl',
      'edts',
      'dinf',
      'sinf',
    };
    return containers.contains(name);
  }

  static int _readUint32BE(List<int> bytes, int offset) {
    return ((bytes[offset] & 0xFF) << 24) |
        ((bytes[offset + 1] & 0xFF) << 16) |
        ((bytes[offset + 2] & 0xFF) << 8) |
        (bytes[offset + 3] & 0xFF);
  }
}
