import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Extrai a capa embutida em arquivos de áudio e salva no cache do app.
///
/// Formatos suportados:
///   - .m4a / .mp4: caixa `covr` dentro de moov/udta/meta/ilst
///   - .mp3: frame APIC dentro do tag ID3v2
class CoverArtService {
  /// Diretório onde as capas são salvas.
  static Future<Directory> get _coversDir async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/covers');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Retorna um nome de arquivo único baseado no path da música.
  static String _coverFileName(String audioPath) {
    // Usa hashCode do path para nome curto e único
    return '${audioPath.hashCode.abs()}.jpg';
  }

  /// Extrai e salva a capa do arquivo de áudio.
  /// Retorna o caminho do arquivo de capa salvo, ou null se não houver capa.
  static Future<String?> extractAndSave(String audioPath) async {
    try {
      Uint8List? imageBytes;

      final lower = audioPath.toLowerCase();
      if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
        imageBytes = await _extractFromMp4(audioPath);
      } else if (lower.endsWith('.mp3')) {
        imageBytes = await _extractFromMp3(audioPath);
      }

      if (imageBytes == null || imageBytes.isEmpty) return null;

      final dir = await _coversDir;
      final fileName = _coverFileName(audioPath);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Remove a capa cacheada de um arquivo (usado na reindexação).
  static Future<void> deleteCover(String audioPath) async {
    try {
      final dir = await _coversDir;
      final file = File('${dir.path}/${_coverFileName(audioPath)}');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Extrator MP4/M4A ────────────────────────────────────────────────────

  /// Percorre as caixas MP4 em busca da caixa `covr` dentro de
  /// moov → udta → meta → ilst → covr → data
  static Future<Uint8List?> _extractFromMp4(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    return _findMp4CoverRecursive(bytes, 0, bytes.length);
  }

  static Uint8List? _findMp4CoverRecursive(
    Uint8List bytes,
    int offset,
    int limit,
  ) {
    int pos = offset;

    while (pos + 8 <= limit) {
      // Tamanho da caixa (4 bytes big-endian)
      final size = _readUint32BE(bytes, pos);
      if (size < 8 || pos + size > limit) break;

      // Nome da caixa (4 bytes ASCII)
      final name = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));

      if (name == 'covr') {
        // A caixa covr contém uma ou mais caixas 'data'
        return _extractCovrData(bytes, pos + 8, pos + size);
      }

      // Caixas container: procura recursivamente dentro delas
      if (_isContainerBox(name)) {
        int innerOffset = pos + 8;
        // meta tem 4 bytes extras de versão/flags
        if (name == 'meta') innerOffset += 4;

        final result = _findMp4CoverRecursive(bytes, innerOffset, pos + size);
        if (result != null) return result;
      }

      pos += size;
    }

    return null;
  }

  static Uint8List? _extractCovrData(Uint8List bytes, int offset, int limit) {
    int pos = offset;
    while (pos + 8 <= limit) {
      final size = _readUint32BE(bytes, pos);
      if (size < 8 || pos + size > limit) break;

      final name = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
      if (name == 'data' && size > 16) {
        // data: 4 bytes type + 4 bytes locale + dados da imagem
        final imageStart = pos + 16;
        final imageEnd = pos + size;
        if (imageEnd <= bytes.length) {
          return Uint8List.fromList(bytes.sublist(imageStart, imageEnd));
        }
      }
      pos += size;
    }
    return null;
  }

  static bool _isContainerBox(String name) {
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

  static int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  // ── Extrator MP3/ID3v2 ────────────────────────────────────────────────

  /// Lê o frame APIC do tag ID3v2.
  static Future<Uint8List?> _extractFromMp3(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final raf = await file.open(mode: FileMode.read);
    try {
      final header = await raf.read(10);
      // Verifica magic "ID3"
      if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
        return null;
      }

      // Tamanho do tag ID3v2 (syncsafe integer)
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

        if (frameId == 'APIC') {
          return _parseApicFrame(tagData, pos, frameSize);
        }

        pos += frameSize;
      }
    } finally {
      await raf.close();
    }
    return null;
  }

  static Uint8List? _parseApicFrame(Uint8List data, int offset, int frameSize) {
    // APIC: encoding(1) + mimeType(null-terminated) + pictureType(1) +
    //       description(null-terminated) + imageData
    int pos = offset;
    final end = offset + frameSize;

    // Pula encoding byte
    pos += 1;

    // Pula mime type (até null byte)
    while (pos < end && data[pos] != 0) pos++;
    pos++; // pula o null

    // Pula picture type byte
    pos += 1;

    // Pula description (até null byte)
    while (pos < end && data[pos] != 0) pos++;
    pos++; // pula o null

    if (pos >= end) return null;
    return Uint8List.fromList(data.sublist(pos, end));
  }
}
