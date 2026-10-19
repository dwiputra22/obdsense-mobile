import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/freeze_frame_data.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/freeze_frame_service.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class FreezeFramePage extends ConsumerStatefulWidget {
  const FreezeFramePage({super.key});

  @override
  ConsumerState<FreezeFramePage> createState() => _FreezeFramePageState();
}

class _FreezeFramePageState extends ConsumerState<FreezeFramePage> {
  bool _loading = false;
  FreezeFrameData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final manager = ref.read(obdConnectionManagerProvider);
    if (manager == null) {
      setState(() {
        _loading = false;
        _error = 'Belum terhubung ke adaptor OBD-II.';
      });
      return;
    }

    try {
      final data = await FreezeFrameService(manager).read();
      setState(() {
        _data = data;
        if (data == null) {
          _error = 'Tidak ada freeze frame tersimpan - wajar kalau belum '
              'pernah ada DTC yang terpicu sejak terakhir dihapus.';
        }
      });
    } catch (e) {
      setState(() => _error = 'Gagal membaca freeze frame: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final tiles = <_FrameTile>[
      if (d?.rpm != null) _FrameTile(icon: Icons.av_timer_rounded, color: AppColors.blue, label: 'RPM', value: d!.rpm!, unit: 'rpm'),
      if (d?.speed != null) _FrameTile(icon: Icons.speed_rounded, color: AppColors.green, label: 'Kecepatan', value: d!.speed!, unit: 'km/j'),
      if (d?.coolantTempC != null) _FrameTile(icon: Icons.thermostat_rounded, color: AppColors.cyan, label: 'Suhu mesin', value: d!.coolantTempC!, unit: '°C'),
      if (d?.engineLoad != null) _FrameTile(icon: Icons.engineering_rounded, color: AppColors.orange, label: 'Beban mesin', value: d!.engineLoad!, unit: '%'),
      if (d?.throttlePosition != null) _FrameTile(icon: Icons.tune_rounded, color: AppColors.purple, label: 'Throttle', value: d!.throttlePosition!, unit: '%'),
      if (d?.intakeTempC != null) _FrameTile(icon: Icons.air_rounded, color: AppColors.blue, label: 'Udara masuk', value: d!.intakeTempC!, unit: '°C'),
      if (d?.fuelLevelPercent != null) _FrameTile(icon: Icons.local_gas_station_rounded, color: AppColors.green, label: 'Level BBM', value: d!.fuelLevelPercent!, unit: '%'),
    ];

    return AppPage(
      title: 'Freeze Frame',
      subtitle: 'Kondisi mobil saat kode terpicu',
      trailing: RoundIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'Muat ulang',
        onTap: () {
          if (!_loading) _load();
        },
      ),
      children: [
        if (_loading)
          const LoadingBlock(label: 'Membaca freeze frame…')
        else if (_error != null)
          NoticeCard(icon: Icons.info_outline_rounded, color: AppColors.orange, text: _error!)
        else if (d != null) ...[
          Reveal(
            index: 1,
            child: GlassCard(
              color: AppColors.red,
              radius: 28,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.ac_unit_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kode pemicu', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(d.triggeringDtc, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
padding: EdgeInsets.zero,
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              for (var i = 0; i < tiles.length; i++) Reveal(index: 2 + (i > 6 ? 6 : i), child: tiles[i]),
            ],
          ),
        ],
      ],
    );
  }
}

class _FrameTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double value;
  final String unit;

  const _FrameTile({required this.icon, required this.color, required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconBubble(icon: icon, color: color, size: 30),
              const SizedBox(width: 8),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedNumber(value: value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, height: 1.0)),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(unit, style: TextStyle(color: palette.muted, fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }
}