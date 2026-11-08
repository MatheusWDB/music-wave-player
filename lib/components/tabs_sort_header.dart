import 'package:flutter/material.dart';
import 'package:music_wave_player/components/shuffle_toggle_button.dart';
import 'package:music_wave_player/components/sort_button.dart';
import 'package:music_wave_player/services/sort_service.dart';

/// Cabeçalho de uma aba de listagem: título e menu de ordenação na primeira
/// linha e, quando [playButton] é informado, aleatório e play logo abaixo.
class TabsSortHeader extends StatelessWidget {
  final String title;
  final SortOption currentSort;
  final List<SortField> sortFields;
  final ValueChanged<SortOption> onSortSelected;
  final Widget? playButton;
  final VoidCallback? onToggleShuffle;
  final bool isShuffleActive;

  const TabsSortHeader({
    super.key,
    required this.title,
    required this.currentSort,
    required this.sortFields,
    required this.onSortSelected,
    this.playButton,
    this.onToggleShuffle,
    this.isShuffleActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SortButton(
                current: currentSort,
                fields: sortFields,
                onSelected: onSortSelected,
              ),
            ],
          ),
          if (playButton != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onToggleShuffle != null)
                  ShuffleToggleButton(
                    isActive: isShuffleActive,
                    onPressed: onToggleShuffle!,
                  ),
                const SizedBox(width: 8.0),
                playButton!,
              ],
            ),
        ],
      ),
    );
  }
}
