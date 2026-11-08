import 'package:flutter/material.dart';

/// Alterna o modo aleatório global; fica destacado quando ativo.
class ShuffleToggleButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;
  final double size;

  const ShuffleToggleButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isActive ? 'Aleatório ligado' : 'Aleatório desligado',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        backgroundColor: isActive ? colorScheme.primaryContainer : null,
      ),
      icon: Icon(
        Icons.shuffle,
        color: isActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}
