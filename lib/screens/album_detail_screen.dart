import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String album;
  final List<MusicTrack> tracks;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<Configuration>();

    // Capa do álbum: usa a primeira faixa que tiver coverPath
    final coverPath = tracks
        .firstWhere((t) => t.coverPath != null, orElse: () => tracks.first)
        .coverPath;

    // Artista mais representativo (primeiro da lista)
    final artist = tracks.first.artist;

    return Scaffold(
      appBar: AppBar(title: Text(album)),
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
                        album,
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
                        '${tracks.length} música${tracks.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    config.playTracks(tracks);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Tocar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de músicas
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
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
