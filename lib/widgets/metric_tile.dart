import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'glass_card.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: TextStyle(color: palette.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
