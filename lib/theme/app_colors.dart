import 'package:flutter/material.dart';

/// Paleta da nova identidade visual do MusicWave Player.
///
/// Isolada do tema atual (definido em `main.dart`) para permitir alternância
/// temporária entre visual antigo e novo via [ThemeToggle] (ver `app_theme.dart`).
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0B1420);
  static const Color surface = Color(0xFF142235);
  static const Color surfaceElevated = Color(0xFF1C2E45);
  static const Color divider = Color(0xFF1E2E42);

  static const Color accent = Color(0xFF6C8CFF);
  static const Color accentDim = Color(0xFF4A5FBF);

  static const Color textPrimary = Color(0xFFF5F3EE);
  static const Color textSecondary = Color(0xFF8A97A8);
  static const Color textTertiary = Color(0xFF566578);

  static const Color error = Color(0xFFE63946);
}
