import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/services/metadata_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRepairDoneKey = 'metadata_repair_v1_done';

/// Corrige retroativamente título/artista/álbum de faixas já indexadas
/// antes da correção de decodificação UTF-8 no [MetadataParser].
///
/// Roda uma única vez (controlado por flag em SharedPreferences), em
/// background, no início do app. Só reprocessa faixas não editadas pelo
/// usuário (isEdited == false) — faixas editadas manualmente têm seus
/// metadados preservados via [MusicDatabase.updateRawMetadata], que não
/// marca a faixa como editada.
class MetadataRepairService {
  MetadataRepairService._();

  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kRepairDoneKey) == true) return;

    try {
      final tracks = await MusicDatabase.instance
          .readAllTracksIncludingHidden();

      for (final track in tracks) {
        if (track.isEdited || track.id == null) continue;
        if (!File(track.path).existsSync()) continue;

        final reparsed = await MetadataParser.extractMetadata(track.path);
        final changed =
            reparsed.title != track.title ||
            reparsed.artist != track.artist ||
            reparsed.album != track.album;
        if (!changed) continue;

        await MusicDatabase.instance.updateRawMetadata(
          id: track.id!,
          title: reparsed.title,
          artist: reparsed.artist,
          album: reparsed.album,
        );
      }

      await prefs.setBool(_kRepairDoneKey, true);
    } catch (e) {
      debugPrint('MetadataRepairService erro: $e');
      // Não marca a flag como concluída em caso de erro — tenta de novo
      // na próxima abertura do app.
    }
  }
}
