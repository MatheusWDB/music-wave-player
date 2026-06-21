import 'package:flutter/material.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:provider/provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Period _selectedPeriod = _Period.lastMonth;
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
    if (_selectedPeriod == _Period.year && _selectedYear != null) {
      return (
        DateTime(_selectedYear!),
        DateTime(_selectedYear! + 1).subtract(const Duration(milliseconds: 1)),
      );
    }
    return switch (_selectedPeriod) {
      _Period.lastMonth => (DateTime(now.year, now.month - 1, now.day), now),
      _Period.lastQuarter => (DateTime(now.year, now.month - 3, now.day), now),
      _Period.lastSemester => (DateTime(now.year, now.month - 6, now.day), now),
      _Period.year => (DateTime(now.year), now),
    };
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}min' : '${h}h';
  }

  // ── Filtro UI ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final colorScheme = Theme.of(context).colorScheme;

    final periods = [
      (_Period.lastMonth, 'Último mês'),
      (_Period.lastQuarter, 'Trimestre'),
      (_Period.lastSemester, 'Semestre'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ...periods.map((p) {
            final isSelected = _selectedPeriod == p.$1 && _selectedYear == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(p.$2),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedPeriod = p.$1;
                    _selectedYear = null;
                  });
                  _loadData();
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              ),
            );
          }),
          ..._availableYears.map((year) {
            final isSelected = _selectedYear == year;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('$year'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedPeriod = _Period.year;
                    _selectedYear = year;
                  });
                  _loadData();
                },
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tracks = context.read<Configuration>().indexedTracks;

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
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TrackStatsTab(
                        stats: _trackStats(tracks),
                        formatSeconds: _formatSeconds,
                      ),
                      _ArtistStatsTab(
                        stats: _artistStats(tracks),
                        formatSeconds: _formatSeconds,
                      ),
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
  final String Function(int) formatSeconds;

  const _TrackStatsTab({required this.stats, required this.formatSeconds});

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
        return ListTile(
          leading: _RankBadge(position: index + 1, colorScheme: colorScheme),
          title: Text(
            stat.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            stat.track.artist.split(';').first.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          trailing: Text(
            formatSeconds(stat.seconds),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

// ── Aba Artistas ──────────────────────────────────────────────────────────────

class _ArtistStatsTab extends StatelessWidget {
  final List<_ArtistStat> stats;
  final String Function(int) formatSeconds;

  const _ArtistStatsTab({required this.stats, required this.formatSeconds});

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
        return ListTile(
          leading: _RankBadge(position: index + 1, colorScheme: colorScheme),
          title: Text(
            stat.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            formatSeconds(stat.seconds),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int position;
  final ColorScheme colorScheme;

  const _RankBadge({required this.position, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isTop3 = position <= 3;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isTop3
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$position',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTop3 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────────────────

enum _Period { lastMonth, lastQuarter, lastSemester, year }

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
