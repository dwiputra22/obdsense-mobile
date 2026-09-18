import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip_record.dart';
import '../../models/maintenance_record.dart';
import '../../models/pending_telemetry.dart';
import '../../models/vehicle_profile.dart';

class VinCheckResult {
  final bool matches;
  final String? previousVin;
  const VinCheckResult({required this.matches, required this.previousVin});
}

class LocalStorageService {
  static const tripsBox = 'trips_box';
  static const maintenanceBox = 'maintenance_box';
  static const pendingTelemetryBox = 'pending_telemetry_box';
  static const vehicleProfileBox = 'vehicle_profile_box';

  Future<void> init() async {
    await Hive.openBox(tripsBox);
    await Hive.openBox(maintenanceBox);
    await Hive.openBox(pendingTelemetryBox);
    await Hive.openBox(vehicleProfileBox);
  }

  Future<void> saveVehicleProfile(VehicleProfile profile) async {
    final box = Hive.box(vehicleProfileBox);
    await box.put('active', profile.toJson());
    if (profile.vin != null) {
      await setActiveVin(profile.vin!);
    }
  }

  VehicleProfile? getVehicleProfile() {
    final box = Hive.box(vehicleProfileBox);
    final raw = box.get('active');
    if (raw == null) return null;
    return VehicleProfile.fromJson(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> setActiveVin(String vin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.activeVinKey, vin);
  }

  Future<String?> getActiveVin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.activeVinKey);
  }

  Future<VinCheckResult> checkVinAgainstStored(String scannedVin) async {
    final stored = await getActiveVin();
    if (stored == null || stored == scannedVin) {
      return VinCheckResult(matches: true, previousVin: stored);
    }
    return VinCheckResult(matches: false, previousVin: stored);
  }

  Future<void> setActiveVehicleId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.activeVehicleIdKey, id);
  }

  Future<int?> getActiveVehicleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.activeVehicleIdKey);
  }

  Future<void> saveTrip(TripRecord trip) async {
    final box = Hive.box(tripsBox);
    await box.add(trip.toJson());
  }

  List<TripRecord> getTrips() {
    final box = Hive.box(tripsBox);
    return box.values.map((e) => TripRecord.fromJson(Map<dynamic, dynamic>.from(e))).toList();
  }

  Future<void> updateTripAt(int index, TripRecord trip) async {
    final box = Hive.box(tripsBox);
    await box.putAt(index, trip.toJson());
  }

  Future<void> saveMaintenance(MaintenanceRecord record) async {
    final box = Hive.box(maintenanceBox);
    await box.add(record.toJson());
  }

  List<MaintenanceRecord> getMaintenanceRecords() {
    final box = Hive.box(maintenanceBox);
    return box.values
        .map((e) => MaintenanceRecord.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateMaintenanceAt(int index, MaintenanceRecord record) async {
    final box = Hive.box(maintenanceBox);
    await box.putAt(index, record.toJson());
  }

  Future<void> savePendingTelemetry(PendingTelemetry item) async {
    final box = Hive.box(pendingTelemetryBox);
    await box.add(item.toJson());
  }

  List<PendingTelemetry> getPendingTelemetry() {
    final box = Hive.box(pendingTelemetryBox);
    return box.values
        .map((e) => PendingTelemetry.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> clearPendingTelemetry() async {
    final box = Hive.box(pendingTelemetryBox);
    await box.clear();
  }

  Future<void> removePendingTelemetryAt(int index) async {
    final box = Hive.box(pendingTelemetryBox);
    await box.deleteAt(index);
  }
}