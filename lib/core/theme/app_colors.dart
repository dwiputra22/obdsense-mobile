import 'package:flutter/material.dart';

class AppColors {
  static const cyan = Color(0xFF3DDCFF);
  static const blue = Color(0xFF4A7BFF);
  static const purple = Color(0xFF8B5CFF);
  static const green = Color(0xFF2BD67B);
  static const orange = Color(0xFFFFA63D);
  static const red = Color(0xFFFF5D73);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color panel;
  final Color panel2;
  final Color text;
  final Color muted;
  final Color border;

  const AppPalette({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.text,
    required this.muted,
    required this.border,
  });

  static const dark = AppPalette(
    bg: Color(0xFF07111F),
    panel: Color(0xFF0E1A2B),
    panel2: Color(0xFF132238),
    text: Color(0xFFEAF2FF),
    muted: Color(0xFF8EA3C7),
    border: Color(0xFF1C2E45),
  );

  static const light = AppPalette(
    bg: Color(0xFFF3F6FB),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFEBF0F8),
    text: Color(0xFF0B1526),
    muted: Color(0xFF5A6B85),
    border: Color(0xFFDBE3F0),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? panel,
    Color? panel2,
    Color? text,
    Color? muted,
    Color? border,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
