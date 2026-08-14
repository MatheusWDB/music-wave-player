import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Lista reordenável das próximas músicas na fila, com suporte a arrastar
/// (reordenar) e deslizar para remover.
///
/// Os índices em [onReorder], [onDismiss] e [onTap] são relativos a
/// [upcomingTracks] (0-based) — a tradução para a posição real na fila
/// completa é responsabilidade do chamador.
class QueueUpcomingList extends StatelessWidget {
  final List<MusicTrack> upcomingTracks;
  final bool hasCurrentTrack;
  final ScrollController scrollController;
  final double bottomPadding;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onDismiss;
  final ValueChanged<int> onTap;

  const QueueUpcomingList({
    super.key,
    required this.upcomingTracks,
    required this.hasCurrentTrack,
    required this.scrollController,
    required this.bottomPadding,
    required this.onReorder,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (upcomingTracks.isEmpty) {
      return Center(
        child: Text(
          hasCurrentTrack ? 'Sem próximas músicas.' : 'Fila vazia.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ReorderableListView.builder(
      scrollController: scrollController,
      padding: EdgeInsets.only(bottom: 16 + bottomPadding),
      itemCount: upcomingTracks.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final track = upcomingTracks[index];

        return Dismissible(
          key: ValueKey('${track.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: colorScheme.error,
            child: Icon(Icons.delete_outline, color: colorScheme.onError),
          ),
          onDismissed: (_) => onDismiss(index),
          child: ListTile(
            key: ValueKey('tile_${track.id}_$index'),
            contentPadding: const EdgeInsets.only(left: 16, right: 8),
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
            onTap: () => onTap(index),
          ),
        );
      },
    );
  }
}
