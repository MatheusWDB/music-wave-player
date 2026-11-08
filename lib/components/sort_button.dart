import 'package:flutter/material.dart';
import 'package:music_wave_player/services/sort_service.dart';

/// Menu de ordenação de uma aba. Mostra o campo atual com a seta de direção;
/// escolher o campo ativo inverte a direção, escolher outro usa o padrão dele.
class SortButton extends StatelessWidget {
  final SortOption current;
  final List<SortField> fields;
  final ValueChanged<SortOption> onSelected;

  const SortButton({
    super.key,
    required this.current,
    required this.fields,
    required this.onSelected,
  });

  IconData get _arrow =>
      current.isAscending ? Icons.arrow_upward : Icons.arrow_downward;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<SortField>(
      tooltip: 'Ordenar',
      onSelected: (field) => onSelected(
        field == current.field ? current.reversed : field.defaultOption,
      ),
      itemBuilder: (_) => fields.map((field) {
        final isActive = field == current.field;
        return PopupMenuItem(
          value: field,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: TextStyle(
                    color: isActive ? colorScheme.primary : null,
                    fontWeight: isActive ? FontWeight.bold : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                _arrow,
                size: 18,
                color: isActive ? colorScheme.primary : Colors.transparent,
              ),
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(_arrow, size: 16.0, color: colorScheme.onSurface),
          ],
        ),
      ),
    );
  }
}
