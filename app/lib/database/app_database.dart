import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> initializeDemoProject() async {
    final existing = await (select(projects)..limit(1)).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final projectId = await into(projects).insert(ProjectsCompanion(
      name: const Value('McLaren M8A 1968'),
      brand: const Value('Tamiya'),
      scale: const Value('1/18'),
      category: const Value('other'),
      status: const Value('in_progress'),
      notes: const Value(
        'Challenger Series No.8 — CAN-AM 1968\n'
        'Livrea: arancio neozelandese #4 Bruce McLaren\n\n'
        'FASI DI LAVORAZIONE\n'
        '1. Preparazione e primer\n'
        '2. Chassis e telaio — TS-17 Gloss Aluminum\n'
        '3. Motore V8 Chevrolet — XF-56 Metallic Grey + X-18 Semi Gloss Black\n'
        '4. Sospensioni anteriori e posteriori — X-18 Semi Gloss Black\n'
        '5. Radiatori e pannelli laterali — XF-16 Flat Aluminium\n'
        '6. Ruote anteriori e posteriori\n'
        '7. Figura pilota — XF-15 Flat Flesh, XF-19 Sky Grey (casco)\n'
        '8. Carrozzeria — TS-56 Brilliant Orange (colore principale)\n'
        '9. Decals — #4 Bruce McLaren / #5 Denis Hulme\n'
        '10. Assemblaggio finale e lucidatura',
      ),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // Vernici inventario — solo quelle presenti nel catalogo tamiya_xf
    final demoXfPaints = ['XF-1', 'XF-2', 'XF-15', 'XF-16', 'XF-19'];
    await batch((b) {
      for (final code in demoXfPaints) {
        b.insert(inventoryPaints, InventoryPaintsCompanion(
          catalogBrand: const Value('tamiya'),
          catalogCode: Value(code),
          quantity: const Value('full'),
        ));
      }
    });
  }

  static const String _catalogVersion = '2024.1';
  static const String _catalogVersionKey = 'catalog_version';

  Future<void> initializeCatalogs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString(_catalogVersionKey);
    if (storedVersion == _catalogVersion) return;

    // Nuova versione catalogo: svuota e ricarica (non tocca inventory)
    await delete(catalogPaints).go();

    final catalogFiles = [
      'assets/catalogs/vallejo_model_color.json',
      'assets/catalogs/vallejo_model_air.json',
      'assets/catalogs/citadel_base.json',
      'assets/catalogs/tamiya_xf.json',
      'assets/catalogs/tamiya_x.json',
      'assets/catalogs/gunze_aqueous.json',
      'assets/catalogs/gunze_mr_color.json',
      'assets/catalogs/gunze_mr_metal.json',
      'assets/catalogs/humbrol_enamel.json',
      'assets/catalogs/lifecolor_ua.json',
      'assets/catalogs/lifecolor_lc.json',
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

    await prefs.setString(_catalogVersionKey, _catalogVersion);
  }
}

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override in main'),
);

QueryExecutor _openConnection() {
  return driftDatabase(name: 'patina_db');
}
