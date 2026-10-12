import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/dtc_code.dart';
import '../../providers/app_providers.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';

class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  bool _loading = false;
  bool _hasScanned = false;
  List<DtcCode> _codes = [];
  String? _error;

  Future<void> _scanDtc() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final obd = ref.read(obdProvider);

    if (obd == null) {
      setState(() {
        _loading = false;
        _error = 'Belum terhubung ke adaptor OBD-II. Sambungkan dulu lewat Settings.';
      });
      return;
    }

    try {
      final result = await obd.readDtc();
      setState(() {
        _codes = result;
        _hasScanned = true;
      });

      // BARU (Phase 2 - DTC Timeline): catat hasil scan ke riwayat
      // (terikat VIN), dan kirim Smart Alert kalau ada kode BARU
      // dibanding scan sebelumnya.
      final vin = ref.read(vehicleProfileProvider).vin;
      if (vin != null) {
        final history = ref.read(dtcHistoryProvider);
        await history.recordScan(vin, result.map((c) => c.code).toList());
        final newlyAppeared = history.getNewlyAppeared(vin);
        if (newlyAppeared.isNotEmpty) {
          await ref.read(notificationProvider).showNewDtcAlert(newlyAppeared);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Scan gagal: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.orange;
      default:
        return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPage(
      title: 'Diagnostics',
      subtitle: 'Baca kode error dan data kendaraan',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: palette.primary,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.onPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.car_repair_rounded, color: palette.onPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scan DTC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 3),
                          Text(
                            _hasScanned
                                ? (_codes.isEmpty ? 'Terakhir: bersih dari kode error' : 'Terakhir: ${_codes.length} kode ditemukan')
                                : 'Baca kode error langsung dari ECU',
                            style: TextStyle(color: palette.onPrimary.withValues(alpha: 0.75), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.onPrimary, foregroundColor: palette.primary),
                    onPressed: _loading ? null : _scanDtc,
                    icon: _loading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.primary),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(_loading ? 'Memindai…' : 'Scan sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            Reveal(
              index: 2,
              child: _ToolTile(icon: Icons.sensors_rounded, label: 'Semua Sensor', color: AppColors.cyan, onTap: () => context.push('/all-sensors')),
            ),
            Reveal(
              index: 3,
              child: _ToolTile(icon: Icons.fact_check_rounded, label: 'Readiness Emisi', color: AppColors.green, onTap: () => context.push('/readiness')),
            ),
            Reveal(
              index: 4,
              child: _ToolTile(icon: Icons.memory_rounded, label: 'Info ECU', color: AppColors.blue, onTap: () => context.push('/ecu-info')),
            ),
            Reveal(
              index: 5,
              child: _ToolTile(icon: Icons.fiber_manual_record_rounded, label: 'Data Recording', color: AppColors.red, onTap: () => context.push('/data-recording')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Hasil scan'),
        if (_error != null)
          NoticeCard(icon: Icons.error_outline_rounded, color: AppColors.orange, text: _error!)
        else if (!_hasScanned)
          const NoticeCard(icon: Icons.touch_app_rounded, text: 'Tekan "Scan sekarang" untuk membaca kode error dari mobil.')
        else if (_codes.isEmpty)
          const NoticeCard(
            icon: Icons.verified_rounded,
            color: AppColors.green,
            title: 'Bersih',
            text: 'Tidak ada DTC aktif. Kondisi mobil bebas dari kode error.',
          ),
        ..._codes.map(
          (code) {
            final color = _severityColor(code.severity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PressScale(
                child: GestureDetector(
                  // Tap DTC untuk lihat Freeze Frame: kondisi mobil saat kode terpicu.
                  onTap: () => context.push('/freeze-frame'),
                  child: GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBubble(icon: Icons.warning_amber_rounded, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(code.code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                                  const SizedBox(width: 8),
                                  StatusChip(text: code.severity, color: color),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(code.description, style: const TextStyle(height: 1.35)),
                              const SizedBox(height: 6),
                              Text('Ketuk untuk lihat freeze frame', style: TextStyle(color: palette.muted, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: palette.muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.label, required this.color, required this.onTap});

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