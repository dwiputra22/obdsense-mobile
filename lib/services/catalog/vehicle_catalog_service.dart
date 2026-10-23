import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../models/vehicle_spec.dart';

class CatalogBrand {
  const CatalogBrand({required this.name, required this.origin, required this.models});

  final String name;
  final String origin;
  final List<CatalogModel> models;
}

class VehicleCatalog {
  VehicleCatalog._(this.brands, this.edition)
      : _brandIndex = {for (final b in brands) normalize(b.name): b},
        _modelIndex = {
          for (final b in brands)
            for (final m in b.models) '${normalize(b.name)}|${normalize(m.name)}': m,
        };

  final List<CatalogBrand> brands;
  final String edition;
  final Map<String, CatalogBrand> _brandIndex;
  final Map<String, CatalogModel> _modelIndex;

  static const String assetPath = 'assets/data/vehicle_catalog_id.json';

  static VehicleCatalog? _instance;

  static VehicleCatalog? get instance => _instance;

  static Future<void> load() async {
    if (_instance != null) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      _instance = VehicleCatalog.parse(raw);
    } catch (_) {
      _instance = null;
    }
  }

  factory VehicleCatalog.parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final brands = <CatalogBrand>[];
    for (final b in (json['brands'] as List)) {
      final bm = Map<String, dynamic>.from(b as Map);
      final name = bm['name'] as String;
      brands.add(CatalogBrand(
        name: name,
        origin: bm['origin'] as String? ?? '',
        models: [
          for (final m in (bm['models'] as List)) CatalogModel.fromJson(name, Map<String, dynamic>.from(m as Map)),
        ],
      ));
    }
    return VehicleCatalog._(brands, json['edition'] as String? ?? '');
  }

  static String normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<String> get brandNames => [for (final b in brands) b.name];

  CatalogBrand? brand(String name) => _brandIndex[normalize(name)];

  List<String> modelNames(String brandName) => [for (final m in brand(brandName)?.models ?? const <CatalogModel>[]) m.name];

  CatalogModel? find(String brandName, String modelName) =>
      _modelIndex['${normalize(brandName)}|${normalize(modelName)}'];

  List<String> suggestBrands(String query) => _rank(brandNames, query);

  List<String> suggestModels(String brandName, String query) => _rank(modelNames(brandName), query);

  static List<String> _rank(List<String> source, String query) {
    final q = normalize(query);
    if (q.isEmpty) return source;
    final starts = <String>[];
    final contains = <String>[];
    for (final s in source) {
      final n = normalize(s);
      if (n.startsWith(q)) {
        starts.add(s);
      } else if (n.contains(q)) {
        contains.add(s);
      }
    }
    return [...starts, ...contains];
  }
}