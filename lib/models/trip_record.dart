import 'geo_point.dart';

class TripRecord {
  final int? remoteId;
  final DateTime startTime;
  final DateTime endTime;
  final double avgSpeed;
  final double maxSpeed;
  final double avgCoolantTempC;
  final double maxCoolantTempC;
  final double distanceKm;
  final String? startAddress;
  final String? endAddress;
  final List<GeoPoint> route;
  final double fuelUsedLiters;
  final double avgFuelConsumptionL100km;
  final int ecoScore;

  const TripRecord({
    this.remoteId,
    required this.startTime,
    required this.endTime,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.avgCoolantTempC,
    required this.maxCoolantTempC,
    this.distanceKm = 0,
    this.startAddress,
    this.endAddress,
    this.route = const [],
    this.fuelUsedLiters = 0,
    this.avgFuelConsumptionL100km = 0,
    this.ecoScore = 100,
  });

  Map<String, dynamic> toJson() {
    return {
      'remoteId': remoteId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'avgCoolantTempC': avgCoolantTempC,
      'maxCoolantTempC': maxCoolantTempC,
      'distanceKm': distanceKm,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'route': route.map((p) => p.toJson()).toList(),
      'fuelUsedLiters': fuelUsedLiters,
      'avgFuelConsumptionL100km': avgFuelConsumptionL100km,
      'ecoScore': ecoScore,
    };
  }

  factory TripRecord.fromJson(Map<dynamic, dynamic> json) {
    return TripRecord(
      remoteId: json['remoteId'] as int?,
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      avgSpeed: (json['avgSpeed'] as num).toDouble(),
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      avgCoolantTempC: (json['avgCoolantTempC'] as num).toDouble(),
      maxCoolantTempC: (json['maxCoolantTempC'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      route: json['route'] == null
          ? const []
          : (json['route'] as List)
              .map((e) => GeoPoint.fromJson(Map<dynamic, dynamic>.from(e)))
              .toList(),
      fuelUsedLiters: (json['fuelUsedLiters'] as num?)?.toDouble() ?? 0,
      avgFuelConsumptionL100km: (json['avgFuelConsumptionL100km'] as num?)?.toDouble() ?? 0,
      ecoScore: (json['ecoScore'] as num?)?.toInt() ?? 100,
    );
  }

  TripRecord copyWith({int? remoteId}) {
    return TripRecord(
      remoteId: remoteId ?? this.remoteId,
      startTime: startTime,
      endTime: endTime,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      avgCoolantTempC: avgCoolantTempC,
      maxCoolantTempC: maxCoolantTempC,
      distanceKm: distanceKm,
      startAddress: startAddress,
      endAddress: endAddress,
      route: route,
      fuelUsedLiters: fuelUsedLiters,
      avgFuelConsumptionL100km: avgFuelConsumptionL100km,
      ecoScore: ecoScore,
    );
  }
}
