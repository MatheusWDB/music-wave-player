import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music_wave_player/theme/app_colors.dart';

/// Tema visual do MusicWave Player.
class AppTheme {
  AppTheme._();

  static final ThemeData wave = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.bg,
      secondary: AppColors.accentDim,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    dividerColor: AppColors.divider,
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.divider,
      thumbColor: AppColors.accent,
      trackHeight: 3,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
  );
}
