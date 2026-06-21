import 'package:flutter/material.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/artist_detail_screen.dart';

class ArtistsTab extends StatelessWidget {
  final List<MusicTrack> tracks;
  final Future<void> Function(int) onTrackTap;

  const ArtistsTab({super.key, required this.tracks, required this.onTrackTap});

  Map<String, List<MusicTrack>> _groupByArtist() {
    final Map<String, List<MusicTrack>> grouped = {};
    for (final track in tracks) {
      final artists = track.artist
          .split(';')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty);
      for (final artist in artists) {
        grouped.putIfAbsent(artist, () => []).add(track);
      }
    }
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

        return ListTile(
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
          trailing: Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ArtistDetailScreen(artist: artist, tracks: artistTracks),
            ),
          ),
        );
      },
    );
  }
}
