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
    final clamped = value.clamp(min, max);
    final palette = context.palette;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clamped.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: constraints.maxWidth * 0.18,
                      fontWeight: FontWeight.bold,
                      color: template.needleColor,
                    ),
                  ),
                  Text(unit, style: TextStyle(color: palette.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(color: palette.muted, fontSize: 10, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.redlineFrom,
    required this.template,
    required this.majorTicks,
    required this.mutedColor,
    required this.borderColor,
  });

  static const _startAngle = 2.35619; // 135 derajat (radian)
  static const _sweepAngle = 4.71239; // 270 derajat total sapuan

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - (size.width * 0.08);
    final trackWidth = size.width * template.trackWidthFactor;

    _paintTrack(canvas, center, radius, trackWidth);

    if (redlineFrom != null) {
      _paintRedline(canvas, center, radius, trackWidth);
    }

    if (template.showTicks) {
      _paintTicks(canvas, center, radius, size.width);
    }

    switch (template.style) {
      case GaugeStyle.arcFill:
        _paintArcFill(canvas, center, radius, trackWidth);
        break;
      case GaugeStyle.needle:
        _paintArcFill(canvas, center, radius, trackWidth * 0.4);
        _paintNeedle(canvas, center, radius);
        break;
    }
  }

  void _paintTrack(Canvas canvas, Offset center, double radius, double trackWidth) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _startAngle, _sweepAngle,
        false, paint);
  }

  void _paintRedline(Canvas canvas, Offset center, double radius, double trackWidth) {
    final redStart = _startAngle + _sweepAngle * ((redlineFrom! - min) / (max - min));
    final redSweep = _startAngle + _sweepAngle - redStart;
    final paint = Paint()
      ..color = AppColors.red.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), redStart, redSweep, false, paint);
  }

  void _paintArcFill(Canvas canvas, Offset center, double radius, double trackWidth) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: [template.valueColorStart, template.valueColorEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _startAngle,
        _sweepAngle * fraction, false, paint);
  }

  void _paintNeedle(Canvas canvas, Offset center, double radius) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final angle = _startAngle + _sweepAngle * fraction;
    final needleLength = radius * 0.82;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * needleLength;
    final tailAngle = angle + math.pi;
    final tail = center + Offset(math.cos(tailAngle), math.sin(tailAngle)) * (radius * 0.12);

    final needlePaint = Paint()
      ..color = template.needleColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip, needlePaint);

    canvas.drawCircle(center, radius * 0.07, Paint()..color = template.needleColor);
    canvas.drawCircle(center, radius * 0.035, Paint()..color = template.hubCenterColor);
  }

  void _paintTicks(Canvas canvas, Offset center, double radius, double gaugeWidth) {
    const minorPerMajor = 4;
    final segments = (majorTicks.length - 1) * minorPerMajor;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = _startAngle + _sweepAngle * t;
      final isMajor = i % minorPerMajor == 0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final tickLen = isMajor ? radius * 0.12 : radius * 0.06;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen);

      final paint = Paint()
        ..color = isMajor ? mutedColor : mutedColor.withValues(alpha: 0.4)
        ..strokeWidth = isMajor ? 2.2 : 1.2;
      canvas.drawLine(inner, outer, paint);

      if (isMajor && template.showTickLabels) {
        final majorIndex = i ~/ minorPerMajor;
        final labelValue = majorTicks[majorIndex];
        final textPainter = TextPainter(
          text: TextSpan(
            text: labelValue.toStringAsFixed(0),
            style: TextStyle(color: mutedColor, fontSize: gaugeWidth * 0.045),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelPos = center +
            Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen - 14) -
            Offset(textPainter.width / 2, textPainter.height / 2);
        textPainter.paint(canvas, labelPos);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.template != template;
  }
}
