import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/local/local_storage_service.dart';
import '../../models/pending_telemetry.dart';
import '../api/api_service.dart';

class TelemetrySyncService {
  final LocalStorageService storage;
  final ApiService api;
  bool _retryInProgress = false;

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
    if (_retryInProgress) return;
    _retryInProgress = true;

    try {
      if (!await hasConnection()) return;

      // The queue is intentionally small and latest-only per vehicle.
      // Process a small batch so retry never monopolizes the UI/network.
      final items = storage.getPendingTelemetry();
      final limit = items.length > 5 ? 5 : items.length;

      for (int i = 0; i < limit; i++) {
        try {
          await api.sendTelemetryRaw(items[i].payload);
          // Re-read because indexes can shift after deletion.
          final current = storage.getPendingTelemetry();
          final matchIndex = current.indexWhere(
            (item) => item.createdAt == items[i].createdAt,
          );
          if (matchIndex >= 0) {
            await storage.removePendingTelemetryAt(matchIndex);
          }
        } catch (_) {
          // Stop this retry pass on the first failure.
          break;
        }
      }
    } finally {
      _retryInProgress = false;
    }
  }
}
