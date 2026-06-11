import 'package:flutter/material.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';

class AlbumsTab extends StatelessWidget {
  final List<MusicTrack> tracks;
  final Function(int) onTrackTap;

  const AlbumsTab({super.key, required this.tracks, required this.onTrackTap});

  /// Agrupa as faixas por álbum, retornando um mapa ordenado alfabeticamente.
  Map<String, List<MusicTrack>> _groupByAlbum() {
    final Map<String, List<MusicTrack>> grouped = {};
    for (final track in tracks) {
      grouped.putIfAbsent(track.album, () => []).add(track);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupByAlbum();
    final albums = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 10.0),
      itemCount: albums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4.0),
      itemBuilder: (context, index) {
        final album = albums[index];
        final albumTracks = grouped[album]!;
        // Pega o artista mais comum do álbum para exibir no subtítulo
        final artist = albumTracks.first.artist;

        return ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Icon(Icons.album, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(
            album,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '$artist · ${albumTracks.length} música${albumTracks.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          children: albumTracks.map((track) {
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 72.0, right: 16.0),
              title: Text(
                track.title,
                style: TextStyle(color: colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                track.artist,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                onTrackTap(track.id!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullPlayerScreen(initialTrackId: track.id!),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
