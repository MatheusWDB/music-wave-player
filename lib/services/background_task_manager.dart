import 'package:flutter/foundation.dart';

/// Ids fixos das tarefas longas do app. Usar sempre estes valores para que
/// a mesma tarefa seja atualizada (e não duplicada) a cada progresso.
class BackgroundTaskIds {
  BackgroundTaskIds._();

  static const indexing = 'indexing';
  static const loudnessRescan = 'loudness_rescan';
  static const backupExport = 'backup_export';
  static const backupRestore = 'backup_restore';
  static const download = 'download';
  static const downloadPlaylist = 'download_playlist';
  static const libraryRename = 'library_rename';

  /// Aviso fixo de "música baixada, falta revisar as tags" (não é uma
  /// tarefa em andamento; some quando o usuário salva ou descarta).
  static const downloadReview = 'download_review';
}

/// Contagem com porcentagem, ex.: "10/50 (20%)". Vazio quando [total] é 0.
String formatProgressCount(int done, int total) {
  if (total <= 0) return '';
  return '$done/$total (${(done / total * 100).round()}%)';
}

/// Sinal de cancelamento cooperativo: quem executa a tarefa consulta
/// [isCancelled] entre os itens e encerra por conta própria.
class TaskCancelToken {
  /// [onCancel] roda uma única vez, no momento do cancelamento — para
  /// tarefas que precisam interromper algo externo (ex: o yt-dlp) em vez
  /// de apenas esperar o próximo item do laço.
  TaskCancelToken({this.onCancel});

  final void Function()? onCancel;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    onCancel?.call();
  }
}

/// Estado imutável de uma tarefa em andamento.
class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.label,
    this.progress,
    this.cancelToken,
  });

  final String id;

  /// Texto exibido no banner (ex.: "Etapa 2/3 · Calculando volume 10/50").
  final String label;

  /// Valor de 0.0 a 1.0; null quando não é possível calcular (indeterminado).
  final double? progress;

  /// Null quando a tarefa não pode ser cancelada.
  final TaskCancelToken? cancelToken;

  bool get isCancellable => cancelToken != null;

  /// Porcentagem inteira (0-100) ou null se indeterminada.
  int? get percent =>
      progress == null ? null : (progress!.clamp(0.0, 1.0) * 100).round();
}

/// Registro central das tarefas longas. A UI (banner) e a notificação leem
/// daqui; quem executa a tarefa só chama [update] e [finish].
class BackgroundTaskManager {
  BackgroundTaskManager._();

  /// Tarefas ativas, na ordem em que foram iniciadas.
  static final ValueNotifier<List<BackgroundTask>> tasks =
      ValueNotifier<List<BackgroundTask>>(const []);

  /// Cria a tarefa ou substitui a existente com o mesmo id.
  static void update(BackgroundTask task) {
    final current = tasks.value;
    final index = current.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      tasks.value = [...current, task];
      return;
    }
    final next = [...current];
    next[index] = task;
    tasks.value = next;
  }

  /// Remove a tarefa; chamar sempre em `finally`.
  static void finish(String id) {
    final current = tasks.value;
    if (!current.any((t) => t.id == id)) return;
    tasks.value = current.where((t) => t.id != id).toList();
  }

  /// Primeira tarefa cancelável (a que a notificação mostra e cancela).
  static BackgroundTask? get primaryCancellable {
    for (final task in tasks.value) {
      if (task.isCancellable) return task;
    }
    return null;
  }

  static void cancel(String id) {
    for (final task in tasks.value) {
      if (task.id == id) {
        task.cancelToken?.cancel();
        return;
      }
    }
  }

  /// Usado pelo botão "Cancelar" da notificação.
  static void cancelPrimary() {
    primaryCancellable?.cancelToken?.cancel();
  }
}
