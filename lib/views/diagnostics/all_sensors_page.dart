import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/pid_table.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class AllSensorsPage extends ConsumerWidget {
  const AllSensorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obd = ref.watch(obdProvider);
    final readings = ref.watch(extraSensorsProvider);
    final detected = obd?.availableExtendedPids ?? [];

    return AppPage(
      title: 'Semua Sensor',
      subtitle: obd == null ? 'OBD belum tersambung' : '${detected.length} sensor tambahan',
      trailing: obd != null ? const PulseDot(color: AppColors.green, size: 8) : null,
      children: [
        if (obd == null)
          const NoticeCard(
            icon: Icons.bluetooth_disabled_rounded,
            color: AppColors.orange,
            title: 'Belum terhubung',
            text: 'Sambungkan adaptor OBD-II lewat Settings untuk mendeteksi sensor yang didukung mobil Anda.',
          )
        else if (detected.isEmpty)
          NoticeCard(
            icon: Icons.search_rounded,
            text: readings.isEmpty && obd.supportedPids.isEmpty
                ? 'Mendeteksi sensor yang didukung… kalau ini tidak berubah, coba sambungkan ulang adaptor.'
                : 'Tidak ada sensor tambahan di luar 9 PID inti yang terdeteksi didukung ECU mobil Anda.',
          )
        else ...[
          NoticeCard(
            icon: Icons.sync_rounded,
            color: AppColors.cyan,
            text: '${detected.length} sensor tambahan terdeteksi dari ${obd.supportedPids.length} total PID yang didukung ECU. Diperbarui tiap ±8 detik.',
          ),
          const SizedBox(height: 14),
          ...detected.asMap().entries.map(
                (e) => Reveal(
                  index: 1 + (e.key > 8 ? 8 : e.key),
                  child: _SensorTile(pidDef: e.value, value: readings[e.value.pid]),
                ),
              ),
        ],
      ],
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
          children: [
            const IconBubble(icon: Icons.sensors_rounded, color: AppColors.cyan, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pidDef.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('PID ${pidDef.pid}', style: TextStyle(color: palette.muted, fontSize: 11.5)),
                ],
              ),
            ),
            value == null
                ? Text('…', style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedNumber(
                        value: value!,
                        decimals: 1,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.cyan),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(pidDef.unit, style: TextStyle(color: palette.muted, fontSize: 12)),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}