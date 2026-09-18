import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark, AppPalette.dark);

  static ThemeData get lightTheme => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final isDark = brightness == Brightness.dark;

    return base.copyWith(
      scaffoldBackgroundColor: palette.bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: palette.text,
        displayColor: palette.text,
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.cyan,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: AppColors.purple,
        onSecondary: Colors.white,
        error: AppColors.red,
        onError: Colors.white,
        surface: palette.panel,
        onSurface: palette.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.text,
      ),
      cardTheme: CardThemeData(
        color: palette.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.panel,
        selectedItemColor: AppColors.cyan,
        unselectedItemColor: palette.muted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
      extensions: [palette],
    );
  }
}
