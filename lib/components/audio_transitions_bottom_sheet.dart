import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:provider/provider.dart';

class AudioTransitionsBottomSheet extends StatelessWidget {
  const AudioTransitionsBottomSheet._();

  static const _crossfadeOptions = [
    (label: 'Desligado', value: 0),
    (label: '1 segundo', value: 1),
    (label: '2 segundos', value: 2),
    (label: '3 segundos', value: 3),
    (label: '5 segundos', value: 5),
  ];

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

              // ── Crossfade ─────────────────────────────────────────────────
              Text(
                'CROSSFADE ENTRE MÚSICAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'O volume da música atual diminui antes de a próxima começar.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              ..._crossfadeOptions.map((opt) {
                final isSelected = config.crossfadeDuration == opt.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check,
                    size: 18,
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.transparent,
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => context
                      .read<Configuration>()
                      .setCrossfadeDuration(opt.value),
                );
              }),

              const Divider(height: 32),

              // ── Fade ao pausar/retomar ────────────────────────────────────
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
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  config.fadeOnPauseResume ? 'Ativado' : 'Desativado',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                value: config.fadeOnPauseResume,
                onChanged: (v) =>
                    context.read<Configuration>().setFadeOnPauseResume(v),
                activeColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
