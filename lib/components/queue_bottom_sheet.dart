import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/current_queue_tile.dart';
import 'package:music_wave_player/components/draggable_sheet_scaffold.dart';
import 'package:music_wave_player/components/queue_upcoming_list.dart';
import 'package:music_wave_player/components/timer_active_banner.dart';
import 'package:music_wave_player/components/timer_bottom_sheet.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/providers/playback_notifier.dart';
import 'package:music_wave_player/providers/queue_notifier.dart';
import 'package:music_wave_player/providers/timer_notifier.dart';

class QueueBottomSheet extends ConsumerStatefulWidget {
  const QueueBottomSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueBottomSheet._(),
    );
  }

  @override
  ConsumerState<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends ConsumerState<QueueBottomSheet> {
  Future<void> _saveQueueAsPlaylist(
    BuildContext context,
    List<int> playbackQueue,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Salvar fila como playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da playlist'),
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
    if (name == null || name.isEmpty) return;

    final resolvedName = await _resolvePlaylistName(name);
    final playlist = await PlaylistDatabase.instance.createPlaylist(
      resolvedName,
    );
    await PlaylistDatabase.instance.addTracks(playlist.id!, playbackQueue);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist "$resolvedName" criada!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String> _resolvePlaylistName(String base) async {
    final existing = await PlaylistDatabase.instance.readAllPlaylists();
    final names = existing.map((p) => p.name).toSet();
    if (!names.contains(base)) return base;
    int counter = 1;
    while (names.contains('$base ($counter)')) {
      counter++;
    }
    return '$base ($counter)';
  }

  Future<void> _confirmClearQueue(
    BuildContext context,
    int? currentTrackId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar fila'),
        content: const Text(
          'Remover todas as músicas da fila exceto a que está tocando?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(queueNotifierProvider.notifier).clear(currentTrackId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final queueState = ref.watch(queueNotifierProvider);
    final playbackState = ref.watch(playbackNotifierProvider).valueOrNull;
    final indexedTracks =
        ref.watch(indexingNotifierProvider).valueOrNull?.indexedTracks ??
        const <MusicTrack>[];
    final timer = ref.watch(timerNotifierProvider);

    final fullQueue = queueState.playbackQueue;
    final currentIndex = queueState.currentQueueIndex;
    final isPlaying = playbackState?.isPlaying ?? false;

    MusicTrack? trackById(int id) =>
        indexedTracks.where((t) => t.id == id).firstOrNull;

    final currentTrack = currentIndex >= 0 && currentIndex < fullQueue.length
        ? trackById(fullQueue[currentIndex])
        : null;

    final nextQueueIds =
        currentIndex >= 0 && currentIndex + 1 < fullQueue.length
        ? fullQueue.sublist(currentIndex + 1)
        : <int>[];

    final upcomingTracks = nextQueueIds
        .map(trackById)
        .whereType<MusicTrack>()
        .toList();

    // Traduz um índice relativo a [upcomingTracks] para a posição real na
    // fila completa (offset pela faixa atual).
    int realIndexOf(int upcomingIndex) => currentIndex + 1 + upcomingIndex;

    return DraggableSheetScaffold(
      title: 'Fila de reprodução',
      actions: [
        if (upcomingTracks.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _saveQueueAsPlaylist(context, fullQueue);
                case 'clear':
                  _confirmClearQueue(context, playbackState?.lastPlayedMusicId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add),
                    SizedBox(width: 12),
                    Text('Salvar fila como playlist'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.playlist_remove),
                    SizedBox(width: 12),
                    Text('Limpar fila'),
                  ],
                ),
              ),
            ],
          ),
      ],
      bodyBuilder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Column(
          children: [
            if (timer.isActive)
              TimerActiveBanner(
                remainingLabel: timer.remainingLabel,
                onTap: () => TimerBottomSheet.show(context),
              ),

            if (currentTrack != null)
              CurrentQueueTile(
                track: currentTrack,
                isPlaying: isPlaying,
                onPlayPause: () => ref
                    .read(playbackNotifierProvider.notifier)
                    .togglePlayPause(
                      indexedTracks: indexedTracks,
                      currentTrackPath: currentTrack.path,
                    ),
              ),

            if (upcomingTracks.isNotEmpty) const Divider(height: 1),

            Expanded(
              child: QueueUpcomingList(
                upcomingTracks: upcomingTracks,
                hasCurrentTrack: currentTrack != null,
                scrollController: scrollController,
                bottomPadding: 8,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(queueNotifierProvider.notifier)
                      .reorder(
                        realIndexOf(oldIndex),
                        realIndexOf(newIndex),
                        playbackState?.lastPlayedMusicId,
                      );
                },
                onDismiss: (index) => ref
                    .read(playbackNotifierProvider.notifier)
                    .removeFromQueue(
                      realIndexOf(index),
                      indexedTracks: indexedTracks,
                    ),
                onTap: (index) {
                  ref
                      .read(playbackNotifierProvider.notifier)
                      .jumpToQueueIndex(
                        realIndexOf(index),
                        indexedTracks: indexedTracks,
                      );
                  Navigator.pop(context);
                },
              ),
            ),

            // Ordem aleatória e temporizador — atalhos rápidos, igual apps de
            // música consolidados.
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(playbackNotifierProvider.notifier)
                          .toggleShuffle(),
                      icon: Icon(
                        Icons.shuffle,
                        size: 18,
                        color: (playbackState?.isShuffleActive ?? false)
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        'Ordem aleatória',
                        style: TextStyle(
                          color: (playbackState?.isShuffleActive ?? false)
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: (playbackState?.isShuffleActive ?? false)
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => TimerBottomSheet.show(context),
                      icon: Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: timer.isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        'Timer',
                        style: TextStyle(
                          color: timer.isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: timer.isActive
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
