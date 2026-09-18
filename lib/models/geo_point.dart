class GeoPoint {
  final double lat;
  final double lng;
  final DateTime? recordedAt;

  const GeoPoint({required this.lat, required this.lng, this.recordedAt});

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'recordedAt': recordedAt?.toIso8601String(),
      };

  factory GeoPoint.fromJson(Map<dynamic, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      recordedAt: json['recordedAt'] != null ? DateTime.parse(json['recordedAt']) : null,
    );
  }
}
