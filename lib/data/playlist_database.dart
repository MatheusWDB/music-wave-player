import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:music_wave_player/models/playlist.dart';

class PlaylistDatabase {
  static final PlaylistDatabase instance = PlaylistDatabase._init();
  static Database? _database;

  PlaylistDatabase._init();

  static const String tablePlaylists = 'playlists';
  static const String tablePlaylistTracks = 'playlist_tracks';

  static const String columnId = '_id';
  static const String columnName = 'name';
  static const String columnPlaylistId = 'playlist_id';
  static const String columnTrackId = 'track_id';
  static const String columnPosition = 'position';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('playlists.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablePlaylists (
        $columnId   INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tablePlaylistTracks (
        $columnId         INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnPlaylistId INTEGER NOT NULL,
        $columnTrackId    INTEGER NOT NULL,
        $columnPosition   INTEGER NOT NULL,
        FOREIGN KEY ($columnPlaylistId) REFERENCES $tablePlaylists ($columnId)
          ON DELETE CASCADE
      )
    ''');
  }

  Future<Playlist> createPlaylist(String name) async {
    final db = await database;
    final id = await db.insert(tablePlaylists, {columnName: name});
    return Playlist(id: id, name: name);
  }

  Future<List<Playlist>> readAllPlaylists() async {
    final db = await database;
    final playlists = await db.query(tablePlaylists, orderBy: columnName);
    final result = <Playlist>[];
    for (final row in playlists) {
      final id = row[columnId] as int;
      final trackIds = await _getTrackIds(db, id);
      result.add(
        Playlist(id: id, name: row[columnName] as String, trackIds: trackIds),
      );
    }
    return result;
  }

  Future<Playlist?> readPlaylist(int id) async {
    final db = await database;
    final rows = await db.query(
      tablePlaylists,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final trackIds = await _getTrackIds(db, id);
    return Playlist(
      id: id,
      name: rows.first[columnName] as String,
      trackIds: trackIds,
    );
  }

  Future<void> renamePlaylist(int id, String newName) async {
    final db = await database;
    await db.update(
      tablePlaylists,
      {columnName: newName},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlaylist(int id) async {
    final db = await database;
    await db.delete(tablePlaylists, where: '$columnId = ?', whereArgs: [id]);
    await db.delete(
      tablePlaylistTracks,
      where: '$columnPlaylistId = ?',
      whereArgs: [id],
    );
  }

  Future<List<int>> _getTrackIds(Database db, int playlistId) async {
    final rows = await db.query(
      tablePlaylistTracks,
      columns: [columnTrackId],
      where: '$columnPlaylistId = ?',
      whereArgs: [playlistId],
      orderBy: columnPosition,
    );
    return rows.map((r) => r[columnTrackId] as int).toList();
  }

  Future<void> addTracks(int playlistId, List<int> trackIds) async {
    final db = await database;
    final maxResult = await db.rawQuery(
      'SELECT MAX($columnPosition) as max_pos FROM $tablePlaylistTracks WHERE $columnPlaylistId = ?',
      [playlistId],
    );
    int nextPos = ((maxResult.first['max_pos'] as int?) ?? -1) + 1;
    await db.transaction((txn) async {
      for (final trackId in trackIds) {
        final exists = await txn.query(
          tablePlaylistTracks,
          where: '$columnPlaylistId = ? AND $columnTrackId = ?',
          whereArgs: [playlistId, trackId],
          limit: 1,
        );
        if (exists.isEmpty) {
          await txn.insert(tablePlaylistTracks, {
            columnPlaylistId: playlistId,
            columnTrackId: trackId,
            columnPosition: nextPos++,
          });
        }
      }
    });
  }

  Future<void> removeTrack(int playlistId, int trackId) async {
    final db = await database;
    await db.delete(
      tablePlaylistTracks,
      where: '$columnPlaylistId = ? AND $columnTrackId = ?',
      whereArgs: [playlistId, trackId],
    );
  }
}
