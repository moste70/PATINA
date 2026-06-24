import 'package:drift/drift.dart';

class CatalogPaints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();
  TextColumn get line => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get hex => text()();
}

class InventoryPaints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get catalogId => integer().nullable().references(CatalogPaints, #id)();
  TextColumn get customBrand => text().nullable()();
  TextColumn get customCode => text().nullable()();
  TextColumn get customName => text().nullable()();
  TextColumn get customHex => text().nullable()();
  TextColumn get quantity => text().withDefault(const Constant('full'))();
  TextColumn get notes => text().nullable()();
  IntColumn get purchasedAt => integer().nullable()();
}
