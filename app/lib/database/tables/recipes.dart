import 'package:drift/drift.dart';
import 'paints.dart';

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get technique => text().nullable()();
  TextColumn get dilution => text().nullable()();
  TextColumn get surface => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId => integer().references(Recipes, #id)();
  IntColumn get paintId => integer().nullable().references(InventoryPaints, #id)();
  IntColumn get catalogId => integer().nullable().references(CatalogPaints, #id)();
  RealColumn get percentage => real()();
}
