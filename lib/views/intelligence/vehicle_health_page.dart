import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/battery_health_analyzer.dart';
import '../../services/intelligence/vehicle_health_score_calculator.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class VehicleHealthPage extends ConsumerWidget {
  const VehicleHealthPage({super.key});

  Color _severityColor(String severity) {
    switch (severity) {
      case 'good':
        return AppColors.green;
      case 'watch':
        return AppColors.orange;
      case 'warning':
        return AppColors.red;
      default:
        return AppColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProfileProvider);
    final anomalies = ref.watch(currentAnomaliesProvider);
    final palette = context.palette;

    if (vehicle.vin == null) {
      return AppPage(
        title: 'Vehicle Health',
        subtitle: 'Kesehatan kendaraan',
        children: [
          const NoticeCard(
            icon: Icons.info_outline_rounded,
            color: AppColors.orange,
            title: 'Butuh VIN',
            text: 'Vehicle Intelligence memakai VIN sebagai identitas mobil supaya baseline & riwayat tidak tercampur kalau adapter dipakai di mobil lain. Scan VIN dulu di halaman Vehicle Profile.',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/vehicle-profile'),
            icon: const Icon(Icons.directions_car_filled_rounded),
            label: const Text('Buka Vehicle Profile'),
          ),
        ],
      );
    }

    final vin = vehicle.vin!;
    final baselineService = ref.read(vehicleBaselineProvider);
    final battery = BatteryHealthAnalyzer.analyze(vin, baselineService);

    // Skor pakai anomali saat ini + placeholder DTC/readiness (dibaca live dari
    // halaman Diagnostics/Readiness terpisah).
    final healthScore = VehicleHealthScoreCalculator.calculate(
      dtcCount: 0,
      milOn: false,
      recentAnomalies: anomalies,
    );
    final scoreColor = healthScore >= 70 ? AppColors.green : AppColors.orange;
    final batteryColor = _severityColor(battery.severity);

    return AppPage(
      title: 'Vehicle Health',
      subtitle: 'Kesehatan kendaraan',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProgressRing(
                      value: healthScore / 100,
                      size: 112,
                      strokeWidth: 11,
                      color: scoreColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedNumber(
                            value: healthScore.toDouble(),
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: scoreColor, height: 1.0),
                          ),
                          Text('/100', style: TextStyle(fontSize: 11, color: palette.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Skor kesehatan', style: TextStyle(color: palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            VehicleHealthScoreCalculator.label(healthScore),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor, letterSpacing: -0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Skor dari kode error, anomali sensor, & kelengkapan monitor emisi - indikatif, bukan diagnosa pasti.',
                  style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 2,
          child: GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBubble(icon: Icons.battery_charging_full_rounded, color: batteryColor, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kesehatan Aki & alternator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(battery.assessment, style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 3,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBubble(
                      icon: anomalies.isEmpty ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      color: anomalies.isEmpty ? AppColors.green : AppColors.orange,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Anomali Terdeteksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    StatusChip(
                      text: anomalies.isEmpty ? 'Aman' : '${anomalies.length}',
                      color: anomalies.isEmpty ? AppColors.green : AppColors.orange,
                    ),
                  ],
                ),
                if (anomalies.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Tidak ada anomali saat ini.', style: TextStyle(color: palette.muted, fontSize: 12.5)),
                ] else ...[
                  const SizedBox(height: 12),
                  ...anomalies.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${a.label}: ${a.actualValue.toStringAsFixed(1)} '
                        '(biasanya ~${a.expectedMean.toStringAsFixed(1)}, '
                        '${a.deviationInStdDevs.toStringAsFixed(1)}σ)',
                        style: TextStyle(
                          color: a.severity == 'warning' ? AppColors.red : AppColors.orange,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Reveal(index: 4, child: SectionTitle('Telusuri lebih dalam')),
        GridView.count(
padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            Reveal(index: 5, child: _NavTile(icon: Icons.insights_rounded, label: 'Status Baseline', color: AppColors.cyan, onTap: () => context.push('/baseline-status'))),
            Reveal(index: 6, child: _NavTile(icon: Icons.fingerprint_rounded, label: 'Fingerprint & Drift', color: AppColors.blue, onTap: () => context.push('/vehicle-fingerprint'))),
            Reveal(index: 7, child: _NavTile(icon: Icons.timeline_rounded, label: 'Riwayat DTC', color: AppColors.orange, onTap: () => context.push('/dtc-timeline'))),
            Reveal(index: 8, child: _NavTile(icon: Icons.psychology_rounded, label: 'Tanya AI Mechanic', color: AppColors.purple, onTap: () => context.push('/ai-mechanic'))),
          ],
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBubble(icon: icon, color: color, size: 40),
              Text(label, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}