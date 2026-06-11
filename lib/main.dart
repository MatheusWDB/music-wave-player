import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/screens/library_screen.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

const Color colorBgDark = Color(0xFF0D1B2A);
const Color colorSurface = Color(0xFF1D3557);
const Color colorHighlight = Color(0xFF457B9D);
const Color colorAccent = Color(0xFFA8DADC);
const Color colorAction = Color(0xFFE63946);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cria Configuration vazio — zero I/O, instantâneo
  final config = Configuration.empty();

  // Inicializa AudioService (necessário antes do runApp)
  final audioHandler = await AudioService.init(
    builder: () => MusicAudioHandler(config),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'br.com.hematsu.music_wave_player.channel',
      androidNotificationChannelName: 'MusicWave Player',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidStopForegroundOnPause: false,
    ),
  );

  config.audioHandler = audioHandler;

  runApp(
    ChangeNotifierProvider<Configuration>.value(
      value: config,
      child: const MyApp(),
    ),
  );

  // CORREÇÃO ANR: carrega SQLite só depois que o primeiro frame foi renderizado.
  // Isso garante que a UI está visível antes de qualquer I/O pesado,
  // e que o processo do audio_service em background não trava no boot.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Solicita permissão de notificação (Android 13+)
    await Permission.notification.request();

    // Agora carrega dados do storage de forma segura
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
