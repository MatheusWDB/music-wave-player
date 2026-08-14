import 'package:flutter/material.dart';
import 'package:music_wave_player/components/crossfade_options_section.dart';
import 'package:music_wave_player/components/fade_on_pause_resume_section.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class AudioTransitionsBottomSheet extends StatelessWidget {
  const AudioTransitionsBottomSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AudioTransitionsBottomSheet._(),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icon(Icons.swap_horiz, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Transições de áudio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              CrossfadeOptionsSection(
                selectedDuration: config.crossfadeDuration,
                onDurationSelected: (value) =>
                    context.read<Configuration>().setCrossfadeDuration(value),
              ),

              const Divider(height: 32),

              FadeOnPauseResumeSection(
                enabled: config.fadeOnPauseResume,
                onChanged: (v) =>
                    context.read<Configuration>().setFadeOnPauseResume(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
