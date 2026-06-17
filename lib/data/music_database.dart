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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTracks (
        $columnId        INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnPath      TEXT NOT NULL UNIQUE,
        $columnTitle     TEXT NOT NULL,
        $columnArtist    TEXT NOT NULL,
        $columnAlbum     TEXT NOT NULL,
        $columnIsEdited  INTEGER NOT NULL DEFAULT 0,
        $columnCoverPath TEXT
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
  }

  Future<List<MusicTrack>> insertTracks(List<MusicTrack> tracks) async {
    final db = await instance.database;
    final List<MusicTrack> savedTracks = [];

    await db.transaction((txn) async {
      // Remove apenas faixas não editadas — preserva metadados personalizados
      await txn.delete(tableTracks, where: '$columnIsEdited = 0');

      for (final track in tracks) {
        // Se a faixa já existe (editada), preserva e retorna
        final existing = await txn.query(
          tableTracks,
          where: '$columnPath = ?',
          whereArgs: [track.path],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          savedTracks.add(MusicTrack.fromMap(existing.first));
          continue;
        }

        final id = await txn.insert(
          tableTracks,
          track.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        savedTracks.add(track.copyWith(id: id));
      }
    });

    return savedTracks;
  }

  Future<List<MusicTrack>> readAllTracks() async {
    final db = await instance.database;
    final result = await db.query(tableTracks);
    final tracks = result.map((m) => MusicTrack.fromMap(m)).toList();
    tracks.sort((a, b) => naturalCompare(
          a.title.toLowerCase(),
          b.title.toLowerCase(),
        ));
    return tracks;
  }

  /// Atualiza metadados editados pelo usuário.
  /// coverPath é opcional — se null, mantém o valor existente no banco.
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
      final int cmp =
          (na != null && nb != null) ? na.compareTo(nb) : pa.compareTo(pb);
      if (cmp != 0) return cmp;
    }
    return partsA.length.compareTo(partsB.length);
  }
}