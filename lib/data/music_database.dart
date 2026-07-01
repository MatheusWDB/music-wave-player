import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_wave_player/models/music_track.dart';

class MusicDatabase {
  static final MusicDatabase instance = MusicDatabase._init();
  static Database? _database;

  MusicDatabase._init();

  static const String tableTracks = 'tracks';
  static const String columnId = '_id';
  static const String columnPath = 'path';
  static const String columnTitle = 'title';
  static const String columnArtist = 'artist';
  static const String columnAlbum = 'album';
  static const String columnIsEdited = 'is_edited';
  static const String columnCoverPath = 'cover_path';
  static const String columnDurationMs = 'duration_ms';
  static const String columnIsHidden = 'is_hidden';
  static const String columnRating = 'rating';
  static const String columnAddedAt = 'added_at';
  static const String columnLoudnessLufs = 'loudness_lufs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('music_wave.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTracks (
        $columnId         INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnPath       TEXT NOT NULL UNIQUE,
        $columnTitle      TEXT NOT NULL,
        $columnArtist     TEXT NOT NULL,
        $columnAlbum      TEXT NOT NULL,
        $columnIsEdited   INTEGER NOT NULL DEFAULT 0,
        $columnCoverPath  TEXT,
        $columnDurationMs INTEGER NOT NULL DEFAULT 0,
        $columnIsHidden   INTEGER NOT NULL DEFAULT 0,
        $columnRating     REAL NOT NULL DEFAULT 0,
        $columnAddedAt       TEXT,
        $columnLoudnessLufs  REAL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnIsEdited INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnCoverPath TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnDurationMs INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnIsHidden INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnRating REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnAddedAt TEXT',
      );
      await db.execute(
        "UPDATE $tableTracks SET $columnAddedAt = '${DateTime.now().toIso8601String()}' WHERE $columnAddedAt IS NULL",
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE $tableTracks ADD COLUMN $columnLoudnessLufs REAL',
      );
    }
  }

  Future<List<MusicTrack>> insertTracks(List<MusicTrack> tracks) async {
    final db = await instance.database;
    final List<MusicTrack> savedTracks = [];
    final now = DateTime.now().toIso8601String();

    // Carrega todas as faixas existentes indexadas por path para lookup O(1)
    final existingRows = await db.query(tableTracks);
    final existingByPath = {
      for (final row in existingRows)
        row[columnPath] as String: MusicTrack.fromMap(row),
    };

    // Paths que vieram da varredura (para remoção de órfãos depois)
    final incomingPaths = tracks.map((t) => t.path).toSet();

    await db.transaction((txn) async {
      for (final track in tracks) {
        final existing = existingByPath[track.path];

        if (existing != null) {
          if (existing.isEdited) {
            // Metadados editados pelo usuário: preserva título/artista/álbum,
            // mas atualiza duração e capa (dados técnicos, não editoriais)
            await txn.update(
              tableTracks,
              {
                columnDurationMs: track.durationMs,
                columnCoverPath: track.coverPath ?? existing.coverPath,
              },
              where: '$columnId = ?',
              whereArgs: [existing.id],
            );
            savedTracks.add(
              existing.copyWith(
                durationMs: track.durationMs,
                coverPath: track.coverPath ?? existing.coverPath,
              ),
            );
          } else {
            // Faixa não editada: atualiza metadados vindos do arquivo
            await txn.update(
              tableTracks,
              {
                columnTitle: track.title,
                columnArtist: track.artist,
                columnAlbum: track.album,
                columnDurationMs: track.durationMs,
                columnCoverPath: track.coverPath ?? existing.coverPath,
              },
              where: '$columnId = ?',
              whereArgs: [existing.id],
            );
            savedTracks.add(
              existing.copyWith(
                title: track.title,
                artist: track.artist,
                album: track.album,
                durationMs: track.durationMs,
                coverPath: track.coverPath ?? existing.coverPath,
              ),
            );
          }
        } else {
          // Faixa nova: insere com added_at
          final map = track.toMap();
          map[columnAddedAt] ??= now;
          final id = await txn.insert(tableTracks, map);
          savedTracks.add(track.copyWith(id: id));
        }
      }

      // Remove faixas não editadas cujo arquivo não existe mais no disco
      final orphanIds = existingByPath.entries
          .where((e) => !incomingPaths.contains(e.key) && !e.value.isEdited)
          .map((e) => e.value.id!)
          .toList();

      if (orphanIds.isNotEmpty) {
        final placeholders = orphanIds.map((_) => '?').join(',');
        await txn.rawDelete(
          'DELETE FROM $tableTracks WHERE $columnId IN ($placeholders)',
          orphanIds,
        );
      }
    });

    return savedTracks;
  }

  /// Retorna apenas faixas visíveis (is_hidden = 0).
  Future<List<MusicTrack>> readAllTracks() async {
    final db = await instance.database;
    final result = await db.query(tableTracks, where: '$columnIsHidden = 0');
    final tracks = result.map((m) => MusicTrack.fromMap(m)).toList();
    tracks.sort(
      (a, b) => naturalCompare(a.title.toLowerCase(), b.title.toLowerCase()),
    );
    return tracks;
  }

  /// Retorna apenas faixas ocultas (is_hidden = 1).
  Future<List<MusicTrack>> readHiddenTracks() async {
    final db = await instance.database;
    final result = await db.query(tableTracks, where: '$columnIsHidden = 1');
    final tracks = result.map((m) => MusicTrack.fromMap(m)).toList();
    tracks.sort(
      (a, b) => naturalCompare(a.title.toLowerCase(), b.title.toLowerCase()),
    );
    return tracks;
  }

  Future<void> setHidden(List<int> ids, {required bool hidden}) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $tableTracks SET $columnIsHidden = ${hidden ? 1 : 0} WHERE $columnId IN ($placeholders)',
      ids,
    );
  }

  Future<void> unhideAll() async {
    final db = await instance.database;
    await db.update(tableTracks, {columnIsHidden: 0});
  }

  Future<void> updateRating(int id, double rating) async {
    final db = await instance.database;
    await db.update(
      tableTracks,
      {columnRating: rating},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLoudness(int id, double lufs) async {
    final db = await instance.database;
    await db.update(
      tableTracks,
      {columnLoudnessLufs: lufs},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTrack({
    required int id,
    required String title,
    required String artist,
    required String album,
    String? coverPath,
  }) async {
    final db = await instance.database;
    final values = <String, dynamic>{
      columnTitle: title,
      columnArtist: artist,
      columnAlbum: album,
      columnIsEdited: 1,
    };
    if (coverPath != null) values[columnCoverPath] = coverPath;

    await db.update(
      tableTracks,
      values,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllTracks() async {
    final db = await instance.database;
    return await db.delete(tableTracks);
  }

  static int naturalCompare(String a, String b) {
    final re = RegExp(r'\d+|\D+');
    final partsA = re.allMatches(a).map((m) => m.group(0)!).toList();
    final partsB = re.allMatches(b).map((m) => m.group(0)!).toList();
    final len = partsA.length < partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final pa = partsA[i];
      final pb = partsB[i];
      final na = int.tryParse(pa);
      final nb = int.tryParse(pb);
      final int cmp = (na != null && nb != null)
          ? na.compareTo(nb)
          : pa.compareTo(pb);
      if (cmp != 0) return cmp;
    }
    return partsA.length.compareTo(partsB.length);
  }
}
