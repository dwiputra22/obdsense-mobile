import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/readiness_status.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/obd_response_validator.dart';
import '../../services/obd/readiness_parser.dart';
import '../../widgets/glass_card.dart';

class ReadinessPage extends ConsumerStatefulWidget {
  const ReadinessPage({super.key});

  @override
  ConsumerState<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends ConsumerState<ReadinessPage> {
  bool _loading = false;
  ReadinessStatus? _status;
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
    if (manager?.queue == null) {
      setState(() {
        _loading = false;
        _error = 'Belum terhubung ke adaptor OBD-II.';
      });
      return;
    }

    try {
      final response = await manager!.queue!.send('0101');
      if (!ObdResponseValidator.isValid(response)) {
        setState(() {
          _error = 'ECU tidak merespons permintaan status readiness.';
        });
        return;
      }
      final parsed = ReadinessParser.parse(response);
      setState(() {
        _status = parsed;
        if (parsed == null) _error = 'Gagal membaca data readiness.';
      });
    } catch (e) {
      setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness (Kesiapan Emisi)'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!, textAlign: TextAlign.center,
                        style: TextStyle(color: palette.muted)),
                  ),
                )
              : _status == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _status!.allReady
                                    ? 'Semua monitor siap - kemungkinan besar lolos uji emisi'
                                    : 'Ada monitor yang belum siap - kendarai mobil dengan '
                                        'pola normal beberapa hari supaya monitor selesai '
                                        'sebelum uji emisi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _status!.allReady ? AppColors.green : AppColors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'MIL (Check Engine): ${_status!.milOn ? "Menyala" : "Mati"} • '
                                '${_status!.dtcCount} DTC tersimpan • '
                                '${_status!.isCompressionIgnition ? "Diesel" : "Bensin"}',
                                style: TextStyle(color: palette.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._status!.monitors.where((m) => m.supported).map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(m.name)),
                                      Row(
                                        children: [
                                          Icon(
                                            m.ready ? Icons.check_circle : Icons.pending,
                                            size: 18,
                                            color: m.ready ? AppColors.green : AppColors.orange,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            m.ready ? 'Siap' : 'Belum Siap',
                                            style: TextStyle(
                                              color: m.ready ? AppColors.green : AppColors.orange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
    );
  }
}
