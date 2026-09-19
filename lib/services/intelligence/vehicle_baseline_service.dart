import 'package:hive/hive.dart';
import '../../models/running_stat.dart';
import '../../models/telemetry_data.dart';
import 'driving_state_classifier.dart';

class VehicleBaselineService {
  static const _boxName = 'vehicle_baseline_box';

  static const trackedSensors = ['rpm', 'coolantTempC', 'batteryVoltage', 'engineLoad'];

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  String _key(String vin, String sensor, DrivingState state) => '$vin|$sensor|${state.name}';

  void recordSample(String vin, TelemetryData data) {
    final state = DrivingStateClassifier.classify(data);
    final box = Hive.box(_boxName);

    final values = {
      'rpm': data.rpm,
      'coolantTempC': data.coolantTempC,
      'batteryVoltage': data.batteryVoltage,
      'engineLoad': data.engineLoad,
    };

    for (final sensor in trackedSensors) {
      if (sensor == 'rpm' && state != DrivingState.idle) continue;

      final key = _key(vin, sensor, state);
      final raw = box.get(key);
      final stat = raw == null
          ? RunningStat()
          : RunningStat.fromJson(Map<dynamic, dynamic>.from(raw));

      stat.add(values[sensor]!);
      box.put(key, stat.toJson());
    }
  }

  RunningStat? getBaseline(String vin, String sensor, DrivingState state) {
    final box = Hive.box(_boxName);
    final raw = box.get(_key(vin, sensor, state));
    if (raw == null) return null;
    return RunningStat.fromJson(Map<dynamic, dynamic>.from(raw));
  }

  Map<String, Map<String, RunningStat?>> getAllBaselines(String vin) {
    final result = <String, Map<String, RunningStat?>>{};
    for (final state in DrivingState.values) {
      result[state.name] = {
        for (final sensor in trackedSensors)
          if (!(sensor == 'rpm' && state != DrivingState.idle))
            sensor: getBaseline(vin, sensor, state),
      };
    }
    return result;
  }

  static const _snapshotBoxName = 'vehicle_baseline_snapshot_box';

  Future<void> initSnapshots() async {
    await Hive.openBox(_snapshotBoxName);
  }

  void takeSnapshot(String vin) {
    final box = Hive.box(_snapshotBoxName);
    final now = DateTime.now().toIso8601String();

    for (final state in DrivingState.values) {
      for (final sensor in trackedSensors) {
        if (sensor == 'rpm' && state != DrivingState.idle) continue;
        final stat = getBaseline(vin, sensor, state);
        if (stat == null || !stat.isReliable) continue;

        final key = '$vin|$sensor|${state.name}';
        final existingRaw = box.get(key) as List? ?? [];
        final snapshots = existingRaw.map((e) => Map<String, dynamic>.from(e)).toList();
        snapshots.add({'at': now, 'mean': stat.mean, 'stdDev': stat.stdDev});

        if (snapshots.length > 60) snapshots.removeAt(0);
        box.put(key, snapshots);
      }
    }
  }

  List<Map<String, dynamic>> getSnapshotHistory(String vin, String sensor, DrivingState state) {
    final box = Hive.box(_snapshotBoxName);
    final raw = box.get('$vin|$sensor|${state.name}') as List? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
