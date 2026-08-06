import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/cover_art_service.dart';
import 'package:music_wave_player/services/loudness_service.dart';
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

  /// Executa a indexação completa da biblioteca, em três fases visíveis
  /// ao usuário:
  /// 1. Varredura e indexação: lista os arquivos e extrai metadados básicos
  ///    (título, artista, álbum) em batches.
  /// 2. Processamento de metadados: lê duração, extrai capas e persiste no
  ///    banco. Sem granularidade de progresso (done/total) por enquanto —
  ///    reporta só o nome da etapa em andamento.
  /// 3. Cálculo de loudness: varre apenas as faixas que ainda não têm
  ///    loudness calculado (novas ou de antes dessa feature existir).
  ///
  /// [onProgress] reporta a fase 1: (faixas processadas, total de arquivos
  /// encontrados na pasta). É chamado com o total já conhecido antes do
  /// primeiro batch, para a UI exibir o total desde o início.
  /// [onMetadataStage] reporta a fase 2: o nome da etapa atual.
  /// [onLoudnessProgress] reporta a fase 3: (faixas com loudness calculado,
  /// total de faixas pendentes).
  /// [onComplete] é chamado ao final das três fases, com as faixas salvas
  /// e a data de scan.
  /// [onError] é chamado em caso de falha.
  static Future<void> startIndexing({
    required String rootDirectory,
    required void Function(int done, int total) onProgress,
    required void Function(String stage) onMetadataStage,
    required void Function(int done, int total) onLoudnessProgress,
    required void Function(List<MusicTrack> tracks, DateTime scanDate)
    onComplete,
    required void Function(Object error) onError,
  }) async {
    try {
      final paths = await compute(scanDirectoryForPaths, rootDirectory);
      onProgress(0, paths.length);

      const batchSize = 50;
      final allTracks = <MusicTrack>[];

      for (int i = 0; i < paths.length; i += batchSize) {
        final batch = paths.sublist(i, (i + batchSize).clamp(0, paths.length));
        final batchTracks = await compute(buildTracksFromPaths, batch);
        allTracks.addAll(batchTracks);
        onProgress(allTracks.length, paths.length);
      }

      onMetadataStage('Lendo durações...');
      await _readDurations(allTracks);

      onMetadataStage('Extraindo capas de álbum...');
      await _extractCovers(allTracks);

      onMetadataStage('Salvando no banco de dados...');
      final savedTracks = await MusicDatabase.instance.insertTracks(
        allTracks,
        onTracksRemoved: (removedIds) async {
          // Faixas removidas por não existirem mais na varredura deixam
          // suas sessões de reprodução órfãs — limpa junto para não
          // acumular dados que nunca mais serão exibidos em estatísticas
          // ou no backup.
          await PlaySessionDatabase.instance.deleteSessionsForTracks(
            removedIds,
          );
        },
      );
      final scanDate = DateTime.now();
      await _saveLastScanDate(scanDate);
      await _triggerMediaScan(rootDirectory);

      await _scanMissingLoudness(savedTracks, onProgress: onLoudnessProgress);

      onComplete(savedTracks, scanDate);
    } catch (e) {
      onError(e);
      debugPrint('IndexingService erro: $e');
    }
  }

  /// Calcula e persiste o loudness apenas das faixas que ainda não possuem
  /// (loudnessLufs == null). Faixas já salvas em reindexações anteriores
  /// são ignoradas — só o valor de loudness é preenchido, nunca a faixa
  /// inteira é reprocessada.
  static Future<void> _scanMissingLoudness(
    List<MusicTrack> tracks, {
    required void Function(int done, int total) onProgress,
  }) async {
    final pending = tracks.where((t) => t.loudnessLufs == null).toList();
    if (pending.isEmpty) return;

    onProgress(0, pending.length);

    for (int i = 0; i < pending.length; i++) {
      final track = pending[i];
      if (track.id != null) {
        try {
          final lufs = await LoudnessService.scan(track.path);
          if (lufs != null) {
            await MusicDatabase.instance.updateLoudness(track.id!, lufs);
          }
        } catch (_) {
          // Falha pontual numa faixa não deve interromper o restante do scan.
        }
      }
      onProgress(i + 1, pending.length);
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
