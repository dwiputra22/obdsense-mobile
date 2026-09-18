class TelemetryData {
  final double rpm;
  final double speed;
  final double coolantTempC;
  final double batteryVoltage;
  final double engineLoad;
  final double throttlePosition;
  final double intakeTempC;
  final DateTime timestamp;
  final double fuelRateLph;
  final double fuelLevelPercent;

  const TelemetryData({
    required this.rpm,
    required this.speed,
    required this.coolantTempC,
    required this.batteryVoltage,
    required this.engineLoad,
    required this.throttlePosition,
    required this.intakeTempC,
    required this.timestamp,
    this.fuelRateLph = 0,
    this.fuelLevelPercent = 0,
  });

  factory TelemetryData.empty() {
    return TelemetryData(
      rpm: 0,
      speed: 0,
      coolantTempC: 0,
      batteryVoltage: 0,
      engineLoad: 0,
      throttlePosition: 0,
      intakeTempC: 0,
      timestamp: DateTime.now(),
      fuelRateLph: 0,
      fuelLevelPercent: 0,
    );
  }
}
