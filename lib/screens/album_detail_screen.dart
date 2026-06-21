import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/data/play_session_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String album;
  final List<MusicTrack> tracks;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.tracks,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late List<MusicTrack> _tracks;

  // Estatísticas
  _StatsPeriod _selectedPeriod = _StatsPeriod.lastMonth;
  int? _selectedYear;
  List<int> _availableYears = [];
  Map<int, int> _trackSeconds = {};
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tracks = List.of(widget.tracks);
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
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
        _loadingStats = false;
      });
    }
  }

  (DateTime, DateTime) _dateRange() {
    final now = DateTime.now();
    if (_selectedPeriod == _StatsPeriod.year && _selectedYear != null) {
      return (
        DateTime(_selectedYear!),
        DateTime(_selectedYear! + 1).subtract(const Duration(milliseconds: 1)),
      );
    }
    return switch (_selectedPeriod) {
      _StatsPeriod.lastMonth => (
        DateTime(now.year, now.month - 1, now.day),
        now,
      ),
      _StatsPeriod.lastQuarter => (
        DateTime(now.year, now.month - 3, now.day),
        now,
      ),
      _StatsPeriod.lastSemester => (
        DateTime(now.year, now.month - 6, now.day),
        now,
      ),
      _StatsPeriod.year => (DateTime(now.year), now),
    };
  }

  int get _totalSecondsForAlbum {
    return _tracks.fold(0, (sum, t) => sum + (_trackSeconds[t.id] ?? 0));
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}min' : '${h}h';
  }

  String _formatDuration(int totalMs) {
    final d = Duration(milliseconds: totalMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _hideTrack(MusicTrack track) async {
    await context.read<Configuration>().hideTracks([track.id!]);
    setState(() => _tracks.removeWhere((t) => t.id == track.id));
    _showSnack('Música ocultada.');
  }

  // ── Filtro de período ─────────────────────────────────────────────────────

  Widget _buildStatsFilter(ColorScheme colorScheme) {
    final periods = [
      (_StatsPeriod.lastMonth, 'Último mês'),
      (_StatsPeriod.lastQuarter, 'Trimestre'),
      (_StatsPeriod.lastSemester, 'Semestre'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  _loadStats();
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
                    _selectedPeriod = _StatsPeriod.year;
                    _selectedYear = year;
                  });
                  _loadStats();
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
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<Configuration>();
    final ids = _tracks.map((t) => t.id!).toList();
    final coverPath = _tracks
        .firstWhere((t) => t.coverPath != null, orElse: () => _tracks.first)
        .coverPath;
    final artist = widget.tracks.first.artist;
    final totalAlbumSeconds = _totalSecondsForAlbum;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'insert_next') {
                config.insertAfterCurrent(ids);
                _showSnack('Músicas adicionadas após a atual');
              } else if (value == 'add_end') {
                config.addToEndOfQueue(ids);
                _showSnack('Músicas adicionadas ao final da fila');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'insert_next',
                child: Row(
                  children: [
                    Icon(Icons.queue_play_next_outlined),
                    SizedBox(width: 12),
                    Text('Tocar a seguir'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_end',
                child: Row(
                  children: [
                    Icon(Icons.add_to_queue_outlined),
                    SizedBox(width: 12),
                    Text('Adicionar à fila'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CoverArtWidget(
                    coverPath: coverPath,
                    size: 80,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.album,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.length} música${_tracks.length == 1 ? '' : 's'} · ${_formatDuration(_tracks.fold(0, (sum, t) => sum + t.durationMs))}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_tracks.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      config.playTracks(_tracks);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Tocar'),
                  ),
              ],
            ),
          ),

          // Seção de estatísticas
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tempo ouvido',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      if (_loadingStats)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          totalAlbumSeconds > 0
                              ? _formatSeconds(totalAlbumSeconds)
                              : '—',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatsFilter(colorScheme),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Lista de músicas
          Expanded(
            child: _tracks.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma música visível.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      final trackSeconds = _trackSeconds[track.id] ?? 0;

                      return ListTile(
                        leading: CoverArtWidget(
                          coverPath: track.coverPath,
                          size: 44,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (trackSeconds > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  _formatSeconds(trackSeconds),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'insert_next') {
                                  config.insertAfterCurrent([track.id!]);
                                  _showSnack('Música adicionada após a atual');
                                } else if (value == 'add_end') {
                                  config.addToEndOfQueue([track.id!]);
                                  _showSnack(
                                    'Música adicionada ao final da fila',
                                  );
                                } else if (value == 'rate') {
                                  await RatingBottomSheet.show(
                                    context,
                                    track: track,
                                  );
                                } else if (value == 'hide') {
                                  await _hideTrack(track);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'insert_next',
                                  child: Row(
                                    children: [
                                      Icon(Icons.queue_play_next_outlined),
                                      SizedBox(width: 12),
                                      Text('Tocar a seguir'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'add_end',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_to_queue_outlined),
                                      SizedBox(width: 12),
                                      Text('Adicionar à fila'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'rate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.star_outline),
                                      SizedBox(width: 12),
                                      Text('Avaliar'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'hide',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_off_outlined),
                                      SizedBox(width: 12),
                                      Text('Ocultar'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          config.playTrack(track.id!);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FullPlayerScreen(initialTrackId: track.id),
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

enum _StatsPeriod { lastMonth, lastQuarter, lastSemester, year }
