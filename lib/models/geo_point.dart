class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory GeoPoint.fromJson(Map<dynamic, dynamic> json) {
    return GeoPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
