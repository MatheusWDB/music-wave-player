import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  static const _limitOptions = [10, 25, 50, 100];
  int _limit = 25;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();
    final allTracks = config.recentlyPlayedTracks;
    final tracks = allTracks.take(_limit).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproduzidas recentemente'),
        actions: [
          // Filtro de quantidade
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Quantidade exibida',
            initialValue: _limit,
            onSelected: (value) => setState(() => _limit = value),
            itemBuilder: (_) => _limitOptions.map((opt) {
              final isSelected = opt == _limit;
              return PopupMenuItem(
                value: opt,
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Últimas $opt',
                      style: TextStyle(
                        color: isSelected ? colorScheme.primary : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (allTracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpar histórico',
              onPressed: () => _confirmClear(context, config),
            ),
        ],
      ),
      body: tracks.isEmpty
          ? Center(
              child: Text(
                'Nenhuma música reproduzida ainda.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _TrackTile(track: track, position: index + 1);
              },
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, Configuration config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar histórico'),
        content: const Text('Deseja remover todo o histórico de reprodução?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await config.clearRecentlyPlayed();
  }
}

class _TrackTile extends StatelessWidget {
  final MusicTrack track;
  final int position;

  const _TrackTile({required this.track, required this.position});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<Configuration>();

    return ListTile(
      leading: CoverArtWidget(
        coverPath: track.coverPath,
        size: 48,
        borderRadius: BorderRadius.circular(6),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} · ${track.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      onTap: () {
        config.playTrack(track.id!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullPlayerScreen(initialTrackId: track.id),
          ),
        );
      },
    );
  }
}
