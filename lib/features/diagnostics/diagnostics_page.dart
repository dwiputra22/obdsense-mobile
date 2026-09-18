import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/dtc_code.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _loading ? null : _scanDtc,
            icon: const Icon(Icons.search),
            label: Text(_loading ? 'Memindai...' : 'Scan DTC'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/all-sensors'),
            icon: const Icon(Icons.sensors),
            label: const Text('Lihat Semua Sensor'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/readiness'),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Readiness (Kesiapan Emisi)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/ecu-info'),
            icon: const Icon(Icons.memory),
            label: const Text('Info ECU'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/data-recording'),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Data Recording'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            GlassCard(
              child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            )
          else if (!_hasScanned)
            const GlassCard(
              child: Text('Tekan "Scan DTC" untuk membaca kode error dari mobil.'),
            )
          else if (_codes.isEmpty)
            const GlassCard(
              child: Text('Tidak ada DTC aktif. Kondisi mobil bersih dari kode error.'),
            ),
          ..._codes.map(
            (code) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/freeze-frame'),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            code.code,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _severityColor(code.severity),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: context.palette.muted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(code.description),
                      const SizedBox(height: 8),
                      Text('Severity: ${code.severity}'),
                      const SizedBox(height: 4),
                      Text(
                        'Ketuk untuk lihat freeze frame',
                        style: TextStyle(color: context.palette.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
