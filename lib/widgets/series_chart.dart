import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../core/i18n/tr_text.dart';

import '../core/theme/app_colors.dart';

class ChartPoint {
  const ChartPoint(this.t, this.v);

  final DateTime t;
  final double v;
}

class SeriesChart extends StatelessWidget {
  const SeriesChart({
    super.key,
    required this.points,
    required this.color,
    required this.yMin,
    required this.yMax,
    required this.yLabels,
    required this.window,
    required this.end,
    this.emptyLabel = 'Menunggu data OBD…',
  });

  final List<ChartPoint> points;
  final Color color;
  final double yMin;
  final double yMax;

  final List<String> yLabels;
  final Duration window;
  final DateTime end;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SeriesPainter(
                points: points,
                color: color,
                yMin: yMin,
                yMax: yMax,
                yLabels: yLabels,
                window: window,
                end: end,
                gridColor: palette.border,
                textColor: palette.muted,
              ),
            ),
          ),
        ),
        if (points.isEmpty)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 16),
              child: Center(
                child: Text(
                  emptyLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.points,
    required this.color,
    required this.yMin,
    required this.yMax,
    required this.yLabels,
    required this.window,
    required this.end,
    required this.gridColor,
    required this.textColor,
  });

  final List<ChartPoint> points;
  final Color color;
  final double yMin;
  final double yMax;
  final List<String> yLabels;
  final Duration window;
  final DateTime end;
  final Color gridColor;
  final Color textColor;

  static String _two(int n) => n.toString().padLeft(2, '0');

  void _text(Canvas canvas, String text, Offset anchor, {bool right = false, bool vCenter = false, bool hCenter = false, double? maxX}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: textColor.withValues(alpha: 0.85), fontSize: 8.5, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = anchor.dx;
    if (right) dx -= tp.width;
    if (hCenter) dx -= tp.width / 2;
    if (maxX != null) dx = math.min(dx, maxX - tp.width);
    dx = math.max(dx, 0);
    final dy = vCenter ? anchor.dy - tp.height / 2 : anchor.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0;
    const right = 6.0;
    const top = 6.0;
    const bottom = 16.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (plot.width < 20 || plot.height < 20) return;

    // Grid + label Y
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final n = yLabels.length;
    for (var i = 0; i < n; i++) {
      final y = n == 1 ? plot.top : plot.top + plot.height * (i / (n - 1));
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(canvas, yLabels[i], Offset(left - 4, y), right: true, vCenter: true);
    }

    // Label X (jam)
    final start = end.subtract(window);
    final showSeconds = window <= const Duration(minutes: 1);
    final labelCount = (plot.width >= 150 && !showSeconds) || plot.width >= 230 ? 5 : 3;
    for (var i = 0; i < labelCount; i++) {
      final f = i / (labelCount - 1);
      final t = start.add(Duration(milliseconds: (window.inMilliseconds * f).round()));
      final label = showSeconds
          ? '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
          : '${_two(t.hour)}:${_two(t.minute)}';
      _text(canvas, label, Offset(plot.left + plot.width * f, plot.bottom + 4), hCenter: true, maxX: size.width);
    }

    // Titik data dalam jendela waktu
    final inWindow = [for (final p in points) if (!p.t.isBefore(start) && !p.t.isAfter(end)) p];
    if (inWindow.isEmpty) return;

    final span = (yMax - yMin) == 0 ? 1.0 : (yMax - yMin);
    final windowMs = window.inMilliseconds.toDouble();
    var offsets = <Offset>[
      for (final p in inWindow)
        Offset(
          plot.left + plot.width * (p.t.difference(start).inMilliseconds / windowMs),
          plot.top + plot.height * (1 - ((p.v.clamp(yMin, yMax) - yMin) / span)),
        ),
    ];

    // persingkat jika terlalu banyak titik (jendela 30 menit = 1800 sampel).
    final maxPts = math.max(20, (plot.width / 2).floor());
    if (offsets.length > maxPts) {
      final group = (offsets.length / maxPts).ceil();
      final merged = <Offset>[];
      for (var i = 0; i < offsets.length; i += group) {
        final slice = offsets.sublist(i, math.min(i + group, offsets.length));
        final mx = slice.map((o) => o.dx).reduce((a, b) => a + b) / slice.length;
        final my = slice.map((o) => o.dy).reduce((a, b) => a + b) / slice.length;
        merged.add(Offset(mx, my));
      }
      offsets = merged;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, plot.top - 4, plot.right + 5, plot.bottom + 1));

    if (offsets.length >= 2) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (var i = 1; i < offsets.length; i++) {
        final a = offsets[i - 1];
        final b = offsets[i];
        final cx = (a.dx + b.dx) / 2;
        line.cubicTo(cx, a.dy, cx, b.dy, b.dx, b.dy);
      }
      final area = Path.from(line)
        ..lineTo(offsets.last.dx, plot.bottom)
        ..lineTo(offsets.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(plot),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final last = offsets.last;
    canvas.drawCircle(last, 5.5, Paint()..color = color.withValues(alpha: 0.20));
    canvas.drawCircle(last, 3.2, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) => true;
}