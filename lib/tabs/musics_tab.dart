import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/edit_track_bottom_sheet.dart';
import 'package:music_wave_player/components/music_track_tile.dart';
import 'package:music_wave_player/components/pick_playlist_dialog.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/components/selection_action_bar.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/screens/full_player_screen.dart';
import 'package:music_wave_player/services/favorites_service.dart';

class MusicsTab extends ConsumerStatefulWidget {
  final List<MusicTrack> tracks;
  final Future<void> Function(int) onTrackTap;

  const MusicsTab({super.key, required this.tracks, required this.onTrackTap});

  @override
  ConsumerState<MusicsTab> createState() => _MusicsTabState();
}

class _MusicsTabState extends ConsumerState<MusicsTab> {
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

  Future<void> _addTracksToPlaylist(List<int> trackIds) async {
    final playlists = await PlaylistDatabase.instance.readAllPlaylists();
    if (!mounted) return;

    final playlistId = await PickPlaylistDialog.show(
      context,
      playlists: playlists,
    );
    if (playlistId == null) return;

    await PlaylistDatabase.instance.addTracks(playlistId, trackIds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trackIds.length == 1
                ? 'Música adicionada à playlist!'
                : 'Músicas adicionadas à playlist!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _addSelectedToPlaylist() async {
    final ids = _selected.toList();
    _clearSelection();
    await _addTracksToPlaylist(ids);
  }

  Future<void> _favoriteSelected() async {
    final ids = _selected.toList();
    _clearSelection();
    final playlistId = await FavoritesService.ensurePlaylist();
    await PlaylistDatabase.instance.addTracks(playlistId, ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} música${ids.length == 1 ? '' : 's'} adicionada${ids.length == 1 ? '' : 's'} aos favoritos!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _hideSelected() async {
    final ids = _selected.toList();
    _clearSelection();
    await ref.read(indexingNotifierProvider.notifier).hideTracks(ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} música${ids.length == 1 ? '' : 's'} ocultada${ids.length == 1 ? '' : 's'}.',
          ),
          behavior: SnackBarBehavior.floating,
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
    final queueNotifier = ref.read(queueNotifierProvider.notifier);
    final indexingNotifier = ref.read(indexingNotifierProvider.notifier);

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.only(bottom: _isSelecting ? 80 : 10),
          itemCount: widget.tracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final track = widget.tracks[index];
            final isSelected = _selected.contains(track.id);

            return MusicTrackTile(
              track: track,
              isSelecting: _isSelecting,
              isSelected: isSelected,
              onToggleSelection: () => _toggleSelection(track.id!),
              onTap: () {
                widget.onTrackTap(track.id!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullPlayerScreen(initialTrackId: track.id),
                  ),
                );
              },
              onEdit: () => EditTrackBottomSheet.show(context, track: track),
              onRate: () => RatingBottomSheet.show(context, track: track),
              onAddToPlaylist: () => _addTracksToPlaylist([track.id!]),
              onInsertNext: () {
                queueNotifier.insertAfterCurrent([track.id!]);
                _showQueueSnack('Música adicionada após a atual');
              },
              onAddToEnd: () {
                queueNotifier.addToEnd([track.id!]);
                _showQueueSnack('Música adicionada ao final da fila');
              },
              onHide: () async {
                await indexingNotifier.hideTracks([track.id!]);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Música ocultada.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            );
          },
        ),
        if (_isSelecting)
          SelectionActionBar(
            selectedCount: _selected.length,
            onClear: _clearSelection,
            onHide: _hideSelected,
            onFavorite: _favoriteSelected,
            onAddToPlaylist: _addSelectedToPlaylist,
          ),
      ],
    );
  }
}
