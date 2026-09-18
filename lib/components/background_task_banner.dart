import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/providers/indexing_notifier.dart';
import 'package:music_wave_player/services/backup_service.dart';
import 'package:music_wave_player/models/indexing_status_info.dart';

/// Barra compacta de progresso exibida no fluxo normal da tela (não
/// flutua por cima de nada) enquanto uma operação longa — indexação de
/// biblioteca ou restore de backup — está rodando em segundo plano.
/// Some sozinha (altura zero) quando não há nada em andamento.
///
/// Usa as mesmas cores do indicador de indexação em [IndexingComponent]
/// (colorScheme.secondary/primary/onSurface), que são definidas de fato
/// no tema — ao contrário de primaryContainer, que não é.
///
/// Prioriza a indexação quando as duas coexistirem (cenário raro, mas
/// possível se o usuário reindexar durante um restore).
class BackgroundTaskBanner extends ConsumerWidget {
  const BackgroundTaskBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexingState = ref.watch(indexingNotifierProvider).valueOrNull;
    final isIndexing = indexingState?.isBusy ?? false;

    return ValueListenableBuilder<bool>(
      valueListenable: BackupService.isRestoring,
      builder: (context, isRestoring, _) {
        return ValueListenableBuilder<RestoreProgress?>(
          valueListenable: BackupService.progress,
          builder: (context, restoreProgress, _) {
            String? label;
            double? percent;

            if (isIndexing) {
              final info = IndexingStatusInfo.from(indexingState!);
              // Durante um restore, a reindexação é a etapa 1 de 4 do
              // restore como um todo — não das 3 etapas da indexação
              // isolada, que não fazem sentido pro usuário nesse contexto.
              final stagePrefix = isRestoring
                  ? 'Etapa 1/4'
                  : 'Etapa ${info.stageIndex}/${info.stageTotal}';
              label = '$stagePrefix · ${info.statusText}';
              percent = info.progressValue;
            } else if (restoreProgress != null) {
              final p = restoreProgress;
              final stagePrefix = 'Etapa ${p.stageIndex}/${p.stageTotal}';
              final pct = p.total > 0
                  ? ((p.done / p.total) * 100).toStringAsFixed(0)
                  : '0';
              label = p.total > 0
                  ? '$stagePrefix · ${p.stage}... ${p.done}/${p.total} ($pct%)'
                  : '$stagePrefix · ${p.stage}...';
              percent = p.total > 0 ? p.done / p.total : null;
            }

            if (label == null) return const SizedBox.shrink();

            final colorScheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(8.0),
                    color: colorScheme.secondary,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.3),
                    minHeight: 6.0,
                    value: percent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
