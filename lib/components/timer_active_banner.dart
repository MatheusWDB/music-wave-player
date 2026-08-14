import 'package:flutter/material.dart';

/// Banner compacto indicando que o temporizador de sono está ativo.
/// Toque abre a tela/bottom sheet de configuração do temporizador.
class TimerActiveBanner extends StatelessWidget {
  final String remainingLabel;
  final VoidCallback onTap;

  const TimerActiveBanner({
    super.key,
    required this.remainingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.bedtime_outlined, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Temporizador: $remainingLabel',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
