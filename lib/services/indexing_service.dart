import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/cover_art_service.dart';
import 'package:music_wave_player/services/metadata_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLastScanDateKey = 'lastScanDate';

/// Responsável por varrer o diretório raiz, extrair metadados e persistir
/// as faixas no banco de dados.
///
/// Comunica progresso e resultado via callbacks — sem dependência direta
/// do [Configuration], facilitando a migração futura para um Notifier no Riverpod.
class IndexingService {
  static const _safChannel = MethodChannel(
    'br.com.hematsu.music_wave_player/saf',
  );

  /// Varre [rootPath] recursivamente e retorna os paths de arquivos suportados.
  /// Executado via [compute] em isolate separado.
  static Future<List<String>> scanDirectoryForPaths(String rootPath) async {
    final paths = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return paths;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && MusicTrack.isSupported(entity.path)) {
        paths.add(entity.path);
      }
    }
    return paths;
  }

  /// Extrai metadados de um batch de paths.
  /// Executado via [compute] em isolate separado.
  static Future<List<MusicTrack>> buildTracksFromPaths(
    List<String> paths,
  ) async {
    final tracks = <MusicTrack>[];
    for (final path in paths) {
      tracks.add(await MetadataParser.extractMetadata(path));
    }
    return tracks;
  }

  /// Executa a indexação completa da biblioteca:
  /// 1. Varre o diretório em batches via isolate
  /// 2. Lê duração de cada faixa via MPV
  /// 3. Extrai capas na thread principal
  /// 4. Persiste no banco e retorna as faixas salvas
  ///
  /// [onProgress] é chamado a cada batch com o total parcial de faixas encontradas.
  /// [onComplete] é chamado ao final com as faixas salvas e a data de scan.
  /// [onError] é chamado em caso de falha.
  static Future<void> startIndexing({
    required String rootDirectory,
    required void Function(int count) onProgress,
    required void Function(List<MusicTrack> tracks, DateTime scanDate)
    onComplete,
    required void Function(Object error) onError,
  }) async {
    try {
      final paths = await compute(scanDirectoryForPaths, rootDirectory);

      const batchSize = 50;
      final allTracks = <MusicTrack>[];

      for (int i = 0; i < paths.length; i += batchSize) {
        final batch = paths.sublist(i, (i + batchSize).clamp(0, paths.length));
        final batchTracks = await compute(buildTracksFromPaths, batch);
        allTracks.addAll(batchTracks);
        onProgress(allTracks.length);
      }

      await _readDurations(allTracks);
      await _extractCovers(allTracks);

      final savedTracks = await MusicDatabase.instance.insertTracks(allTracks);
      final scanDate = DateTime.now();
      await _saveLastScanDate(scanDate);
      await _triggerMediaScan(rootDirectory);

      onComplete(savedTracks, scanDate);
    } catch (e) {
      onError(e);
      debugPrint('IndexingService erro: $e');
    }
  }

  /// Lê a duração de cada faixa usando um player MPV temporário.
  static Future<void> _readDurations(List<MusicTrack> tracks) async {
    final durationPlayer = Player(
      configuration: const PlayerConfiguration(autoPlay: false),
    );
    for (int i = 0; i < tracks.length; i++) {
      try {
        final completer = Completer<Duration>();
        final sub = durationPlayer.stream.duration.listen((d) {
          if (d > Duration.zero && !completer.isCompleted) {
            completer.complete(d);
          }
        });
        await durationPlayer.open(
          Media('file://${tracks[i].path}'),
          play: false,
        );
        final duration = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => Duration.zero,
        );
        await sub.cancel();
        tracks[i] = tracks[i].copyWith(durationMs: duration.inMilliseconds);
      } catch (_) {}
    }
    await durationPlayer.dispose();
  }

  /// Extrai capas de álbum na thread principal.
  /// getTemporaryDirectory() não funciona em isolates no Android.
  static Future<void> _extractCovers(List<MusicTrack> tracks) async {
    for (int i = 0; i < tracks.length; i++) {
      try {
        final coverPath = await CoverArtService.extractAndSave(tracks[i].path);
        if (coverPath != null) {
          tracks[i] = tracks[i].copyWith(coverPath: coverPath);
        }
      } catch (_) {}
    }
  }

  static Future<void> _saveLastScanDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastScanDateKey, date.millisecondsSinceEpoch);
  }

  static Future<void> _triggerMediaScan(String dirPath) async {
    try {
      await _safChannel.invokeMethod('scanMedia', {'path': dirPath});
    } catch (_) {}
  }
}
