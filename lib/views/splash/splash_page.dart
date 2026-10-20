import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/scene_kit.dart';

double _c01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.progress,
    required this.ready,
    required this.onFinished,
  });

  final ValueListenable<double> progress;

  final bool ready;
  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  static const double _minShow = 2.4;

  late final Ticker _ticker;
  final SceneClock _clock = SceneClock();
  Duration _last = Duration.zero;

  double _t = 0;
  double _p = 0;
  double _carX = -0.34;
  double _speed = 34;
  double _vx = 0;
  double _exitT = -1;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _clock.hour = hourNow();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1000000.0, 0.05);
    _last = elapsed;
    if (dt <= 0) return;

    _t += dt;
    _clock.hour = hourNow();

    final real = widget.progress.value;
    final target = widget.ready ? 1.0 : math.max(real * 0.92, math.min(0.9, _t / 3.0));
    _p += (target - _p) * math.min(1.0, dt * 2.0);
    _p = math.min(_p, (_t + 0.15) / _minShow);

    if (_exitT < 0 && widget.ready && _p > 0.985 && _t > _minShow) _exitT = 0;
    var boost = 0.0;
    if (_exitT >= 0) {
      _exitT += dt;
      boost = _c01(_exitT / 0.6);
    }

    final cruise = 34.0 + 6 * math.sin(_t * 1.3);
    final speedTarget = cruise + boost * 170;
    _speed += (speedTarget - _speed) * math.min(1.0, dt * (_exitT >= 0 ? 4.5 : 2.0));
    _clock.dist += dt * (28 + _speed * 2.6);

    if (_exitT < 0) {
      final tx = 0.22 + 0.36 * Curves.easeInOut.transform(_c01(_p));
      _carX += (tx - _carX) * math.min(1.0, dt * 2.2);
    } else {
      _vx += dt * 4.0;
      _carX += _vx * dt;
    }

    _clock.t = _t;
    _clock.tick();

    if (_exitT >= 1.0 && !_finished) {
      _finished = true;
      _ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    }
  }

  String _status(double p) {
    if (p < 0.34) return 'Memuat baseline kendaraan…';
    if (p < 0.67) return 'Membuka riwayat DTC…';
    if (p < 0.98) return 'Menyalakan notifikasi…';
    return 'Siap berkendara';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size.width < 100 || size.height < 200) {
            return const ColoredBox(color: Colors.black);
          }
          final topPad = MediaQuery.paddingOf(context).top;
          final bottomPad = MediaQuery.paddingOf(context).bottom;
          return AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final p = SkyPalette.at(_clock.hour);
              final fadeIn = Curves.easeOut.transform(_c01(_t / 0.5));
              final exit = _exitT < 0 ? 0.0 : _c01(_exitT / 1.0);
              final outOpacity = 1 - Curves.easeIn.transform(_c01((exit - 0.45) / 0.55));
              final outScale = 1 + 0.06 * Curves.easeInOut.transform(exit);
              final boost = _exitT < 0 ? 0.0 : _c01(_exitT / 0.6);

              final worldTop = size.height * 0.44;
              final vh = (size.height * 0.30).clamp(200.0, 300.0).toDouble();
              final sheetTop = worldTop + vh - 6;
              final sheetColor = Color.lerp(const Color(0xFFF4F1EA), const Color(0xFF0D1511), p.night)!;
              final inkColor = Color.lerp(const Color(0xFF17261D), const Color(0xFFEAF1EB), p.night)!;
              final mutedColor = Color.lerp(const Color(0xFF7B857E), const Color(0xFF93A399), p.night)!;
              final accent = Color.lerp(const Color(0xFF2E9D83), const Color(0xFF8FD3A4), p.night)!;

              final sheetIn = Curves.easeOutCubic.transform(_c01((_t - 0.2) / 0.8));
              final shown = _c01(_p);

              return Opacity(
                opacity: _c01(fadeIn * outOpacity),
                child: Transform.scale(
                  scale: outScale,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _SplashPainter(
                          hour: _clock.hour,
                          dist: _clock.dist,
                          t: _t,
                          carX: _carX,
                          worldTop: worldTop,
                          vh: vh,
                          speed: _speed,
                          boost: boost,
                        ),
                      ),
                      Positioned(
                        top: topPad + size.height * 0.07,
                        left: 0,
                        right: 0,
                        child: _Brand(t: _t, ink: p.onSky, accent: accent),
                      ),
                      Positioned(
                        top: sheetTop,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Transform.translate(
                          offset: Offset(0, (1 - sheetIn) * 260),
                          child: Container(
                          decoration: BoxDecoration(
                            color: sheetColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.fromLTRB(30, 26, 30, 24 + bottomPad),
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 320),
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                      child: Align(
                                        key: ValueKey(_status(shown)),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _status(shown),
                                          style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(shown * 100).round()}%',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _RoadBar(progress: shown, accent: accent, track: mutedColor.withValues(alpha: 0.22), t: _t),
                              const SizedBox(height: 18),
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'INTELLIGENT OBD VEHICLE MONITOR',
                                    style: TextStyle(
                                      color: mutedColor.withValues(alpha: 0.85 * _c01((_t - 1.0) / 0.6)),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Logo + wordmark yang muncul huruf demi huruf.
class _Brand extends StatelessWidget {
  const _Brand({required this.t, required this.ink, required this.accent});

  final double t;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pop = Curves.easeOutBack.transform(_c01((t - 0.15) / 0.7));
    final float = math.sin(t * 2.0) * 3;
    const word = 'RushSense';
    const ai = ' AI';

    Widget letter(String ch, int i, Color color) {
      final a = Curves.easeOutCubic.transform(_c01((t - (0.5 + i * 0.05)) / 0.5));
      return Opacity(
        opacity: a,
        child: Transform.translate(
          offset: Offset(0, (1 - a) * 20),
          child: Text(
            ch,
            style: TextStyle(color: color, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1),
          ),
        ),
      );
    }

    return Column(
      children: [
        Transform.translate(
          offset: Offset(0, float),
          child: Transform.scale(
            scale: pop,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/icon-rushsense.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.directions_car_filled_rounded, size: 40, color: accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < word.length; i++) letter(word[i], i, ink),
            for (var i = 0; i < ai.length; i++) letter(ai[i], word.length + i, accent),
          ],
        ),
      ],
    );
  }
}

/// Bar progres berbentuk jalan: isi bergradasi, ada penanda mobil kecil di
/// ujungnya, dan kilau yang bergerak.
class _RoadBar extends StatelessWidget {
  const _RoadBar({required this.progress, required this.accent, required this.track, required this.t});

  final double progress;
  final Color accent;
  final Color track;
  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final fill = math.max(10.0, w * progress);
          final shimmerX = ((t * 0.6) % 1.4 - 0.2) * w;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 9,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Positioned(
                left: 0,
                top: 9,
                height: 8,
                width: fill,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [accent.withValues(alpha: 0.55), accent]),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        left: shimmerX - 40,
                        top: 0,
                        bottom: 0,
                        width: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: fill - 13,
                top: 0,
                child: Transform.translate(
                  offset: Offset(0, math.sin(t * 14) * 0.6),
                  child: Icon(Icons.directions_car_rounded, size: 26, color: accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.hour,
    required this.dist,
    required this.t,
    required this.carX,
    required this.worldTop,
    required this.vh,
    required this.speed,
    required this.boost,
  });

  final double hour;
  final double dist;
  final double t;
  final double carX;
  final double worldTop;
  final double vh;
  final double speed;
  final double boost;

  @override
  void paint(Canvas canvas, Size size) {
    final p = SkyPalette.at(hour);
    final horizon = worldTop + vh * 0.62;

    SceneKit.sky(canvas, size, p);
    SceneKit.stars(canvas, size, p, t, maxY: worldTop + vh * 0.4);
    SceneKit.celestial(canvas, size, p, hour, horizonY: horizon, arcH: horizon - size.height * 0.16);
    SceneKit.clouds(canvas, size, p, dist, yTop: size.height * 0.22, ySpan: vh * 0.7, t: t);

    canvas.save();
    canvas.translate(0, worldTop);
    final worldSize = Size(size.width, size.height - worldTop);
    SceneKit.world(canvas, worldSize, p, dist, vh: vh);

    final roadTop = vh * 0.80;
    final groundY = roadTop + (vh - roadTop) * 0.50;
    final scale = math.min(size.width * 0.42, 176.0) / 160;
    final cx = size.width * carX;
    final sceneSpeed = 28 + speed * 2.6;

    // Garis kecepatan saat tancap gas
    if (boost > 0.05) {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.38 * boost)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 16; i++) {
        final y = vh * (0.10 + 0.82 * ((i * 0.6180339) % 1.0));
        final span = size.width + 260;
        final x = SceneKit.mod(i * 97.3 - dist * (1.2 + (i % 4) * 0.25), span) - 130;
        final len = 40 + boost * (90 + (i % 3) * 40);
        canvas.drawLine(Offset(x, y), Offset(x + len, y), line);
      }
    }

    // Kepulan knalpot (stateless dari waktu)
    final rearX = cx - 80 * scale;
    final rearY = groundY - 9 * scale;
    for (var k = 0; k < 11; k++) {
      final spawn = (t / 0.11).floorToDouble() * 0.11 - k * 0.11;
      final age = t - spawn;
      if (age < 0 || age > 1.2) continue;
      final x = rearX - age * sceneSpeed * 0.85 - 6;
      final y = rearY - age * 16 - math.sin(age * 5 + k) * 2;
      final r = 3 + age * 9;
      final a = (1 - age / 1.2) * 0.24 * (1 - boost * 0.6);
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: a));
    }

    SceneKit.car(
      canvas,
      cx: cx,
      groundY: groundY,
      scale: scale,
      dist: dist,
      p: p,
      bob: math.sin(dist * 0.09) * (1.1 + boost * 0.6),
      noseUp: boost * 0.07,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => true;
}