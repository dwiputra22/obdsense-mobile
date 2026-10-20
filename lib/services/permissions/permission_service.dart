import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:permission_handler/permission_handler.dart';

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.bluetooth,
    required this.location,
    required this.notification,
    required this.anyPermanentlyDenied,
  });

  final bool bluetooth;
  final bool location;
  final bool notification;

  final bool anyPermanentlyDenied;

  bool get allGranted => bluetooth && location && notification;
}

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

  List<Permission> get _bluetoothPermissions => defaultTargetPlatform == TargetPlatform.iOS
      ? [Permission.bluetooth]
      : [Permission.bluetoothScan, Permission.bluetoothConnect];

  bool _ok(PermissionStatus s) => s.isGranted || s.isLimited;

  Future<PermissionSnapshot> checkAll() async {
    final btStatuses = [for (final p in _bluetoothPermissions) await p.status];
    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;

    return PermissionSnapshot(
      bluetooth: btStatuses.every(_ok),
      location: _ok(location),
      notification: _ok(notification),
      anyPermanentlyDenied: btStatuses.any((s) => s.isPermanentlyDenied) ||
          location.isPermanentlyDenied ||
          notification.isPermanentlyDenied,
    );
  }

  Future<PermissionSnapshot> requestAll() async {
    await [
      ..._bluetoothPermissions,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
    return checkAll();
  }

  Future<bool> openSettings() => openAppSettings();
}
