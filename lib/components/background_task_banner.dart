import 'package:flutter/material.dart';
import 'package:music_wave_player/screens/download_screen.dart';
import 'package:music_wave_player/services/background_task_manager.dart';

/// Barras compactas de progresso exibidas no fluxo normal da tela (não
/// flutuam por cima de nada) enquanto há operações longas em segundo
/// plano: indexação, restore e exportação de backup, recálculo de volume,
/// downloads. Uma linha por tarefa, empilhadas; some sozinho (altura zero)
/// quando não há nada em andamento. Tarefas canceláveis ganham um botão "X".
///
/// Usa as mesmas cores do indicador de indexação em [IndexingComponent]
/// (colorScheme.secondary/primary/onSurface), que são definidas de fato
/// no tema — ao contrário de primaryContainer, que não é.
class BackgroundTaskBanner extends StatelessWidget {
  const BackgroundTaskBanner({super.key});

  /// Tarefas cujo cancelamento deixa algo pela metade e por isso pede
  /// confirmação; as demais cancelam direto.
  static const _confirmations =
      <String, ({String title, String content, String confirm})>{
        BackgroundTaskIds.backupRestore: (
          title: 'Cancelar restauração?',
          content:
              'O que já foi aplicado permanece. Para completar, restaure o '
              'mesmo backup de novo.',
          confirm: 'Cancelar restauração',
        ),
        BackgroundTaskIds.downloadPlaylist: (
          title: 'Cancelar o download da playlist?',
          content:
              'As músicas já salvas continuam na biblioteca. A que está '
              'sendo baixada agora será descartada.',
          confirm: 'Cancelar download',
        ),
      };

  Future<void> _requestCancel(BuildContext context, BackgroundTask task) async {
    final confirmation = _confirmations[task.id];
    if (confirmation == null) {
      BackgroundTaskManager.cancel(task.id);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirmation.title),
        content: Text(confirmation.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmation.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) BackgroundTaskManager.cancel(task.id);
  }

  /// Só o aviso de "música baixada" é tocável: leva à revisão das tags.
  VoidCallback? _onTap(BuildContext context, BackgroundTask task) {
    if (task.id != BackgroundTaskIds.downloadReview) return null;
    return () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DownloadScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BackgroundTask>>(
      valueListenable: BackgroundTaskManager.tasks,
      builder: (context, tasks, _) {
        if (tasks.isEmpty) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tasks.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                InkWell(
                  onTap: _onTap(context, tasks[i]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        borderRadius: BorderRadius.circular(8.0),
                        color: colorScheme.secondary,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.3,
                        ),
                        minHeight: 6.0,
                        value: tasks[i].progress,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tasks[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (tasks[i].isCancellable)
                            IconButton(
                              tooltip: 'Cancelar',
                              icon: const Icon(Icons.close),
                              iconSize: 18,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                              color: colorScheme.onSurface,
                              onPressed: () =>
                                  _requestCancel(context, tasks[i]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
