import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/local/local_storage_service.dart';
import '../models/ai_insight.dart';
import '../models/anomaly.dart';
import '../models/geo_point.dart';
import '../models/telemetry_data.dart';
import '../models/trip_record.dart';
import '../models/vehicle_profile.dart';
import '../services/ai/ai_diagnosis_service.dart';
import '../services/api/api_service.dart';
import '../services/intelligence/anomaly_detector.dart';
import '../services/intelligence/dtc_history_service.dart';
import '../services/intelligence/vehicle_baseline_service.dart';
import '../services/location/location_tracking_service.dart';
import '../services/notifications/notification_service.dart';
import '../services/obd/i_obd_transport.dart';
import '../services/obd/obd_connection_manager.dart';
import '../services/obd/obd_service.dart';
import '../services/sync/telemetry_sync_service.dart';
import '../services/trips/auto_trip_detection_service.dart';
import '../services/trips/trip_recorder_service.dart';
import '../services/recording/data_recording_service.dart';

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final vehicleProfileProvider = Provider<VehicleProfile>((ref) {
  final storage = ref.watch(localStorageProvider);
  return storage.getVehicleProfile() ??
      const VehicleProfile(
        brand: 'Toyota',
        model: 'All New Rush',
        year: 2019,
        nickname: 'Rush',
        engineName: '2NR-VE',
      );
});

final notificationProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final telemetrySyncProvider = Provider<TelemetrySyncService>((ref) {
  return TelemetrySyncService(
    storage: ref.read(localStorageProvider),
    api: ref.read(apiServiceProvider),
  );
});

final obdTransportProvider = StateProvider<IObdTransport?>((ref) => null);

final obdConnectionManagerProvider = Provider<ObdConnectionManager?>((ref) {
  final transport = ref.watch(obdTransportProvider);
  if (transport == null) return null;
  final manager = ObdConnectionManager(transport);
  ref.onDispose(manager.dispose);
  return manager;
});

final obdProvider = Provider<ObdService?>((ref) {
  final manager = ref.watch(obdConnectionManagerProvider);
  if (manager == null) return null;
  final service = ObdService(manager);
  ref.onDispose(service.dispose);
  return service;
});

final aiDiagnosisProvider = Provider<AiDiagnosisService>((ref) {
  return AiDiagnosisService();
});

final vehicleBaselineProvider = Provider<VehicleBaselineService>((ref) {
  return VehicleBaselineService();
});

final dtcHistoryProvider = Provider<DtcHistoryService>((ref) {
  return DtcHistoryService();
});

final currentAnomaliesProvider = Provider<List<Anomaly>>((ref) {
  final vin = ref.watch(vehicleProfileProvider).vin;
  final data = ref.watch(telemetryProvider);
  if (vin == null) return [];
  final baselineService = ref.read(vehicleBaselineProvider);
  return AnomalyDetector.detect(vin, data, baselineService);
});

final extraSensorsProvider = StateProvider<Map<String, double>>((ref) => {});

final activeVehicleIdProvider = StateProvider<int>((ref) => 1);

final telemetryProvider =
StateNotifierProvider<TelemetryNotifier, TelemetryData>((ref) {
  return TelemetryNotifier(
    ref: ref,
    notificationService: ref.read(notificationProvider),
    apiService: ref.read(apiServiceProvider),
    syncService: ref.read(telemetrySyncProvider),
  );
});

class TelemetryNotifier extends StateNotifier<TelemetryData> {
  final Ref ref;
  final NotificationService notificationService;
  final ApiService apiService;
  final TelemetrySyncService syncService;

  StreamSubscription? _sub;
  StreamSubscription? _extraSub;
  Timer? _retryTimer;
  bool _highTempNotified = false;
  final Set<String> _anomalyNotifiedSensors = {};

  TelemetryNotifier({
    required this.ref,
    required this.notificationService,
    required this.apiService,
    required this.syncService,
  }) : super(TelemetryData.empty()) {
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncService.retryPending();
    });

    ref.listen<ObdService?>(obdProvider, (_, next) async {
      await _sub?.cancel();
      await _extraSub?.cancel();
      if (next == null) return;

      _extraSub = next.extraSensorsStream.listen((readings) {
        ref.read(extraSensorsProvider.notifier).state = readings;
      });

      _sub = next.telemetryStream.listen((event) async {
        state = event;
        ref.read(tripControllerProvider.notifier).addTelemetrySample(event);
        ref.read(dataRecordingProvider).addSample(event);

        final vin = ref.read(vehicleProfileProvider).vin;
        if (vin != null) {
          ref.read(vehicleBaselineProvider).recordSample(vin, event);

          final anomalies = ref.read(currentAnomaliesProvider);
          final anomalousSensors = anomalies.map((a) => a.sensorKey).toSet();

          Anomaly? newWarning;
          for (final a in anomalies) {
            if (a.severity == 'warning' && !_anomalyNotifiedSensors.contains(a.sensorKey)) {
              newWarning = a;
              break;
            }
          }
          if (newWarning != null) {
            _anomalyNotifiedSensors.add(newWarning.sensorKey);
            await notificationService.showAnomalyAlert(newWarning);
          }
          _anomalyNotifiedSensors.removeWhere((s) => !anomalousSensors.contains(s));
        }

        if (event.coolantTempC >= 100 && !_highTempNotified) {
          _highTempNotified = true;
          await notificationService.showHighTempAlert(event.coolantTempC);
        }

        if (event.coolantTempC < 95) {
          _highTempNotified = false;
        }

        final vehicleId = ref.read(activeVehicleIdProvider);

        try {
          await apiService.sendTelemetry(vehicleId, event);
        } catch (_) {
          await syncService.enqueue({
            'vehicle_id': vehicleId,
            'rpm': event.rpm,
            'speed': event.speed,
            'coolant_temp_c': event.coolantTempC,
            'battery_voltage': event.batteryVoltage,
            'engine_load': event.engineLoad,
            'throttle_position': event.throttlePosition,
            'intake_temp_c': event.intakeTempC,
            'recorded_at': event.timestamp.toIso8601String(),
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _extraSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

final aiInsightsProvider = Provider<List<AiInsight>>((ref) {
  final data = ref.watch(telemetryProvider);
  return ref.read(aiDiagnosisProvider).analyze(data);
});

final tripRecorderProvider = Provider<TripRecorderService>((ref) {
  return TripRecorderService();
});

final dataRecordingProvider = Provider<DataRecordingService>((ref) {
  return DataRecordingService();
});

final autoTripDetectionProvider = Provider<AutoTripDetectionService>((ref) {
  final service = AutoTripDetectionService(
    onDriveDetectedStart: () {
      if (!ref.read(tripRecorderProvider).isRecording) {
        ref.read(tripControllerProvider.notifier).startTrip();
      }
    },
    onDriveDetectedStop: () {
      if (ref.read(tripRecorderProvider).isRecording) {
        ref.read(tripControllerProvider.notifier).stopTrip();
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final locationTrackingProvider = Provider<LocationTrackingService>((ref) {
  final service = LocationTrackingService();
  ref.onDispose(service.dispose);
  return service;
});

final tripControllerProvider =
StateNotifierProvider<TripController, List<TripRecord>>((ref) {
  return TripController(
    storage: ref.read(localStorageProvider),
    recorder: ref.read(tripRecorderProvider),
    location: ref.read(locationTrackingProvider),
    api: ref.read(apiServiceProvider),
    ref: ref,
  );
});

class TripController extends StateNotifier<List<TripRecord>> {
  final LocalStorageService storage;
  final TripRecorderService recorder;
  final LocationTrackingService location;
  final ApiService api;
  final Ref ref;

  StreamSubscription<GeoPoint>? _locationSub;

  TripController({
    required this.storage,
    required this.recorder,
    required this.location,
    required this.api,
    required this.ref,
  }) : super(storage.getTrips());

  Future<void> startTrip() async {
    recorder.start();
    await location.start();
    await _locationSub?.cancel();
    _locationSub = location.points.listen(recorder.addLocationPoint);
  }

  void addTelemetrySample(TelemetryData data) {
    recorder.addSample(data);
  }

  Future<void> stopTrip() async {
    await _locationSub?.cancel();
    await location.stop();

    final trip = await recorder.stop();
    if (trip == null) return;

    TripRecord finalTrip = trip;
    try {
      final vehicleId = ref.read(activeVehicleIdProvider);
      final remoteId = await api.syncTrip(vehicleId, trip);
      finalTrip = trip.copyWith(remoteId: remoteId);
    } catch (_) {
      // Tetap simpan lokal walau sync gagal.
    }

    await storage.saveTrip(finalTrip);
    state = storage.getTrips();
  }

  Future<void> retrySync(int index, TripRecord trip) async {
    if (trip.remoteId != null) return;
    try {
      final vehicleId = ref.read(activeVehicleIdProvider);
      final remoteId = await api.syncTrip(vehicleId, trip);
      await storage.updateTripAt(index, trip.copyWith(remoteId: remoteId));
      state = storage.getTrips();
    } catch (_) {
      // Biarkan tetap belum tersinkron, user bisa coba lagi nanti.
    }
  }

  void reload() {
    state = storage.getTrips();
  }
}
