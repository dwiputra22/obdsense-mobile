class VehicleProfile {
  final String? vin;
  final int? remoteId;
  final String brand;
  final String model;
  final int year;
  final String nickname;
  final String engineName;

  final String? fuelType;
  final String? transmission;
  final int? gearCount;
  final double? tankLiters;

  const VehicleProfile({
    this.vin,
    this.remoteId,
    required this.brand,
    required this.model,
    required this.year,
    required this.nickname,
    required this.engineName,
    this.fuelType,
    this.transmission,
    this.gearCount,
    this.tankLiters,
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
      'fuelType': fuelType,
      'transmission': transmission,
      'gearCount': gearCount,
      'tankLiters': tankLiters,
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
      fuelType: json['fuelType'] as String?,
      transmission: json['transmission'] as String?,
      gearCount: (json['gearCount'] as num?)?.toInt(),
      tankLiters: (json['tankLiters'] as num?)?.toDouble(),
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
    String? fuelType,
    String? transmission,
    int? gearCount,
    double? tankLiters,
  }) {
    return VehicleProfile(
      vin: vin ?? this.vin,
      remoteId: remoteId ?? this.remoteId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      nickname: nickname ?? this.nickname,
      engineName: engineName ?? this.engineName,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      gearCount: gearCount ?? this.gearCount,
      tankLiters: tankLiters ?? this.tankLiters,
    );
  }
}
