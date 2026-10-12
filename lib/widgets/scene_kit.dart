import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Jam saat ini sebagai pecahan jam (mis. 16.5 = 16:30).
double hourNow() {
  final n = DateTime.now();
  return n.hour + n.minute / 60 + n.second / 3600;
}

double _c01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

enum DayPhase {
  pagi('Pagi'),
  siang('Siang'),
  sore('Sore'),
  malam('Malam');

  const DayPhase(this.label);
  final String label;

  String get greeting => 'Selamat ${label.toLowerCase()}';

  static DayPhase of(double hour) {
    final h = ((hour % 24) + 24) % 24;
    if (h >= 5 && h < 10.5) return DayPhase.pagi;
    if (h >= 10.5 && h < 15) return DayPhase.siang;
    if (h >= 15 && h < 18.6) return DayPhase.sore;
    return DayPhase.malam;
  }
}

class SceneClock extends ChangeNotifier {
  double dist = 0;
  double hour = 12;
  double t = 0;

  /// Kecepatan tampil (km/j, sudah dihaluskan). 0 = adegan standby.
  double speed = 0;

  void tick() => notifyListeners();
}

/// Palet langit/lanskap untuk satu waktu. Di-interpolasi mulus antar
/// keyframe (fajar, pagi, siang, sore, senja, malam) sehingga warna dunia
/// berubah kontinu mengikuti jam, bukan loncat per fase.
@immutable
class SkyPalette {
  const SkyPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.hillFar,
    required this.hillNear,
    required this.tree,
    required this.road,
    required this.sun,
    required this.onSky,
    required this.night,
    required this.mist,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color hillFar;
  final Color hillNear;
  final Color tree;
  final Color road;
  final Color sun;
  final Color onSky;

  /// 0 = terang penuh, 1 = malam penuh (bintang, lampu, lampu mobil).
  final double night;

  /// Kabut tipis pagi hari (0..1).
  final double mist;

  static SkyPalette lerp(SkyPalette a, SkyPalette b, double t) => SkyPalette(
        skyTop: Color.lerp(a.skyTop, b.skyTop, t)!,
        skyBottom: Color.lerp(a.skyBottom, b.skyBottom, t)!,
        hillFar: Color.lerp(a.hillFar, b.hillFar, t)!,
        hillNear: Color.lerp(a.hillNear, b.hillNear, t)!,
        tree: Color.lerp(a.tree, b.tree, t)!,
        road: Color.lerp(a.road, b.road, t)!,
        sun: Color.lerp(a.sun, b.sun, t)!,
        onSky: Color.lerp(a.onSky, b.onSky, t)!,
        night: a.night + (b.night - a.night) * t,
        mist: a.mist + (b.mist - a.mist) * t,
      );

  static const SkyPalette _night = SkyPalette(
    skyTop: Color(0xFF0B1511),
    skyBottom: Color(0xFF1B3327),
    hillFar: Color(0xFF16291F),
    hillNear: Color(0xFF1F3A2B),
    tree: Color(0xFF2C5240),
    road: Color(0xFF0C130F),
    sun: Color(0xFFE8F2EA),
    onSky: Color(0xFFFFFFFF),
    night: 1,
    mist: 0,
  );
  static const SkyPalette _dawn = SkyPalette(
    skyTop: Color(0xFF7F9BC4),
    skyBottom: Color(0xFFF7C9A0),
    hillFar: Color(0xFF8FB89A),
    hillNear: Color(0xFF5E9E76),
    tree: Color(0xFF3D7A56),
    road: Color(0xFF3A433E),
    sun: Color(0xFFFFD28A),
    onSky: Color(0xFF17261D),
    night: 0.25,
    mist: 0.55,
  );
  static const SkyPalette _morning = SkyPalette(
    skyTop: Color(0xFFA8D8E8),
    skyBottom: Color(0xFFEAF5E4),
    hillFar: Color(0xFFA9D3B3),
    hillNear: Color(0xFF6DB383),
    tree: Color(0xFF3E8E5A),
    road: Color(0xFF3A433E),
    sun: Color(0xFFFFF1BE),
    onSky: Color(0xFF17261D),
    night: 0,
    mist: 0.25,
  );
  static const SkyPalette _noon = SkyPalette(
    skyTop: Color(0xFF6FBFE6),
    skyBottom: Color(0xFFDDF2E8),
    hillFar: Color(0xFF9FD0AC),
    hillNear: Color(0xFF5FB07A),
    tree: Color(0xFF37864F),
    road: Color(0xFF3A433E),
    sun: Color(0xFFFFF7D6),
    onSky: Color(0xFF17261D),
    night: 0,
    mist: 0,
  );
  static const SkyPalette _afternoon = SkyPalette(
    skyTop: Color(0xFF9CCBE0),
    skyBottom: Color(0xFFF6EBC8),
    hillFar: Color(0xFFB4D2A2),
    hillNear: Color(0xFF78B070),
    tree: Color(0xFF45873F),
    road: Color(0xFF3A433E),
    sun: Color(0xFFFFE19A),
    onSky: Color(0xFF17261D),
    night: 0,
    mist: 0,
  );
  static const SkyPalette _golden = SkyPalette(
    skyTop: Color(0xFFF0A868),
    skyBottom: Color(0xFFFBE3B0),
    hillFar: Color(0xFFA9B77A),
    hillNear: Color(0xFF6F9A5C),
    tree: Color(0xFF48793F),
    road: Color(0xFF39403A),
    sun: Color(0xFFFFC66B),
    onSky: Color(0xFF3A2410),
    night: 0.1,
    mist: 0,
  );
  static const SkyPalette _sunset = SkyPalette(
    skyTop: Color(0xFF6E5A8F),
    skyBottom: Color(0xFFFF9E6B),
    hillFar: Color(0xFF5F7A63),
    hillNear: Color(0xFF3F6048),
    tree: Color(0xFF2E4D3A),
    road: Color(0xFF262E29),
    sun: Color(0xFFFF8A5B),
    onSky: Color(0xFFFFFFFF),
    night: 0.45,
    mist: 0,
  );
  static const SkyPalette _dusk = SkyPalette(
    skyTop: Color(0xFF1D2A4A),
    skyBottom: Color(0xFF6B5B7B),
    hillFar: Color(0xFF2C4337),
    hillNear: Color(0xFF264034),
    tree: Color(0xFF1E3629),
    road: Color(0xFF161E19),
    sun: Color(0xFFE8EEF2),
    onSky: Color(0xFFFFFFFF),
    night: 0.8,
    mist: 0,
  );

  static const List<_Key> _keys = [
    _Key(0, _night),
    _Key(5, _night),
    _Key(6.5, _dawn),
    _Key(8.5, _morning),
    _Key(12, _noon),
    _Key(15.5, _afternoon),
    _Key(17.5, _golden),
    _Key(18.5, _sunset),
    _Key(19.8, _dusk),
    _Key(21.5, _night),
    _Key(24, _night),
  ];

  static SkyPalette at(double hour) {
    final h = ((hour % 24) + 24) % 24;
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i];
      final b = _keys[i + 1];
      if (h >= a.hour && h <= b.hour) {
        final t = (h - a.hour) / (b.hour - a.hour);
        return lerp(a.p, b.p, Curves.easeInOut.transform(t));
      }
    }
    return _night;
  }
}

class _Key {
  const _Key(this.hour, this.p);

  final double hour;
  final SkyPalette p;
}

class SceneKit {
  SceneKit._();

  static double mod(double a, double b) => ((a % b) + b) % b;
  static double _frac(double v) => v - v.floorToDouble();

  static void sky(Canvas canvas, Size size, SkyPalette p) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ).createShader(r),
    );
  }

  /// Matahari (05:30-19:00) dan bulan sabit (malam) bergerak di busur langit.
  static void celestial(Canvas canvas, Size size, SkyPalette p, double hour,
      {required double horizonY, required double arcH}) {
    final w = size.width;
    final h = mod(hour, 24);
    final r = (arcH * 0.14).clamp(14.0, 30.0).toDouble();

    if (h >= 5.5 && h <= 19.0) {
      final t = (h - 5.5) / 13.5;
      final x = w * 0.10 + w * 0.80 * t;
      final y = horizonY - math.sin(math.pi * t) * arcH;
      final fade = _c01(math.sin(math.pi * t) * 4);
      _glow(canvas, Offset(x, y), r * 3.2, p.sun, 0.45 * fade);
      canvas.drawCircle(Offset(x, y), r, Paint()..color = p.sun.withValues(alpha: fade));
    }

    if (p.night > 0.3) {
      final hm = h >= 18 ? h - 18 : h + 6;
      final t = _c01(hm / 12);
      final x = w * 0.10 + w * 0.80 * t;
      final y = horizonY - math.sin(math.pi * t) * arcH * 0.9;
      final a = _c01((p.night - 0.3) / 0.5);
      const moonColor = Color(0xFFEAF2EC);
      _glow(canvas, Offset(x, y), r * 3.0, const Color(0xFFE8F2EA), 0.20 * a);
      final disc = Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r * 0.95));
      final bite = Path()..addOval(Rect.fromCircle(center: Offset(x + r * 0.55, y - r * 0.18), radius: r * 0.82));
      canvas.drawPath(
        Path.combine(PathOperation.difference, disc, bite),
        Paint()..color = moonColor.withValues(alpha: a),
      );
    }
  }

  static void _glow(Canvas canvas, Offset center, double radius, Color color, double alpha) {
    if (alpha <= 0) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  static void stars(Canvas canvas, Size size, SkyPalette p, double t, {required double maxY}) {
    if (p.night < 0.35) return;
    final a = _c01((p.night - 0.35) / 0.5);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final fx = _frac(math.sin(i * 12.9898) * 43758.5453);
      final fy = _frac(math.sin(i * 78.233) * 12345.6789);
      final tw = 0.5 + 0.5 * math.sin(t * 1.8 + i * 1.7);
      paint.color = Colors.white.withValues(alpha: a * (0.25 + 0.65 * tw));
      canvas.drawCircle(Offset(fx * size.width, fy * maxY), i % 7 == 0 ? 1.6 : 1.0, paint);
    }
  }

  static void _cloud(Canvas canvas, double x, double y, double s, Color color) {
    final p = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 54 * s, height: 20 * s), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(x - 16 * s, y + 4 * s), width: 34 * s, height: 16 * s), p);
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 18 * s, y + 3 * s), width: 36 * s, height: 16 * s), p);
  }

  static void clouds(Canvas canvas, Size size, SkyPalette p, double dist,
      {required double yTop, required double ySpan, double t = 0}) {
    final a = 0.80 * (1 - p.night) + 0.10 * p.night;
    final color = Color.lerp(Colors.white, p.skyBottom, 0.35)!.withValues(alpha: a);
    final w = size.width;
    final span = w + 200;
    _cloud(canvas, mod(w * 0.20 - dist * 0.04 - t * 3.0, span) - 100, yTop + ySpan * 0.30, 1.0, color);
    _cloud(canvas, mod(w * 0.62 - dist * 0.06 - t * 4.2, span) - 100, yTop + ySpan * 0.10, 0.7, color);
    _cloud(canvas, mod(w * 1.05 - dist * 0.05 - t * 3.6, span) - 100, yTop + ySpan * 0.52, 0.85, color);
  }

  static double hillY(double x, double off, double baseY, double amp, double wl) {
    final t = (x + off) / wl * math.pi * 2;
    return baseY - amp * (0.5 + 0.5 * math.sin(t)) - amp * 0.35 * math.sin(t * 2.3 + 1.3);
  }

  static void _hills(Canvas canvas, Size size, double off, double baseY, double amp, double wl, Color color) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 6; x += 6) {
      path.lineTo(x, hillY(x, off, baseY, amp, wl));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Bukit berlapis, pepohonan, kabut pagi, jalan, dan lampu jalan malam.
  /// [vh] = tinggi area yang tampak (dasar proporsi); [size.height] boleh
  /// lebih besar (tanah/jalan meluas ke bawah, tertutup sheet).
  static void world(Canvas canvas, Size size, SkyPalette p, double dist, {required double vh}) {
    final w = size.width;
    _hills(canvas, size, dist * 0.10, vh * 0.64, vh * 0.12, w * 0.95, p.hillFar);
    final nearBase = vh * 0.74;
    final nearAmp = vh * 0.09;
    final nearWl = w * 0.62;
    final nearOff = dist * 0.22;
    _hills(canvas, size, nearOff, nearBase, nearAmp, nearWl, p.hillNear);

    final crown = Paint()..color = p.tree;
    final trunk = Paint()..color = Color.lerp(p.tree, Colors.black, 0.55)!;
    final treeSpan = w + 120;
    final treeCount = math.max(1, (treeSpan / 86.0).round());
    final treeStep = treeSpan / treeCount;
    for (var i = 0; i < treeCount; i++) {
      final x = mod(i * treeStep - dist * 0.40, treeSpan) - 60;
      final y = hillY(x, nearOff, nearBase, nearAmp, nearWl) + 4;
      final big = i.isEven ? 1.0 : 0.78;
      canvas.drawRect(Rect.fromLTWH(x - 1.5, y - 8 * big, 3, 9 * big), trunk);
      canvas.drawCircle(Offset(x, y - 15 * big), 9 * big, crown);
    }

    final roadTop = vh * 0.80;

    if (p.mist > 0.02) {
      final mistRect = Rect.fromLTRB(0, vh * 0.46, w, roadTop);
      canvas.drawRect(
        mistRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.white.withValues(alpha: 0.55 * p.mist), Colors.white.withValues(alpha: 0)],
          ).createShader(mistRect),
      );
    }

    canvas.drawRect(Rect.fromLTWH(0, roadTop, w, size.height - roadTop), Paint()..color = p.road);
    canvas.drawRect(Rect.fromLTWH(0, roadTop, w, 2.5), Paint()..color = Colors.white.withValues(alpha: 0.30));

    const dashLen = 26.0;
    const gap = 24.0;
    const period = dashLen + gap;
    final lineY = roadTop + (vh - roadTop) * 0.55;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double x = -period + mod(-dist, period); x < w + period; x += period) {
      canvas.drawLine(Offset(x, lineY), Offset(x + dashLen, lineY), linePaint);
    }

    if (p.night > 0.25) _lamps(canvas, size, p, dist, vh, roadTop);
  }

  static void _lamps(Canvas canvas, Size size, SkyPalette p, double dist, double vh, double roadTop) {
    final a = _c01((p.night - 0.25) / 0.5);
    const baseSpacing = 210.0;
    final span = size.width + baseSpacing;
    final count = math.max(1, (span / baseSpacing).round());
    final step = span / count;
    final pole = Paint()
      ..color = Color.lerp(p.road, Colors.white, 0.28)!
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const warm = Color(0xFFFFE6A3);
    for (var i = 0; i < count; i++) {
      final x = mod(i * step - dist, span) - step / 2;
      final top = Offset(x, roadTop - vh * 0.20);
      final head = Offset(x + 11, top.dy);
      canvas.drawLine(Offset(x, roadTop + 1), top, pole);
      canvas.drawLine(top, head, pole);
      canvas.drawCircle(
        head,
        44,
        Paint()
          ..shader = RadialGradient(colors: [
            warm.withValues(alpha: 0.55 * a),
            warm.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: head, radius: 44)),
      );
      canvas.drawCircle(head, 3.2, Paint()..color = warm.withValues(alpha: a));
    }
  }

  /// SUV generik orisinal. [noseUp] dalam radian (hidung terangkat saat
  /// akselerasi), diputar di sekitar roda belakang.
  static void car(
    Canvas canvas, {
    required double cx,
    required double groundY,
    required double scale,
    required double dist,
    required SkyPalette p,
    double bob = 0,
    double noseUp = 0,
  }) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, groundY + 7 * scale), width: 150 * scale, height: 10 * scale),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    canvas.save();
    canvas.translate(cx, groundY + bob);
    canvas.scale(scale);
    canvas.translate(-48, -7);
    canvas.rotate(-noseUp);
    canvas.translate(48, 7);

    final bodyColor = Color.lerp(const Color(0xFFF7F8F4), const Color(0xFFC9D6CD), p.night)!;
    final shadeColor = Color.lerp(const Color(0xFFD8DED8), const Color(0xFFA3B2A8), p.night)!;
    final body = Paint()..color = bodyColor;
    final shade = Paint()..color = shadeColor;

    // Cahaya lampu depan (makin kuat saat gelap)
    final beam = Path()
      ..moveTo(80, -24)
      ..lineTo(160, -38)
      ..lineTo(160, -4)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(colors: [
          const Color(0xFFFFF2B0).withValues(alpha: 0.12 + 0.42 * p.night),
          const Color(0xFFFFF2B0).withValues(alpha: 0),
        ]).createShader(const Rect.fromLTRB(80, -38, 160, -4)),
    );

    canvas.drawRRect(RRect.fromLTRBR(-80, -36, 80, -10, const Radius.circular(9)), body);
    canvas.drawRRect(RRect.fromLTRBR(-80, -17, 80, -10, const Radius.circular(4)), shade);

    final cabin = Path()
      ..moveTo(-50, -36)
      ..lineTo(-38, -60)
      ..lineTo(30, -60)
      ..lineTo(52, -36)
      ..close();
    canvas.drawPath(cabin, body);

    final glass = Paint()
      ..color = Color.lerp(const Color(0xFF8FB0A4), const Color(0xFF35524A), p.night)!.withValues(alpha: 0.92);
    canvas.drawPath(
      Path()
        ..moveTo(-43, -38)
        ..lineTo(-34, -56)
        ..lineTo(-2, -56)
        ..lineTo(-2, -38)
        ..close(),
      glass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(3, -38)
        ..lineTo(3, -56)
        ..lineTo(27, -56)
        ..lineTo(45, -38)
        ..close(),
      glass,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(-34, -64, 26, -61, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF55635B),
    );

    canvas.drawRRect(RRect.fromLTRBR(74, -30, 80, -22, const Radius.circular(2)), Paint()..color = const Color(0xFFFFE680));
    canvas.drawRRect(RRect.fromLTRBR(-80, -30, -75, -22, const Radius.circular(2)), Paint()..color = const Color(0xFFE5534B));
    if (p.night > 0.3) {
      canvas.drawCircle(
        const Offset(-82, -26),
        9,
        Paint()..color = const Color(0xFFE5534B).withValues(alpha: 0.25 * _c01((p.night - 0.3) / 0.5)),
      );
    }

    final spin = dist * 0.06;
    for (final wx in const [-48.0, 46.0]) {
      final c = Offset(wx, -7);
      canvas.drawCircle(c, 14, Paint()..color = const Color(0xFF1C2420));
      canvas.drawCircle(c, 8, Paint()..color = const Color(0xFFD9E0DB));
      final spoke = Paint()
        ..color = const Color(0xFF8A968F)
        ..strokeWidth = 1.6;
      for (var i = 0; i < 4; i++) {
        final a = spin + i * math.pi / 2;
        canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 7, spoke);
      }
      canvas.drawCircle(c, 2, Paint()..color = const Color(0xFF55635B));
    }

    canvas.restore();
  }
}