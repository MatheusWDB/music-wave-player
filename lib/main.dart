import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:music_wave_player/models/configuration.dart';
import 'package:music_wave_player/screens/library_screen.dart';
import 'package:music_wave_player/services/music_audio_handler.dart';
import 'package:provider/provider.dart';

const Color colorBgDark = Color(0xFF0D1B2A);
const Color colorSurface = Color(0xFF1D3557);
const Color colorHighlight = Color(0xFF457B9D);
const Color colorAccent = Color(0xFFA8DADC);
const Color colorAction = Color(0xFFE63946);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Carrega o Configuration (Modelo de Estado)
  final config = await Configuration.loadFromStorage();

  // 2. Inicia o Audio Service (Player Real)
  final audioHandler = await _initAudioService(config);

  // 3. Injeta o handler no Configuration
  config.audioHandler = audioHandler;

  // 💡 CORREÇÃO: Passa o Configuration já carregado
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider<Configuration>.value(value: config)],
      child: const MyApp(),
    ),
  );
}

Future<AudioHandler> _initAudioService(Configuration config) async {
  return await AudioService.init(
    builder: () => MusicAudioHandler(config),
    // 💡 CORREÇÃO 2a: Usar parâmetros individuais da AudioServiceConfig
    config: const AudioServiceConfig(
      // Parâmetros obrigatórios e recomendados para notificação Android:
      androidNotificationChannelId: 'music_wave_player_channel',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationIcon: 'mipmap/ic_launcher', // Caminho para o ícone
      // Configurações de UI:
      artDownscaleHeight: 128,
      artDownscaleWidth: 128,

      // Se quiser que o app continue em primeiro plano mesmo em pausa, mude este para false
      androidStopForegroundOnPause: true,
    ),
  );
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

        colorScheme: ColorScheme(
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

        appBarTheme: AppBarTheme(
          backgroundColor: colorSurface,
          foregroundColor: colorAccent,
        ),
      ),
      home: LibraryScreen(),
    );
  }
}
