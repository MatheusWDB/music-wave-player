import 'package:flutter/material.dart';

/// Lista de opções predefinidas do temporizador de sono: durações fixas,
/// fim da música atual, fim da fila e atalho para duração personalizada.
class TimerPresetOptions extends StatelessWidget {
  final ValueChanged<int> onDurationSelected;
  final VoidCallback onEndOfTrack;
  final VoidCallback onEndOfQueue;
  final VoidCallback onCustomTapped;

  const TimerPresetOptions({
    super.key,
    required this.onDurationSelected,
    required this.onEndOfTrack,
    required this.onEndOfQueue,
    required this.onCustomTapped,
  });

  static const _presets = [
    (label: '15 minutos', seconds: 15 * 60),
    (label: '30 minutos', seconds: 30 * 60),
    (label: '45 minutos', seconds: 45 * 60),
    (label: '1 hora', seconds: 60 * 60),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ..._presets.map(
          (p) => _OptionTile(
            label: p.label,
            onTap: () => onDurationSelected(p.seconds),
            colorScheme: colorScheme,
          ),
        ),
        _OptionTile(
          label: 'Fim da música atual',
          icon: Icons.music_note_outlined,
          onTap: onEndOfTrack,
          colorScheme: colorScheme,
        ),
        _OptionTile(
          label: 'Fim da fila',
          icon: Icons.queue_music_outlined,
          onTap: onEndOfQueue,
          colorScheme: colorScheme,
        ),
        _OptionTile(
          label: 'Personalizado...',
          icon: Icons.tune,
          onTap: onCustomTapped,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _OptionTile({
    required this.label,
    this.icon,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon ?? Icons.timer_outlined, color: colorScheme.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}
