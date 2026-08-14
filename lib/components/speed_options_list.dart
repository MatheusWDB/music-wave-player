import 'package:flutter/material.dart';

/// Lista de opções de velocidade de reprodução (0.5x–2x).
class SpeedOptionsList extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const SpeedOptionsList({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _speeds.map((speed) {
        final isSelected = speed == currentSpeed;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.check,
            size: 18,
            color: isSelected ? colorScheme.primary : Colors.transparent,
          ),
          title: Text(
            speed == 1.0 ? 'Normal (1.0x)' : '${speed}x',
            style: TextStyle(
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () => onSpeedSelected(speed),
        );
      }).toList(),
    );
  }
}
