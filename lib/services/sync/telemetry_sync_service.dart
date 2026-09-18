import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/local/local_storage_service.dart';
import '../../models/pending_telemetry.dart';
import '../api/api_service.dart';

class TelemetrySyncService {
  final LocalStorageService storage;
  final ApiService api;

  TelemetrySyncService({
    required this.storage,
    required this.api,
  });

  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    await storage.savePendingTelemetry(
      PendingTelemetry(
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> retryPending() async {
    final connected = await hasConnection();
    if (!connected) return;

    final items = storage.getPendingTelemetry();
    final sentIndexes = <int>[];

    for (int i = 0; i < items.length; i++) {
      try {
        await api.sendTelemetryRaw(items[i].payload);
        sentIndexes.add(i);
      } catch (_) {
        // Biarkan tetap di antrian, dicoba lagi di retryPending() berikutnya.
      }
    }

    for (final i in sentIndexes.reversed) {
      await storage.removePendingTelemetryAt(i);
    }
  }
}
