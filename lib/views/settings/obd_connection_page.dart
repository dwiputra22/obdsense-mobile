import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/obd/bluetooth_elm_transport.dart';
import '../../services/obd/i_obd_transport.dart';
import '../../services/obd/obd_transport_type.dart';
import '../../services/obd/usb_elm_transport.dart';
import '../../services/obd/wifi_elm_transport.dart';
import '../../services/permissions/permission_service.dart';
import '../../widgets/glass_card.dart';
import '../../providers/app_providers.dart';
import '../../providers/auto_trip_settings_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(obdConnectionManagerProvider)?.isConnected == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Koneksi OBD-II')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(connected ? Icons.check_circle : Icons.info_outline, color: connected ? AppColors.green : AppColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(connected ? 'OBD terhubung' : 'Belum terhubung', style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 10),
          Text(status, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 14),
          const Text('Jenis Koneksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _radio(ObdTransportType.bluetooth, 'Bluetooth', 'Scan perangkat OBD di sekitar'),
          _radio(ObdTransportType.wifi, 'Wi-Fi', 'Gunakan host dan port adapter'),
          _radio(ObdTransportType.usb, 'USB / OTG', 'Scan port adapter yang tersambung kabel'),
        ])),
        const SizedBox(height: 14),
        if (selectedType == ObdTransportType.bluetooth) _bluetoothPanel(),
        if (selectedType == ObdTransportType.wifi) _wifiPanel(),
        if (selectedType == ObdTransportType.usb) _usbPanel(),
      ]),
    );
  }

  Widget _radio(ObdTransportType type, String title, String subtitle) => RadioListTile<ObdTransportType>(
    value: type, groupValue: selectedType, contentPadding: EdgeInsets.zero,
    onChanged: (v) { if (v != null) setState(() { selectedType = v; status = 'Siap ${title.toLowerCase()} scan.'; }); },
    title: Text(title), subtitle: Text(subtitle),
  );

  Widget _bluetoothPanel() => Column(children: [
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: loading ? null : scanBluetooth,
      icon: const Icon(Icons.bluetooth_searching),
      label: Text(loading ? 'Memindai...' : 'Scan Bluetooth'),
    )),
    const SizedBox(height: 12),
    if (bluetoothResults.isEmpty)
      const GlassCard(child: Text('Belum ada hasil. Tekan Scan Bluetooth, lalu tunggu sampai proses selesai.')),
    ...bluetoothResults.map((result) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(child: Row(children: [
        const Icon(Icons.bluetooth, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_deviceName(result), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${result.device.remoteId.str}  •  RSSI ${result.rssi} dBm', style: const TextStyle(fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: loading ? null : () => connectBluetooth(result.device), child: const Text('Hubungkan')),
      ])),
    )),
  ]);

  Widget _wifiPanel() => GlassCard(child: Column(children: [
    TextField(controller: wifiHostController, decoration: const InputDecoration(labelText: 'Host Wi-Fi OBD', prefixIcon: Icon(Icons.wifi), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16))),
    const SizedBox(height: 12),
    TextField(controller: wifiPortController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port', prefixIcon: Icon(Icons.settings_ethernet), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16))),
    const SizedBox(height: 14),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: loading ? null : connectWifi, icon: const Icon(Icons.link), label: Text(loading ? 'Menguji koneksi...' : 'Uji & Hubungkan Wi-Fi'))),
    const SizedBox(height: 8),
    const Text('Wi-Fi OBD umumnya tidak menyediakan daftar perangkat seperti Bluetooth. Aplikasi akan menguji host:port yang diberikan.', style: TextStyle(fontSize: 11)),
  ]));

  Widget _usbPanel() => Column(children: [
    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: loading ? null : scanUsb, icon: const Icon(Icons.usb), label: Text(loading ? 'Memindai...' : 'Scan USB / OTG'))),
    const SizedBox(height: 12),
    if (usbPorts.isEmpty) const GlassCard(child: Text('Belum ada port USB ditemukan. Sambungkan adapter melalui OTG lalu scan.')),
    ...usbPorts.map((port) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          child: Row(children: [
            const Icon(Icons.usb, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(port, style: const TextStyle(fontWeight: FontWeight.w600))),
            ElevatedButton(onPressed: loading ? null : () => connectUsb(port), child: const Text('Hubungkan')),
          ]),
        ),
      );
    }),
  ]);
}
