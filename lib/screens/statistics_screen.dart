import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/listening_stats_section.dart';
import 'package:music_wave_player/components/period_filter_bar.dart';
import 'package:music_wave_player/components/stat_rank_tile.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StatsPeriod _selectedPeriod = StatsPeriod.lastMonth;
  int? _selectedYear;
  List<int> _availableYears = [];
  bool _loading = true;

  Map<int, int> _trackSeconds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadYears();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadYears() async {
    final years = await PlaySessionDatabase.instance.availableYears();
    setState(() => _availableYears = years);
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final range = _dateRange();
    final data = await PlaySessionDatabase.instance.totalSecondsByTrack(
      from: range.$1,
      to: range.$2,
    );
    setState(() {
      _trackSeconds = data;
      _loading = false;
    });
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

  // ── Agrupamentos ──────────────────────────────────────────────────────────

  List<_TrackStat> _trackStats(List<MusicTrack> tracks) {
    final result = <_TrackStat>[];
    for (final track in tracks) {
      final seconds = _trackSeconds[track.id] ?? 0;
      if (seconds > 0) result.add(_TrackStat(track: track, seconds: seconds));
    }
    result.sort((a, b) => b.seconds.compareTo(a.seconds));
    return result;
  }

  List<_ArtistStat> _artistStats(List<MusicTrack> tracks) {
    final Map<String, int> artistSeconds = {};
    for (final track in tracks) {
      final seconds = _trackSeconds[track.id] ?? 0;
      if (seconds <= 0) continue;
      final artist = track.artist.split(';').first.trim();
      if (artist.isEmpty) continue;
      artistSeconds[artist] = (artistSeconds[artist] ?? 0) + seconds;
    }
    final result =
        artistSeconds.entries
            .map((e) => _ArtistStat(artist: e.key, seconds: e.value))
            .toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tracks =
        ref.watch(indexingNotifierProvider).valueOrNull?.indexedTracks ??
        const <MusicTrack>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Músicas'),
            Tab(text: 'Artistas'),
          ],
        ),
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TrackStatsTab(stats: _trackStats(tracks)),
                      _ArtistStatsTab(stats: _artistStats(tracks)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Aba Músicas ───────────────────────────────────────────────────────────────

class _TrackStatsTab extends StatelessWidget {
  final List<_TrackStat> stats;

  const _TrackStatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (stats.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma reprodução neste período.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return StatRankTile(
          position: index + 1,
          title: stat.track.title,
          subtitle: stat.track.artist.split(';').first.trim(),
          timeLabel: ListeningStatsSection.formatSeconds(stat.seconds),
        );
      },
    );
  }
}

// ── Aba Artistas ──────────────────────────────────────────────────────────────

class _ArtistStatsTab extends StatelessWidget {
  final List<_ArtistStat> stats;

  const _ArtistStatsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (stats.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma reprodução neste período.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return StatRankTile(
          position: index + 1,
          title: stat.artist,
          timeLabel: ListeningStatsSection.formatSeconds(stat.seconds),
        );
      },
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────────────────

class _TrackStat {
  final MusicTrack track;
  final int seconds;
  const _TrackStat({required this.track, required this.seconds});
}

class _ArtistStat {
  final String artist;
  final int seconds;
  const _ArtistStat({required this.artist, required this.seconds});
}
