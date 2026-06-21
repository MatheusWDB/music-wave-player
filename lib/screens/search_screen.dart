import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/screens/album_detail_screen.dart';
import 'package:music_wave_player/screens/artist_detail_screen.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:music_wave_player/screens/playlist_detail_screen.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Playlist> _playlists = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await PlaylistDatabase.instance.readAllPlaylists();
    if (mounted) setState(() => _playlists = playlists);
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  List<String> _splitArtists(String artist) {
    return artist
        .split(';')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  List<MusicTrack> _matchingTracks(List<MusicTrack> all) {
    if (_query.isEmpty) return [];
    return all.where((t) {
      final artistMatch = _splitArtists(
        t.artist,
      ).any((a) => a.toLowerCase().contains(_query));
      return t.title.toLowerCase().contains(_query) ||
          artistMatch ||
          t.album.toLowerCase().contains(_query);
    }).toList();
  }

  Map<String, List<MusicTrack>> _matchingArtists(List<MusicTrack> all) {
    if (_query.isEmpty) return {};
    final Map<String, List<MusicTrack>> grouped = {};
    for (final track in all) {
      for (final artist in _splitArtists(track.artist)) {
        if (artist.toLowerCase().contains(_query)) {
          grouped.putIfAbsent(artist, () => []).add(track);
        }
      }
    }
    return grouped;
  }

  Map<String, List<MusicTrack>> _matchingAlbums(List<MusicTrack> all) {
    if (_query.isEmpty) return {};
    final Map<String, List<MusicTrack>> grouped = {};
    for (final track in all) {
      if (track.album.toLowerCase().contains(_query)) {
        grouped.putIfAbsent(track.album, () => []).add(track);
      }
    }
    return grouped;
  }

  List<Playlist> _matchingPlaylists() {
    if (_query.isEmpty) return [];
    return _playlists
        .where((p) => p.name.toLowerCase().contains(_query))
        .toList();
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _openTrack(BuildContext context, MusicTrack track) {
    context.read<Configuration>().playTrack(track.id!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(initialTrackId: track.id),
      ),
    );
  }

  void _openArtist(
    BuildContext context,
    String artist,
    List<MusicTrack> tracks,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(artist: artist, tracks: tracks),
      ),
    );
  }

  void _openAlbum(BuildContext context, String album, List<MusicTrack> tracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album, tracks: tracks),
      ),
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  Future<void> _hideTrack(MusicTrack track) async {
    await context.read<Configuration>().hideTracks([track.id!]);
    setState(() => _query = _query);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Música ocultada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<Configuration>();
    final allTracks = config.indexedTracks;

    final tracks = _matchingTracks(allTracks);
    final artists = _matchingArtists(allTracks);
    final albums = _matchingAlbums(allTracks);
    final playlists = _matchingPlaylists();

    final hasResults =
        tracks.isNotEmpty ||
        artists.isNotEmpty ||
        albums.isNotEmpty ||
        playlists.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Buscar músicas, artistas, álbuns...',
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _query.isEmpty
          ? Center(
              child: Text(
                'Digite para buscar',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : !hasResults
          ? Center(
              child: Text(
                'Nenhum resultado para "$_query"',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView(
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
                        onSelected: (value) async {
                          if (value == 'rate') {
                            await RatingBottomSheet.show(context, track: track);
                          } else if (value == 'hide') {
                            await _hideTrack(track);
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
                      onTap: () => _openTrack(context, track),
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
                      title: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.value.length} música${e.value.length == 1 ? '' : 's'}',
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _openArtist(context, e.key, e.value),
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
                      title: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.value.first.artist} · ${e.value.length} música${e.value.length == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _openAlbum(context, e.key, e.value),
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
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${p.trackIds.length} música${p.trackIds.length == 1 ? '' : 's'}',
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _openPlaylist(context, p),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
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
