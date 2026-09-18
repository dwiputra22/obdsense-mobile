import 'dart:math' as math;
import 'package:geocoding/geocoding.dart';
import '../../models/geo_point.dart';
import '../../models/health_event.dart';
import '../../models/telemetry_data.dart';
import '../../models/trip_record.dart';
import '../intelligence/anomaly_detector.dart';
import '../intelligence/vehicle_baseline_service.dart';
import 'eco_driving_scorer.dart';
import 'fuel_efficiency_calculator.dart';

class TripRecorderService {
  final List<TelemetryData> _buffer = [];
  final List<GeoPoint> _route = [];
  DateTime? _startTime;

  bool get isRecording => _startTime != null;

  void start() {
    _buffer.clear();
    _route.clear();
    _startTime = DateTime.now();
  }

  void addSample(TelemetryData data) {
    if (_startTime == null) return;
    _buffer.add(data);
  }

  void addLocationPoint(GeoPoint point) {
    if (_startTime == null) return;
    _route.add(point);
  }

  Future<TripRecord?> stop({String? vin, VehicleBaselineService? baselineService}) async {
    if (_startTime == null || _buffer.isEmpty) {
      _reset();
      return null;
    }

    final endTime = DateTime.now();

    final avgSpeed =
        _buffer.map((e) => e.speed).reduce((a, b) => a + b) / _buffer.length;
    final maxSpeed =
        _buffer.map((e) => e.speed).reduce((a, b) => a > b ? a : b);
    final avgCoolant =
        _buffer.map((e) => e.coolantTempC).reduce((a, b) => a + b) / _buffer.length;
    final maxCoolant =
        _buffer.map((e) => e.coolantTempC).reduce((a, b) => a > b ? a : b);

    final route = List<GeoPoint>.from(_route);
    final distanceKm = _calculateDistanceKm(route);

    final fuelRates = _buffer.map((e) => e.fuelRateLph).toList();
    final fuelUsedLiters =
        FuelEfficiencyCalculator.integrateFuelUsed(fuelRates, const Duration(seconds: 2));
    final avgFuelConsumption =
        distanceKm > 0 ? (fuelUsedLiters / distanceKm) * 100 : 0.0;
    final ecoScore = EcoDrivingScorer.score(_buffer);

    final healthEvents = (vin != null && baselineService != null)
        ? _computeHealthEvents(vin, baselineService, route)
        : <HealthEvent>[];

    String? startAddress;
    String? endAddress;
    if (route.isNotEmpty) {
      startAddress = await _reverseGeocode(route.first);
      endAddress = await _reverseGeocode(route.last);
    }

    final trip = TripRecord(
      startTime: _startTime!,
      endTime: endTime,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      avgCoolantTempC: avgCoolant,
      maxCoolantTempC: maxCoolant,
      distanceKm: distanceKm,
      startAddress: startAddress,
      endAddress: endAddress,
      route: route,
      fuelUsedLiters: fuelUsedLiters,
      avgFuelConsumptionL100km: avgFuelConsumption,
      ecoScore: ecoScore,
      healthEvents: healthEvents,
    );

    _reset();
    return trip;
  }

  List<HealthEvent> _computeHealthEvents(
    String vin,
    VehicleBaselineService baselineService,
    List<GeoPoint> route,
  ) {
    final events = <HealthEvent>[];
    for (final point in route) {
      if (point.recordedAt == null) continue;
      final nearest = _nearestSample(point.recordedAt!);
      if (nearest == null) continue;

      final anomalies = AnomalyDetector.detect(vin, nearest, baselineService);
      for (final a in anomalies) {
        events.add(HealthEvent(
          lat: point.lat,
          lng: point.lng,
          sensorLabel: a.label,
          severity: a.severity,
        ));
      }
    }
    return events;
  }

  TelemetryData? _nearestSample(DateTime at) {
    if (_buffer.isEmpty) return null;
    TelemetryData best = _buffer.first;
    Duration bestDiff = (best.timestamp.difference(at)).abs();
    for (final s in _buffer) {
      final diff = (s.timestamp.difference(at)).abs();
      if (diff < bestDiff) {
        best = s;
        bestDiff = diff;
      }
    }
    // Kalau sample terdekat tetap >30 detik jauhnya, anggap tidak ada
    // data yang cukup relevan untuk titik ini.
    return bestDiff.inSeconds <= 30 ? best : null;
  }

  void _reset() {
    _startTime = null;
    _buffer.clear();
    _route.clear();
  }

  Future<String?> _reverseGeocode(GeoPoint point) async {
    try {
      final placemarks = await placemarkFromCoordinates(point.lat, point.lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.trim().isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  double _calculateDistanceKm(List<GeoPoint> route) {
    if (route.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < route.length - 1; i++) {
      total += _haversineKm(route[i], route[i + 1]);
    }
    return total;
  }

  double _haversineKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.lat - a.lat);
    final dLng = _degToRad(b.lng - a.lng);
    final lat1 = _degToRad(a.lat);
    final lat2 = _degToRad(b.lat);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);
}
