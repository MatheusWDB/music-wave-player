import 'package:flutter/material.dart';

/// Seção de seleção de duração do crossfade entre músicas.
class CrossfadeOptionsSection extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onDurationSelected;

  const CrossfadeOptionsSection({
    super.key,
    required this.selectedDuration,
    required this.onDurationSelected,
  });

  static const _options = [
    (label: 'Desligado', value: 0),
    (label: '1 segundo', value: 1),
    (label: '2 segundos', value: 2),
    (label: '3 segundos', value: 3),
    (label: '5 segundos', value: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CROSSFADE ENTRE MÚSICAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'O volume da música atual diminui antes de a próxima começar.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ..._options.map((opt) {
          final isSelected = selectedDuration == opt.value;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.check,
              size: 18,
              color: isSelected ? colorScheme.primary : Colors.transparent,
            ),
            title: Text(
              opt.label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => onDurationSelected(opt.value),
          );
        }),
      ],
    );
  }
}
