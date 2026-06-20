import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/edit_track_bottom_sheet.dart';
import 'package:music_wave_player/components/favorite_button.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/models/playlist.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:provider/provider.dart';

class MusicsTab extends StatefulWidget {
  final List<MusicTrack> tracks;
  final Future<void> Function(int) onTrackTap;

  const MusicsTab({super.key, required this.tracks, required this.onTrackTap});

  @override
  State<MusicsTab> createState() => _MusicsTabState();
}

class _MusicsTabState extends State<MusicsTab> {
  final Set<int> _selected = {};
  bool get _isSelecting => _selected.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  Future<void> _addSelectedToPlaylist() async {
    final playlists = await PlaylistDatabase.instance.readAllPlaylists();
    if (!mounted) return;

    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => _PickPlaylistDialog(playlists: playlists),
    );

    if (result == null) return;

    int playlistId;
    if (result is String) {
      final newPlaylist = await PlaylistDatabase.instance.createPlaylist(
        result,
      );
      playlistId = newPlaylist.id!;
    } else if (result is int) {
      playlistId = result;
    } else {
      return;
    }

    await PlaylistDatabase.instance.addTracks(playlistId, _selected.toList());
    _clearSelection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Músicas adicionadas à playlist!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
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

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.only(bottom: _isSelecting ? 80 : 10),
          itemCount: widget.tracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final track = widget.tracks[index];
            final isSelected = _selected.contains(track.id);

            return InkWell(
              onTap: () {
                if (_isSelecting) {
                  _toggleSelection(track.id!);
                } else {
                  widget.onTrackTap(track.id!);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FullPlayerScreen(initialTrackId: track.id),
                    ),
                  );
                }
              },
              onLongPress: () => _toggleSelection(track.id!),
              borderRadius: BorderRadius.circular(12),
              child: Card(
                color: isSelected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      if (_isSelecting)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(track.id!),
                            activeColor: colorScheme.primary,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: CoverArtWidget(
                            coverPath: track.coverPath,
                            size: 48,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isSelecting) FavoriteButton(trackId: track.id!),
                      if (!_isSelecting)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await EditTrackBottomSheet.show(
                                context,
                                track: track,
                              );
                            } else if (value == 'playlist') {
                              setState(() => _selected.add(track.id!));
                              await _addSelectedToPlaylist();
                            } else if (value == 'insert_next') {
                              config.insertAfterCurrent([track.id!]);
                              _showQueueSnack('Música adicionada após a atual');
                            } else if (value == 'add_end') {
                              config.addToEndOfQueue([track.id!]);
                              _showQueueSnack(
                                'Música adicionada ao final da fila',
                              );
                            }
                          },
                          itemBuilder: (_) => const [
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
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined),
                                  SizedBox(width: 12),
                                  Text('Editar informações'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'playlist',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add_outlined),
                                  SizedBox(width: 12),
                                  Text('Adicionar à playlist'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Barra de ações do modo seleção
        if (_isSelecting)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancelar seleção',
                  ),
                  Expanded(
                    child: Text(
                      '${_selected.length} selecionada${_selected.length == 1 ? '' : 's'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addSelectedToPlaylist,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PickPlaylistDialog extends StatelessWidget {
  final List<Playlist> playlists;
  const _PickPlaylistDialog({required this.playlists});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Adicionar à playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: colorScheme.primary,
              ),
              title: const Text('Nova playlist'),
              onTap: () async {
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Nome da playlist'),
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
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text('Criar'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty && context.mounted) {
                  Navigator.pop(context, name);
                }
              },
            ),
            if (playlists.isNotEmpty) const Divider(),
            ...playlists.map(
              (p) => ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: Text(p.name),
                subtitle: Text(
                  '${p.trackIds.length} música${p.trackIds.length == 1 ? '' : 's'}',
                ),
                onTap: () => Navigator.pop(context, p.id),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
