import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/pid_table.dart';
import '../../widgets/glass_card.dart';

class AllSensorsPage extends ConsumerWidget {
  const AllSensorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obd = ref.watch(obdProvider);
    final readings = ref.watch(extraSensorsProvider);
    final palette = context.palette;

    final detected = obd?.availableExtendedPids ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Semua Sensor')),
      body: obd == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum terhubung ke adaptor OBD-II. Sambungkan dulu lewat '
                  'Settings untuk mendeteksi sensor yang didukung mobil Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          : detected.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      readings.isEmpty && obd.supportedPids.isEmpty
                          ? 'Mendeteksi sensor yang didukung... kalau ini '
                              'tidak berubah, coba sambungkan ulang adaptor.'
                          : 'Tidak ada sensor tambahan di luar 9 PID inti '
                              'yang terdeteksi didukung ECU mobil Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      child: Text(
                        '${detected.length} sensor tambahan terdeteksi dari '
                        '${obd.supportedPids.length} total PID yang '
                        'didukung ECU. Diperbarui tiap ±8 detik.',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...detected.map((pidDef) => _SensorTile(
                          pidDef: pidDef,
                          value: readings[pidDef.pid],
                        )),
                  ],
                ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final PidDefinition pidDef;
  final double? value;

  const _SensorTile({required this.pidDef, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pidDef.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('PID ${pidDef.pid}', style: TextStyle(color: palette.muted, fontSize: 11)),
                ],
              ),
            ),
            Text(
              value == null ? '...' : '${value!.toStringAsFixed(1)} ${pidDef.unit}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
