import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/edit_track_bottom_sheet.dart';
import 'package:music_wave_player/components/music_track_tile.dart';
import 'package:music_wave_player/components/pick_playlist_dialog.dart';
import 'package:music_wave_player/components/rating_bottom_sheet.dart';
import 'package:music_wave_player/components/selection_action_bar.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/current_track_provider.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrentTrack(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Deixa a música tocando no topo da tela ao abrir a aba, sem precisar
  // medir o layout — usa MusicTrackTile.itemExtent, que é a altura fixa do
  // item.
  void _scrollToCurrentTrack() {
    if (!_scrollController.hasClients) return;

    final currentTrackId = ref.read(currentTrackProvider)?.id;
    if (currentTrackId == null) return;

    final index = widget.tracks.indexWhere((t) => t.id == currentTrackId);
    if (index < 0) return;

    final target = index * MusicTrackTile.itemExtent;

    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

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
    final currentTrackId = ref.watch(currentTrackProvider)?.id;

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          // 150 ≈ altura do mini player + menu flutuantes (library_screen.dart),
          // pra última música não ficar permanentemente escondida atrás deles.
          padding: EdgeInsets.only(bottom: _isSelecting ? 220 : 150),
          itemCount: widget.tracks.length,
          itemExtent: MusicTrackTile.itemExtent,
          itemBuilder: (context, index) {
            final track = widget.tracks[index];
            final isSelected = _selected.contains(track.id);

            return MusicTrackTile(
              track: track,
              isSelecting: _isSelecting,
              isSelected: isSelected,
              isCurrentTrack: track.id == currentTrackId,
              onToggleSelection: () => _toggleSelection(track.id!),
              onTap: () => widget.onTrackTap(track.id!),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: SelectionActionBar(
              selectedCount: _selected.length,
              onClear: _clearSelection,
              onHide: _hideSelected,
              onFavorite: _favoriteSelected,
              onAddToPlaylist: _addSelectedToPlaylist,
            ),
          ),
      ],
    );
  }
}
