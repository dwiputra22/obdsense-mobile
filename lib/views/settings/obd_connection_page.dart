import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../core/i18n/tr_text.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/obd/bluetooth_elm_transport.dart';
import '../../services/obd/i_obd_transport.dart';
import '../../services/obd/obd_transport_type.dart';
import '../../services/obd/usb_elm_transport.dart';
import '../../services/obd/wifi_elm_transport.dart';
import '../../services/permissions/permission_service.dart';
import '../../core/motion/motion.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_kit.dart';
import '../../providers/app_providers.dart';
import '../../providers/auto_trip_settings_provider.dart';
import '../../core/i18n/translations.dart';

class ObdConnectionPage extends ConsumerStatefulWidget {
  const ObdConnectionPage({super.key});

  @override
  ConsumerState<ObdConnectionPage> createState() => _ObdConnectionPageState();
}

class _ObdConnectionPageState extends ConsumerState<ObdConnectionPage> {
  ObdTransportType selectedType = ObdTransportType.bluetooth;
  List<ScanResult> bluetoothResults = [];
  List<String> usbPorts = [];
  bool loading = false;
  String status = 'Pilih metode koneksi, lalu lakukan scan.';
  StreamSubscription<List<ScanResult>>? _scanSub;

  final wifiHostController = TextEditingController(text: '192.168.0.10');
  final wifiPortController = TextEditingController(text: '35000');
  final PermissionService _permissions = PermissionService();

  @override
  void dispose() {
    _scanSub?.cancel();
    wifiHostController.dispose();
    wifiPortController.dispose();
    super.dispose();
  }

  String _deviceName(ScanResult result) {
    final advertised = result.advertisementData.advName.trim();
    if (advertised.isNotEmpty) return advertised;

    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;

    final deviceAdv = result.device.advName.trim();
    if (deviceAdv.isNotEmpty) return deviceAdv;

    return 'Perangkat Bluetooth';
  }

  String _friendlyError(Object error, {String fallback = 'Operasi gagal. Coba lagi.'}) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission')) return 'Izin Bluetooth belum diberikan. Aktifkan izin lalu coba lagi.';
    if (raw.contains('bluetooth') && raw.contains('off')) return 'Bluetooth sedang mati. Nyalakan Bluetooth lalu scan lagi.';
    if (raw.contains('timeout')) return 'Perangkat tidak merespons dalam batas waktu.';
    if (raw.contains('socket') || raw.contains('connection')) return 'Koneksi ke adapter gagal. Periksa adapter, host, port, atau jarak perangkat.';
    return fallback;
  }

  Future<void> scanBluetooth() async {
    if (loading) return;
    setState(() {
      loading = true;
      bluetoothResults = [];
      status = 'Memindai Bluetooth... perangkat yang ditemukan akan muncul di bawah.';
    });

    try {
      await _permissions.requestBluetoothPermissions();
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth tidak didukung perangkat ini');
      }

      await _scanSub?.cancel();
      await FlutterBluePlus.stopScan();

      final seen = <String, ScanResult>{};
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          seen[result.device.remoteId.str] = result;
        }
        if (mounted) {
          setState(() {
            bluetoothResults = seen.values.toList()
              ..sort((a, b) => b.rssi.compareTo(a.rssi));
            status = bluetoothResults.isEmpty
                ? 'Sedang mencari perangkat...'
                : '${bluetoothResults.length} perangkat ditemukan';
          });
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 7));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

      if (mounted) {
        setState(() {
          status = bluetoothResults.isEmpty
              ? 'Tidak ada perangkat Bluetooth ditemukan. Pastikan adapter OBD aktif dan dekat dengan ponsel.'
              : 'Scan selesai • ${bluetoothResults.length} perangkat ditemukan';
        });
      }
    } catch (e) {
      await _scanSub?.cancel();
      _scanSub = null;
      if (mounted) setState(() => status = _friendlyError(e, fallback: 'Scan Bluetooth gagal. Periksa Bluetooth dan izin aplikasi.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> connectBluetooth(BluetoothDevice device) async {
    if (loading) return;
    setState(() {
      loading = true;
      status = 'Menghubungkan ke ${device.platformName.isEmpty ? device.remoteId.str : device.platformName}...';
    });
    try {
      await _connectTransport(BluetoothElmTransport(device));
      if (mounted) setState(() => status = 'Bluetooth OBD terhubung dan siap digunakan.');
    } catch (e) {
      if (mounted) setState(() => status = _friendlyError(e, fallback: 'Gagal menghubungkan Bluetooth OBD.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> connectWifi() async {
    final host = wifiHostController.text.trim();
    final port = int.tryParse(wifiPortController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => status = 'Host dan port Wi-Fi belum valid.');
      return;
    }
    if (loading) return;
    setState(() {
      loading = true;
      status = 'Menguji koneksi Wi-Fi OBD ke $host:$port...';
    });
    try {
      await _connectTransport(WifiElmTransport(host: host, port: port));
      if (mounted) setState(() => status = 'Wi-Fi OBD terhubung dan siap digunakan.');
    } catch (e) {
      if (mounted) setState(() => status = _friendlyError(e, fallback: 'Wi-Fi OBD tidak dapat dihubungkan.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> scanUsb() async {
    if (loading) return;
    setState(() {
      loading = true;
      usbPorts = [];
      status = 'Memindai port USB/OTG...';
    });

    try {
      final foundPorts = await UsbElmTransport.listPorts();
      if (mounted) {
        setState(() {
          usbPorts = foundPorts.map((port) => port.path).toList();
          status = foundPorts.isEmpty
              ? 'Tidak ada adapter USB/OTG ditemukan. Pastikan kabel OTG dan adapter tersambung.'
              : 'Scan selesai • ${foundPorts.length} port ditemukan';
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = _friendlyError(e, fallback: 'Scan USB/OTG gagal. Periksa kabel OTG dan izin perangkat.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> connectUsb(String portEntry) async {
    if (loading) return;
    setState(() {
      loading = true;
      status = 'Menghubungkan adapter USB...';
    });

    try {
      final portName = portEntry.split(' - ').first;
      await _connectTransport(UsbElmTransport(portName));
      if (mounted) setState(() => status = 'USB/OTG OBD terhubung dan siap digunakan.');
    } catch (e) {
      if (mounted) setState(() => status = _friendlyError(e, fallback: 'Gagal menghubungkan USB/OTG OBD.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _connectTransport(IObdTransport transport) async {
    ref.read(obdTransportProvider.notifier).state = transport;

    final manager = ref.read(obdConnectionManagerProvider);
    if (manager == null) throw Exception('Connection manager tidak tersedia');
    await manager.connect();

    final obd = ref.read(obdProvider);
    if (obd != null) {
      manager.startAutoReconnect();
      await obd.initializeAdapter();
      obd.startPolling();
    }

    await _maybeAutoStartTrip();
  }

  Future<void> _maybeAutoStartTrip() async {
    final settings = ref.read(autoTripSettingsProvider);
    if (!settings.autoStartOnObdConnect) return;

    final recorder = ref.read(tripRecorderProvider);
    if (recorder.isRecording) return;

    await ref.read(tripControllerProvider.notifier).startTrip();
  }

  static const _types = [ObdTransportType.bluetooth, ObdTransportType.wifi, ObdTransportType.usb];
  static const _typeTitles = ['Bluetooth', 'Wi-Fi', 'USB'];

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return AppColors.green;
    if (rssi >= -80) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(obdConnectionManagerProvider)?.isConnected == true;
    final palette = context.palette;
    final typeIndex = _types.indexOf(selectedType);

    return AppPage(
      title: 'Koneksi OBD-II',
      subtitle: connected ? 'Adapter tersambung' : 'Hubungkan adapter ELM327',
      children: [
        Reveal(
          index: 1,
          child: GlassCard(
            color: connected ? palette.primary : null,
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (connected)
                      const PulseDot(color: AppColors.green)
                    else
                      const IconBubble(icon: Icons.link_off_rounded, color: AppColors.orange, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        connected ? 'OBD terhubung' : 'Belum terhubung',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: connected ? palette.onPrimary.withValues(alpha: 0.8) : palette.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          index: 2,
          child: PillTabs(
            labels: _typeTitles,
            index: typeIndex < 0 ? 0 : typeIndex,
            onChanged: (i) => setState(() {
              selectedType = _types[i];
              status = 'Siap ${_typeTitles[i].toLowerCase()} scan.';
            }),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: switch (selectedType) {
            ObdTransportType.bluetooth => _bluetoothPanel(),
            ObdTransportType.wifi => _wifiPanel(),
            ObdTransportType.usb => _usbPanel(),
          },
        )),
      ],
    );
  }

  Widget _bluetoothPanel() => Column(
        key: const ValueKey('bt'),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : scanBluetooth,
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: Text(loading ? 'Memindai…' : 'Scan Bluetooth'),
            ),
          ),
          const SizedBox(height: 12),
          if (bluetoothResults.isEmpty)
            const NoticeCard(icon: Icons.bluetooth_rounded, text: 'Belum ada hasil. Tekan Scan Bluetooth, lalu tunggu sampai proses selesai.'),
          ...bluetoothResults.map(
            (result) => Padding(
              key: ValueKey(result.device.remoteId.str),
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 22,
                child: Row(
                  children: [
                    const IconBubble(icon: Icons.bluetooth_rounded, color: AppColors.blue, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_deviceName(result), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              StatusChip(text: '${result.rssi} dBm', color: _rssiColor(result.rssi)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(result.device.remoteId.str, style: TextStyle(color: context.palette.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
                      onPressed: loading ? null : () => connectBluetooth(result.device),
                      child: const Text('Hubungkan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _wifiPanel() => GlassCard(
        key: const ValueKey('wifi'),
        child: Column(
          children: [
            TextField(
              controller: wifiHostController,
              decoration: InputDecoration(
                labelText: tr('Host Wi-Fi OBD'),
                prefixIcon: Icon(Icons.wifi_rounded),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wifiPortController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Port'),
                prefixIcon: Icon(Icons.settings_ethernet_rounded),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : connectWifi,
                icon: const Icon(Icons.link_rounded),
                label: Text(loading ? 'Menguji koneksi…' : 'Uji & hubungkan Wi-Fi'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Wi-Fi OBD umumnya tidak menyediakan daftar perangkat seperti Bluetooth. Aplikasi akan menguji host:port yang diberikan.',
              style: TextStyle(fontSize: 11.5, color: context.palette.muted, height: 1.35),
            ),
          ],
        ),
      );

  Widget _usbPanel() => Column(
        key: const ValueKey('usb'),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : scanUsb,
              icon: const Icon(Icons.usb_rounded),
              label: Text(loading ? 'Memindai…' : 'Scan USB / OTG'),
            ),
          ),
          const SizedBox(height: 12),
          if (usbPorts.isEmpty)
            const NoticeCard(icon: Icons.usb_rounded, text: 'Belum ada port USB ditemukan. Sambungkan adapter melalui OTG lalu scan.'),
          ...usbPorts.map(
            (port) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 22,
                child: Row(
                  children: [
                    const IconBubble(icon: Icons.usb_rounded, color: AppColors.purple, size: 42),
                    const SizedBox(width: 12),
                    Expanded(child: Text(port, style: const TextStyle(fontWeight: FontWeight.w700))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
                      onPressed: loading ? null : () => connectUsb(port),
                      child: const Text('Hubungkan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}