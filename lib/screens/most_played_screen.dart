import 'package:flutter/material.dart';
import 'package:music_wave_player/components/listening_stats_section.dart';
import 'package:music_wave_player/components/period_filter_bar.dart';
import 'package:music_wave_player/components/ranked_track_tile.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

enum _SortOrder { mostPlayed, leastPlayed }

class MostPlayedScreen extends StatefulWidget {
  const MostPlayedScreen({super.key});

  @override
  State<MostPlayedScreen> createState() => _MostPlayedScreenState();
}

class _MostPlayedScreenState extends State<MostPlayedScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.lastMonth;
  int? _selectedYear;
  List<int> _availableYears = [];
  Map<int, int> _trackSeconds = {};
  bool _loading = true;
  _SortOrder _sortOrder = _SortOrder.mostPlayed;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final years = await PlaySessionDatabase.instance.availableYears();
    final range = _dateRange();
    final data = await PlaySessionDatabase.instance.totalSecondsByTrack(
      from: range.$1,
      to: range.$2,
    );
    if (mounted) {
      setState(() {
        _availableYears = years;
        _trackSeconds = data;
        _loading = false;
      });
    }
  }

  (DateTime, DateTime) _dateRange() {
    final now = DateTime.now();
    if (_selectedPeriod == StatsPeriod.year && _selectedYear != null) {
      return (
        DateTime(_selectedYear!),
        DateTime(_selectedYear! + 1).subtract(const Duration(milliseconds: 1)),
      );
    }
    return switch (_selectedPeriod) {
      StatsPeriod.lastMonth => (
        DateTime(now.year, now.month - 1, now.day),
        now,
      ),
      StatsPeriod.lastQuarter => (
        DateTime(now.year, now.month - 3, now.day),
        now,
      ),
      StatsPeriod.lastSemester => (
        DateTime(now.year, now.month - 6, now.day),
        now,
      ),
      StatsPeriod.year => (DateTime(now.year), now),
    };
  }

  void _onPeriodSelected(StatsPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _selectedYear = null;
    });
    _loadData();
  }

  void _onYearSelected(int year) {
    setState(() {
      _selectedPeriod = StatsPeriod.year;
      _selectedYear = year;
    });
    _loadData();
  }

  List<_TrackStat> _buildStats(List<MusicTrack> tracks) {
    final played = <_TrackStat>[];
    final neverPlayed = <_TrackStat>[];

    for (final track in tracks) {
      final seconds = _trackSeconds[track.id] ?? 0;
      if (seconds > 0) {
        played.add(_TrackStat(track: track, seconds: seconds));
      } else {
        neverPlayed.add(_TrackStat(track: track, seconds: 0));
      }
    }

    if (_sortOrder == _SortOrder.mostPlayed) {
      // Mais ouvidas: ouvidas DESC, nunca ouvidas por duração DESC
      played.sort((a, b) => b.seconds.compareTo(a.seconds));
      neverPlayed.sort(
        (a, b) => b.track.durationMs.compareTo(a.track.durationMs),
      );
      return [...played, ...neverPlayed];
    } else {
      // Menos ouvidas: nunca ouvidas por duração ASC, ouvidas ASC
      played.sort((a, b) => a.seconds.compareTo(b.seconds));
      neverPlayed.sort(
        (a, b) => a.track.durationMs.compareTo(b.track.durationMs),
      );
      return [...neverPlayed, ...played];
    }
  }

  void _openTrack(MusicTrack track) {
    context.read<Configuration>().playTrack(track.id!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(initialTrackId: track.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tracks = context.read<Configuration>().indexedTracks;
    final stats = _buildStats(tracks);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _sortOrder == _SortOrder.mostPlayed
              ? 'Mais ouvidas'
              : 'Menos ouvidas',
        ),
        actions: [
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Ordenação',
            initialValue: _sortOrder,
            onSelected: (value) => setState(() => _sortOrder = value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortOrder.mostPlayed,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: _sortOrder == _SortOrder.mostPlayed
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Mais ouvidas',
                      style: TextStyle(
                        color: _sortOrder == _SortOrder.mostPlayed
                            ? colorScheme.primary
                            : null,
                        fontWeight: _sortOrder == _SortOrder.mostPlayed
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _SortOrder.leastPlayed,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: _sortOrder == _SortOrder.leastPlayed
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Menos ouvidas',
                      style: TextStyle(
                        color: _sortOrder == _SortOrder.leastPlayed
                            ? colorScheme.primary
                            : null,
                        fontWeight: _sortOrder == _SortOrder.leastPlayed
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          PeriodFilterBar(
            selectedPeriod: _selectedPeriod,
            selectedYear: _selectedYear,
            availableYears: _availableYears,
            onPeriodSelected: _onPeriodSelected,
            onYearSelected: _onYearSelected,
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : stats.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma música encontrada.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: stats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final stat = stats[index];
                      return RankedTrackTile(
                        position: index + 1,
                        title: stat.track.title,
                        artist: stat.track.artist.split(';').first.trim(),
                        seconds: stat.seconds,
                        durationMs: stat.track.durationMs,
                        onTap: () => _openTrack(stat.track),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrackStat {
  final MusicTrack track;
  final int seconds;
  const _TrackStat({required this.track, required this.seconds});
}
