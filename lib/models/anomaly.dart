class Anomaly {
  final String sensorKey;
  final String label;
  final double expectedMean;
  final double actualValue;
  final double deviationInStdDevs;
  final String severity; // 'watch' | 'warning'

  const Anomaly({
    required this.sensorKey,
    required this.label,
    required this.expectedMean,
    required this.actualValue,
    required this.deviationInStdDevs,
    required this.severity,
  });
}
