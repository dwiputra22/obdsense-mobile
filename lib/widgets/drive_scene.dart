import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scene_kit.dart';

/// Adegan berkendara animasi untuk hero Home. Langit, matahari/bulan, bintang,
/// kabut, lampu jalan, dan lampu mobil mengikuti JAM perangkat secara mulus
/// (pagi -> siang -> sore -> malam). [hourOverride] dipakai untuk pratinjau
/// waktu; perpindahan jam di-ease sehingga langit "berputar" halus.
/// Kecepatan scroll mengikuti [speedKmh] (dihaluskan).
class DriveScene extends StatefulWidget {
  const DriveScene({
    super.key,
    required this.speedKmh,
    required this.height,
    this.visibleHeight,
    this.hourOverride,
    this.hourNotifier,
    this.carX = 0.64,
  });

  final double speedKmh;
  final double height;

  final double? visibleHeight;
  final double? hourOverride;

  /// Diisi jam adegan saat ini (dibatasi frekuensinya) agar overlay teks bisa
  /// menyesuaikan warna terhadap langit.
  final ValueNotifier<double>? hourNotifier;
  final double carX;

  @override
  State<DriveScene> createState() => _DriveSceneState();
}

class _DriveSceneState extends State<DriveScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final SceneClock _clock = SceneClock();
  Duration _last = Duration.zero;
  double _speed = 0;
  double _published = -99;

  @override
  void initState() {
    super.initState();
    _clock.hour = widget.hourOverride ?? hourNow();
    _published = _clock.hour;
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1000000.0, 0.05);
    _last = elapsed;
    if (dt <= 0) return;

    final target = widget.speedKmh.isFinite ? widget.speedKmh.clamp(0.0, 220.0).toDouble() : 0.0;
    _speed += (target - _speed) * math.min(1.0, dt * 2.5);
    // Standby: sensor 0 -> berhenti total.
    if (target < 0.5 && _speed < 0.4) _speed = 0;
    _clock.speed = _speed;
    // Gerak scenery PROPORSIONAL dengan kecepatan sensor:
    // cepat -> deras, melambat -> melambat, diam -> diam.
    _clock.dist += dt * _speed * 3.0;
    _clock.t += dt;

    // Jam: ease menuju target lewat jalur terpendek di lingkaran 24 jam.
    final targetHour = widget.hourOverride ?? hourNow();
    var diff = (targetHour - _clock.hour) % 24;
    if (diff > 12) diff -= 24;
    if (diff.abs() > 0.0005) {
      final step = diff * math.min(1.0, dt * 2.4);
      _clock.hour = (_clock.hour + step + 24) % 24;
    }
    if ((_clock.hour - _published).abs() > 0.02) {
      _published = _clock.hour;
      widget.hourNotifier?.value = _clock.hour;
    }
    _clock.tick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ScenePainter(
            clock: _clock,
            visibleHeight: widget.visibleHeight ?? widget.height,
            carX: widget.carX,
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.clock, required this.visibleHeight, required this.carX}) : super(repaint: clock);

  final SceneClock clock;
  final double visibleHeight;
  final double carX;

  @override
  void paint(Canvas canvas, Size size) {
    final p = SkyPalette.at(clock.hour);
    final vh = visibleHeight;

    SceneKit.sky(canvas, size, p);
    SceneKit.stars(canvas, size, p, clock.t, maxY: vh * 0.5);
    SceneKit.celestial(canvas, size, p, clock.hour, horizonY: vh * 0.64, arcH: vh * 0.52);
    SceneKit.clouds(canvas, size, p, clock.dist, yTop: vh * 0.06, ySpan: vh * 0.34, t: clock.t);
    SceneKit.world(canvas, size, p, clock.dist, vh: vh);

    final roadTop = vh * 0.80;
    final moving = math.min(1.0, clock.speed / 25);
    SceneKit.car(
      canvas,
      cx: size.width * carX,
      groundY: roadTop + (vh - roadTop) * 0.50,
      scale: math.min(size.width * 0.42, 176.0) / 160,
      dist: clock.dist,
      p: p,
      // Berkendara: bergoyang mengikuti jalan. Diam: hanya "bernapas" sangat halus.
      bob: math.sin(clock.dist * 0.09) * 1.1 * moving + math.sin(clock.t * 2.4) * 0.25 * (1 - moving),
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.visibleHeight != visibleHeight || old.carX != carX;
}
