enum FuelType {
  gasoline,
  diesel,
  hybrid,
  electric;

  static FuelType? parse(String? v) {
    for (final f in FuelType.values) {
      if (f.name == v) return f;
    }
    return null;
  }

  String get label => switch (this) {
        FuelType.gasoline => 'Bensin',
        FuelType.diesel => 'Diesel',
        FuelType.hybrid => 'Hybrid',
        FuelType.electric => 'Listrik',
      };
}

class CatalogEngine {
  const CatalogEngine({required this.fuel, this.code, this.cc, this.turbo = false});

  final FuelType fuel;
  final String? code;
  final int? cc;
  final bool turbo;

  factory CatalogEngine.fromJson(Map<String, dynamic> j) => CatalogEngine(
        fuel: FuelType.parse(j['fuel'] as String?) ?? FuelType.gasoline,
        code: j['code'] as String?,
        cc: (j['cc'] as num?)?.toInt(),
        turbo: j['turbo'] as bool? ?? false,
      );

  /// Contoh: "1.5 L Turbo · Bensin (2NR-VE)".
  String get label {
    if (fuel == FuelType.electric) return 'Listrik (EV)';
    final parts = <String>[];
    if (cc != null) parts.add('${(cc! / 1000).toStringAsFixed(1)} L${turbo ? ' Turbo' : ''}');
    parts.add(fuel.label);
    final base = parts.join(' · ');
    return code == null ? base : '$base ($code)';
  }
}

class CatalogTransmission {
  const CatalogTransmission({required this.type, this.gears});

  /// MT, AT, CVT, DCT, AMT, ECVT, EV
  final String type;
  final int? gears;

  factory CatalogTransmission.fromJson(Map<String, dynamic> j) =>
      CatalogTransmission(type: j['type'] as String, gears: (j['gears'] as num?)?.toInt());

  bool get isAutomatic => type != 'MT';

  bool get isContinuous => type == 'CVT' || type == 'ECVT' || type == 'EV';

  String get label {
    final g = gears;
    switch (type) {
      case 'MT':
        return g == null ? 'Manual' : 'Manual $g-speed';
      case 'AT':
        return g == null ? 'Automatic' : 'Automatic $g-speed';
      case 'CVT':
        return 'CVT';
      case 'DCT':
        return g == null ? 'DCT (dual clutch)' : 'DCT $g-speed';
      case 'AMT':
        return g == null ? 'AMT / AGS' : 'AMT / AGS $g-speed';
      case 'ECVT':
        return 'e-CVT (hybrid)';
      case 'EV':
        return 'Satu rasio (EV)';
      default:
        return type;
    }
  }
}

class CatalogModel {
  const CatalogModel({
    required this.brand,
    required this.name,
    required this.body,
    required this.fromYear,
    this.toYear,
    required this.engines,
    required this.transmissions,
    this.tankLiters,
  });

  final String brand;
  final String name;
  final String body;
  final int fromYear;
  final int? toYear;
  final List<CatalogEngine> engines;
  final List<CatalogTransmission> transmissions;
  final double? tankLiters;

  factory CatalogModel.fromJson(String brand, Map<String, dynamic> j) => CatalogModel(
        brand: brand,
        name: j['name'] as String,
        body: j['body'] as String? ?? '',
        fromYear: (j['from'] as num).toInt(),
        toYear: (j['to'] as num?)?.toInt(),
        engines: [
          for (final e in (j['engines'] as List? ?? const [])) CatalogEngine.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        transmissions: [
          for (final t in (j['transmissions'] as List? ?? const []))
            CatalogTransmission.fromJson(Map<String, dynamic>.from(t as Map)),
        ],
        tankLiters: (j['tankLiters'] as num?)?.toDouble(),
      );

  String get yearsLabel => toYear == null ? '$fromYear–sekarang' : '$fromYear–$toYear';

  FuelType? get onlyFuel {
    final set = engines.map((e) => e.fuel).toSet();
    return set.length == 1 ? set.first : null;
  }
}