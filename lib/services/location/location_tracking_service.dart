import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/geo_point.dart';
import '../permissions/permission_service.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _sub;
  final StreamController<GeoPoint> _controller = StreamController.broadcast();
  final PermissionService _permissions = PermissionService();

  Stream<GeoPoint> get points => _controller.stream;

  Future<bool> ensurePermission() async {
    try {
      await _permissions.requestLocationPermission();
    } catch (_) {
      return false;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  Future<void> start() async {
    final granted = await ensurePermission();
    if (!granted) return;

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen((pos) {
      _controller.add(GeoPoint(lat: pos.latitude, lng: pos.longitude, recordedAt: DateTime.now()));
    });
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Merekam trip',
          notificationText: 'RushSense AI sedang merekam rute perjalanan Anda',
          enableWakeLock: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
