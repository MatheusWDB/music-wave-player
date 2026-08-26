import 'package:flutter/material.dart';
import 'package:music_wave_player/components/sort_button.dart';
import 'package:music_wave_player/services/sort_service.dart';

/// Cabeçalho de uma aba de listagem: título da aba à esquerda e botão de
/// ordenação à direita.
class TabsSortHeader extends StatelessWidget {
  final String title;
  final SortOption currentSort;
  final List<SortOption> sortOptions;
  final ValueChanged<SortOption> onSortSelected;

  const TabsSortHeader({
    super.key,
    required this.title,
    required this.currentSort,
    required this.sortOptions,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
            options: sortOptions,
            onSelected: onSortSelected,
          ),
        ],
      ),
    );
  }
}
