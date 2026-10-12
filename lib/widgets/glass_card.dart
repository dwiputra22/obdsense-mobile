import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Warna latar khusus (mis. kartu hero hijau). Default: warna panel.
  final Color? color;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? palette.panel;
    final onBg = color == null ? palette.text : _readable(bg);
    return AutoReveal(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: color == null ? Border.all(color: palette.border) : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.forest.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: onBg),
            child: child,
          ),
        ),
      ),
    );
  }

  static Color _readable(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : const Color(0xFF17261D);
}