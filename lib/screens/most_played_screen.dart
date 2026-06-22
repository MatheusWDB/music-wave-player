import 'package:flutter/material.dart';
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
  _Period _selectedPeriod = _Period.lastMonth;
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

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}min' : '${h}h';
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (d.inHours > 0)
      return '${d.inHours}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

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
          _buildFilterBar(),
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
                      final hasPlays = stat.seconds > 0;

                      return ListTile(
                        leading: _RankBadge(
                          position: index + 1,
                          colorScheme: colorScheme,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                stat.track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!hasPlays)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nunca ouvida',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          stat.track.artist.split(';').first.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (hasPlays)
                              Text(
                                _formatSeconds(stat.seconds),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            Text(
                              _formatDuration(stat.track.durationMs),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          context.read<Configuration>().playTrack(
                            stat.track.id!,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullPlayerScreen(
                                initialTrackId: stat.track.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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

enum _Period { lastMonth, lastQuarter, lastSemester, year }

class _TrackStat {
  final MusicTrack track;
  final int seconds;
  const _TrackStat({required this.track, required this.seconds});
}
