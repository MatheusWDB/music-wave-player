import 'package:flutter/material.dart';

/// Badge circular numerado usado em listas de ranking (mais/menos ouvidas,
/// estatísticas). Os 3 primeiros lugares recebem destaque visual.
class RankBadge extends StatelessWidget {
  final int position;

  const RankBadge({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTop3 = position <= 3;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isTop3
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$position',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isTop3 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
