import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/providers/custom_images_provider.dart';
import 'package:music_wave_player/providers/equalizer_notifier.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';
import 'package:music_wave_player/providers/sort_notifier.dart';
import 'package:music_wave_player/services/background_task_manager.dart';
import 'package:music_wave_player/services/background_task_service.dart';
import 'package:music_wave_player/services/custom_image_service.dart';
import 'package:music_wave_player/services/equalizer_service.dart';
import 'package:music_wave_player/services/sort_service.dart';
import 'package:permission_handler/permission_handler.dart';

const String _kBackupFormat = 'MWP_BACKUP';
const int _kBackupVersion = 2;

// ── Resultado do parse ───────────────────────────────────────────────────────

sealed class BackupParseResult {
  const BackupParseResult();
  const factory BackupParseResult.success(BackupData data) = BackupParseSuccess;
  const factory BackupParseResult.failure(String reason) = BackupParseFailure;
}

class BackupParseSuccess extends BackupParseResult {
  final BackupData data;
  const BackupParseSuccess(this.data);
}

class BackupParseFailure extends BackupParseResult {
  final String reason;
  const BackupParseFailure(this.reason);
}

// ── Modelos de dados do backup ────────────────────────────────────────────────

class BackupTrackRef {
  final String path;
  final String title;
  final String artist;
  const BackupTrackRef({
    required this.path,
    required this.title,
    required this.artist,
  });
}

class BackupTrackMeta {
  final String path;
  final String title;
  final String artist;
  final double rating;
  final bool isHidden;

  const BackupTrackMeta({
    required this.path,
    required this.title,
    required this.artist,
    required this.rating,
    required this.isHidden,
  });
}

class BackupPlaylist {
  final String name;
  final List<BackupTrackRef> tracks;
  const BackupPlaylist({required this.name, required this.tracks});
}

class BackupPlaySession {
  final String trackPath;
  final String trackTitle;
  final String trackArtist;
  final int secondsPlayed;
  final String playedAt;

  const BackupPlaySession({
    required this.trackPath,
    required this.trackTitle,
    required this.trackArtist,
    required this.secondsPlayed,
    required this.playedAt,
  });
}

/// Imagem personalizada embutida no backup (base64). [key] é o nome da
/// playlist (não o id, que muda entre aparelhos), o nome do artista ou
/// 'álbum|artista'.
class BackupCustomImage {
  final String type;
  final String key;
  final String data;

  const BackupCustomImage({
    required this.type,
    required this.key,
    required this.data,
  });
}

class BackupData {
  final Map<String, dynamic> settings;
  final List<BackupTrackMeta> trackMeta;
  final List<BackupPlaylist> playlists;
  final List<BackupPlaySession> playSessions;
  final List<BackupCustomImage> customImages;

  const BackupData({
    required this.settings,
    required this.trackMeta,
    required this.playlists,
    required this.playSessions,
    this.customImages = const [],
  });
}

/// Progresso de uma etapa do restore (avaliações/ocultas, playlists ou
/// sessões), para exibição em tempo real — evita a sensação de app
/// travado em bibliotecas grandes, já que o restore roda desacoplado da
/// tela.
class RestoreProgress {
  final String stage;
  final int done;
  final int total;
  final int stageIndex;
  final int stageTotal;
  const RestoreProgress({
    required this.stage,
    required this.done,
    required this.total,
    required this.stageIndex,
    required this.stageTotal,
  });
}

/// Resumo do resultado de uma restauração, exibido ao usuário.
class RestoreSummary {
  final int playlistsRestored;
  final int tracksIndexed;
  final int trackMetaMatched;
  final int trackMetaUnmatched;
  final int sessionsRestored;
  final int sessionsUnmatched;
  final int imagesRestored;

  /// Verdadeiro quando o usuário cancelou: só parte do backup foi aplicada.
  final bool cancelled;

  const RestoreSummary({
    required this.playlistsRestored,
    required this.tracksIndexed,
    required this.trackMetaMatched,
    required this.trackMetaUnmatched,
    required this.sessionsRestored,
    required this.sessionsUnmatched,
    this.imagesRestored = 0,
    this.cancelled = false,
  });
}

/// Monta o backup (export) e aplica a restauração por merge (import).
///
/// Faixas são referenciadas no arquivo por [path, title, artist] para
/// sobreviver à reindexação em outro diretório ou aparelho: a busca tenta
/// path exato primeiro e cai para título+artista (case-insensitive) se
/// não encontrar. O restore reindexa a biblioteca inteira a partir do
/// diretório raiz salvo no backup antes de aplicar ratings, ocultas,
/// playlists e sessões — não depende mais de recriar faixas pontuais.
///
/// Recebe um [Ref] em vez de um objeto `Configuration` — lê/escreve
/// diretamente nos Notifiers correspondentes (Sort, PlayerSettings,
/// Equalizer, Indexing).
class BackupService {
  BackupService._();

  /// Progresso das etapas do restore em andamento (avaliações/ocultas,
  /// playlists, sessões); `null` quando nenhum restore está rodando.
  /// A reindexação da biblioteca em si é reportada à parte, pelo
  /// [indexingNotifierProvider] — ambos são ouvidos por
  /// [BackgroundTaskBanner] via [ValueListenableBuilder]/[ref.watch].
  static final ValueNotifier<RestoreProgress?> progress = ValueNotifier(null);

  /// `true` durante todo o restore, incluindo a etapa de reindexação (que
  /// não passa por [progress], e sim pelo [indexingNotifierProvider]).
  /// Permite ao [BackgroundTaskBanner] rotular a reindexação como
  /// "Etapa 1/4" do restore, em vez de mostrar o progresso isolado da
  /// indexação (que por si só tem sua própria contagem de 3 etapas).
  static final ValueNotifier<bool> isRestoring = ValueNotifier(false);

  /// Reindexação da biblioteca, avaliações/ocultas, playlists, sessões,
  /// imagens personalizadas.
  static const _restoreTotalStages = 5;

  /// Formata e manda o texto de progresso pra notificação — chamado a
  /// cada item das etapas 2-4; o throttle de frequência já é feito
  /// dentro de [BackgroundTaskService.update].
  static void _notifyRestoreProgress(
    RestoreProgress p,
    TaskCancelToken cancelToken,
  ) {
    final pct = p.total > 0
        ? ((p.done / p.total) * 100).toStringAsFixed(0)
        : '0';
    final text = p.total > 0
        ? 'Etapa ${p.stageIndex}/${p.stageTotal} · ${p.stage}... ${p.done}/${p.total} ($pct%)'
        : 'Etapa ${p.stageIndex}/${p.stageTotal} · ${p.stage}...';
    BackgroundTaskManager.update(
      BackgroundTask(
        id: BackgroundTaskIds.backupRestore,
        label: text,
        progress: p.total > 0 ? p.done / p.total : null,
        cancelToken: cancelToken,
      ),
    );
    unawaited(
      BackgroundTaskService.update(title: 'MusicWave Player', text: text),
    );
  }

  // ── Export ──────────────────────────────────────────────────────────────

  /// Gera o conteúdo do backup mantendo o processo em foreground, para a
  /// exportação não ser suspensa se a tela bloquear ou o app for minimizado.
  /// [ref] é um [ProviderContainer] (e não o `WidgetRef` da tela) para a
  /// operação continuar funcionando depois que a tela que a iniciou for
  /// fechada.
  static Future<String> buildBackup(ProviderContainer ref) async {
    _reportExportProgress(0);
    unawaited(
      BackgroundTaskService.start(
        title: 'MusicWave Player',
        text: 'Gerando backup... (0%)',
      ),
    );
    try {
      return await _buildBackupInternal(ref);
    } finally {
      BackgroundTaskManager.finish(BackgroundTaskIds.backupExport);
      unawaited(BackgroundTaskService.stop());
    }
  }

  /// Progresso da exportação (0.0 a 1.0): leitura dos dados até 20%,
  /// imagens personalizadas de 20% a 90% (a etapa mais pesada) e a
  /// serialização do JSON no restante.
  static void _reportExportProgress(double progress) {
    final label = 'Gerando backup... (${(progress * 100).round()}%)';
    BackgroundTaskManager.update(
      BackgroundTask(
        id: BackgroundTaskIds.backupExport,
        label: label,
        progress: progress,
      ),
    );
    unawaited(
      BackgroundTaskService.update(title: 'MusicWave Player', text: label),
    );
  }

  static Future<String> _buildBackupInternal(ProviderContainer ref) async {
    final allTracks = await MusicDatabase.instance
        .readAllTracksIncludingHidden();
    final tracksById = {for (final t in allTracks) t.id: t};

    final playlists = await PlaylistDatabase.instance.readAllPlaylists();
    final sessions = await PlaySessionDatabase.instance.readAllSessions();

    final indexingState = await ref.read(indexingNotifierProvider.future);
    final sortState = await ref.read(sortNotifierProvider.future);
    final playerSettings = await ref.read(
      playerSettingsNotifierProvider.future,
    );
    final eqState = await ref.read(equalizerNotifierProvider.future);
    _reportExportProgress(0.2);

    final customImages = await _exportCustomImages(
      playlists,
      onProgress: (done, total) =>
          _reportExportProgress(0.2 + 0.7 * (total > 0 ? done / total : 1)),
    );

    final json = {
      'format': _kBackupFormat,
      'version': _kBackupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'rootDirectory': indexingState.rootDirectory,
        'sortMusics': sortState.musics.key,
        'sortPlaylists': sortState.playlists.key,
        'sortAlbums': sortState.albums.key,
        'sortArtists': sortState.artists.key,
        'crossfadeDuration': playerSettings.crossfadeDuration,
        'fadeOnPauseResume': playerSettings.fadeOnPauseResume,
        'eq': {
          'enabled': eqState.enabled,
          'preset': eqState.activePreset.name,
          'bandGains': eqState.bandGains,
        },
      },
      // Só exporta faixas com dado relevante (evita inflar o arquivo com
      // milhares de entradas neutras).
      'trackMeta': allTracks
          .where((t) => t.rating > 0 || t.isHidden)
          .map(
            (t) => {
              'path': t.path,
              'title': t.title,
              'artist': t.artist,
              'rating': t.rating,
              'isHidden': t.isHidden,
            },
          )
          .toList(),
      'playlists': playlists
          .map(
            (p) => {
              'name': p.name,
              'tracks': p.trackIds
                  .map((id) => tracksById[id])
                  .whereType<MusicTrack>()
                  .map(
                    (t) => {
                      'path': t.path,
                      'title': t.title,
                      'artist': t.artist,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'playSessions': sessions
          .map((s) {
            final track = tracksById[s.trackId];
            if (track == null) return null;
            return {
              'path': track.path,
              'title': track.title,
              'artist': track.artist,
              'secondsPlayed': s.secondsPlayed,
              'playedAt': s.playedAt,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList(),
      'customImages': customImages,
    };

    _reportExportProgress(0.9);
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Embute as imagens personalizadas (já reduzidas a ~800px no momento da
  /// escolha) em base64. Playlists são identificadas pelo nome, já que o id
  /// não sobrevive a um aparelho novo. Imagens cujo arquivo sumiu são
  /// ignoradas.
  static Future<List<Map<String, dynamic>>> _exportCustomImages(
    List<Playlist> playlists, {
    required void Function(int done, int total) onProgress,
  }) async {
    final rows = await MusicDatabase.instance.readAllCustomImages();
    final playlistNameById = {for (final p in playlists) '${p.id}': p.name};
    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < rows.length; i++) {
      onProgress(i, rows.length);
      final row = rows[i];
      final type = row[MusicDatabase.columnEntityType] as String;
      var key = row[MusicDatabase.columnEntityKey] as String;
      if (type == CustomImageType.playlist.name) {
        final name = playlistNameById[key];
        if (name == null) continue;
        key = name;
      }

      final file = File(row[MusicDatabase.columnImagePath] as String);
      if (!await file.exists()) continue;
      result.add({
        'type': type,
        'key': key,
        'data': base64Encode(await file.readAsBytes()),
      });
    }
    return result;
  }

  // ── Parse ───────────────────────────────────────────────────────────────

  static BackupParseResult parseBackup(String content) {
    try {
      final map = jsonDecode(content) as Map<String, dynamic>;
      if (map['format'] != _kBackupFormat) {
        return const BackupParseResult.failure(
          'Arquivo não é um backup válido do MusicWave Player.',
        );
      }

      final settings = (map['settings'] as Map<String, dynamic>?) ?? {};

      final trackMeta = ((map['trackMeta'] as List?) ?? [])
          .map(
            (e) => BackupTrackMeta(
              path: e['path'] as String,
              title: e['title'] as String,
              artist: e['artist'] as String,
              rating: (e['rating'] as num? ?? 0).toDouble(),
              isHidden: e['isHidden'] as bool? ?? false,
            ),
          )
          .toList();

      final playlists = ((map['playlists'] as List?) ?? [])
          .map(
            (e) => BackupPlaylist(
              name: e['name'] as String,
              tracks: ((e['tracks'] as List?) ?? [])
                  .map(
                    (t) => BackupTrackRef(
                      path: t['path'] as String,
                      title: t['title'] as String,
                      artist: t['artist'] as String,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();

      final playSessions = ((map['playSessions'] as List?) ?? [])
          .map(
            (e) => BackupPlaySession(
              trackPath: e['path'] as String,
              trackTitle: e['title'] as String,
              trackArtist: e['artist'] as String,
              secondsPlayed: e['secondsPlayed'] as int,
              playedAt: e['playedAt'] as String,
            ),
          )
          .toList();

      // Ausente em backups da versão 1.
      final customImages = ((map['customImages'] as List?) ?? [])
          .map(
            (e) => BackupCustomImage(
              type: e['type'] as String,
              key: e['key'] as String,
              data: e['data'] as String,
            ),
          )
          .toList();

      return BackupParseResult.success(
        BackupData(
          settings: settings,
          trackMeta: trackMeta,
          playlists: playlists,
          playSessions: playSessions,
          customImages: customImages,
        ),
      );
    } catch (e) {
      return BackupParseResult.failure('Erro ao ler o arquivo de backup: $e');
    }
  }

  // ── Restore (merge) ───────────────────────────────────────────────────────

  static Future<RestoreSummary> restore({
    required BackupData data,
    required ProviderContainer ref,
  }) async {
    isRestoring.value = true;
    final cancelToken = TaskCancelToken();
    BackgroundTaskManager.update(
      BackgroundTask(
        id: BackgroundTaskIds.backupRestore,
        label: 'Restaurando backup...',
        cancelToken: cancelToken,
      ),
    );
    unawaited(
      BackgroundTaskService.start(
        title: 'MusicWave Player',
        text: 'Restaurando backup...',
      ),
    );
    try {
      return await _restoreInternal(
        data: data,
        ref: ref,
        cancelToken: cancelToken,
      );
    } finally {
      progress.value = null;
      isRestoring.value = false;
      BackgroundTaskManager.finish(BackgroundTaskIds.backupRestore);
      unawaited(BackgroundTaskService.stop());
    }
  }

  static Future<RestoreSummary> _restoreInternal({
    required BackupData data,
    required ProviderContainer ref,
    required TaskCancelToken cancelToken,
  }) async {
    var tracksIndexed = 0;
    var metaMatched = 0, metaUnmatched = 0;
    var playlistsRestored = 0;
    var sessionsRestored = 0, sessionsUnmatched = 0;
    var imagesRestored = 0;

    RestoreSummary buildSummary({bool cancelled = false}) => RestoreSummary(
      playlistsRestored: playlistsRestored,
      tracksIndexed: tracksIndexed,
      trackMetaMatched: metaMatched,
      trackMetaUnmatched: metaUnmatched,
      sessionsRestored: sessionsRestored,
      sessionsUnmatched: sessionsUnmatched,
      imagesRestored: imagesRestored,
      cancelled: cancelled,
    );

    // Cancelar não desfaz o que já foi aplicado: o restore é um merge
    // idempotente, então restaurar o mesmo backup de novo completa o resto.
    Future<RestoreSummary> cancelledSummary() async {
      await ref.read(customImagesProvider.notifier).reload();
      await ref.read(indexingNotifierProvider.notifier).loadIndexedTracks();
      return buildSummary(cancelled: true);
    }

    // Restaura settings primeiro (inclui o diretório raiz), e reindexa a
    // biblioteca inteira a partir dele antes de aplicar o resto do backup.
    // Isso substitui a recriação pontual de faixas referenciadas: agora
    // a biblioteca inteira volta, não só o que tinha nota/playlist/sessão.
    await _restoreSettings(data.settings, ref);

    final rootDirectory = ref
        .read(indexingNotifierProvider)
        .valueOrNull
        ?.rootDirectory;
    final tracksBeforeReindex = await MusicDatabase.instance
        .readAllTracksIncludingHidden();

    if (rootDirectory != null) {
      final permission = await Permission.audio.request();
      if (permission.isGranted) {
        await ref
            .read(indexingNotifierProvider.notifier)
            .startIndexing(
              taskId: BackgroundTaskIds.backupRestore,
              stagePrefix: 'Etapa 1/$_restoreTotalStages',
              cancelToken: cancelToken,
            );
      }
      // Sem a permissão concedida não dá pra reindexar agora — segue o
      // restore só com o que já está na biblioteca, sem travar por isso.
    }

    if (cancelToken.isCancelled) return cancelledSummary();

    final allTracks = await MusicDatabase.instance
        .readAllTracksIncludingHidden();
    tracksIndexed = allTracks.length - tracksBeforeReindex.length;
    if (tracksIndexed < 0) tracksIndexed = 0;

    // Rating e ocultas
    final toHide = <int>[];
    final toUnhide = <int>[];
    for (var i = 0; i < data.trackMeta.length; i++) {
      if (cancelToken.isCancelled) return cancelledSummary();
      final meta = data.trackMeta[i];
      progress.value = RestoreProgress(
        stage: 'Restaurando avaliações e faixas ocultas',
        done: i,
        total: data.trackMeta.length,
        stageIndex: 2,
        stageTotal: _restoreTotalStages,
      );
      _notifyRestoreProgress(progress.value!, cancelToken);
      final match = _findMatch(
        path: meta.path,
        title: meta.title,
        artist: meta.artist,
        tracks: allTracks,
      );
      if (match == null) {
        metaUnmatched++;
        continue;
      }
      metaMatched++;
      if (meta.rating > 0) {
        await MusicDatabase.instance.updateRating(match.id!, meta.rating);
      }
      if (meta.isHidden) {
        toHide.add(match.id!);
      } else {
        toUnhide.add(match.id!);
      }
    }
    if (toHide.isNotEmpty) {
      await MusicDatabase.instance.setHidden(toHide, hidden: true);
    }
    if (toUnhide.isNotEmpty) {
      await MusicDatabase.instance.setHidden(toUnhide, hidden: false);
    }

    // Playlists — cria se não existir (mesmo nome) e adiciona as faixas
    // resolvidas; addTracks já ignora duplicatas.
    final existingPlaylists = await PlaylistDatabase.instance
        .readAllPlaylists();
    for (var i = 0; i < data.playlists.length; i++) {
      if (cancelToken.isCancelled) return cancelledSummary();
      final backupPlaylist = data.playlists[i];
      progress.value = RestoreProgress(
        stage: 'Restaurando playlists',
        done: i,
        total: data.playlists.length,
        stageIndex: 3,
        stageTotal: _restoreTotalStages,
      );
      _notifyRestoreProgress(progress.value!, cancelToken);
      final existing = existingPlaylists
          .where((p) => p.name == backupPlaylist.name)
          .firstOrNull;
      final playlistId =
          existing?.id ??
          (await PlaylistDatabase.instance.createPlaylist(
            backupPlaylist.name,
          )).id!;

      final resolvedIds = <int>[];
      for (final trackRef in backupPlaylist.tracks) {
        final match = _findMatch(
          path: trackRef.path,
          title: trackRef.title,
          artist: trackRef.artist,
          tracks: allTracks,
        );
        if (match != null) resolvedIds.add(match.id!);
      }
      if (resolvedIds.isNotEmpty) {
        await PlaylistDatabase.instance.addTracks(playlistId, resolvedIds);
      }
      playlistsRestored++;
    }

    // Sessões de reprodução — upsert mantendo o maior tempo ouvido em caso
    // de mesmo (faixa, data), para não inflar estatísticas em restaurações repetidas.
    for (var i = 0; i < data.playSessions.length; i++) {
      if (cancelToken.isCancelled) return cancelledSummary();
      final session = data.playSessions[i];
      progress.value = RestoreProgress(
        stage: 'Restaurando sessões de reprodução',
        done: i,
        total: data.playSessions.length,
        stageIndex: 4,
        stageTotal: _restoreTotalStages,
      );
      _notifyRestoreProgress(progress.value!, cancelToken);
      final match = _findMatch(
        path: session.trackPath,
        title: session.trackTitle,
        artist: session.trackArtist,
        tracks: allTracks,
      );
      if (match == null) {
        sessionsUnmatched++;
        continue;
      }
      await PlaySessionDatabase.instance.upsertSession(
        trackId: match.id!,
        secondsPlayed: session.secondsPlayed,
        playedAt: session.playedAt,
      );
      sessionsRestored++;
    }

    // Imagens personalizadas — playlists são resolvidas pelo nome, depois de
    // restauradas na etapa 3 (o id pode ser diferente do original).
    final restoredPlaylists = await PlaylistDatabase.instance
        .readAllPlaylists();
    final playlistIdByName = {for (final p in restoredPlaylists) p.name: p.id!};
    for (var i = 0; i < data.customImages.length; i++) {
      if (cancelToken.isCancelled) return cancelledSummary();
      final image = data.customImages[i];
      progress.value = RestoreProgress(
        stage: 'Restaurando imagens personalizadas',
        done: i,
        total: data.customImages.length,
        stageIndex: 5,
        stageTotal: _restoreTotalStages,
      );
      _notifyRestoreProgress(progress.value!, cancelToken);

      final type = CustomImageType.values
          .where((t) => t.name == image.type)
          .firstOrNull;
      if (type == null) continue;

      var key = image.key;
      if (type == CustomImageType.playlist) {
        final playlistId = playlistIdByName[key];
        if (playlistId == null) continue;
        key = '$playlistId';
      }

      try {
        await CustomImageService.saveBytes(type, key, base64Decode(image.data));
        imagesRestored++;
      } catch (e) {
        debugPrint('[Backup] imagem personalizada ignorada ($key): $e');
      }
    }
    await ref.read(customImagesProvider.notifier).reload();

    // Recarrega para refletir ratings/hidden/faixas reindexadas na UI.
    await ref.read(indexingNotifierProvider.notifier).loadIndexedTracks();

    return buildSummary();
  }

  static Future<void> _restoreSettings(
    Map<String, dynamic> settings,
    ProviderContainer ref,
  ) async {
    if (settings['rootDirectory'] != null) {
      await ref
          .read(indexingNotifierProvider.notifier)
          .setRootDirectory(settings['rootDirectory'] as String);
    }

    final sortNotifier = ref.read(sortNotifierProvider.notifier);
    final currentSort = await ref.read(sortNotifierProvider.future);

    await sortNotifier.setSortMusics(
      SortOptionLabel.fromKey(
        settings['sortMusics'] as String? ?? '',
        currentSort.musics,
      ),
    );
    await sortNotifier.setSortPlaylists(
      SortOptionLabel.fromKey(
        settings['sortPlaylists'] as String? ?? '',
        currentSort.playlists,
      ),
    );
    await sortNotifier.setSortAlbums(
      SortOptionLabel.fromKey(
        settings['sortAlbums'] as String? ?? '',
        currentSort.albums,
      ),
    );
    await sortNotifier.setSortArtists(
      SortOptionLabel.fromKey(
        settings['sortArtists'] as String? ?? '',
        currentSort.artists,
      ),
    );

    final playerSettingsNotifier = ref.read(
      playerSettingsNotifierProvider.notifier,
    );
    if (settings['crossfadeDuration'] != null) {
      await playerSettingsNotifier.setCrossfadeDuration(
        settings['crossfadeDuration'] as int,
      );
    }
    if (settings['fadeOnPauseResume'] != null) {
      await playerSettingsNotifier.setFadeOnPauseResume(
        settings['fadeOnPauseResume'] as bool,
      );
    }

    final eq = settings['eq'] as Map<String, dynamic>?;
    if (eq == null) return;

    final eqNotifier = ref.read(equalizerNotifierProvider.notifier);
    final currentEq = await ref.read(equalizerNotifierProvider.future);

    final enabled = eq['enabled'] as bool? ?? currentEq.enabled;
    await eqNotifier.setEnabled(enabled);

    final preset = EqualizerPreset.values.firstWhere(
      (p) => p.name == eq['preset'],
      orElse: () => currentEq.activePreset,
    );

    if (preset != EqualizerPreset.manual) {
      await eqNotifier.setPreset(preset);
    } else {
      final gains = (eq['bandGains'] as List?)?.cast<num>();
      if (gains == null) return;
      for (
        int i = 0;
        i < gains.length && i < EqualizerService.bands.length;
        i++
      ) {
        await eqNotifier.setBandGain(i, gains[i].toDouble());
      }
    }
  }

  // ── Matching de faixas ────────────────────────────────────────────────────

  /// Tenta encontrar a faixa correspondente por path exato; se não achar,
  /// cai para título+artista (case-insensitive) — cobre reindexação em
  /// outro diretório ou aparelho.
  static MusicTrack? _findMatch({
    required String path,
    required String title,
    required String artist,
    required List<MusicTrack> tracks,
  }) {
    for (final t in tracks) {
      if (t.path == path) return t;
    }
    final normTitle = title.trim().toLowerCase();
    final normArtist = artist.trim().toLowerCase();
    for (final t in tracks) {
      if (t.title.trim().toLowerCase() == normTitle &&
          t.artist.trim().toLowerCase() == normArtist) {
        return t;
      }
    }
    return null;
  }
}
