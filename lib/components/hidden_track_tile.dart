import 'package:flutter/material.dart';
import 'package:music_wave_player/components/cover_art_widget.dart';
import 'package:music_wave_player/models/music_track.dart';

/// Item de lista de uma música oculta. Diferente de [MusicTrackTile], está
/// sempre em modo de seleção — o checkbox é sempre visível e o toque
/// alterna a seleção (não abre o player).
class HiddenTrackTile extends StatelessWidget {
  final MusicTrack track;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const HiddenTrackTile({
    super.key,
    required this.track,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggleSelection,
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
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelection(),
                  activeColor: colorScheme.primary,
                ),
              ),
              CoverArtWidget(
                coverPath: track.coverPath,
                size: 48,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}
