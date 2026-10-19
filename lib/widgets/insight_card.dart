import 'package:flutter/material.dart' hide Text;
import '../core/i18n/tr_text.dart';

import '../core/theme/app_colors.dart';
import '../models/ai_insight.dart';
import 'glass_card.dart';
import 'ui_kit.dart';

class InsightCard extends StatelessWidget {
  final AiInsight insight;

  const InsightCard({super.key, required this.insight});

  Color _severityColor() {
    switch (insight.severity) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.orange;
      default:
        return AppColors.green;
    }
  }

  IconData _severityIcon() {
    switch (insight.severity) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _severityColor();
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: _severityIcon(), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 5),
                Text(insight.summary, style: TextStyle(color: palette.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}