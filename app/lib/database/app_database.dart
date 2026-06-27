import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables/projects.dart';
import 'tables/paints.dart';
import 'tables/recipes.dart';
import 'tables/pins.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Projects,
  ProjectPhotos,
  CatalogPaints,
  InventoryPaints,
  Recipes,
  RecipeIngredients,
  Pins,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> initializeCatalogs() async {
    final count = await (select(catalogPaints)..limit(1)).get();
    if (count.isNotEmpty) return;

    final catalogFiles = [
      'assets/catalogs/vallejo_model_color.json',
      'assets/catalogs/citadel_base.json',
      'assets/catalogs/tamiya_xf.json',
    ];

    await batch((b) async {
      for (final path in catalogFiles) {
        try {
          final raw = await rootBundle.loadString(path);
          final data = json.decode(raw) as Map<String, dynamic>;
          final brand = data['brand'] as String;
          final line = data['line'] as String;
          final paints = data['paints'] as List<dynamic>;
          for (final paint in paints) {
            b.insert(catalogPaints, CatalogPaintsCompanion(
              brand: Value(brand),
              line: Value(line),
              code: Value(paint['code'] as String),
              name: Value(paint['name'] as String),
              hex: Value(paint['hex'] as String),
            ));
          }
        } catch (_) {}
      }
    });
  }
}

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override in main'),
);

QueryExecutor _openConnection() {
  return driftDatabase(name: 'patina_db');
}
