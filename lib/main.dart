import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/screens/library_screen.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:music_wave_player/services/timer_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

const Color colorBgDark = Color(0xFF0D1B2A);
const Color colorSurface = Color(0xFF1D3557);
const Color colorHighlight = Color(0xFF457B9D);
const Color colorAccent = Color(0xFFA8DADC);
const Color colorAction = Color(0xFFE63946);

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
        backgroundColor: isError ? colorAction : colorHighlight,
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = Configuration.empty();

  final handler = MusicAudioHandler(config);
  config.audioHandler = handler;

  final timerService = SleepTimerService(config);
  handler.setTimerService(timerService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Configuration>.value(value: config),
        ChangeNotifierProvider<SleepTimerService>.value(value: timerService),
      ],
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Permission.notification.request();
    await config.loadFromStorageAsync();
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
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: colorHighlight,
          onPrimary: colorSurface,
          secondary: colorAccent,
          onSecondary: colorSurface,
          surface: colorSurface,
          onSurface: colorAccent,
          error: colorAction,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: colorBgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: colorSurface,
          foregroundColor: colorAccent,
        ),
      ),
      home: const LibraryScreen(),
    );
  }
}
