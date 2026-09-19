class DriftSignal {
  final String sensorLabel;
  final String stateLabel;
  final double oldMean;
  final double newMean;
  final double changePercent;
  final String direction; // 'naik' | 'turun'

  const DriftSignal({
    required this.sensorLabel,
    required this.stateLabel,
    required this.oldMean,
    required this.newMean,
    required this.changePercent,
    required this.direction,
  });
}

class DriftDetector {
  static const _labels = {
    'rpm': 'RPM Idle',
    'coolantTempC': 'Suhu Mesin',
    'batteryVoltage': 'Voltase Aki',
    'engineLoad': 'Beban Mesin',
  };

  static const _stateLabels = {'idle': 'Idle', 'city': 'Kota', 'highway': 'Tol'};

  /// Minimal 5 snapshot
  static List<DriftSignal> detect(List<Map<String, dynamic>> snapshots, String sensor, String state) {
    if (snapshots.length < 5) return [];

    final oldest = snapshots.first;
    final newest = snapshots.last;
    final oldMean = (oldest['mean'] as num).toDouble();
    final newMean = (newest['mean'] as num).toDouble();

    if (oldMean == 0) return [];
    final changePercent = ((newMean - oldMean) / oldMean.abs()) * 100;

    if (changePercent.abs() < 8) return [];

    return [
      DriftSignal(
        sensorLabel: _labels[sensor] ?? sensor,
        stateLabel: _stateLabels[state] ?? state,
        oldMean: oldMean,
        newMean: newMean,
        changePercent: changePercent.abs(),
        direction: changePercent > 0 ? 'naik' : 'turun',
      ),
    ];
  }
}
