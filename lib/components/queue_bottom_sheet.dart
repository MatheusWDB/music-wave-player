import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
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

    final nextQueue = currentIndex >= 0 && currentIndex + 1 < fullQueue.length
        ? fullQueue.sublist(currentIndex + 1)
        : <int>[];

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

            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fila de reprodução',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (nextQueue.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.playlist_add,
                        color: colorScheme.primary,
                      ),
                      tooltip: 'Salvar fila como playlist',
                      onPressed: () => _saveQueueAsPlaylist(context, config),
                    ),
                  if (nextQueue.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.playlist_remove,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Limpar fila',
                      onPressed: () => _confirmClearQueue(context, config),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),

            // Banner do temporizador ativo
            if (timer.isActive)
              GestureDetector(
                onTap: () => TimerBottomSheet.show(context),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bedtime_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Temporizador: ${timer.remainingLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

            const Divider(height: 1),

            // Música atual
            if (currentTrack != null)
              _CurrentTile(
                track: currentTrack,
                isPlaying: isPlaying,
                colorScheme: colorScheme,
                onPlayPause: config.togglePlayPause,
              ),

            if (nextQueue.isNotEmpty) const Divider(height: 1),

            // Próximas músicas
            Expanded(
              child: nextQueue.isEmpty
                  ? Center(
                      child: Text(
                        currentTrack == null
                            ? 'Fila vazia.'
                            : 'Sem próximas músicas.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ReorderableListView.builder(
                      scrollController: _scrollController,
                      padding: EdgeInsets.only(bottom: 16 + bottomInset),
                      itemCount: nextQueue.length,
                      onReorder: (oldIndex, newIndex) {
                        final realOld = currentIndex + 1 + oldIndex;
                        final realNew = currentIndex + 1 + newIndex;
                        config.reorderQueue(realOld, realNew);
                      },
                      itemBuilder: (context, index) {
                        final realIndex = currentIndex + 1 + index;
                        final track = trackById(nextQueue[index]);
                        if (track == null) {
                          return const SizedBox.shrink(key: ValueKey(-1));
                        }

                        return Dismissible(
                          key: ValueKey('${track.id}_$realIndex'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: colorScheme.error,
                            child: Icon(
                              Icons.delete_outline,
                              color: colorScheme.onError,
                            ),
                          ),
                          onDismissed: (_) => config.removeFromQueue(realIndex),
                          child: ListTile(
                            key: ValueKey('tile_${track.id}_$realIndex'),
                            contentPadding: const EdgeInsets.only(
                              left: 16,
                              right: 8,
                            ),
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
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () {
                              config.jumpToQueueIndex(realIndex);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentTile extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final ColorScheme colorScheme;
  final VoidCallback onPlayPause;

  const _CurrentTile({
    required this.track,
    required this.isPlaying,
    required this.colorScheme,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 8),
        leading: CoverArtWidget(
          coverPath: track.coverPath,
          size: 44,
          borderRadius: BorderRadius.circular(6),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Tocando agora',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: colorScheme.primary,
            size: 32,
          ),
          onPressed: onPlayPause,
        ),
      ),
    );
  }
}
