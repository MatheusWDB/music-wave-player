import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Registro bruto de uma sessão de reprodução — usado no export de backup,
/// que precisa dos dados crus (não agregados) para reconstruir o histórico.
class PlaySessionRecord {
  final int trackId;
  final int secondsPlayed;
  final String playedAt;

  const PlaySessionRecord({
    required this.trackId,
    required this.secondsPlayed,
    required this.playedAt,
  });
}

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

  /// Insere ou atualiza uma sessão vinda de um backup restaurado.
  ///
  /// Se já existir uma sessão com o mesmo (trackId, playedAt), mantém o
  /// maior seconds_played entre a existente e a do backup — evita inflar
  /// as estatísticas caso o mesmo backup seja restaurado mais de uma vez.
  Future<void> upsertSession({
    required int trackId,
    required int secondsPlayed,
    required String playedAt,
  }) async {
    final db = await database;
    final existing = await db.query(
      tableSessions,
      where: '$columnTrackId = ? AND $columnPlayedAt = ?',
      whereArgs: [trackId, playedAt],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(tableSessions, {
        columnTrackId: trackId,
        columnSecondsPlayed: secondsPlayed,
        columnPlayedAt: playedAt,
      });
      return;
    }

    final currentSeconds = existing.first[columnSecondsPlayed] as int? ?? 0;
    if (secondsPlayed > currentSeconds) {
      await db.update(
        tableSessions,
        {columnSecondsPlayed: secondsPlayed},
        where: '$columnId = ?',
        whereArgs: [existing.first[columnId]],
      );
    }
  }

  /// Remove todas as sessões associadas aos [trackIds] informados.
  ///
  /// Usado quando faixas são removidas do banco por não existirem mais no
  /// disco (reindexação com mudança de diretório) — sem isso, as sessões
  /// ficam órfãs, referenciando um track_id que não existe mais, e nunca
  /// mais aparecem em estatísticas ou no backup.
  Future<void> deleteSessionsForTracks(List<int> trackIds) async {
    if (trackIds.isEmpty) return;
    final db = await database;
    final placeholders = trackIds.map((_) => '?').join(',');
    await db.rawDelete(
      'DELETE FROM $tableSessions WHERE $columnTrackId IN ($placeholders)',
      trackIds,
    );
  }

  /// Retorna todas as sessões em formato bruto — usado no export de backup.
  Future<List<PlaySessionRecord>> readAllSessions() async {
    final db = await database;
    final rows = await db.query(tableSessions);
    return rows
        .map(
          (r) => PlaySessionRecord(
            trackId: r[columnTrackId] as int,
            secondsPlayed: r[columnSecondsPlayed] as int,
            playedAt: r[columnPlayedAt] as String,
          ),
        )
        .toList();
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
