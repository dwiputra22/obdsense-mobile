import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LiveLineChart extends StatelessWidget {
  final List<double> values;
  final String title;
  final Color color;

  const LiveLineChart({
    super.key,
    required this.values,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: palette.text)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: values.isEmpty
                ? Center(
                    child: Text(
                      'Menunggu data...',
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: palette.border, strokeWidth: 1),
                        getDrawingVerticalLine: (_) =>
                            FlLine(color: palette.border, strokeWidth: 1),
                      ),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
