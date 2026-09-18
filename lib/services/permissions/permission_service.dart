import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted) {
      throw Exception(
        'Izin Bluetooth (scan & connect) diperlukan untuk terhubung ke adaptor OBD-II.',
      );
    }
  }

  Future<void> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      throw Exception('Izin lokasi diperlukan untuk merekam rute GPS trip.');
    }
  }

  Future<void> requestBluetoothAndLocationPermissions() async {
    await requestBluetoothPermissions();
    await requestLocationPermission();
  }
}
