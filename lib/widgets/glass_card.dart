import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.text),
        child: child,
      ),
    );
  }
}
