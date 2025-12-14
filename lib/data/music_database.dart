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
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE $tableTracks (
        $columnId $idType,
        $columnPath $textType UNIQUE, 
        $columnTitle $textType,
        $columnArtist $textType,
        $columnAlbum $textType
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableTracks ADD COLUMN new_column TEXT');
    }
  }

  Future<List<MusicTrack>> insertTracks(List<MusicTrack> tracks) async {
    final db = await instance.database;
    final List<MusicTrack> savedTracks = [];

    await db.transaction((txn) async {
      await txn.delete(tableTracks);

      for (final track in tracks) {
        final id = await txn.insert(
          tableTracks,
          track.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        savedTracks.add(
          MusicTrack(
            id: id,
            path: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
          ),
        );
      }
    });

    return savedTracks;
  }

  Future<List<MusicTrack>> readAllTracks() async {
    final db = await instance.database;
    final result = await db.query(tableTracks, orderBy: '$columnTitle ASC');
    return result.map((json) => MusicTrack.fromMap(json)).toList();
  }

  Future<int> deleteAllTracks() async {
    final db = await instance.database;
    return await db.delete(tableTracks);
  }
}
