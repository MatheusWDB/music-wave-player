import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_wave_player/screens/library_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
