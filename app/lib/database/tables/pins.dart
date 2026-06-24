import 'package:drift/drift.dart';
import 'paints.dart';
import 'recipes.dart';

class Pins extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get photoId => integer()();
  TextColumn get type => text()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  IntColumn get paintId => integer().nullable().references(InventoryPaints, #id)();
  IntColumn get recipeId => integer().nullable().references(Recipes, #id)();
  TextColumn get techniqueType => text().nullable()();
  TextColumn get productUsed => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get phaseId => integer().nullable()();
}
