import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Text(
              'Berdiri diam, tekan Mulai, lalu akselerasi penuh. Bukan '
              'alat ukur presisi (tergantung latensi OBD ~2 detik/siklus) '
              '- untuk perbandingan kasar antar percobaan saja.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${currentSpeed.toStringAsFixed(0)} km/j',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.cyan),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _running ? _stop : _start,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              label: Text(_running ? 'Stop' : 'Mulai Tes'),
            ),
          ),
          const SizedBox(height: 16),
          ..._targets.map((target) {
            final time = _checkpoints[target];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0-$target km/j'),
                    Text(
                      time == null ? '-' : '${(time.inMilliseconds / 1000).toStringAsFixed(2)}s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: time == null ? palette.muted : AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
