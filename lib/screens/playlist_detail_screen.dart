import 'package:flutter/material.dart';
import 'package:music_wave_player/components/playlist_header_card.dart';
import 'package:music_wave_player/components/playlist_track_tile.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/components/track_selection_bottom_sheet.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:music_wave_player/services/favorites_service.dart';
import 'package:provider/provider.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  Future<void> _reload() async {
    final updated = await PlaylistDatabase.instance.readPlaylist(_playlist.id!);
    if (updated != null && mounted) setState(() => _playlist = updated);
  }

  List<MusicTrack> _getTracks(List<MusicTrack> allTracks) {
    return _playlist.trackIds
        .map((id) {
          try {
            return allTracks.firstWhere((t) => t.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<MusicTrack>()
        .toList();
  }

  Future<void> _addTracks(List<MusicTrack> allTracks) async {
    final selected = await TrackSelectionBottomSheet.show(
      context,
      tracks: allTracks,
      alreadySelected: _playlist.trackIds,
      title: 'Adicionar músicas',
    );
    if (selected == null || selected.isEmpty) return;
    setState(() => _loading = true);
    await PlaylistDatabase.instance.addTracks(_playlist.id!, selected);
    await _reload();
    setState(() => _loading = false);
  }

  Future<void> _removeTrack(int trackId) async {
    await PlaylistDatabase.instance.removeTrack(_playlist.id!, trackId);
    await _reload();
  }

  Future<void> _hideTrack(MusicTrack track) async {
    await context.read<Configuration>().hideTracks([track.id!]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Música ocultada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _playlist.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await PlaylistDatabase.instance.renamePlaylist(_playlist.id!, newName);
    await _reload();
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

  void _showQueueSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.read<Configuration>();
    final allTracks = config.indexedTracks;
    final tracks = _getTracks(allTracks);
    final ids = tracks.map((t) => t.id!).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          if (_playlist.name != FavoritesService.favoritesName)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _rename,
              tooltip: 'Renomear',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'play') {
                config.playPlaylist(_playlist);
                Navigator.pop(context);
              } else if (value == 'insert_next') {
                config.insertAfterCurrent(ids);
                _showQueueSnack('Músicas adicionadas após a atual');
              } else if (value == 'add_end') {
                config.addToEndOfQueue(ids);
                _showQueueSnack('Músicas adicionadas ao final da fila');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'play',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_outlined),
                    SizedBox(width: 12),
                    Text('Tocar playlist'),
                  ],
                ),
              ),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                PlaylistHeaderCard(
                  name: _playlist.name,
                  coverPath: tracks.isNotEmpty ? tracks.first.coverPath : null,
                  trackCount: tracks.length,
                  durationLabel: _formatDuration(
                    tracks.fold(0, (sum, t) => sum + t.durationMs),
                  ),
                  onPlay: tracks.isNotEmpty
                      ? () {
                          config.playPlaylist(_playlist);
                          Navigator.pop(context);
                        }
                      : null,
                ),
                const Divider(height: 1),
                Expanded(
                  child: tracks.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma música ainda.\nToque + para adicionar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tracks.length,
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return PlaylistTrackTile(
                              track: track,
                              onRemove: () => _removeTrack(track.id!),
                              onRate: () =>
                                  RatingBottomSheet.show(context, track: track),
                              onHide: () => _hideTrack(track),
                              onTap: () {
                                config.playTrack(track.id!);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullPlayerScreen(
                                      initialTrackId: track.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTracks(allTracks),
        tooltip: 'Adicionar músicas',
        child: const Icon(Icons.add),
      ),
    );
  }
}
