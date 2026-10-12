import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../motion/motion.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark, AppPalette.dark);

  static ThemeData get lightTheme => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final isDark = brightness == Brightness.dark;
    const r18 = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18)));
    final buttonText = const TextStyle(fontWeight: FontWeight.w700, fontSize: 14);

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SlideFadePageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: p.text,
        displayColor: p.text,
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        secondary: AppColors.cyan,
        onSecondary: Colors.white,
        error: AppColors.red,
        onError: Colors.white,
        surface: p.panel,
        onSurface: p.text,
        outline: p.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.text,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: p.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.panel2,
          disabledForegroundColor: p.muted,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: r18,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(0, 50),
          shape: r18,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          backgroundColor: p.panel,
          side: BorderSide(color: p.border),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: r18,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? p.primary : AppColors.cyan,
          textStyle: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.soft,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: p.muted, size: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.onPrimary : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.panel2,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.muted,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.primary : p.panel,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.onPrimary : p.muted,
          ),
          side: WidgetStateProperty.all(BorderSide(color: p.border)),
          shape: WidgetStateProperty.all(const StadiumBorder()),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.primary,
        contentTextStyle: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.cyan),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.panel,
        selectedItemColor: p.primary,
        unselectedItemColor: p.muted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      extensions: [p],
    );
  }
}