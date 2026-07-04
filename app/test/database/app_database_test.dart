// ATTENZIONE: richiede app_database.g.dart generato da build_runner.
// Prima di eseguire: cd app && flutter pub run build_runner build
// Runnare: flutter test test/database/app_database_test.dart

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patina/database/app_database.dart';

AppDatabase _openInMemory() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() => db = _openInMemory());
  tearDown(() => db.close());

  // ─── Schema ────────────────────────────────────────────────────────────────

  group('Schema v2', () {
    test('il database si apre e le tabelle di base sono accessibili', () async {
      final rows = await db.select(db.projects).get();
      expect(rows, isEmpty);
    });

    test('tabella custom_paints esiste (aggiunta in v2)', () async {
      final rows = await db.select(db.customPaints).get();
      expect(rows, isEmpty);
    });

    test('tabella inventory_paints esiste', () async {
      final rows = await db.select(db.inventoryPaints).get();
      expect(rows, isEmpty);
    });

    test('tabella catalog_paints esiste', () async {
      final rows = await db.select(db.catalogPaints).get();
      expect(rows, isEmpty);
    });
  });

  // ─── Demo project ──────────────────────────────────────────────────────────

  group('initializeDemoProject', () {
    test('crea il progetto McLaren', () async {
      await db.initializeDemoProject();
      final projects = await db.select(db.projects).get();
      expect(projects.length, equals(1));
      expect(projects.first.name, equals('McLaren M8A 1968'));
      expect(projects.first.status, equals('in_progress'));
    });

    test('è idempotente — chiamate multiple non duplicano il progetto', () async {
      await db.initializeDemoProject();
      await db.initializeDemoProject();
      await db.initializeDemoProject();
      final projects = await db.select(db.projects).get();
      expect(projects.length, equals(1));
    });

    test('crea 5 vernici inventario Tamiya XF', () async {
      await db.initializeDemoProject();
      final inventory = await db.select(db.inventoryPaints).get();
      expect(inventory.length, equals(5));
      expect(
        inventory.map((p) => p.catalogCode).toSet(),
        containsAll(['XF-1', 'XF-2', 'XF-15', 'XF-16', 'XF-19']),
      );
    });

    test('le vernici demo hanno brand=tamiya e quantity=full', () async {
      await db.initializeDemoProject();
      final inventory = await db.select(db.inventoryPaints).get();
      for (final paint in inventory) {
        expect(paint.catalogBrand, equals('tamiya'));
        expect(paint.quantity, equals('full'));
      }
    });
  });

  // ─── CustomPaints ──────────────────────────────────────────────────────────

  group('CustomPaints', () {
    CustomPaintsCompanion _companion({
      String brand = 'scale75',
      String code = 'SC-01',
      String name = 'Inktense Black',
      String hex = '#0A0A0A',
    }) =>
        CustomPaintsCompanion.insert(
          brand: brand,
          code: code,
          name: name,
          hex: hex,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );

    test('inserisce una vernice custom', () async {
      await db.into(db.customPaints).insert(_companion());
      final rows = await db.select(db.customPaints).get();
      expect(rows.length, equals(1));
      expect(rows.first.brand, equals('scale75'));
      expect(rows.first.code, equals('SC-01'));
    });

    test('brand+code sono unique key — secondo inserimento fallisce', () async {
      await db.into(db.customPaints).insert(_companion());
      expect(
        () => db.into(db.customPaints).insert(_companion()),
        throwsA(anything),
      );
    });

    test('brand+code diversi → entrambi inseriti', () async {
      await db.into(db.customPaints).insert(_companion(code: 'SC-01'));
      await db.into(db.customPaints).insert(_companion(code: 'SC-02', name: 'Inktense White', hex: '#F0F0F0'));
      final rows = await db.select(db.customPaints).get();
      expect(rows.length, equals(2));
    });

    test('hex è memorizzato correttamente', () async {
      await db.into(db.customPaints).insert(_companion(hex: '#D99B3E'));
      final rows = await db.select(db.customPaints).get();
      expect(rows.first.hex, equals('#D99B3E'));
    });
  });

  // ─── InventoryPaints ───────────────────────────────────────────────────────

  group('InventoryPaints', () {
    test('inserisce vernice da catalogo con chiave naturale', () async {
      await db.into(db.inventoryPaints).insert(InventoryPaintsCompanion.insert(
        catalogBrand: const Value('vallejo'),
        catalogCode: const Value('70.950'),
      ));
      final rows = await db.select(db.inventoryPaints).get();
      expect(rows.first.catalogBrand, equals('vallejo'));
      expect(rows.first.catalogCode, equals('70.950'));
      expect(rows.first.quantity, equals('full')); // default
    });

    test('quantity default è full', () async {
      await db.into(db.inventoryPaints).insert(InventoryPaintsCompanion.insert(
        catalogBrand: const Value('tamiya'),
        catalogCode: const Value('XF-1'),
      ));
      final rows = await db.select(db.inventoryPaints).get();
      expect(rows.first.quantity, equals('full'));
    });

    test('quantity accetta i valori full|half|low|empty', () async {
      for (final qty in ['full', 'half', 'low', 'empty']) {
        await db.into(db.inventoryPaints).insert(InventoryPaintsCompanion.insert(
          catalogBrand: const Value('tamiya'),
          catalogCode: Value('XF-${qty.hashCode}'),
          quantity: Value(qty),
        ));
      }
      final rows = await db.select(db.inventoryPaints).get();
      expect(rows.map((r) => r.quantity).toSet(),
          containsAll(['full', 'half', 'low', 'empty']));
    });
  });
}
