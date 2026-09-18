import 'dart:math' as math;
import 'package:geocoding/geocoding.dart';
import '../../models/geo_point.dart';
import '../../models/telemetry_data.dart';
import '../../models/trip_record.dart';
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

  Future<TripRecord?> stop() async {
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
    );

    _reset();
    return trip;
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
