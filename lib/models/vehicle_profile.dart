class VehicleProfile {
  final String? vin;
  final int? remoteId;
  final String brand;
  final String model;
  final int year;
  final String nickname;
  final String engineName;

  const VehicleProfile({
    this.vin,
    this.remoteId,
    required this.brand,
    required this.model,
    required this.year,
    required this.nickname,
    required this.engineName,
  });

  Map<String, dynamic> toJson() {
    return {
      'vin': vin,
      'remoteId': remoteId,
      'brand': brand,
      'model': model,
      'year': year,
      'nickname': nickname,
      'engineName': engineName,
    };
  }

  factory VehicleProfile.fromJson(Map<dynamic, dynamic> json) {
    return VehicleProfile(
      vin: json['vin'] as String?,
      remoteId: json['remoteId'] as int?,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      nickname: json['nickname'] as String,
      engineName: json['engineName'] as String,
    );
  }

  VehicleProfile copyWith({
    String? vin,
    int? remoteId,
    String? brand,
    String? model,
    int? year,
    String? nickname,
    String? engineName,
  }) {
    return VehicleProfile(
      vin: vin ?? this.vin,
      remoteId: remoteId ?? this.remoteId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      nickname: nickname ?? this.nickname,
      engineName: engineName ?? this.engineName,
    );
  }
}
