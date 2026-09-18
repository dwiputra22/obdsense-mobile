class EcuInfo {
  final String? vin;
  final String? calibrationId;
  final String? ecuName;

  const EcuInfo({this.vin, this.calibrationId, this.ecuName});

  bool get isEmpty => vin == null && calibrationId == null && ecuName == null;
}
