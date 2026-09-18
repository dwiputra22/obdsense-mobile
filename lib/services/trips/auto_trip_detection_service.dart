import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class AutoTripDetectionService {
  static const _startThresholdKmh = 10.0;
  static const _stopThresholdKmh = 2.0;
  static const _sustainToStart = Duration(seconds: 15);
  static const _sustainToStop = Duration(minutes: 3);

  StreamSubscription<Position>? _sub;
  Timer? _startTimer;
  Timer? _stopTimer;
  bool _isDriving = false;

  final VoidCallback onDriveDetectedStart;
  final VoidCallback onDriveDetectedStop;

  AutoTripDetectionService({
    required this.onDriveDetectedStart,
    required this.onDriveDetectedStop,
  });

  Future<void> start() async {
    if (_sub != null) return; // sudah jalan

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // biarkan gagal senyap - fitur ini opsional, jangan ganggu UX lain
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 20,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    final speedKmh = position.speed * 3.6; // Geolocator kasih speed dalam m/s

    if (!_isDriving) {
      if (speedKmh >= _startThresholdKmh) {
        _startTimer ??= Timer(_sustainToStart, () {
          _isDriving = true;
          onDriveDetectedStart();
        });
      } else {
        _startTimer?.cancel();
        _startTimer = null;
      }
    } else {
      if (speedKmh <= _stopThresholdKmh) {
        _stopTimer ??= Timer(_sustainToStop, () {
          _isDriving = false;
          onDriveDetectedStop();
        });
      } else {
        _stopTimer?.cancel();
        _stopTimer = null;
      }
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _startTimer?.cancel();
    _stopTimer?.cancel();
    _startTimer = null;
    _stopTimer = null;
    _isDriving = false;
  }

  void dispose() {
    _sub?.cancel();
    _startTimer?.cancel();
    _stopTimer?.cancel();
  }
}
