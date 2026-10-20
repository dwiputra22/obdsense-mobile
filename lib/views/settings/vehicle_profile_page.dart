import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/obd/ecu_info_service.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';
import '../../core/i18n/translations.dart';

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
  late TextEditingController vinCtrl;

  bool _editing = false;
  bool _syncing = false;
  bool _scanningVin = false;
  bool _showManualVinInput = false;
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
    vinCtrl = TextEditingController(text: _profile!.vin ?? '');
  }

  @override
  void dispose() {
    brandCtrl.dispose();
    modelCtrl.dispose();
    yearCtrl.dispose();
    nicknameCtrl.dispose();
    engineCtrl.dispose();
    vinCtrl.dispose();
    super.dispose();
  }

  bool get _obdConnected => ref.watch(obdConnectedProvider);

  Future<void> _save() async {
    final updated = VehicleProfile(
      vin: vinCtrl.text.trim().isEmpty ? _profile?.vin : vinCtrl.text.trim().toUpperCase(),
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
        if (mounted) setState(() => _showManualVinInput = true);
        _showMessage('VIN tidak tersedia dari ECU. Silakan masukkan VIN secara manual.');
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
      if (mounted) {
        setState(() { _profile = updated; vinCtrl.text = info.vin!.trim().toUpperCase(); _showManualVinInput = false; });
      }
      _showMessage('VIN terdeteksi: ${info.vin}');
    } catch (_) {
      if (mounted) setState(() => _showManualVinInput = true);
      _showMessage('Scan VIN gagal. Anda bisa memasukkan VIN secara manual.');
    } finally {
      if (mounted) setState(() => _scanningVin = false);
    }
  }

  Future<void> _saveManualVin() async {
    final vin = vinCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (vin.length != 17 || RegExp(r'[IOQ]').hasMatch(vin)) {
      _showMessage('VIN harus terdiri dari 17 karakter dan tidak boleh mengandung I, O, atau Q.');
      return;
    }
    final storage = ref.read(localStorageProvider);
    final check = await storage.checkVinAgainstStored(vin);
    if (!check.matches && check.previousVin != null && mounted) {
      final proceed = await _confirmVinMismatch(check.previousVin!, vin);
      if (proceed != true) return;
    }
    final updated = _profile!.copyWith(vin: vin);
    await storage.saveVehicleProfile(updated);
    ref.invalidate(vehicleProfileProvider);
    if (mounted) setState(() { _profile = updated; vinCtrl.text = vin; _showManualVinInput = false; });
    _showMessage('VIN berhasil disimpan.');
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

    return AppPage(
      title: 'Vehicle Profile',
      subtitle: 'Identitas kendaraan Anda',
      trailing: RoundIconButton(
        icon: _editing ? Icons.close_rounded : Icons.edit_rounded,
        tooltip: _editing ? 'Batal' : 'Ubah',
        onTap: () => setState(() => _editing = !_editing),
      ),
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: hasVin ? palette.primary : null,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    hasVin
                        ? Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.onPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.verified_rounded, color: palette.onPrimary),
                    )
                        : const IconBubble(icon: Icons.info_outline_rounded, color: AppColors.orange, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasVin ? 'VIN terdeteksi' : 'VIN belum terdeteksi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: hasVin ? palette.onPrimary.withValues(alpha: 0.75) : palette.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasVin ? profile.vin! : 'Scan dari OBD-II',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'VIN dibaca dari ECU melalui OBD-II. Hubungkan adaptor terlebih dahulu.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasVin ? palette.onPrimary.withValues(alpha: 0.7) : palette.muted,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: hasVin
                        ? ElevatedButton.styleFrom(backgroundColor: palette.onPrimary, foregroundColor: palette.primary)
                        : null,
                    onPressed: (!_obdConnected || _scanningVin) ? null : _scanVin,
                    icon: _scanningVin
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: hasVin ? palette.primary : palette.onPrimary))
                        : const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(_scanningVin ? 'Membaca VIN…' : (_obdConnected ? 'Scan VIN dari OBD' : 'Hubungkan OBD untuk scan VIN')),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _showManualVinInput = !_showManualVinInput),
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: Text(_showManualVinInput ? 'Tutup input VIN manual' : 'Input VIN secara manual'),
                ),
                if (_showManualVinInput) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: vinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 17,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'VIN kendaraan',
                      hintText: 'Contoh: 1HGCM82633A004352',
                      prefixIcon: Icon(Icons.directions_car_filled_outlined),
                      helperText: 'Masukkan 17 karakter VIN pada STNK atau bodi kendaraan.',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveManualVin,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan VIN manual'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 2,
          child: GlassCard(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profil kendaraan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  if (!_editing) ...[
                    _infoRow(Icons.directions_car_rounded, 'Merek', _value(profile.brand)),
                    _infoRow(Icons.car_repair_rounded, 'Model', _value(profile.model)),
                    _infoRow(Icons.calendar_today_rounded, 'Tahun', profile.year > 0 ? '${profile.year}' : 'Belum diisi'),
                    _infoRow(Icons.badge_rounded, 'Nama panggilan', _value(profile.nickname)),
                    _infoRow(Icons.settings_rounded, 'Mesin', _value(profile.engineName)),
                    _infoRow(
                      profile.remoteId != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      'Server',
                      profile.remoteId != null ? 'Tersinkron #${profile.remoteId}' : 'Belum tersinkron',
                    ),
                  ] else ...[
                    _field(brandCtrl, 'Merek', Icons.directions_car_rounded),
                    _field(modelCtrl, 'Model', Icons.car_repair_rounded),
                    _field(yearCtrl, 'Tahun', Icons.calendar_today_rounded, keyboard: TextInputType.number),
                    _field(nicknameCtrl, 'Nama panggilan', Icons.badge_rounded),
                    _field(engineCtrl, 'Kode / tipe mesin', Icons.settings_rounded),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Simpan profil'),
                      ),
                    ),
                  ],
                  if (hasVin) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _syncing ? null : _syncToBackend,
                        icon: _syncing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(_syncing ? 'Menyinkronkan…' : 'Sinkronkan ke server'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
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
          labelText: tr(label),
          prefixIcon: Icon(icon, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconBubble(icon: icon, color: AppColors.cyan, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: palette.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}