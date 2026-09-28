import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/insight_card.dart';
import '../../widgets/metric_tile.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(telemetryProvider);
    final insights = ref.watch(aiInsightsProvider);
    final vehicle = ref.watch(vehicleProfileProvider);
    final anomalies = ref.watch(currentAnomaliesProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RushSense AI'),
        actions: [
          IconButton(
            onPressed: () => ref.read(currentTabIndexProvider.notifier).state = 4,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.brand} ${vehicle.model} ${vehicle.year}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dashboard monitoring "${vehicle.nickname}" dengan AI diagnosis dan telemetry OBD-II',
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: () => ref.read(currentTabIndexProvider.notifier).state = 1,
                      child: const Text('Live Monitor'),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/diagnostics'),
                      child: const Text('Diagnostics'),
                    ),
                    ElevatedButton(
                      onPressed: () => ref.read(currentTabIndexProvider.notifier).state = 2,
                      child: const Text('Trips'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/vehicle-health'),
            child: GlassCard(
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: vehicle.vin == null
                        ? palette.muted
                        : (anomalies.isEmpty ? AppColors.green : AppColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Health', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          vehicle.vin == null
                              ? 'Scan VIN dulu untuk mengaktifkan'
                              : anomalies.isEmpty
                                  ? 'Tidak ada anomali terdeteksi'
                                  : '${anomalies.length} anomali terdeteksi',
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: palette.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              MetricTile(
                label: 'Suhu Mesin',
                value: data.coolantTempC.toStringAsFixed(0),
                unit: '°C',
                color: data.coolantTempC >= 100 ? AppColors.red : AppColors.cyan,
              ),
              MetricTile(
                label: 'RPM',
                value: data.rpm.toStringAsFixed(0),
                unit: 'rpm',
                color: AppColors.blue,
              ),
              MetricTile(
                label: 'Kecepatan',
                value: data.speed.toStringAsFixed(0),
                unit: 'km/j',
                color: AppColors.green,
              ),
              MetricTile(
                label: 'Voltase Aki',
                value: data.batteryVoltage.toStringAsFixed(1),
                unit: 'V',
                color: data.batteryVoltage < 12.3 ? AppColors.orange : AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'AI Insight',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            GlassCard(
              child: Text(
                'Belum ada insight. Nyalakan Live Monitor sambil berkendara '
                'supaya AI punya data untuk dianalisis.',
                style: TextStyle(color: palette.muted),
              ),
            ),
          ...insights.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InsightCard(insight: e),
            ),
          ),
        ],
      ),
    );
  }
}
