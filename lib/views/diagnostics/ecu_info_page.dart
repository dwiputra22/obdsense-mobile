import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ecu_info.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/ecu_info_service.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class EcuInfoPage extends ConsumerStatefulWidget {
  const EcuInfoPage({super.key});

  @override
  ConsumerState<EcuInfoPage> createState() => _EcuInfoPageState();
}

class _EcuInfoPageState extends ConsumerState<EcuInfoPage> {
  bool _loading = false;
  EcuInfo? _info;
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
      final info = await EcuInfoService(manager).read();
      setState(() {
        _info = info;
        if (info.isEmpty) {
          _error = 'ECU tidak merespons permintaan info kendaraan (Mode 09) - '
              'tidak semua ECU mendukung ini.';
        }
      });
    } catch (e) {
      setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Info ECU',
      subtitle: 'Identitas modul kendaraan',
      trailing: RoundIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'Muat ulang',
        onTap: () {
          if (!_loading) _load();
        },
      ),
      children: [
        if (_loading)
          const LoadingBlock(label: 'Membaca ECU…')
        else ...[
          if (_error != null) NoticeCard(icon: Icons.info_outline_rounded, color: AppColors.orange, text: _error!),
          if (_info?.vin != null)
            Reveal(index: 1, child: _InfoRow(icon: Icons.badge_rounded, color: AppColors.cyan, label: 'VIN', value: _info!.vin!)),
          if (_info?.calibrationId != null)
            Reveal(index: 2, child: _InfoRow(icon: Icons.tune_rounded, color: AppColors.blue, label: 'Calibration ID', value: _info!.calibrationId!)),
          if (_info?.ecuName != null)
            Reveal(index: 3, child: _InfoRow(icon: Icons.memory_rounded, color: AppColors.purple, label: 'Nama ECU', value: _info!.ecuName!)),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            IconBubble(icon: icon, color: color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  SelectableText(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}