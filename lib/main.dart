import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/screens/library_screen.dart';
import 'package:music_wave_player/services/background_task_service.dart';
import 'package:music_wave_player/services/diag_log.dart';
import 'package:music_wave_player/theme/app_colors.dart';
import 'package:music_wave_player/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';

/// Chave global do ScaffoldMessenger — permite mostrar feedback (SnackBar)
/// para operações assíncronas de longa duração (ex: restauração de backup)
/// mesmo que a tela que as iniciou já tenha sido fechada.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Helper para mostrar feedback global, independente de qual tela está
/// ativa no momento.
class AppMessenger {
  AppMessenger._();

  static void show(String message, {bool isError = false}) {
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : AppColors.surfaceElevated,
      ),
    );
  }
}

/// DIAGNÓSTICO TEMPORÁRIO — registra no log as mudanças de ciclo de vida do
/// app e os avisos de pouca memória do sistema. Cruza com o `exit-info`.
class _LifecycleLogger extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    DiagLog.player('ciclo de vida do app: ${state.name}');
  }

  @override
  void didHaveMemoryPressure() {
    DiagLog.player('sistema avisou: pouca memória');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DIAGNÓSTICO TEMPORÁRIO — erros que hoje passam em silêncio vão pro log.
  // O comportamento padrão continua (presentError / return false).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagLog.error('FlutterError', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagLog.error('Erro não tratado', error, stack);
    return false;
  };
  WidgetsBinding.instance.addObserver(_LifecycleLogger());
  DiagLog.player(
    'app iniciado (ciclo de vida inicial: '
    '${WidgetsBinding.instance.lifecycleState?.name})',
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Configuração síncrona do plugin — precisa rodar antes do runApp. A
  // checagem de permissão de notificação é assíncrona e não bloqueia.
  unawaited(BackgroundTaskService.init());

  runApp(const ProviderScope(child: MyApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Permission.notification.request();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MusicWave Player',
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.wave,
      home: const LibraryScreen(),
    );
  }
}
