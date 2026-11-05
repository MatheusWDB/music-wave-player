import 'package:flutter/material.dart';

/// Envolve uma imagem de cabeçalho com um toque para editá-la e um
/// pequeno selo de lápis no canto, indicando que é editável.
class EditableImageFrame extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const EditableImageFrame({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Icon(Icons.edit, size: 12, color: colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
