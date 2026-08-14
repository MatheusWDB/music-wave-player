import 'package:flutter/material.dart';
import 'package:music_wave_player/components/current_queue_tile.dart';
import 'package:music_wave_player/components/queue_header_bar.dart';
import 'package:music_wave_player/components/queue_upcoming_list.dart';
import 'package:music_wave_player/components/timer_active_banner.dart';
import 'package:music_wave_player/components/timer_bottom_sheet.dart';
import 'package:music_wave_player/data/playlist_database.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/models/music_track.dart';
import 'package:music_wave_player/services/timer_service.dart';
import 'package:provider/provider.dart';

class QueueBottomSheet extends StatefulWidget {
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
  State<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<QueueBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveQueueAsPlaylist(
    BuildContext context,
    Configuration config,
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
    await PlaylistDatabase.instance.addTracks(
      playlist.id!,
      config.playbackQueue.toList(),
    );

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
    Configuration config,
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
    if (confirmed == true) config.clearQueue();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final config = context.watch<Configuration>();
    final timer = context.watch<SleepTimerService>();
    final fullQueue = config.playbackQueue;
    final tracks = config.indexedTracks;
    final currentIndex = config.currentQueueIndex;
    final isPlaying = config.isPlaying;

    MusicTrack? trackById(int id) {
      try {
        return tracks.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }

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

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Alça
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            QueueHeaderBar(
              hasUpcomingTracks: upcomingTracks.isNotEmpty,
              onSaveAsPlaylist: () => _saveQueueAsPlaylist(context, config),
              onClearQueue: () => _confirmClearQueue(context, config),
              onClose: () => Navigator.pop(context),
            ),

            if (timer.isActive)
              TimerActiveBanner(
                remainingLabel: timer.remainingLabel,
                onTap: () => TimerBottomSheet.show(context),
              ),

            const Divider(height: 1),

            if (currentTrack != null)
              CurrentQueueTile(
                track: currentTrack,
                isPlaying: isPlaying,
                onPlayPause: config.togglePlayPause,
              ),

            if (upcomingTracks.isNotEmpty) const Divider(height: 1),

            Expanded(
              child: QueueUpcomingList(
                upcomingTracks: upcomingTracks,
                hasCurrentTrack: currentTrack != null,
                scrollController: _scrollController,
                bottomPadding: bottomInset,
                onReorder: (oldIndex, newIndex) {
                  config.reorderQueue(
                    realIndexOf(oldIndex),
                    realIndexOf(newIndex),
                  );
                },
                onDismiss: (index) =>
                    config.removeFromQueue(realIndexOf(index)),
                onTap: (index) {
                  config.jumpToQueueIndex(realIndexOf(index));
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
