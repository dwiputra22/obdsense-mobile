import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/ai_insight.dart';
import 'glass_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _severityColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.summary,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
