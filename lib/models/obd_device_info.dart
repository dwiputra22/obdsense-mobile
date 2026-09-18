class ObdDeviceInfo {
  final String id;
  final String name;
  final bool isConnected;

  const ObdDeviceInfo({
    required this.id,
    required this.name,
    this.isConnected = false,
  });
}