import 'package:flutter/material.dart';

/// Seletor de duração personalizada (horas/minutos) para o temporizador
/// de sono. Mantém as horas/minutos escolhidos internamente e reporta a
/// confirmação via [onConfirm] em segundos totais.
class TimerCustomDurationPicker extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<int> onConfirm;

  const TimerCustomDurationPicker({
    super.key,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  State<TimerCustomDurationPicker> createState() =>
      _TimerCustomDurationPickerState();
}

class _TimerCustomDurationPickerState extends State<TimerCustomDurationPicker> {
  int _hours = 0;
  int _minutes = 30;

  void _confirm() {
    final seconds = (_hours * 3600) + (_minutes * 60);
    if (seconds <= 0) return;
    widget.onConfirm(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Definir duração',
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _Wheel(
                  label: 'Horas',
                  itemCount: 24,
                  selected: _hours,
                  colorScheme: colorScheme,
                  onSelectedItemChanged: (i) => setState(() => _hours = i),
                ),
              ),
              Text(
                ':',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: _Wheel(
                  label: 'Minutos',
                  itemCount: 60,
                  selected: _minutes,
                  colorScheme: colorScheme,
                  onSelectedItemChanged: (i) => setState(() => _minutes = i),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Voltar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (_hours == 0 && _minutes == 0) ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Iniciar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  final String label;
  final int itemCount;
  final int selected;
  final ColorScheme colorScheme;
  final ValueChanged<int> onSelectedItemChanged;

  const _Wheel({
    required this.label,
    required this.itemCount,
    required this.selected,
    required this.colorScheme,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            perspective: 0.003,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            controller: FixedExtentScrollController(initialItem: selected),
            onSelectedItemChanged: onSelectedItemChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (_, i) => Center(
                child: Text(
                  i.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: selected == i
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: selected == i
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
