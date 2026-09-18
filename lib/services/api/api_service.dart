import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../models/maintenance_record.dart';
import '../../models/telemetry_data.dart';
import '../../models/trip_record.dart';

class ApiService {
  final Dio dio;

  ApiService()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-API-Key': AppConstants.deviceApiKey,
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  Future<void> sendTelemetry(int vehicleId, TelemetryData data) async {
    await dio.post('/telemetry', data: {
      'vehicle_id': vehicleId,
      'rpm': data.rpm,
      'speed': data.speed,
      'coolant_temp_c': data.coolantTempC,
      'battery_voltage': data.batteryVoltage,
      'engine_load': data.engineLoad,
      'throttle_position': data.throttlePosition,
      'intake_temp_c': data.intakeTempC,
      'recorded_at': data.timestamp.toIso8601String(),
    });
  }

  Future<void> sendTelemetryRaw(Map<String, dynamic> payload) async {
    await dio.post('/telemetry', data: payload);
  }

  Future<List<dynamic>> getVehicles() async {
    final res = await dio.get('/vehicles');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> payload) async {
    final res = await dio.post('/vehicles', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<int> syncTrip(int vehicleId, TripRecord trip) async {
    final res = await dio.post('/vehicles/$vehicleId/trips', data: {
      'started_at': trip.startTime.toIso8601String(),
      'ended_at': trip.endTime.toIso8601String(),
      'avg_speed': trip.avgSpeed,
      'max_speed': trip.maxSpeed,
      'avg_coolant_temp_c': trip.avgCoolantTempC,
      'max_coolant_temp_c': trip.maxCoolantTempC,
      'distance_km': trip.distanceKm,
      'start_address': trip.startAddress,
      'end_address': trip.endAddress,
      'route': trip.route.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      'fuel_used_liters': trip.fuelUsedLiters,
      'avg_fuel_consumption_l100km': trip.avgFuelConsumptionL100km,
      'eco_score': trip.ecoScore,
    });
    return res.data['id'] as int;
  }

  Future<int> syncMaintenance(int vehicleId, MaintenanceRecord record) async {
    final res = await dio.post('/vehicles/$vehicleId/maintenance', data: {
      'title': record.title,
      'notes': record.notes,
      'performed_at': record.date.toIso8601String(),
      'odometer': record.odometer,
    });
    return res.data['id'] as int;
  }
}
