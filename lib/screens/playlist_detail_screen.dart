import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/track_selection_bottom_sheet.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
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
                // Cabeçalho
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            tracks.isNotEmpty && tracks.first.coverPath != null
                            ? CoverArtWidget(
                                coverPath: tracks.first.coverPath,
                                size: 80,
                                borderRadius: BorderRadius.circular(12),
                              )
                            : Icon(
                                Icons.library_music,
                                size: 40,
                                color: colorScheme.onPrimaryContainer,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _playlist.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tracks.length} música${tracks.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tracks.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () {
                            config.playPlaylist(_playlist);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Tocar'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de faixas
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
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: colorScheme.error,
                                onPressed: () => _removeTrack(track.id!),
                                tooltip: 'Remover da playlist',
                              ),
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
