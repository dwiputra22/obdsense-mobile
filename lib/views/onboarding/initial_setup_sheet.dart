import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import '../../core/i18n/translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/permissions/permission_service.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/vehicle_form.dart';
import '../../core/constants/app_constants.dart';

const _vinDeferredKey = 'setup_vin_deferred';

bool _vehicleDataMissing(VehicleProfile p, {required bool vinDeferred}) {
  if (p.brand.trim().isEmpty || p.model.trim().isEmpty || p.year <= 0) return true;
  if (!vinDeferred && (p.vin == null || p.vin!.trim().isEmpty)) return true;
  return false;
}

Future<void> showInitialSetupIfNeeded(BuildContext context, WidgetRef ref) async {
  final perms = await PermissionService().checkAll();
  final prefs = await SharedPreferences.getInstance();
  final vinDeferred = prefs.getBool(_vinDeferredKey) ?? false;
  final profile = ref.read(localStorageProvider).getVehicleProfile() ??
      const VehicleProfile(brand: '', model: '', year: 0, nickname: '', engineName: '');

  final needPerms = !perms.allGranted;
  final needVehicle = _vehicleDataMissing(profile, vinDeferred: vinDeferred);
  if (!needPerms && !needVehicle) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: context.palette.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _InitialSetupSheet(),
  );
}

class _InitialSetupSheet extends ConsumerStatefulWidget {
  const _InitialSetupSheet();

  @override
  ConsumerState<_InitialSetupSheet> createState() => _InitialSetupSheetState();
}

class _InitialSetupSheetState extends ConsumerState<_InitialSetupSheet> with WidgetsBindingObserver {
  final _permissions = PermissionService();

  late final VehicleFormController _form;
  late final TextEditingController _vin;

  PermissionSnapshot? _perms;
  bool _vinDeferred = false;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  late VehicleProfile _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _existing = ref.read(localStorageProvider).getVehicleProfile() ??
        const VehicleProfile(brand: '', model: '', year: 0, nickname: '', engineName: '');
    _form = VehicleFormController(_existing);
    _vin = TextEditingController(text: _existing.vin ?? '');
    _load();
  }

  Future<void> _load() async {
    final perms = await _permissions.checkAll();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _perms = perms;
      _vinDeferred = prefs.getBool(_vinDeferredKey) ?? false;
      _loaded = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pengguna kembali dari Pengaturan sistem: segarkan status izin.
    if (state == AppLifecycleState.resumed) _refreshPerms();
  }

  Future<void> _refreshPerms() async {
    final perms = await _permissions.checkAll();
    if (mounted) setState(() => _perms = perms);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _form.dispose();
    _vin.dispose();
    super.dispose();
  }

  bool get _needPerms => !(_perms?.allGranted ?? true);

  bool get _needVehicle => _vehicleDataMissing(_existing, vinDeferred: _vinDeferred);

  String _normalizedVin() => _vin.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String? _validateVehicle() {
    final error = _form.validate();
    if (error != null) return error;
    final vin = _normalizedVin();
    if (vin.isNotEmpty && (vin.length != 17 || RegExp(r'[IOQ]').hasMatch(vin))) {
      return 'VIN harus 17 karakter dan tidak boleh mengandung huruf I, O, atau Q.';
    }
    return null;
  }

  Future<void> _saveVehicle() async {
    final vin = _normalizedVin();
    final updated = _form.toProfile(_existing, vin: vin.isEmpty ? _existing.vin : vin);
    await ref.read(localStorageProvider).saveVehicleProfile(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vinDeferredKey, updated.vin == null || updated.vin!.isEmpty);
    ref.invalidate(vehicleProfileProvider);
    _existing = updated;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    if (_needVehicle) {
      final error = _validateVehicle();
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_needVehicle) await _saveVehicle();
      if (_needPerms) {
        final perms = await _permissions.requestAll();
        if (mounted) setState(() => _perms = perms);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final permsIncomplete = _perms?.allGranted == false;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(permsIncomplete
              ? 'Data tersimpan. Beberapa izin belum aktif, fitur terkait mungkin terbatas.'
              : 'Siap! Hubungkan adapter OBD-II untuk mulai.'),
        ));
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: !_loaded
          ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBubble(icon: Icons.rocket_launch_rounded, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Siapkan ${AppConstants.appName}',
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text('Beri izin dan isi data kendaraan agar fitur berjalan akurat.',
                                style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_needPerms) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('1. Izin aplikasi'),
                    const SizedBox(height: 10),
                    _permRow(Icons.bluetooth_rounded, 'Bluetooth', 'Mencari & terhubung ke adapter OBD-II', _perms!.bluetooth),
                    _permRow(Icons.location_on_rounded, 'Lokasi', 'Merekam rute perjalanan (GPS)', _perms!.location),
                    _permRow(Icons.notifications_rounded, 'Notifikasi', 'Peringatan suhu mesin & anomali', _perms!.notification),
                    if (_perms!.anyPermanentlyDenied)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton.icon(
                          onPressed: _permissions.openSettings,
                          icon: const Icon(Icons.settings_rounded, size: 18),
                          label: const Text('Buka Pengaturan untuk mengaktifkan izin'),
                        ),
                      ),
                  ],
                  if (_needVehicle) ...[
                    const SizedBox(height: 20),
                    _sectionLabel(_needPerms ? '2. Data kendaraan' : 'Data kendaraan'),
                    const SizedBox(height: 12),
                    VehicleFormFields(controller: _form, collapseTechnical: true),
                    TextField(
                      controller: _vin,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 17,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: tr('Nomor VIN'),
                        hintText: tr('17 karakter, ada di STNK / bodi kendaraan'),
                        helperText: tr('Boleh dikosongkan, VIN bisa dipindai dari OBD-II nanti.'),
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12.5, height: 1.3)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : const Icon(Icons.check_rounded),
                      label: Text(_ctaLabel()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: Text('Nanti saja', style: TextStyle(color: palette.muted)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _ctaLabel() {
    if (_busy) return 'Memproses…';
    if (_needVehicle && _needPerms) return 'Simpan & beri izin';
    if (_needVehicle) return 'Simpan data kendaraan';
    return 'Beri izin';
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: context.palette.muted),
      );

  Widget _permRow(IconData icon, String title, String subtitle, bool granted) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconBubble(icon: icon, color: granted ? AppColors.green : AppColors.orange, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Icon(
            granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: granted ? AppColors.green : palette.muted,
            size: 22,
          ),
        ],
      ),
    );
  }
}