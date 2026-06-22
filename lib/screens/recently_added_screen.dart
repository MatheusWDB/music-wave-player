import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class RecentlyAddedScreen extends StatelessWidget {
  const RecentlyAddedScreen({super.key});

  List<MusicTrack> _sorted(List<MusicTrack> tracks) {
    final list = List<MusicTrack>.of(tracks);
    list.sort((a, b) {
      // Faixas sem data ficam no final
      if (a.addedAt == null && b.addedAt == null) return 0;
      if (a.addedAt == null) return 1;
      if (b.addedAt == null) return -1;
      return b.addedAt!.compareTo(a.addedAt!);
    });
    return list;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoje';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    if (diff.inDays < 30)
      return 'Há ${(diff.inDays / 7).floor()} semana${(diff.inDays / 7).floor() == 1 ? '' : 's'}';
    if (diff.inDays < 365)
      return 'Há ${(diff.inDays / 30).floor()} mês${(diff.inDays / 30).floor() == 1 ? '' : 'es'}';
    return 'Há ${(diff.inDays / 365).floor()} ano${(diff.inDays / 365).floor() == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();
    final tracks = _sorted(config.indexedTracks);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionadas recentemente')),
      body: tracks.isEmpty
          ? Center(
              child: Text(
                'Nenhuma música indexada.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  leading: CoverArtWidget(
                    coverPath: track.coverPath,
                    size: 48,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${track.artist.split(';').first.trim()} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(
                    _formatDate(track.addedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
    );
  }
}
