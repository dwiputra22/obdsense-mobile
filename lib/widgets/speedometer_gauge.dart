import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' hide Text;
import '../core/i18n/tr_text.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/gauge_templates.dart';

const double _startAngle = 2.35619;
const double _sweepAngle = 4.71239;

class SpeedometerGauge extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String unit;
  final double? redlineFrom;
  final GaugeTemplate template;
  final List<double>? majorTicks;

  /// Pembagi angka skala (mis. 1000 -> 0..7 untuk RPM 0..7000).
  final double tickDivisor;

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
    this.tickDivisor = 1,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isFinite ? value.clamp(min, max).toDouble() : min;
    final palette = context.palette;
    final ticks = majorTicks ?? _defaultTicks(min, max);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        final side = constraints.maxWidth;
        final compact = side < 100;
        final showChip = side >= 140;
        return Stack(alignment: Alignment.center, children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(side),
              painter: _GaugeFacePainter(
                min: min,
                max: max,
                redlineFrom: redlineFrom,
                template: template,
                majorTicks: ticks,
                tickDivisor: tickDivisor,
                drawLabels: !compact,
                mutedColor: palette.muted,
                borderColor: palette.border,
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: min, end: target),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Stack(alignment: Alignment.center, children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(side),
                  painter: _GaugeValuePainter(value: v, min: min, max: max, template: template),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: side * (compact ? 0.24 : 0.19),
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: template.needleColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    unit.toUpperCase(),
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: (side * 0.08).clamp(9.0, 12.0).toDouble(),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
                if (showChip) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: template.needleColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(color: palette.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
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

class _GaugeFacePainter extends CustomPainter {
  final double min;
  final double max;
  final double? redlineFrom;
  final GaugeTemplate template;
  final List<double> majorTicks;
  final double tickDivisor;
  final bool drawLabels;
  final Color mutedColor;
  final Color borderColor;

  _GaugeFacePainter({
    required this.min,
    required this.max,
    required this.redlineFrom,
    required this.template,
    required this.majorTicks,
    required this.tickDivisor,
    required this.drawLabels,
    required this.mutedColor,
    required this.borderColor,
  });

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

  void _paintTicks(Canvas canvas, Offset center, double radius, double gaugeWidth) {
    const minorPerMajor = 4;
    final segments = math.max(1, (majorTicks.length - 1) * minorPerMajor);
    final labelSize = math.max(8.0, gaugeWidth * 0.045);
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

      if (isMajor && drawLabels && template.showTickLabels) {
        final index = i ~/ minorPerMajor;
        final value = majorTicks[index] / tickDivisor;
        final tp = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(0),
            style: TextStyle(color: mutedColor.withValues(alpha: 0.78), fontSize: labelSize, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen - gaugeWidth * 0.065) - Offset(tp.width / 2, tp.height / 2);
        tp.paint(canvas, pos);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeFacePainter old) =>
      old.min != min ||
      old.max != max ||
      old.redlineFrom != redlineFrom ||
      old.template != template ||
      old.tickDivisor != tickDivisor ||
      old.drawLabels != drawLabels ||
      old.mutedColor != mutedColor ||
      old.borderColor != borderColor ||
      !listEquals(old.majorTicks, majorTicks);
}

class _GaugeValuePainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final GaugeTemplate template;

  _GaugeValuePainter({required this.value, required this.min, required this.max, required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.39;
    final trackWidth = size.width * 0.075;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();

    _paintProgress(canvas, center, radius, trackWidth, fraction);
    if (template.style == GaugeStyle.needle) {
      _paintNeedle(canvas, center, radius, fraction);
    }
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

  @override
  bool shouldRepaint(covariant _GaugeValuePainter old) =>
      old.value != value || old.min != min || old.max != max || old.template != template;
}