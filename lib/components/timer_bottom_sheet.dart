import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/timer_custom_duration_picker.dart';
import 'package:music_wave_player/components/timer_preset_options.dart';
import 'package:music_wave_player/providers/timer_notifier.dart';

class TimerBottomSheet extends ConsumerStatefulWidget {
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
  ConsumerState<TimerBottomSheet> createState() => _TimerBottomSheetState();
}

class _TimerBottomSheetState extends ConsumerState<TimerBottomSheet> {
  bool _showCustomPicker = false;

  void _startDuration(int seconds) {
    ref.read(timerNotifierProvider.notifier).startDuration(seconds);
    Navigator.pop(context);
  }

  void _startEndOfTrack() {
    ref.read(timerNotifierProvider.notifier).startEndOfTrack();
    Navigator.pop(context);
  }

  void _startEndOfQueue() {
    ref.read(timerNotifierProvider.notifier).startEndOfQueue();
    Navigator.pop(context);
  }

  void _cancel() {
    ref.read(timerNotifierProvider.notifier).cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final timer = ref.watch(timerNotifierProvider);

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
              _ActiveStatusBanner(
                remainingLabel: timer.remainingLabel,
                onCancel: _cancel,
                colorScheme: colorScheme,
              ),
            ],

            const SizedBox(height: 16),

            if (!_showCustomPicker)
              TimerPresetOptions(
                onDurationSelected: _startDuration,
                onEndOfTrack: _startEndOfTrack,
                onEndOfQueue: _startEndOfQueue,
                onCustomTapped: () => setState(() => _showCustomPicker = true),
              )
            else
              TimerCustomDurationPicker(
                onBack: () => setState(() => _showCustomPicker = false),
                onConfirm: _startDuration,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveStatusBanner extends StatelessWidget {
  final String remainingLabel;
  final VoidCallback onCancel;
  final ColorScheme colorScheme;

  const _ActiveStatusBanner({
    required this.remainingLabel,
    required this.onCancel,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ativo: $remainingLabel',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text('Cancelar', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
