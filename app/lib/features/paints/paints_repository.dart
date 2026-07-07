import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';

class CustomPaintRef {
  final String brand;
  final String code;
  final String name;
  final String hex;
  const CustomPaintRef({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
  });
}

class PaintsRepository {
  final AppDatabase _db;
  PaintsRepository(this._db);

  Stream<List<InventoryPaint>> watchInventoryPaints() =>
      (_db.select(_db.inventoryPaints)
            ..orderBy([
              (t) => OrderingTerm.asc(t.catalogBrand),
              (t) => OrderingTerm.asc(t.catalogCode),
            ]))
          .watch();

  Stream<Map<String, CustomPaintRef>> watchCustomPaintIndex() =>
      _db.select(_db.customPaints).watch().map((rows) {
        final index = <String, CustomPaintRef>{};
        for (final r in rows) {
          index['${r.brand}+${r.code}'] = CustomPaintRef(
            brand: r.brand,
            code: r.code,
            name: r.name,
            hex: r.hex,
          );
        }
        return index;
      });

  Future<void> addInventoryPaint({
    required String brand,
    required String code,
    String quantity = 'full',
  }) async {
    final exists = await (_db.select(_db.inventoryPaints)
          ..where(
              (t) => t.catalogBrand.equals(brand) & t.catalogCode.equals(code)))
        .getSingleOrNull();
    if (exists != null) return;
    await _db.into(_db.inventoryPaints).insert(InventoryPaintsCompanion(
          catalogBrand: Value(brand),
          catalogCode: Value(code),
          quantity: Value(quantity),
        ));
  }

  Future<void> updatePaintQuantity(int id, String quantity) =>
      (_db.update(_db.inventoryPaints)..where((t) => t.id.equals(id)))
          .write(InventoryPaintsCompanion(quantity: Value(quantity)));

  Future<void> deleteInventoryPaint(int id) =>
      (_db.delete(_db.inventoryPaints)..where((t) => t.id.equals(id))).go();
}

final paintsRepositoryProvider = Provider<PaintsRepository>((ref) {
  return PaintsRepository(ref.watch(databaseProvider));
});
