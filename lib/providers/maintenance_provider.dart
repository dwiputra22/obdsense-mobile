import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'app_providers.dart';
import '../data/local/local_storage_service.dart';
import '../models/maintenance_record.dart';
import '../services/api/api_service.dart';

final maintenanceControllerProvider =
    StateNotifierProvider<MaintenanceController, List<MaintenanceRecord>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final api = ref.watch(apiServiceProvider);
  return MaintenanceController(storage: storage, api: api, ref: ref)..load();
});

class MaintenanceController extends StateNotifier<List<MaintenanceRecord>> {
  final LocalStorageService storage;
  final ApiService api;
  final Ref ref;

  MaintenanceController({
    required this.storage,
    required this.api,
    required this.ref,
  }) : super([]);

  void load() {
    state = storage.getMaintenanceRecords();
  }

  Future<void> addRecord(MaintenanceRecord record) async {
    MaintenanceRecord finalRecord = record;
    try {
      final vehicleId = ref.read(activeVehicleIdProvider);
      final remoteId = await api.syncMaintenance(vehicleId, record);
      finalRecord = MaintenanceRecord(
        remoteId: remoteId,
        title: record.title,
        notes: record.notes,
        date: record.date,
        odometer: record.odometer,
      );
    } catch (_) {
      // Tetap simpan lokal walau sync gagal.
    }

    await storage.saveMaintenance(finalRecord);
    load();
  }

  Future<void> retrySync(int index, MaintenanceRecord record) async {
    if (record.remoteId != null) return;
    try {
      final vehicleId = ref.read(activeVehicleIdProvider);
      final remoteId = await api.syncMaintenance(vehicleId, record);
      final updated = MaintenanceRecord(
        remoteId: remoteId,
        title: record.title,
        notes: record.notes,
        date: record.date,
        odometer: record.odometer,
      );
      await storage.updateMaintenanceAt(index, updated);
      load();
    } catch (_) {
      // Biarkan tetap belum tersinkron.
    }
  }
}
