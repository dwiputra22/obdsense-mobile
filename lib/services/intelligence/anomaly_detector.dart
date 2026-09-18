import '../../models/anomaly.dart';
import '../../models/telemetry_data.dart';
import 'driving_state_classifier.dart';
import 'vehicle_baseline_service.dart';

class AnomalyDetector {
  static const watchThresholdStdDevs = 2.0;
  static const warningThresholdStdDevs = 3.0;

  static List<Anomaly> detect(
    String vin,
    TelemetryData data,
    VehicleBaselineService baselineService,
  ) {
    final state = DrivingStateClassifier.classify(data);
    final anomalies = <Anomaly>[];

    final checks = <(String, String, double)>[
      ('coolantTempC', 'Suhu Mesin', data.coolantTempC),
      ('batteryVoltage', 'Voltase Aki', data.batteryVoltage),
      ('engineLoad', 'Beban Mesin', data.engineLoad),
      if (state == DrivingState.idle) ('rpm', 'RPM Idle', data.rpm),
    ];

    for (final (sensorKey, label, value) in checks) {
      final baseline = baselineService.getBaseline(vin, sensorKey, state);
      if (baseline == null || !baseline.isReliable) continue;
      if (baseline.stdDev == 0) continue;

      final deviation = (value - baseline.mean).abs() / baseline.stdDev;

      String? severity;
      if (deviation >= warningThresholdStdDevs) {
        severity = 'warning';
      } else if (deviation >= watchThresholdStdDevs) {
        severity = 'watch';
      }

      if (severity != null) {
        anomalies.add(Anomaly(
          sensorKey: sensorKey,
          label: label,
          expectedMean: baseline.mean,
          actualValue: value,
          deviationInStdDevs: deviation,
          severity: severity,
        ));
      }
    }

    return anomalies;
  }
}
