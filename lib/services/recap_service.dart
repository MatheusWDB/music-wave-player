import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RecapType { month, quarter, semester, year }

class RecapPeriod {
  final RecapType type;
  final DateTime from;
  final DateTime to;
  final String label;
  final int topLimit;

  const RecapPeriod({
    required this.type,
    required this.from,
    required this.to,
    required this.label,
    required this.topLimit,
  });
}

class RecapResult {
  final RecapPeriod period;
  final List<_RankedTrack> topTracks;
  final List<_RankedArtist> topArtists;

  const RecapResult({
    required this.period,
    required this.topTracks,
    required this.topArtists,
  });

  bool get isEmpty => topTracks.isEmpty && topArtists.isEmpty;
}

class _RankedTrack {
  final MusicTrack track;
  final int seconds;
  const _RankedTrack({required this.track, required this.seconds});
}

class _RankedArtist {
  final String artist;
  final int seconds;
  const _RankedArtist({required this.artist, required this.seconds});
}

class RecapService {
  static const _kPrefix = 'recap_shown_';

  /// Verifica se há um recap pendente para exibir.
  /// Retorna o RecapResult se houver, ou null caso contrário.
  static Future<RecapResult?> checkPendingRecap(List<MusicTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final periods = _periodsToCheck(now);

    for (final period in periods) {
      final key = _keyFor(period);
      if (prefs.getBool(key) == true) continue;

      final result = await _buildRecap(period, tracks);
      if (result.isEmpty) {
        // Marca como visto mesmo sem dados para não checar de novo
        await prefs.setBool(key, true);
        continue;
      }

      await prefs.setBool(key, true);
      return result;
    }

    return null;
  }

  /// Gera os períodos que deveriam ter recap no momento atual.
  static List<RecapPeriod> _periodsToCheck(DateTime now) {
    final periods = <RecapPeriod>[];

    // Fim de mês: primeiro dia do mês atual → recap do mês anterior
    if (now.day <= 3) {
      final lastMonth = DateTime(now.year, now.month - 1);
      periods.add(
        RecapPeriod(
          type: RecapType.month,
          from: DateTime(lastMonth.year, lastMonth.month),
          to: DateTime(
            now.year,
            now.month,
          ).subtract(const Duration(milliseconds: 1)),
          label: _monthLabel(lastMonth),
          topLimit: 10,
        ),
      );
    }

    // Fim de trimestre: meses 1, 4, 7, 10
    if (now.day <= 3 && [1, 4, 7, 10].contains(now.month)) {
      final quarterEnd = DateTime(
        now.year,
        now.month,
      ).subtract(const Duration(milliseconds: 1));
      final quarterStart = DateTime(now.year, now.month - 3);
      periods.add(
        RecapPeriod(
          type: RecapType.quarter,
          from: quarterStart,
          to: quarterEnd,
          label: _quarterLabel(quarterStart),
          topLimit: 10,
        ),
      );
    }

    // Fim de semestre: meses 1 e 7
    if (now.day <= 3 && [1, 7].contains(now.month)) {
      final semEnd = DateTime(
        now.year,
        now.month,
      ).subtract(const Duration(milliseconds: 1));
      final semStart = DateTime(now.year, now.month - 6);
      periods.add(
        RecapPeriod(
          type: RecapType.semester,
          from: semStart,
          to: semEnd,
          label: _semesterLabel(semStart),
          topLimit: 15,
        ),
      );
    }

    // Fim de ano: primeiros dias de janeiro
    if (now.day <= 3 && now.month == 1) {
      final lastYear = now.year - 1;
      periods.add(
        RecapPeriod(
          type: RecapType.year,
          from: DateTime(lastYear),
          to: DateTime(lastYear + 1).subtract(const Duration(milliseconds: 1)),
          label: '$lastYear',
          topLimit: 15,
        ),
      );
    }

    return periods;
  }

  static Future<RecapResult> _buildRecap(
    RecapPeriod period,
    List<MusicTrack> tracks,
  ) async {
    final sessionData = await PlaySessionDatabase.instance.totalSecondsByTrack(
      from: period.from,
      to: period.to,
    );

    if (sessionData.isEmpty) {
      return RecapResult(period: period, topTracks: [], topArtists: []);
    }

    // Top músicas
    final trackStats = <_RankedTrack>[];
    for (final track in tracks) {
      final seconds = sessionData[track.id] ?? 0;
      if (seconds > 0)
        trackStats.add(_RankedTrack(track: track, seconds: seconds));
    }
    trackStats.sort((a, b) => b.seconds.compareTo(a.seconds));
    final topTracks = trackStats.take(period.topLimit).toList();

    // Top artistas (só o primeiro artista)
    final artistSeconds = <String, int>{};
    for (final track in tracks) {
      final seconds = sessionData[track.id] ?? 0;
      if (seconds <= 0) continue;
      final artist = track.artist.split(';').first.trim();
      if (artist.isEmpty) continue;
      artistSeconds[artist] = (artistSeconds[artist] ?? 0) + seconds;
    }
    final artistList =
        artistSeconds.entries
            .map((e) => _RankedArtist(artist: e.key, seconds: e.value))
            .toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final topArtists = artistList.take(period.topLimit).toList();

    return RecapResult(
      period: period,
      topTracks: topTracks,
      topArtists: topArtists,
    );
  }

  static String _keyFor(RecapPeriod period) {
    return '$_kPrefix${period.type.name}_${period.from.year}_${period.from.month}';
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _quarterLabel(DateTime start) {
    final q = ((start.month - 1) ~/ 3) + 1;
    return 'T$q ${start.year}';
  }

  static String _semesterLabel(DateTime start) {
    final s = start.month <= 6 ? 1 : 2;
    return '${s}º Semestre ${start.year}';
  }
}

// Expõe os tipos internos para uso no widget de recap
extension RecapResultAccess on RecapResult {
  List<({MusicTrack track, int seconds})> get tracks =>
      (topTracks).map((e) => (track: e.track, seconds: e.seconds)).toList();

  List<({String artist, int seconds})> get artists =>
      (topArtists).map((e) => (artist: e.artist, seconds: e.seconds)).toList();
}
