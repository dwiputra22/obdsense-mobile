import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/ecu_info_service.dart';
import '../../widgets/glass_card.dart';

class VehicleProfilePage extends ConsumerStatefulWidget {
  const VehicleProfilePage({super.key});

  @override
  ConsumerState<VehicleProfilePage> createState() => _VehicleProfilePageState();
}

class _VehicleProfilePageState extends ConsumerState<VehicleProfilePage> {
  late TextEditingController brandCtrl;
  late TextEditingController modelCtrl;
  late TextEditingController yearCtrl;
  late TextEditingController nicknameCtrl;
  late TextEditingController engineCtrl;

  bool _editing = false;
  bool _syncing = false;
  bool _scanningVin = false;
  VehicleProfile? _profile;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    _profile = storage.getVehicleProfile() ??
        const VehicleProfile(
          brand: 'Toyota',
          model: 'All New Rush',
          year: 2019,
          nickname: 'Rush',
          engineName: '2NR-VE',
        );

    brandCtrl = TextEditingController(text: _profile!.brand);
    modelCtrl = TextEditingController(text: _profile!.model);
    yearCtrl = TextEditingController(text: _profile!.year.toString());
    nicknameCtrl = TextEditingController(text: _profile!.nickname);
    engineCtrl = TextEditingController(text: _profile!.engineName);
  }

  @override
  void dispose() {
    brandCtrl.dispose();
    modelCtrl.dispose();
    yearCtrl.dispose();
    nicknameCtrl.dispose();
    engineCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = VehicleProfile(
      vin: _profile?.vin,
      remoteId: _profile?.remoteId,
      brand: brandCtrl.text.trim(),
      model: modelCtrl.text.trim(),
      year: int.tryParse(yearCtrl.text.trim()) ?? _profile!.year,
      nickname: nicknameCtrl.text.trim(),
      engineName: engineCtrl.text.trim(),
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveVehicleProfile(updated);
    ref.invalidate(vehicleProfileProvider);
    setState(() {
      _profile = updated;
      _editing = false;
    });
  }

  Future<void> _scanVin() async {
    final manager = ref.read(obdConnectionManagerProvider);
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum terhubung ke adaptor OBD-II.')),
      );
      return;
    }

    setState(() => _scanningVin = true);
    try {
      final info = await EcuInfoService(manager).read();
      if (info.vin == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ECU tidak merespons permintaan VIN (Mode 09) - '
                  'tidak semua kendaraan mendukung ini lewat OBD-II generik.'),
            ),
          );
        }
        return;
      }

      final storage = ref.read(localStorageProvider);
      final check = await storage.checkVinAgainstStored(info.vin!);

      if (!check.matches && mounted) {
        final proceed = await _confirmVinMismatch(check.previousVin!, info.vin!);
        if (proceed != true) return;
      }

      final updated = _profile!.copyWith(vin: info.vin);
      await storage.saveVehicleProfile(updated);
      ref.invalidate(vehicleProfileProvider);
      setState(() => _profile = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VIN terdeteksi: ${info.vin}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal scan VIN: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanningVin = false);
    }
  }

  Future<bool?> _confirmVinMismatch(String previousVin, String newVin) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VIN berbeda terdeteksi'),
        content: Text(
          'VIN yang baru terbaca ($newVin) beda dari yang tersimpan '
          'sebelumnya ($previousVin). Ini kemungkinan adapter sedang '
          'dipakai di mobil yang berbeda.\n\n'
          'Melanjutkan akan mengganti identitas mobil aktif - riwayat '
          'baseline & DTC mobil sebelumnya tidak akan tercampur, tapi '
          'app akan mulai "belajar" dari nol untuk mobil ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToBackend() async {
    setState(() => _syncing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final storage = ref.read(localStorageProvider);

      final result = await api.createVehicle({
        'vin': _profile!.vin,
        'brand': _profile!.brand,
        'model': _profile!.model,
        'year': _profile!.year,
        'nickname': _profile!.nickname,
        'engine_name': _profile!.engineName,
      });

      final remoteId = result['id'] as int;
      final updated = _profile!.copyWith(remoteId: remoteId);
      await storage.saveVehicleProfile(updated);
      await storage.setActiveVehicleId(remoteId);
      ref.read(activeVehicleIdProvider.notifier).state = remoteId;
      ref.invalidate(vehicleProfileProvider);

      setState(() => _profile = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kendaraan tersinkron ke server')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal sinkron: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Profile'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _profile!.vin != null ? Icons.verified : Icons.help_outline,
                      size: 18,
                      color: _profile!.vin != null ? AppColors.green : AppColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _profile!.vin ?? 'VIN belum terdeteksi',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'VIN adalah identitas utama mobil untuk baseline & riwayat '
                  'DTC - didapat dari scan OBD, bukan diketik manual.',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanningVin ? null : _scanVin,
                    icon: _scanningVin
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.qr_code_scanner),
                    label: Text(_scanningVin ? 'Membaca...' : 'Scan VIN dari OBD'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil Kendaraan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (!_editing) ...[
                  Text('Merek: ${_profile!.brand}'),
                  Text('Model: ${_profile!.model}'),
                  Text('Tahun: ${_profile!.year}'),
                  Text('Nama panggilan: ${_profile!.nickname}'),
                  Text('Mesin: ${_profile!.engineName}'),
                  Text(
                    _profile!.remoteId != null
                        ? 'Status: tersinkron (id #${_profile!.remoteId})'
                        : 'Status: belum tersinkron ke server',
                  ),
                ] else ...[
                  TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(labelText: 'Merek'),
                  ),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                  TextField(
                    controller: yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tahun'),
                  ),
                  TextField(
                    controller: nicknameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama panggilan'),
                  ),
                  TextField(
                    controller: engineCtrl,
                    decoration: const InputDecoration(labelText: 'Mesin'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncing ? null : _syncToBackend,
              icon: _syncing
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_sync),
              label: Text(_syncing ? 'Menyinkronkan...' : 'Sinkronkan ke server'),
            ),
          ),
        ],
      ),
    );
  }
}
