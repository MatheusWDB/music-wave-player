import 'package:flutter/material.dart';
import 'package:music_wave_player/components/speed_options_list.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class SpeedBottomSheet extends StatelessWidget {
  const SpeedBottomSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SpeedBottomSheet._(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final config = context.watch<Configuration>();

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
                currentSpeed: config.playbackSpeed,
                onSpeedSelected: (speed) {
                  context.read<Configuration>().setPlaybackSpeed(speed);
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
