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
        const VehicleProfile(brand: '', model: '', year: 0, nickname: '', engineName: '');

    brandCtrl = TextEditingController(text: _profile!.brand);
    modelCtrl = TextEditingController(text: _profile!.model);
    yearCtrl = TextEditingController(text: _profile!.year > 0 ? _profile!.year.toString() : '');
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

  bool get _obdConnected => ref.read(obdConnectionManagerProvider)?.isConnected == true;

  Future<void> _save() async {
    final updated = VehicleProfile(
      vin: _profile?.vin,
      remoteId: _profile?.remoteId,
      brand: brandCtrl.text.trim(),
      model: modelCtrl.text.trim(),
      year: int.tryParse(yearCtrl.text.trim()) ?? 0,
      nickname: nicknameCtrl.text.trim(),
      engineName: engineCtrl.text.trim(),
    );

    await ref.read(localStorageProvider).saveVehicleProfile(updated);
    ref.invalidate(vehicleProfileProvider);
    setState(() {
      _profile = updated;
      _editing = false;
    });
  }

  Future<void> _scanVin() async {
    final manager = ref.read(obdConnectionManagerProvider);
    if (manager == null || !manager.isConnected) {
      _showMessage('Hubungkan OBD-II terlebih dahulu sebelum scan VIN.');
      return;
    }

    setState(() => _scanningVin = true);
    try {
      final info = await EcuInfoService(manager).read();
      if (info.vin == null || info.vin!.trim().isEmpty) {
        _showMessage('VIN tidak tersedia dari ECU. Tidak semua kendaraan mendukung pembacaan VIN lewat OBD-II generik.');
        return;
      }

      final storage = ref.read(localStorageProvider);
      final check = await storage.checkVinAgainstStored(info.vin!);
      if (!check.matches && mounted) {
        final proceed = await _confirmVinMismatch(check.previousVin!, info.vin!);
        if (proceed != true) return;
      }

      final updated = _profile!.copyWith(vin: info.vin!.trim());
      await storage.saveVehicleProfile(updated);
      ref.invalidate(vehicleProfileProvider);
      if (mounted) setState(() => _profile = updated);
      _showMessage('VIN terdeteksi: ${info.vin}');
    } catch (_) {
      _showMessage('Scan VIN gagal. Pastikan OBD tersambung dan ECU dapat merespons Mode 09.');
    } finally {
      if (mounted) setState(() => _scanningVin = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmVinMismatch(String previousVin, String newVin) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VIN berbeda terdeteksi'),
        content: Text('VIN baru ($newVin) berbeda dari VIN tersimpan ($previousVin). Lanjutkan untuk mengganti kendaraan aktif?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lanjutkan')),
        ],
      ),
    );
  }

  Future<void> _syncToBackend() async {
    if (_profile?.vin == null) return;
    setState(() => _syncing = true);
    try {
      final result = await ref.read(apiServiceProvider).createVehicle({
        'vin': _profile!.vin,
        'brand': _profile!.brand,
        'model': _profile!.model,
        'year': _profile!.year,
        'nickname': _profile!.nickname,
        'engine_name': _profile!.engineName,
      });
      final remoteId = result['id'] as int;
      final updated = _profile!.copyWith(remoteId: remoteId);
      await ref.read(localStorageProvider).saveVehicleProfile(updated);
      await ref.read(localStorageProvider).setActiveVehicleId(remoteId);
      ref.read(activeVehicleIdProvider.notifier).state = remoteId;
      ref.invalidate(vehicleProfileProvider);
      if (mounted) setState(() => _profile = updated);
      _showMessage('Kendaraan berhasil disinkronkan ke server.');
    } catch (_) {
      _showMessage('Sinkronisasi gagal. Periksa koneksi internet dan server.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _value(String value) => value.trim().isEmpty ? 'Belum diisi' : value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = _profile!;
    final hasVin = profile.vin?.isNotEmpty == true;

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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(hasVin ? Icons.verified : Icons.info_outline, size: 18,
                    color: hasVin ? AppColors.green : AppColors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(hasVin ? profile.vin! : 'VIN belum terdeteksi',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 6),
              Text('VIN dibaca dari ECU melalui OBD-II. Hubungkan adaptor terlebih dahulu.',
                  style: TextStyle(color: palette.muted, fontSize: 11)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (!_obdConnected || _scanningVin) ? null : _scanVin,
                  icon: _scanningVin
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.qr_code_scanner),
                  label: Text(_scanningVin ? 'Membaca VIN...' : (_obdConnected ? 'Scan VIN dari OBD' : 'Hubungkan OBD untuk Scan VIN')),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Profil Kendaraan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (!_editing) ...[
                _infoRow('Merek', _value(profile.brand)),
                _infoRow('Model', _value(profile.model)),
                _infoRow('Tahun', profile.year > 0 ? '${profile.year}' : 'Belum diisi'),
                _infoRow('Nama panggilan', _value(profile.nickname)),
                _infoRow('Mesin', _value(profile.engineName)),
                _infoRow('Server', profile.remoteId != null ? 'Tersinkron #${profile.remoteId}' : 'Belum tersinkron'),
              ] else ...[
                _field(brandCtrl, 'Merek', Icons.directions_car),
                _field(modelCtrl, 'Model', Icons.car_repair),
                _field(yearCtrl, 'Tahun', Icons.calendar_today, keyboard: TextInputType.number),
                _field(nicknameCtrl, 'Nama panggilan', Icons.badge),
                _field(engineCtrl, 'Kode / tipe mesin', Icons.settings),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Profil'),
                )),
              ],
              if (hasVin) ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncToBackend,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text(_syncing ? 'Menyinkronkan...' : 'Sinkronkan ke Server'),
                )),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
