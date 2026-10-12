import 'package:flutter/material.dart';

class AppColors {
  static const cyan = Color(0xFF2E9D83);
  static const blue = Color(0xFF4E8FC6);
  static const purple = Color(0xFF8B74C9);
  static const green = Color(0xFF58B368);
  static const orange = Color(0xFFF0932B);
  static const red = Color(0xFFE5534B);
  static const forest = Color(0xFF1E3A2B);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color panel;
  final Color panel2;
  final Color text;
  final Color muted;
  final Color border;

  final Color primary;
  final Color onPrimary;

  final Color soft;

  const AppPalette({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.text,
    required this.muted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.soft,
  });

  static const light = AppPalette(
    bg: Color(0xFFF4F1EA),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFEFEBE1),
    text: Color(0xFF17261D),
    muted: Color(0xFF7B857E),
    border: Color(0xFFE6E1D5),
    primary: Color(0xFF1E3A2B),
    onPrimary: Color(0xFFFFFFFF),
    soft: Color(0xFFE3EFE4),
  );

  static const dark = AppPalette(
    bg: Color(0xFF0D1511),
    panel: Color(0xFF16211B),
    panel2: Color(0xFF1D2B24),
    text: Color(0xFFEAF1EB),
    muted: Color(0xFF93A399),
    border: Color(0xFF26352D),
    primary: Color(0xFFBFE3C9),
    onPrimary: Color(0xFF0D1511),
    soft: Color(0xFF1F3128),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? panel,
    Color? panel2,
    Color? text,
    Color? muted,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? soft,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      soft: soft ?? this.soft,
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
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
