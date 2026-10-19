import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class PerformanceTestPage extends ConsumerStatefulWidget {
  const PerformanceTestPage({super.key});

  @override
  ConsumerState<PerformanceTestPage> createState() => _PerformanceTestPageState();
}

class _PerformanceTestPageState extends ConsumerState<PerformanceTestPage> {
  bool _running = false;
  Stopwatch? _stopwatch;
  final Map<int, Duration> _checkpoints = {};
  static const _targets = [20, 40, 60, 80, 100];
  ProviderSubscription<double>? _speedSub;

  void _start() {
    setState(() {
      _running = true;
      _checkpoints.clear();
    });
    _stopwatch = Stopwatch()..start();

    _speedSub = ref.listenManual(
      telemetryProvider.select((d) => d.speed),
      (previous, speed) {
        for (final target in _targets) {
          if (speed >= target && !_checkpoints.containsKey(target)) {
            setState(() => _checkpoints[target] = _stopwatch!.elapsed);
          }
        }
        if (speed >= _targets.last) {
          _stop();
        }
      },
    );
  }

  void _stop() {
    _stopwatch?.stop();
    _speedSub?.close();
    setState(() => _running = false);
  }

  @override
  void dispose() {
    _speedSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentSpeed = ref.watch(telemetryProvider.select((d) => d.speed));
    final reached = _checkpoints.length;

    return AppPage(
      title: 'Performance Test',
      subtitle: 'Akselerasi 0-100 km/j',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: palette.primary,
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedNumber(
                      value: currentSpeed,
                      style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -3),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('km/j', style: TextStyle(color: palette.onPrimary.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.onPrimary, foregroundColor: palette.primary),
                    onPressed: _running ? _stop : _start,
                    icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_running ? 'Stop' : 'Mulai tes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const NoticeCard(
          icon: Icons.info_outline_rounded,
          text: 'Berdiri diam, tekan Mulai, lalu akselerasi penuh. Bukan alat ukur presisi (tergantung latensi OBD ~2 detik/siklus) - untuk perbandingan kasar antar percobaan saja.',
        ),
        const SizedBox(height: 16),
        SectionTitle('Checkpoint', trailing: StatusChip(text: '$reached/${_targets.length}', color: reached == _targets.length ? AppColors.green : AppColors.cyan)),
        ..._targets.asMap().entries.map((e) {
          final target = e.value;
          final time = _checkpoints[target];
          final done = time != null;
          return Reveal(
            index: 2 + e.key,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    IconBubble(icon: done ? Icons.flag_rounded : Icons.outlined_flag_rounded, color: done ? AppColors.green : palette.muted, size: 38),
                    const SizedBox(width: 12),
                    Expanded(child: Text('0-$target km/j', style: const TextStyle(fontWeight: FontWeight.w700))),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        done ? '${(time.inMilliseconds / 1000).toStringAsFixed(2)}s' : '-',
                        key: ValueKey(done),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: done ? AppColors.green : palette.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}