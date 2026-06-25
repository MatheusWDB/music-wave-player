import 'package:flutter/material.dart';
import 'package:music_wave_player/services/timer_service.dart';
import 'package:provider/provider.dart';

class TimerBottomSheet extends StatefulWidget {
  const TimerBottomSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TimerBottomSheet._(),
    );
  }

  @override
  State<TimerBottomSheet> createState() => _TimerBottomSheetState();
}

class _TimerBottomSheetState extends State<TimerBottomSheet> {
  bool _showCustomPicker = false;
  int _customHours = 0;
  int _customMinutes = 30;

  static const _presets = [
    (label: '15 minutos', seconds: 15 * 60),
    (label: '30 minutos', seconds: 30 * 60),
    (label: '45 minutos', seconds: 45 * 60),
    (label: '1 hora', seconds: 60 * 60),
  ];

  void _startDuration(int seconds) {
    context.read<SleepTimerService>().startDuration(seconds);
    Navigator.pop(context);
  }

  void _startEndOfTrack() {
    context.read<SleepTimerService>().startEndOfTrack();
    Navigator.pop(context);
  }

  void _startEndOfQueue() {
    context.read<SleepTimerService>().startEndOfQueue();
    Navigator.pop(context);
  }

  void _cancel() {
    context.read<SleepTimerService>().cancel();
    Navigator.pop(context);
  }

  void _confirmCustom() {
    final seconds = (_customHours * 3600) + (_customMinutes * 60);
    if (seconds <= 0) return;
    _startDuration(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final timer = context.watch<SleepTimerService>();

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alça
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Temporizador de sono',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            // Status ativo
            if (timer.isActive) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ativo: ${timer.remainingLabel}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancel,
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (!_showCustomPicker) ...[
              // Opções predefinidas
              ..._presets.map(
                (p) => _OptionTile(
                  label: p.label,
                  onTap: () => _startDuration(p.seconds),
                  colorScheme: colorScheme,
                ),
              ),
              _OptionTile(
                label: 'Fim da música atual',
                icon: Icons.music_note_outlined,
                onTap: _startEndOfTrack,
                colorScheme: colorScheme,
              ),
              _OptionTile(
                label: 'Fim da fila',
                icon: Icons.queue_music_outlined,
                onTap: _startEndOfQueue,
                colorScheme: colorScheme,
              ),
              _OptionTile(
                label: 'Personalizado...',
                icon: Icons.tune,
                onTap: () => setState(() => _showCustomPicker = true),
                colorScheme: colorScheme,
              ),
            ] else ...[
              // Picker personalizado
              Text(
                'Definir duração',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Horas
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Horas',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(
                                initialItem: _customHours,
                              ),
                              onSelectedItemChanged: (i) =>
                                  setState(() => _customHours = i),
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 24,
                                builder: (_, i) => Center(
                                  child: Text(
                                    i.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: _customHours == i
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _customHours == i
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                    // Minutos
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Minutos',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(
                                initialItem: _customMinutes,
                              ),
                              onSelectedItemChanged: (i) =>
                                  setState(() => _customMinutes = i),
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (_, i) => Center(
                                  child: Text(
                                    i.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: _customMinutes == i
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _customMinutes == i
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      onPressed: () =>
                          setState(() => _showCustomPicker = false),
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
                      onPressed: (_customHours == 0 && _customMinutes == 0)
                          ? null
                          : _confirmCustom,
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
          ],
        ),
      ),
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
