import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/favorite_button.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item de lista de uma música, com suporte a modo de seleção (checkbox no
/// lugar da capa) e menu de ações rápidas quando fora do modo de seleção.
class MusicTrackTile extends StatelessWidget {
  final MusicTrack track;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;
  final VoidCallback onEdit;
  final VoidCallback onRate;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onInsertNext;
  final VoidCallback onAddToEnd;
  final VoidCallback onHide;

  const MusicTrackTile({
    super.key,
    required this.track,
    required this.isSelecting,
    required this.isSelected,
    required this.onTap,
    required this.onToggleSelection,
    required this.onEdit,
    required this.onRate,
    required this.onAddToPlaylist,
    required this.onInsertNext,
    required this.onAddToEnd,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isSelecting ? onToggleSelection : onTap,
      onLongPress: onToggleSelection,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (isSelecting)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelection(),
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
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
              if (!isSelecting) FavoriteButton(trackId: track.id!),
              if (!isSelecting)
                _ActionsMenu(
                  onEdit: onEdit,
                  onRate: onRate,
                  onAddToPlaylist: onAddToPlaylist,
                  onInsertNext: onInsertNext,
                  onAddToEnd: onAddToEnd,
                  onHide: onHide,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onRate;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onInsertNext;
  final VoidCallback onAddToEnd;
  final VoidCallback onHide;

  const _ActionsMenu({
    required this.onEdit,
    required this.onRate,
    required this.onAddToPlaylist,
    required this.onInsertNext,
    required this.onAddToEnd,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'insert_next':
            onInsertNext();
          case 'add_end':
            onAddToEnd();
          case 'edit':
            onEdit();
          case 'rate':
            onRate();
          case 'playlist':
            onAddToPlaylist();
          case 'hide':
            onHide();
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
          value: 'playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_outlined),
              SizedBox(width: 12),
              Text('Adicionar à playlist'),
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
    );
  }
}
