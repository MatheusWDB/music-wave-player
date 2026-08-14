import 'package:flutter/material.dart';
import 'package:music_wave_player/components/grouped_entity_tile.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/screens/album_detail_screen.dart';

class AlbumsTab extends StatelessWidget {
  final List<MusicTrack> tracks;
  final Future<void> Function(int) onTrackTap;

  const AlbumsTab({super.key, required this.tracks, required this.onTrackTap});

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
    final grouped = _groupByAlbum();
    final albums = grouped.keys.toList();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 10.0),
      itemCount: albums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4.0),
      itemBuilder: (context, index) {
        final album = albums[index];
        final albumTracks = grouped[album]!;
        final coverPath = albumTracks
            .firstWhere(
              (t) => t.coverPath != null,
              orElse: () => albumTracks.first,
            )
            .coverPath;

        return GroupedEntityTile(
          leading: EntityCoverThumbnail(
            coverPath: coverPath,
            fallbackIcon: Icons.album,
          ),
          title: album,
          subtitle:
              '${albumTracks.first.artist} · ${albumTracks.length} música${albumTracks.length == 1 ? '' : 's'}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AlbumDetailScreen(album: album, tracks: albumTracks),
            ),
          ),
        );
      },
    );
  }
}
