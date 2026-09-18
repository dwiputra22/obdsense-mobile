import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/freeze_frame_data.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/freeze_frame_service.dart';
import '../../widgets/glass_card.dart';

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
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freeze Frame'),
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
              : _data == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kondisi mobil saat kode ini terpicu:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _data!.triggeringDtc,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_data!.rpm != null)
                          _FrameRow(label: 'RPM', value: '${_data!.rpm!.toStringAsFixed(0)} rpm'),
                        if (_data!.speed != null)
                          _FrameRow(label: 'Kecepatan', value: '${_data!.speed!.toStringAsFixed(0)} km/j'),
                        if (_data!.coolantTempC != null)
                          _FrameRow(label: 'Suhu Mesin', value: '${_data!.coolantTempC!.toStringAsFixed(0)}°C'),
                        if (_data!.engineLoad != null)
                          _FrameRow(label: 'Beban Mesin', value: '${_data!.engineLoad!.toStringAsFixed(0)}%'),
                        if (_data!.throttlePosition != null)
                          _FrameRow(label: 'Posisi Throttle', value: '${_data!.throttlePosition!.toStringAsFixed(0)}%'),
                        if (_data!.intakeTempC != null)
                          _FrameRow(label: 'Suhu Udara Masuk', value: '${_data!.intakeTempC!.toStringAsFixed(0)}°C'),
                        if (_data!.fuelLevelPercent != null)
                          _FrameRow(label: 'Level BBM', value: '${_data!.fuelLevelPercent!.toStringAsFixed(0)}%'),
                      ],
                    ),
    );
  }
}

class _FrameRow extends StatelessWidget {
  final String label;
  final String value;

  const _FrameRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan)),
          ],
        ),
      ),
    );
  }
}
