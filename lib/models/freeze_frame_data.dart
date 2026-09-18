class FreezeFrameData {
  final String triggeringDtc;
  final double? rpm;
  final double? speed;
  final double? coolantTempC;
  final double? engineLoad;
  final double? throttlePosition;
  final double? intakeTempC;
  final double? fuelLevelPercent;

  const FreezeFrameData({
    required this.triggeringDtc,
    this.rpm,
    this.speed,
    this.coolantTempC,
    this.engineLoad,
    this.throttlePosition,
    this.intakeTempC,
    this.fuelLevelPercent,
  });
}
