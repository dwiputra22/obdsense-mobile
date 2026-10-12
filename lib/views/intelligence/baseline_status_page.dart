import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

const _sensorLabels = {
  'rpm': 'RPM Idle',
  'coolantTempC': 'Suhu Mesin',
  'batteryVoltage': 'Voltase',
  'engineLoad': 'Beban Mesin',
};

const _stateLabels = {
  'idle': 'Idle (Diam)',
  'city': 'Kota (<60 km/j)',
  'highway': 'Tol/Jalan Cepat',
};

const _stateIcons = {
  'idle': Icons.pause_circle_outline_rounded,
  'city': Icons.location_city_rounded,
  'highway': Icons.add_road_rounded,
};

class BaselineStatusPage extends ConsumerWidget {
  const BaselineStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vin = ref.watch(vehicleProfileProvider).vin;
    final palette = context.palette;

    if (vin == null) {
      return const AppPage(
        title: 'Status Baseline',
        subtitle: 'Kebiasaan normal mobil',
        children: [
          NoticeCard(icon: Icons.qr_code_scanner_rounded, color: AppColors.orange, text: 'Belum ada VIN - scan dulu di Vehicle Profile.'),
        ],
      );
    }

    final baselines = ref.read(vehicleBaselineProvider).getAllBaselines(vin);

    return AppPage(
      title: 'Status Baseline',
      subtitle: 'Kebiasaan normal mobil',
      children: [
        const NoticeCard(
          icon: Icons.school_rounded,
          color: AppColors.cyan,
          title: 'Apa itu baseline?',
          text: 'Kebiasaan normal mobil ini yang dipelajari dari riwayat berkendara. Butuh minimal 30 sample per kondisi sebelum cukup andal untuk deteksi anomali. Progress rendah bukan error - cuma butuh waktu berkendara normal.',
        ),
        const SizedBox(height: 14),
        ...baselines.entries.toList().asMap().entries.map((entry) {
          final stateName = entry.value.key;
          final sensors = entry.value.value;

          return Reveal(
            index: 1 + entry.key,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBubble(icon: _stateIcons[stateName] ?? Icons.directions_car_rounded, color: AppColors.blue, size: 38),
                        const SizedBox(width: 12),
                        Text(_stateLabels[stateName] ?? stateName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...sensors.entries.map((sensorEntry) {
                      final stat = sensorEntry.value;
                      final count = stat?.count ?? 0;
                      final progress = (count / 30).clamp(0.0, 1.0).toDouble();
                      final reliable = stat?.isReliable ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_sensorLabels[sensorEntry.key] ?? sensorEntry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  stat == null
                                      ? 'Belum ada data'
                                      : reliable
                                          ? '${stat.mean.toStringAsFixed(1)} ± ${stat.stdDev.toStringAsFixed(1)}'
                                          : '$count/30 sample',
                                  style: TextStyle(color: reliable ? AppColors.green : palette.muted, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: v,
                                  minHeight: 7,
                                  backgroundColor: palette.border.withValues(alpha: 0.6),
                                  color: progress >= 1 ? AppColors.green : AppColors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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