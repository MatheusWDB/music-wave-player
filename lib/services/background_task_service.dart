import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Mantém o processo do app em primeiro plano (via notificação persistente)
/// durante operações longas — indexação da biblioteca e restore de backup —
/// para o Android não pausar a execução quando o app é minimizado. Sem
/// isso, timers/Futures do Dart podem congelar em segundo plano mesmo com
/// a exceção de restrição de bateria concedida (são mecanismos diferentes
/// do Android — um evita o processo ser morto, o outro evita ele ser
/// suspenso).
///
/// Não roda nenhuma tarefa na isolate de segundo plano do plugin — só
/// segura o status de foreground. A indexação/restore continuam rodando
/// normalmente na isolate principal, como sempre fizeram.
class BackgroundTaskService {
  BackgroundTaskService._();

  static const _serviceId = 1001;
  static bool _initialized = false;

  /// Nome da meta-data declarada no AndroidManifest.xml, que aponta pro
  /// drawable do ícone de notificação (ic_notification, já gerado pelo
  /// flutter_launcher_icons). O ícone padrão do plugin, sem isso, é um
  /// ponto genérico do sistema.
  static const _notificationIcon = NotificationIcon(
    metaDataName: 'br.com.hematsu.music_wave_player.notification_icon',
  );

  /// Chamado uma vez, no início do app.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'background_task_channel',
        channelName: 'Tarefas em segundo plano',
        channelDescription:
            'Aparece durante indexação da biblioteca ou restauração de backup.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Contador de quem está "segurando" o foreground — indexação e restore
  /// podem se sobrepor (restore dispara uma reindexação por dentro), e
  /// nenhum dos dois sabe se o outro também depende do serviço. Com
  /// contagem de referência, cada [start] soma 1 e cada [stop] subtrai 1;
  /// o serviço só para de verdade quando o contador chega a 0 — assim
  /// cada chamador só precisa saber da própria etapa, sem coordenar com
  /// quem mais pode estar rodando.
  static int _activeCount = 0;

  /// Inicia a notificação de foreground com o texto de progresso atual —
  /// ou só atualiza o texto, se já estiver rodando (ex: indexação que
  /// começa durante um restore já em andamento).
  static Future<void> start({
    required String title,
    required String text,
  }) async {
    _activeCount++;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
        notificationIcon: _notificationIcon,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: title,
      notificationText: text,
      notificationIcon: _notificationIcon,
      callback: _startCallback,
    );
  }

  /// Atualiza o texto da notificação, sem efeito se o serviço não estiver
  /// rodando (ex: chamada de progresso perdida numa corrida com [stop]).
  ///
  /// Limitado a no máximo 1 atualização nativa por segundo — quem chama
  /// pode chamar isso a cada faixa processada sem se preocupar em limitar
  /// a frequência, chamadas dentro da janela são simplesmente ignoradas
  /// (a próxima, com o texto mais recente, vai passar).
  static DateTime? _lastUpdateAt;
  static const _minUpdateInterval = Duration(seconds: 1);

  static Future<void> update({
    required String title,
    required String text,
  }) async {
    final now = DateTime.now();
    if (_lastUpdateAt != null &&
        now.difference(_lastUpdateAt!) < _minUpdateInterval) {
      return;
    }

    if (!await FlutterForegroundTask.isRunningService) return;
    _lastUpdateAt = now;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationIcon: _notificationIcon,
    );
  }

  /// Sinaliza que uma operação que chamou [start] terminou. Só para o
  /// serviço de verdade quando não sobrar nenhuma outra operação
  /// dependendo dele (contador chega a 0) — sempre chamar em `finally`,
  /// pareado 1:1 com o [start] correspondente.
  static Future<void> stop() async {
    if (_activeCount > 0) _activeCount--;
    if (_activeCount > 0) return;

    if (!await FlutterForegroundTask.isRunningService) return;
    _lastUpdateAt = null;
    await FlutterForegroundTask.stopService();
  }
}

// Handler vazio — não faz nada periodicamente, só existe pra satisfazer a
// exigência do plugin de um TaskHandler ao iniciar o serviço. O trabalho
// de verdade (indexação/restore) roda na isolate principal, não aqui.
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_NoOpTaskHandler());
}

class _NoOpTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
