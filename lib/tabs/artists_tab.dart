import 'package:flutter/material.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';

class ArtistsTab extends StatelessWidget {
  final List<MusicTrack> tracks;
  final Function(int) onTrackTap;

  const ArtistsTab({super.key, required this.tracks, required this.onTrackTap});

  /// Agrupa as faixas por artista, retornando um mapa ordenado alfabeticamente.
  Map<String, List<MusicTrack>> _groupByArtist() {
    final Map<String, List<MusicTrack>> grouped = {};
    for (final track in tracks) {
      grouped.putIfAbsent(track.artist, () => []).add(track);
    }
    // Ordena os artistas alfabeticamente
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupByArtist();
    final artists = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 10.0),
      itemCount: artists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4.0),
      itemBuilder: (context, index) {
        final artist = artists[index];
        final artistTracks = grouped[artist]!;

        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(
            artist,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${artistTracks.length} música${artistTracks.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12.0,
            ),
          ),
          children: artistTracks.map((track) {
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 72.0, right: 16.0),
              title: Text(
                track.title,
                style: TextStyle(color: colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                track.album,
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
