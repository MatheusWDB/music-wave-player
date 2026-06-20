import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';

/// Botão reutilizável que exibe as opções de ordenação disponíveis para uma aba.
class SortButton extends StatelessWidget {
  final SortOption current;
  final List<SortOption> options;
  final ValueChanged<SortOption> onSelected;

  const SortButton({
    super.key,
    required this.current,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<SortOption>(
      tooltip: 'Ordenar',
      icon: Icon(Icons.sort, color: colorScheme.onSurface),
      onSelected: onSelected,
      itemBuilder: (_) => options.map((option) {
        final isActive = option == current;
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check : Icons.check,
                color: isActive ? colorScheme.primary : Colors.transparent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                option.label,
                style: TextStyle(
                  color: isActive ? colorScheme.primary : null,
                  fontWeight: isActive ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
