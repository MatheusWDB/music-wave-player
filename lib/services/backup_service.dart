import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/data/music_database.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/equalizer_notifier.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';
import 'package:music_wave_player/providers/sort_notifier.dart';
import 'package:music_wave_player/services/cover_art_service.dart';
import 'package:music_wave_player/services/equalizer_service.dart';
import 'package:music_wave_player/services/metadata_parser.dart';
import 'package:music_wave_player/services/sort_service.dart';

const String _kBackupFormat = 'MWP_BACKUP';
const int _kBackupVersion = 1;

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

class BackupData {
  final Map<String, dynamic> settings;
  final List<BackupTrackMeta> trackMeta;
  final List<BackupPlaylist> playlists;
  final List<BackupPlaySession> playSessions;

  const BackupData({
    required this.settings,
    required this.trackMeta,
    required this.playlists,
    required this.playSessions,
  });
}

/// Resumo do resultado de uma restauração, exibido ao usuário.
class RestoreSummary {
  final int playlistsRestored;
  final int tracksRecreated;
  final int trackMetaMatched;
  final int trackMetaUnmatched;
  final int sessionsRestored;
  final int sessionsUnmatched;

  const RestoreSummary({
    required this.playlistsRestored,
    required this.tracksRecreated,
    required this.trackMetaMatched,
    required this.trackMetaUnmatched,
    required this.sessionsRestored,
    required this.sessionsUnmatched,
  });
}

/// Monta o backup (export) e aplica a restauração por merge (import).
///
/// Faixas são referenciadas no arquivo por [path, title, artist] para
/// sobreviver à reindexação em outro diretório ou aparelho: a busca tenta
/// path exato primeiro e cai para título+artista (case-insensitive) se
/// não encontrar. Se a faixa sumiu do banco mas o arquivo ainda existe no
/// path salvo, ela é recriada automaticamente antes do merge.
///
/// Recebe um [Ref] em vez de um objeto `Configuration` — lê/escreve
/// diretamente nos Notifiers correspondentes (Sort, PlayerSettings,
/// Equalizer, Indexing).
class BackupService {
  BackupService._();

  // ── Export ──────────────────────────────────────────────────────────────

  static Future<String> buildBackup(WidgetRef ref) async {
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
    };

    return const JsonEncoder.withIndent('  ').convert(json);
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

      return BackupParseResult.success(
        BackupData(
          settings: settings,
          trackMeta: trackMeta,
          playlists: playlists,
          playSessions: playSessions,
        ),
      );
    } catch (e) {
      return BackupParseResult.failure('Erro ao ler o arquivo de backup: $e');
    }
  }

  // ── Restore (merge) ───────────────────────────────────────────────────────

  static Future<RestoreSummary> restore({
    required BackupData data,
    required WidgetRef ref,
  }) async {
    var allTracks = await MusicDatabase.instance.readAllTracksIncludingHidden();

    final recreated = await _recreateMissingTracks(
      data: data,
      existingTracks: allTracks,
    );
    if (recreated.isNotEmpty) {
      allTracks = await MusicDatabase.instance.readAllTracksIncludingHidden();
    }

    await _restoreSettings(data.settings, ref);

    // Rating e ocultas
    int metaMatched = 0, metaUnmatched = 0;
    final toHide = <int>[];
    final toUnhide = <int>[];
    for (final meta in data.trackMeta) {
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
    int playlistsRestored = 0;
    for (final backupPlaylist in data.playlists) {
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
    int sessionsRestored = 0, sessionsUnmatched = 0;
    for (final session in data.playSessions) {
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

    // Recarrega para refletir ratings/hidden/faixas recriadas na UI.
    await ref.read(indexingNotifierProvider.notifier).loadIndexedTracks();

    return RestoreSummary(
      playlistsRestored: playlistsRestored,
      tracksRecreated: recreated.length,
      trackMetaMatched: metaMatched,
      trackMetaUnmatched: metaUnmatched,
      sessionsRestored: sessionsRestored,
      sessionsUnmatched: sessionsUnmatched,
    );
  }

  /// Recria no banco as faixas referenciadas pelo backup (playlists, notas,
  /// sessões) que sumiram da biblioteca local — mas cujo arquivo ainda
  /// existe no path original. Extrai metadados reais, capa e duração, igual
  /// a uma indexação normal; loudness fica de fora para manter o restore
  /// rápido (é preenchido na próxima reindexação).
  static Future<List<MusicTrack>> _recreateMissingTracks({
    required BackupData data,
    required List<MusicTrack> existingTracks,
  }) async {
    final existingPaths = existingTracks.map((t) => t.path).toSet();

    final referencedPaths = <String>{
      ...data.trackMeta.map((m) => m.path),
      ...data.playlists.expand((p) => p.tracks.map((t) => t.path)),
      ...data.playSessions.map((s) => s.trackPath),
    };

    final missingPaths = referencedPaths
        .where((p) => !existingPaths.contains(p))
        .where((p) => File(p).existsSync())
        .toList();

    if (missingPaths.isEmpty) return [];

    final newTracks = <MusicTrack>[];
    final durationPlayer = Player(
      configuration: const PlayerConfiguration(autoPlay: false),
    );

    try {
      for (final path in missingPaths) {
        var track = await MetadataParser.extractMetadata(path);

        try {
          final completer = Completer<Duration>();
          final sub = durationPlayer.stream.duration.listen((d) {
            if (d > Duration.zero && !completer.isCompleted) {
              completer.complete(d);
            }
          });
          await durationPlayer.open(Media('file://$path'), play: false);
          final duration = await completer.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () => Duration.zero,
          );
          await sub.cancel();
          track = track.copyWith(durationMs: duration.inMilliseconds);
        } catch (_) {}

        try {
          final coverPath = await CoverArtService.extractAndSave(path);
          if (coverPath != null) track = track.copyWith(coverPath: coverPath);
        } catch (_) {}

        newTracks.add(track);
      }
    } finally {
      await durationPlayer.dispose();
    }

    return MusicDatabase.instance.upsertTracks(newTracks);
  }

  static Future<void> _restoreSettings(
    Map<String, dynamic> settings,
    WidgetRef ref,
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
