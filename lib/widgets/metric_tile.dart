import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_colors.dart';
import 'glass_card.dart';
import 'ui_kit.dart';

/// Tile statistik
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData? icon;

  final double? numberValue;
  final int decimals;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.icon,
    this.numberValue,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) IconBubble(icon: icon!, color: color, size: 32),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: Motion.medium,
                builder: (context, c, _) {
                  final style = TextStyle(
                    fontSize: 28,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: c,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  );
                  final n = numberValue;
                  return n != null
                      ? AnimatedNumber(value: n, decimals: decimals, style: style)
                      : Text(value, style: style);
                },
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}