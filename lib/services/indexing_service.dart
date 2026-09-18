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
  /// 1. Varredura: lista os arquivos e extrai metadados básicos (título,
  ///    artista, álbum) em batches, e remove do banco as faixas cujo
  ///    arquivo não existe mais (só depende dos paths encontrados, roda
  ///    antes do processamento pesado de cada faixa).
  /// 2. Processamento progressivo: para cada faixa, lê duração, extrai
  ///    capa e já salva no banco — a biblioteca vai sendo preenchida aos
  ///    poucos em vez de aparecer tudo de uma vez só no final.
  /// 3. Cálculo de loudness: varre apenas as faixas que ainda não têm
  ///    loudness calculado (novas ou de antes dessa feature existir).
  ///
  /// [onProgress] reporta a fase 1: (faixas processadas, total de arquivos
  /// encontrados na pasta). É chamado com o total já conhecido antes do
  /// primeiro batch, para a UI exibir o total desde o início.
  /// [onTracksRemoved] reporta os ids removidos por não existirem mais no
  /// disco, logo após a fase 1 — permite a UI já tirá-los da lista em
  /// memória sem esperar o resto da indexação.
  /// [onMetadataStage] reporta o início da fase 2.
  /// [onMetadataProgress] reporta o progresso faixa a faixa da fase 2.
  /// [onLibraryBatch] entrega faixas já processadas e salvas, em lotes
  /// curtos (a cada poucas faixas ou intervalo curto de tempo), para a UI
  /// atualizar a lista da biblioteca sem recompor a tela a cada faixa.
  /// [onLoudnessProgress] reporta a fase 3: (faixas com loudness calculado,
  /// total de faixas pendentes).
  /// [onComplete] é chamado ao final das três fases, com o snapshot final
  /// e definitivo das faixas salvas e a data de scan.
  /// [onError] é chamado em caso de falha.
  static Future<void> startIndexing({
    required String rootDirectory,
    required void Function(int done, int total) onProgress,
    required void Function(List<int> removedIds) onTracksRemoved,
    required void Function(String stage) onMetadataStage,
    required void Function(int done, int total) onMetadataProgress,
    required void Function(List<MusicTrack> newTracks) onLibraryBatch,
    required void Function(int done, int total) onLoudnessProgress,
    required void Function(List<MusicTrack> tracks, DateTime scanDate)
    onComplete,
    required void Function(Object error) onError,
  }) async {
    try {
      final paths = await compute(scanDirectoryForPaths, rootDirectory);
      onProgress(0, paths.length);

      await MusicDatabase.instance.pruneOrphanTracks(
        paths,
        onTracksRemoved: (removedIds) async {
          // Faixas removidas por não existirem mais na varredura deixam
          // suas sessões de reprodução órfãs — limpa junto para não
          // acumular dados que nunca mais serão exibidos em estatísticas
          // ou no backup.
          await PlaySessionDatabase.instance.deleteSessionsForTracks(
            removedIds,
          );
          onTracksRemoved(removedIds);
        },
      );

      const batchSize = 50;
      final basicTracks = <MusicTrack>[];

      for (int i = 0; i < paths.length; i += batchSize) {
        final batch = paths.sublist(i, (i + batchSize).clamp(0, paths.length));
        final batchTracks = await compute(buildTracksFromPaths, batch);
        basicTracks.addAll(batchTracks);
        onProgress(basicTracks.length, paths.length);
      }

      onMetadataStage('Processando faixas...');
      final savedTracks = await _processTracksProgressively(
        basicTracks,
        onProgress: onMetadataProgress,
        onLibraryBatch: onLibraryBatch,
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

  /// Processa cada faixa por completo (duração + capa) e já salva no banco
  /// individualmente, entregando lotes curtos via [onLibraryBatch] — a
  /// biblioteca vai enchendo aos poucos em vez de aparecer tudo de uma vez
  /// só no final da indexação.
  ///
  /// O lote é liberado a cada 5 faixas processadas ou 500ms, o que vier
  /// primeiro — junta a resposta visual pedida (faixa a faixa) com um
  /// número de rebuilds da lista que não compromete a rolagem da tela.
  static Future<List<MusicTrack>> _processTracksProgressively(
    List<MusicTrack> tracks, {
    required void Function(int done, int total) onProgress,
    required void Function(List<MusicTrack> newTracks) onLibraryBatch,
  }) async {
    final durationPlayer = Player(
      configuration: const PlayerConfiguration(autoPlay: false),
    );
    final saved = <MusicTrack>[];
    final pendingBatch = <MusicTrack>[];
    var lastEmit = DateTime.now();

    void flushBatch() {
      if (pendingBatch.isEmpty) return;
      onLibraryBatch(List.of(pendingBatch));
      pendingBatch.clear();
      lastEmit = DateTime.now();
    }

    for (int i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      try {
        final completer = Completer<Duration>();
        final sub = durationPlayer.stream.duration.listen((d) {
          if (d > Duration.zero && !completer.isCompleted) {
            completer.complete(d);
          }
        });
        await durationPlayer.open(Media('file://${track.path}'), play: false);
        final duration = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => Duration.zero,
        );
        await sub.cancel();
        track = track.copyWith(durationMs: duration.inMilliseconds);
      } catch (_) {}

      try {
        final coverPath = await CoverArtService.extractAndSave(track.path);
        if (coverPath != null) track = track.copyWith(coverPath: coverPath);
      } catch (_) {}

      final upserted = await MusicDatabase.instance.upsertTracks([track]);
      if (upserted.isNotEmpty) {
        saved.add(upserted.first);
        pendingBatch.add(upserted.first);
      }

      onProgress(i + 1, tracks.length);

      final elapsedSinceEmit = DateTime.now().difference(lastEmit);
      if (pendingBatch.length >= 5 ||
          elapsedSinceEmit >= const Duration(milliseconds: 500)) {
        flushBatch();
      }
    }

    flushBatch();
    await durationPlayer.dispose();
    return saved;
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
