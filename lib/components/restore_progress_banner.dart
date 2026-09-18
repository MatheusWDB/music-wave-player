import 'package:flutter/material.dart';
import 'package:music_wave_player/services/backup_service.dart';

/// Banner compacto exibido enquanto um restore de backup está recriando
/// faixas ausentes em segundo plano — evita a sensação de app travado em
/// bibliotecas grandes. Some sozinho quando [BackupService.progress] volta
/// a `null`.
class RestoreProgressBanner extends StatelessWidget {
  const RestoreProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RestoreProgress?>(
      valueListenable: BackupService.progress,
      builder: (context, progress, _) {
        if (progress == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final percent = progress.total > 0
            ? progress.done / progress.total
            : null;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: percent,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restaurando backup... ${progress.done}/${progress.total} faixas',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
