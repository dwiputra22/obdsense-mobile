class HealthEvent {
  final double lat;
  final double lng;
  final String sensorLabel;
  final String severity; // 'watch' | 'warning'

  const HealthEvent({
    required this.lat,
    required this.lng,
    required this.sensorLabel,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'sensorLabel': sensorLabel,
        'severity': severity,
      };

  factory HealthEvent.fromJson(Map<dynamic, dynamic> json) {
    return HealthEvent(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      sensorLabel: json['sensorLabel'] as String,
      severity: json['severity'] as String,
    );
  }
}
