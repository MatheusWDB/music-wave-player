import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/components/crossfade_options_section.dart';
import 'package:music_wave_player/components/fade_on_pause_resume_section.dart';
import 'package:music_wave_player/providers/player_settings_notifier.dart';

class AudioTransitionsBottomSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final settings = ref.watch(playerSettingsNotifierProvider).valueOrNull;

    if (settings == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
                selectedDuration: settings.crossfadeDuration,
                onDurationSelected: (value) => ref
                    .read(playerSettingsNotifierProvider.notifier)
                    .setCrossfadeDuration(value),
              ),

              const Divider(height: 32),

              FadeOnPauseResumeSection(
                enabled: settings.fadeOnPauseResume,
                onChanged: (v) => ref
                    .read(playerSettingsNotifierProvider.notifier)
                    .setFadeOnPauseResume(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
