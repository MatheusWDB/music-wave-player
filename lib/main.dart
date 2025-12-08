import 'package:flutter/material.dart';
import 'package:music_wave_player/screens/root_directory_config_screen.dart';

const Color colorBgDark = Color(0xFF0D1B2A);
const Color colorSurface = Color(0xFF1D3557);
const Color colorHighlight = Color(0xFF457B9D);
const Color colorAccent = Color(0xFFA8DADC);
const Color colorAction = Color(0xFFE63946);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
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
      home: RootDirectoryConfigScreen(),
    );
  }
}
