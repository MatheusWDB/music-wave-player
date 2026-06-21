import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PlaySessionDatabase {
  static final PlaySessionDatabase instance = PlaySessionDatabase._init();
  static Database? _database;

  PlaySessionDatabase._init();

  static const String tableSessions = 'play_sessions';
  static const String columnId = '_id';
  static const String columnTrackId = 'track_id';
  static const String columnSecondsPlayed = 'seconds_played';
  static const String columnPlayedAt = 'played_at';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('play_sessions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSessions (
        $columnId            INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTrackId       INTEGER NOT NULL,
        $columnSecondsPlayed INTEGER NOT NULL,
        $columnPlayedAt      TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_played_at ON $tableSessions ($columnPlayedAt)',
    );
    await db.execute(
      'CREATE INDEX idx_track_id ON $tableSessions ($columnTrackId)',
    );
  }

  /// Registra uma sessão de reprodução.
  Future<void> insertSession({
    required int trackId,
    required int secondsPlayed,
  }) async {
    if (secondsPlayed <= 0) return;
    final db = await database;
    await db.insert(tableSessions, {
      columnTrackId: trackId,
      columnSecondsPlayed: secondsPlayed,
      columnPlayedAt: DateTime.now().toIso8601String(),
    });
  }

  /// Retorna tempo total ouvido por música dentro de um período.
  /// Resultado: map de trackId → segundos totais.
  Future<Map<int, int>> totalSecondsByTrack({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT $columnTrackId, SUM($columnSecondsPlayed) as total
      FROM $tableSessions
      WHERE $columnPlayedAt >= ? AND $columnPlayedAt <= ?
      GROUP BY $columnTrackId
      ORDER BY total DESC
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );

    return {
      for (final row in rows)
        row[columnTrackId] as int: (row['total'] as int? ?? 0),
    };
  }

  /// Retorna tempo total ouvido por artista dentro de um período.
  /// Requer o mapa de trackId → artist para agregar.
  Future<Map<int, int>> totalSecondsByTrackInPeriod({
    required DateTime from,
    required DateTime to,
    int? limit,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT $columnTrackId, SUM($columnSecondsPlayed) as total
      FROM $tableSessions
      WHERE $columnPlayedAt >= ? AND $columnPlayedAt <= ?
      GROUP BY $columnTrackId
      ORDER BY total DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );

    return {
      for (final row in rows)
        row[columnTrackId] as int: (row['total'] as int? ?? 0),
    };
  }

  /// Retorna os anos com sessões registradas (para filtros dinâmicos).
  Future<List<int>> availableYears() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y', $columnPlayedAt) as year
      FROM $tableSessions
      ORDER BY year DESC
    ''');
    return rows.map((r) => int.parse(r['year'] as String)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
