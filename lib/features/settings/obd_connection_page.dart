import 'package:flserial/serial_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  List<BluetoothDevice> devices = [];
  List<String> usbPorts = [];
  bool loading = false;
  String status = 'Belum terhubung';

  final wifiHostController = TextEditingController(text: '192.168.0.10');
  final wifiPortController = TextEditingController(text: '35000');
  final PermissionService _permissions = PermissionService();

  Future<void> scanBluetooth() async {
    setState(() {
      loading = true;
      status = 'Memindai perangkat Bluetooth...';
    });

    try {
      await _permissions.requestBluetoothPermissions();

      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      final found = <BluetoothDevice>[];
      await for (final results in FlutterBluePlus.scanResults) {
        for (final r in results) {
          final exists = found.any((e) => e.remoteId.str == r.device.remoteId.str);
          if (!exists) found.add(r.device);
        }
        break;
      }

      await FlutterBluePlus.stopScan();

      setState(() {
        devices = found;
        status = 'Scan selesai';
      });
    } catch (e) {
      setState(() {
        status = 'Scan gagal: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> connectBluetooth(BluetoothDevice device) async {
    setState(() {
      loading = true;
      status = 'Menghubungkan Bluetooth...';
    });

    try {
      final transport = BluetoothElmTransport(device);
      await _connectTransport(transport);

      setState(() {
        status = 'Bluetooth OBD terhubung';
      });
    } catch (e) {
      setState(() {
        status = 'Gagal konek Bluetooth: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> connectWifi() async {
    setState(() {
      loading = true;
      status = 'Menghubungkan Wi-Fi OBD...';
    });

    try {
      final transport = WifiElmTransport(
        host: wifiHostController.text.trim(),
        port: int.tryParse(wifiPortController.text.trim()) ?? 35000,
      );
      await _connectTransport(transport);

      setState(() {
        status = 'Wi-Fi OBD terhubung';
      });
    } catch (e) {
      setState(() {
        status = 'Gagal konek Wi-Fi: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> scanUsb() async {
    setState(() {
      loading = true;
      status = 'Memindai perangkat USB...';
    });

    try {
      final List<SerialPortInfo> foundPorts = await UsbElmTransport.listPorts();

      setState(() {
        usbPorts = foundPorts.map((port) => port.path).toList();

        status = foundPorts.isEmpty
            ? 'Tidak ada adapter USB terdeteksi. Pastikan kabel OTG dan adapter tersambung.'
            : 'Scan selesai';
      });
    } catch (e) {
      setState(() {
        status = 'Scan USB gagal: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> connectUsb(String portEntry) async {
    setState(() {
      loading = true;
      status = 'Menghubungkan USB...';
    });

    try {
      final portName = portEntry.split(' - ').first;
      final transport = UsbElmTransport(portName);
      await _connectTransport(transport);

      setState(() {
        status = 'USB OBD terhubung';
      });
    } catch (e) {
      setState(() {
        status = 'Gagal konek USB: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _connectTransport(IObdTransport transport) async {
    ref.read(obdTransportProvider.notifier).state = transport;

    final manager = ref.read(obdConnectionManagerProvider);
    if (manager == null) {
      throw Exception('Gagal menyiapkan connection manager.');
    }
    await manager.connect();

    final obd = ref.read(obdProvider);
    if (obd != null) {
      manager.startAutoReconnect();
      await obd.initializeAdapter();
      obd.startPolling();
    }

    await _maybeAutoStartTrip();
  }

  /// Auto-mulai trip jika pengaturan otomatis aktif.
  Future<void> _maybeAutoStartTrip() async {
    final settings = ref.read(autoTripSettingsProvider);
    if (!settings.autoStartOnObdConnect) return;

    final recorder = ref.read(tripRecorderProvider);
    if (recorder.isRecording) return;

    await ref.read(tripControllerProvider.notifier).startTrip();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koneksi OBD-II'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jenis Koneksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                RadioListTile<ObdTransportType>(
                  value: ObdTransportType.bluetooth,
                  groupValue: selectedType,
                  onChanged: (v) {
                    if (v != null) setState(() => selectedType = v);
                  },
                  title: const Text('Bluetooth'),
                ),
                RadioListTile<ObdTransportType>(
                  value: ObdTransportType.wifi,
                  groupValue: selectedType,
                  onChanged: (v) {
                    if (v != null) setState(() => selectedType = v);
                  },
                  title: const Text('Wi-Fi'),
                ),
                RadioListTile<ObdTransportType>(
                  value: ObdTransportType.usb,
                  groupValue: selectedType,
                  onChanged: (v) {
                    if (v != null) setState(() => selectedType = v);
                  },
                  title: const Text('USB (kabel OTG)'),
                  subtitle: const Text('Backup kalau Bluetooth/Wi-Fi tidak stabil'),
                ),
                const SizedBox(height: 8),
                Text(status),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (selectedType == ObdTransportType.bluetooth) ...[
            ElevatedButton(
              onPressed: loading ? null : scanBluetooth,
              child: Text(loading ? 'Memproses...' : 'Scan Bluetooth'),
            ),
            const SizedBox(height: 16),
            ...devices.map(
                  (d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(d.platformName.isEmpty ? d.remoteId.str : d.platformName),
                      ),
                      ElevatedButton(
                        onPressed: loading ? null : () => connectBluetooth(d),
                        child: const Text('Hubungkan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (selectedType == ObdTransportType.wifi) ...[
            TextField(
              controller: wifiHostController,
              decoration: const InputDecoration(
                labelText: 'Host Wi-Fi OBD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wifiPortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : connectWifi,
              child: Text(loading ? 'Memproses...' : 'Hubungkan Wi-Fi'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: loading ? null : scanUsb,
              child: Text(loading ? 'Memproses...' : 'Scan USB'),
            ),
            const SizedBox(height: 16),
            ...usbPorts.map(
                  (portEntry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(portEntry)),
                      ElevatedButton(
                        onPressed: loading ? null : () => connectUsb(portEntry),
                        child: const Text('Hubungkan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
