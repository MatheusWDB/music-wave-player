import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/components/track_options_bottom_sheet.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item de lista de uma música, com suporte a modo de seleção (checkbox no
/// lugar da capa) e menu de ações rápidas quando fora do modo de seleção.
///
/// Visual chapado (sem fundo próprio por item) — o destaque de elevação
/// fica reservado ao miniplayer.
class MusicTrackTile extends StatelessWidget {
  /// Altura total de cada item (conteúdo + margem), usada pelo
  /// [ScrollController] em `musics_tab.dart` para rolar até uma música
  /// específica sem precisar medir o layout. Se o padding, a margem ou o
  /// tamanho da capa mudarem aqui, atualize esta constante também.
  static const double itemExtent = 76;

  final MusicTrack track;
  final bool isSelecting;
  final bool isSelected;
  final bool isCurrentTrack;
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
    this.isCurrentTrack = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isSelecting ? onToggleSelection : onTap,
      onLongPress: onToggleSelection,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    size: 56,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isCurrentTrack ? colorScheme.primary : null,
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
              if (!isSelecting)
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => TrackOptionsBottomSheet.show(
                    context,
                    track: track,
                    onEdit: onEdit,
                    onRate: onRate,
                    onAddToPlaylist: onAddToPlaylist,
                    onInsertNext: onInsertNext,
                    onAddToEnd: onAddToEnd,
                    onHide: onHide,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
