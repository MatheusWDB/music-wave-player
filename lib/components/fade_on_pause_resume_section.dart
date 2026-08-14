import 'package:flutter/material.dart';

/// Seção com switch para ativar/desativar o fade suave ao pausar e
/// retomar a reprodução.
class FadeOnPauseResumeSection extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const FadeOnPauseResumeSection({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FADE AO PAUSAR / RETOMAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'O volume diminui suavemente ao pausar e aumenta ao retomar.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            enabled ? 'Ativado' : 'Desativado',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          value: enabled,
          onChanged: onChanged,
          activeColor: colorScheme.primary,
        ),
      ],
    );
  }
}
