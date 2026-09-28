import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/gauge_templates.dart';

class SpeedometerGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String unit;
  final double? redlineFrom;
  final GaugeTemplate template;
  final List<double>? majorTicks;

  const SpeedometerGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.unit,
    this.redlineFrom,
    this.template = GaugeTemplates.neonArc,
    this.majorTicks,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    final palette = context.palette;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size.square(constraints.maxWidth),
            painter: _GaugePainter(
              value: clamped,
              min: min,
              max: max,
              redlineFrom: redlineFrom,
              template: template,
              majorTicks: majorTicks ?? _defaultTicks(min, max),
              mutedColor: palette.muted,
              borderColor: palette.border,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(clamped.toStringAsFixed(0), style: TextStyle(
              fontSize: constraints.maxWidth * 0.18,
              height: 0.95,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: template.needleColor,
            )),
            const SizedBox(height: 3),
            Text(unit.toUpperCase(), style: TextStyle(color: palette.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.7)),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: template.needleColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(label.toUpperCase(), style: TextStyle(color: palette.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ]),
        ]);
      }),
    );
  }

  List<double> _defaultTicks(double min, double max) {
    const steps = 6;
    final stepValue = (max - min) / steps;
    return List.generate(steps + 1, (i) => min + stepValue * i);
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final double? redlineFrom;
  final GaugeTemplate template;
  final List<double> majorTicks;
  final Color mutedColor;
  final Color borderColor;

  _GaugePainter({required this.value, required this.min, required this.max, required this.redlineFrom, required this.template, required this.majorTicks, required this.mutedColor, required this.borderColor});

  static const _startAngle = 2.35619;
  static const _sweepAngle = 4.71239;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.39;
    final trackWidth = size.width * 0.075;
    final outerRadius = size.width * 0.46;

    canvas.drawCircle(center, outerRadius, Paint()..color = borderColor.withValues(alpha: 0.035));
    canvas.drawCircle(center, outerRadius, Paint()..color = borderColor.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = 1);

    _paintTrack(canvas, center, radius, trackWidth);
    if (redlineFrom != null) _paintRedline(canvas, center, radius, trackWidth);
    if (template.showTicks) _paintTicks(canvas, center, radius, size.width);

    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    _paintProgress(canvas, center, radius, trackWidth, fraction);

    if (template.style == GaugeStyle.needle) {
      _paintNeedle(canvas, center, radius, fraction);
    }

  }

  void _paintTrack(Canvas canvas, Offset center, double radius, double width) {
    final paint = Paint()..color = borderColor.withValues(alpha: 0.24)..style = PaintingStyle.stroke..strokeWidth = width..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _startAngle, _sweepAngle, false, paint);
  }

  void _paintRedline(Canvas canvas, Offset center, double radius, double width) {
    final start = _startAngle + _sweepAngle * ((redlineFrom! - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    final sweep = (_startAngle + _sweepAngle - start).clamp(0.0, _sweepAngle).toDouble();
    final paint = Paint()..color = AppColors.red.withValues(alpha: 0.65)..style = PaintingStyle.stroke..strokeWidth = width..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
  }

  void _paintProgress(Canvas canvas, Offset center, double radius, double width, double fraction) {
    if (fraction <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final glow = Paint()..color = template.valueColorEnd.withValues(alpha: 0.13)..style = PaintingStyle.stroke..strokeWidth = width * 2.1..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle * fraction, false, glow);
    final paint = Paint()
      ..shader = SweepGradient(startAngle: _startAngle, endAngle: _startAngle + _sweepAngle, colors: [template.valueColorStart, template.valueColorEnd]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle * fraction, false, paint);
  }

  void _paintNeedle(Canvas canvas, Offset center, double radius, double fraction) {
    final angle = _startAngle + _sweepAngle * fraction;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.88);
    final tail = center + Offset(math.cos(angle + math.pi), math.sin(angle + math.pi)) * (radius * 0.12);
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.28)..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawLine(tail + const Offset(0, 2), tip + const Offset(0, 2), shadow);
    final needle = Paint()..color = template.needleColor..strokeWidth = 3.2..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip, needle);
  }

  void _paintTicks(Canvas canvas, Offset center, double radius, double gaugeWidth) {
    const minorPerMajor = 4;
    final segments = math.max(1, (majorTicks.length - 1) * minorPerMajor);
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = _startAngle + _sweepAngle * t;
      final isMajor = i % minorPerMajor == 0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * (radius + gaugeWidth * 0.015);
      final tickLen = isMajor ? radius * 0.10 : radius * 0.045;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen);
      final paint = Paint()
        ..color = isMajor ? mutedColor.withValues(alpha: 0.85) : mutedColor.withValues(alpha: 0.30)
        ..strokeWidth = isMajor ? 1.8 : 1.0;
      canvas.drawLine(inner, outer, paint);

      if (isMajor && template.showTickLabels) {
        final index = i ~/ minorPerMajor;
        final value = majorTicks[index];
        final tp = TextPainter(text: TextSpan(text: value.toStringAsFixed(0), style: TextStyle(color: mutedColor.withValues(alpha: 0.72), fontSize: gaugeWidth * 0.037, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen - gaugeWidth * 0.055) - Offset(tp.width / 2, tp.height / 2);
        tp.paint(canvas, pos);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.value != value || oldDelegate.template != template || oldDelegate.redlineFrom != redlineFrom;
}
