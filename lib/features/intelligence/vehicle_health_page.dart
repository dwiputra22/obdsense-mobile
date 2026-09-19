import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/intelligence/battery_health_analyzer.dart';
import '../../services/intelligence/vehicle_health_score_calculator.dart';
import '../../widgets/glass_card.dart';

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
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Health')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 40, color: palette.muted),
                const SizedBox(height: 12),
                Text(
                  'Vehicle Intelligence butuh VIN sebagai identitas mobil '
                  'supaya baseline & riwayat tidak tercampur kalau adapter '
                  'dipakai di mobil lain. Scan VIN dulu di halaman Vehicle Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/vehicle-profile'),
                  child: const Text('Buka Vehicle Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final vin = vehicle.vin!;
    final baselineService = ref.read(vehicleBaselineProvider);
    final battery = BatteryHealthAnalyzer.analyze(vin, baselineService);

    // Skor pakai anomali saat ini + placeholder DTC/readiness (dibaca
    // live dari halaman Diagnostics/Readiness terpisah - skor di sini
    // fokus ke sinyal yang sudah tersedia tanpa perlu query OBD lagi).
    final healthScore = VehicleHealthScoreCalculator.calculate(
      dtcCount: 0,
      milOn: false,
      recentAnomalies: anomalies,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Health Score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$healthScore',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: healthScore >= 70 ? AppColors.green : AppColors.orange,
                      ),
                    ),
                    const Text('/100', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Text(VehicleHealthScoreCalculator.label(healthScore)),
                  ],
                ),
                Text(
                  'Skor dari kode error, anomali sensor, & kelengkapan monitor '
                  'emisi - indikatif, bukan diagnosa pasti.',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.battery_charging_full, color: _severityColor(battery.severity)),
                    const SizedBox(width: 8),
                    const Text('Kesehatan Aki/Alternator',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(battery.assessment, style: TextStyle(color: palette.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Anomali Terdeteksi', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (anomalies.isEmpty)
                  Text('Tidak ada anomali saat ini.', style: TextStyle(color: palette.muted, fontSize: 12))
                else
                  ...anomalies.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${a.label}: ${a.actualValue.toStringAsFixed(1)} '
                          '(biasanya ~${a.expectedMean.toStringAsFixed(1)}, '
                          '${a.deviationInStdDevs.toStringAsFixed(1)}σ)',
                          style: TextStyle(
                            color: a.severity == 'warning' ? AppColors.red : AppColors.orange,
                            fontSize: 12,
                          ),
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/baseline-status'),
            icon: const Icon(Icons.insights),
            label: const Text('Status Pembelajaran Baseline'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/dtc-timeline'),
            icon: const Icon(Icons.timeline),
            label: const Text('Riwayat DTC (Timeline)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/ai-mechanic'),
            icon: const Icon(Icons.psychology),
            label: const Text('Tanya AI Mechanic'),
          ),
        ],
      ),
    );
  }
}
