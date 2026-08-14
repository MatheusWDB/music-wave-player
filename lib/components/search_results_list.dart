import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';

/// Lista de resultados de busca, organizada em seções: músicas, artistas,
/// álbuns e playlists. Recebe os resultados já filtrados — não faz
/// nenhuma lógica de busca própria.
class SearchResultsList extends StatelessWidget {
  final List<MusicTrack> tracks;
  final Map<String, List<MusicTrack>> artists;
  final Map<String, List<MusicTrack>> albums;
  final List<Playlist> playlists;
  final ValueChanged<MusicTrack> onTrackTap;
  final void Function(String artist, List<MusicTrack> tracks) onArtistTap;
  final void Function(String album, List<MusicTrack> tracks) onAlbumTap;
  final ValueChanged<Playlist> onPlaylistTap;
  final ValueChanged<MusicTrack> onRateTrack;
  final ValueChanged<MusicTrack> onHideTrack;

  const SearchResultsList({
    super.key,
    required this.tracks,
    required this.artists,
    required this.albums,
    required this.playlists,
    required this.onTrackTap,
    required this.onArtistTap,
    required this.onAlbumTap,
    required this.onPlaylistTap,
    required this.onRateTrack,
    required this.onHideTrack,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        if (tracks.isNotEmpty) ...[
          _SectionHeader(label: 'Músicas', colorScheme: colorScheme),
          ...tracks.map(
            (track) => ListTile(
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
                '${track.artist} · ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rate') {
                    onRateTrack(track);
                  } else if (value == 'hide') {
                    onHideTrack(track);
                  }
                },
                itemBuilder: (_) => const [
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
              onTap: () => onTrackTap(track),
            ),
          ),
        ],
        if (artists.isNotEmpty) ...[
          _SectionHeader(label: 'Artistas', colorScheme: colorScheme),
          ...artists.entries.map(
            (e) => ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${e.value.length} música${e.value.length == 1 ? '' : 's'}',
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => onArtistTap(e.key, e.value),
            ),
          ),
        ],
        if (albums.isNotEmpty) ...[
          _SectionHeader(label: 'Álbuns', colorScheme: colorScheme),
          ...albums.entries.map(
            (e) => ListTile(
              leading: CoverArtWidget(
                coverPath: e.value
                    .firstWhere(
                      (t) => t.coverPath != null,
                      orElse: () => e.value.first,
                    )
                    .coverPath,
                size: 44,
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${e.value.first.artist} · ${e.value.length} música${e.value.length == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => onAlbumTap(e.key, e.value),
            ),
          ),
        ],
        if (playlists.isNotEmpty) ...[
          _SectionHeader(label: 'Playlists', colorScheme: colorScheme),
          ...playlists.map(
            (p) => ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.library_music_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${p.trackIds.length} música${p.trackIds.length == 1 ? '' : 's'}',
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => onPlaylistTap(p),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
