import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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

class BaselineStatusPage extends ConsumerWidget {
  const BaselineStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vin = ref.watch(vehicleProfileProvider).vin;
    final palette = context.palette;

    if (vin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Status Baseline')),
        body: Center(
          child: Text('Belum ada VIN - scan dulu di Vehicle Profile.',
              style: TextStyle(color: palette.muted)),
        ),
      );
    }

    final baselines = ref.read(vehicleBaselineProvider).getAllBaselines(vin);

    return Scaffold(
      appBar: AppBar(title: const Text('Status Baseline')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Text(
              'Baseline adalah "kebiasaan normal" mobil ini yang dipelajari '
              'dari riwayat berkendara - butuh minimal 30 sample per '
              'kondisi sebelum dianggap cukup diandalkan untuk deteksi '
              'anomali. Baru mulai / progress rendah bukan error, cuma '
              'butuh waktu berkendara normal.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ...baselines.entries.map((stateEntry) {
            final stateName = stateEntry.key;
            final sensors = stateEntry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_stateLabels[stateName] ?? stateName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sensors.entries.map((sensorEntry) {
                      final stat = sensorEntry.value;
                      final count = stat?.count ?? 0;
                      final progress = (count / 30).clamp(0.0, 1.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_sensorLabels[sensorEntry.key] ?? sensorEntry.key),
                                Text(
                                  stat == null
                                      ? 'Belum ada data'
                                      : stat.isReliable
                                          ? '${stat.mean.toStringAsFixed(1)} ± ${stat.stdDev.toStringAsFixed(1)}'
                                          : '$count/30 sample',
                                  style: TextStyle(
                                    color: (stat?.isReliable ?? false)
                                        ? AppColors.green
                                        : palette.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: palette.border,
                                color: progress >= 1 ? AppColors.green : AppColors.cyan,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
