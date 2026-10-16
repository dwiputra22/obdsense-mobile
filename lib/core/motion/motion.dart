import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 650);
  static const Duration stagger = Duration(milliseconds: 55);
  static const Curve enter = Curves.easeOutCubic;
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.dy = 22,
  });

  final Widget child;

  final int index;
  final double dy;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Motion.slow);
    _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);
    final steps = math.min(math.max(widget.index, 0), 10);
    if (steps == 0) {
      _controller.forward();
    } else {
      _timer = Timer(Motion.stagger * steps, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return _RevealScope(
      child: RepaintBoundary(
      child: FadeTransition(
        opacity: _curve,
        child: AnimatedBuilder(
          animation: _curve,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, (1 - _curve.value) * widget.dy),
            child: child,
          ),
        ),
      ),
    ));
  }
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required super.child});

  static bool active(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RevealScope>() != null;

  @override
  bool updateShouldNotify(_RevealScope oldWidget) => false;
}

class _Stagger {
  static int _n = 0;
  static bool _scheduled = false;

  /// Urutan build dalam satu frame; di-reset setelah frame selesai.
  static int take() {
    final i = _n++;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _n = 0;
        _scheduled = false;
      });
    }
    return i;
  }
}

class AutoReveal extends StatefulWidget {
  const AutoReveal({super.key, required this.child});

  final Widget child;

  @override
  State<AutoReveal> createState() => _AutoRevealState();
}

class _AutoRevealState extends State<AutoReveal> {
  int? _order;

  @override
  Widget build(BuildContext context) {
    if (_RevealScope.active(context)) return widget.child;
    _order ??= _Stagger.take();
    return Reveal(index: _order!, dy: 18, child: widget.child);
  }
}

// ---------------------------------------------------------------------------
// PulseDot: notif sedang aktif (indikator "sedang merekam" / "live").
// ---------------------------------------------------------------------------
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = AppColors.red, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.4,
      height: widget.size * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (1 + 1.4 * t),
                height: widget.size * (1 + 1.4 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// AnimatedNumber: angka berhitung naik saat muncul dan bergeser halus antar
/// pembacaan.
// ---------------------------------------------------------------------------
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 450),
  });

  final double value;
  final int decimals;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final safe = value.isFinite ? value : 0.0;
    final effective = (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: safe),
      duration: _reduceMotion(context) ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: effective),
    );
  }
}

// ---------------------------------------------------------------------------
/// PressScale: kartu mengecil sedikit saat ditekan. Memakai Listener (bukan
/// GestureDetector) supaya TIDAK mencuri tap dari InkWell/tombol di dalamnya,
/// dan kembali normal kalau jari mulai menggeser (scroll).
// ---------------------------------------------------------------------------
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  Offset? _start;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        final s = _start;
        if (s != null && (e.position - s).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// ProgressRing: cincin progres yang terisi dari 0 saat muncul, lalu bergeser
/// halus kalau nilainya berubah. [value] 0..1.
// ---------------------------------------------------------------------------
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 88,
    this.strokeWidth = 9,
    this.child,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final track = context.palette.border;
    final target = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: _reduceMotion(context) ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: v,
                  color: color,
                  trackColor: track,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - strokeWidth * 2.2) / 2,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (progress <= 0) return;
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
/// PageScaleFx: halaman sedikit mengecil saat digeser keluar/masuk (efek
/// kartu bertumpuk).
// ---------------------------------------------------------------------------
class PageScaleFx extends StatelessWidget {
  const PageScaleFx({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var page = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.hasPixels) {
          page = controller.page ?? page;
        }
        final d = (page - index).abs().clamp(0.0, 1.0).toDouble();
        return Transform.scale(scale: 1 - 0.05 * d, child: child);
      },
    );
  }
}

// ---------------------------------------------------------------------------
/// FluidBottomNav: bottom nav dengan "pill" yang mengikuti jari saat swipe
/// pindah tab.
// ---------------------------------------------------------------------------
class NavItemData {
  const NavItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class FluidBottomNav extends StatelessWidget {
  const FluidBottomNav({
    super.key,
    required this.controller,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItemData> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              const pillWidth = 56.0;
              const pillHeight = 32.0;
              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      var page = currentIndex.toDouble();
                      if (controller.hasClients && controller.position.hasPixels) {
                        page = controller.page ?? page;
                      }
                      return Positioned(
                        left: page * itemWidth + (itemWidth - pillWidth) / 2,
                        top: 8,
                        width: pillWidth,
                        height: pillHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(pillHeight / 2),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            selectedColor: palette.primary,
                            unselectedColor: palette.muted,
                            onTap: () {
                              if (i != currentIndex) HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final NavItemData item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: AnimatedScale(
                  scale: selected ? 1.14 : 1.0,
                  duration: Motion.medium,
                  curve: Curves.easeOutBack,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: Motion.fast,
                    builder: (context, c, _) => Icon(item.icon, size: 22, color: c),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Transisi halaman.
// ---------------------------------------------------------------------------
class SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = animation.drive(
      Tween<Offset>(begin: const Offset(0.10, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    final fade = animation.drive(CurveTween(curve: Curves.easeOut));
    final outgoing = secondaryAnimation.drive(
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.05, 0))
          .chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    return SlideTransition(
      position: outgoing,
      child: SlideTransition(
        position: incoming,
        child: FadeTransition(opacity: fade, child: child),
      ),
    );
  }
}