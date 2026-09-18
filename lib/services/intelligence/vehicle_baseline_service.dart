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
}
