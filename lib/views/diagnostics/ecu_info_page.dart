import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ecu_info.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/ecu_info_service.dart';
import '../../widgets/glass_card.dart';

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
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Info ECU'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  GlassCard(
                    child: Text(_error!, style: TextStyle(color: palette.muted)),
                  ),
                if (_info?.vin != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(label: 'VIN', value: _info!.vin!),
                ],
                if (_info?.calibrationId != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Calibration ID', value: _info!.calibrationId!),
                ],
                if (_info?.ecuName != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Nama ECU', value: _info!.ecuName!),
                ],
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.palette.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
