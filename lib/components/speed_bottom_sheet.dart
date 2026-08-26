import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/speed_options_list.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';

class SpeedBottomSheet extends ConsumerWidget {
  const SpeedBottomSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SpeedBottomSheet._(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final currentSpeed = ref.watch(
      playerSettingsNotifierProvider.select(
        (s) => s.valueOrNull?.playbackSpeed ?? 1.0,
      ),
    );

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  Icon(Icons.speed, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Velocidade de reprodução',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SpeedOptionsList(
                currentSpeed: currentSpeed,
                onSpeedSelected: (speed) {
                  ref
                      .read(playerSettingsNotifierProvider.notifier)
                      .setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
