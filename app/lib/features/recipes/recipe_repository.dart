import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';

class RecipeRepository {
  final AppDatabase _db;
  RecipeRepository(this._db);

  Stream<List<Recipe>> watchAllRecipes() =>
      (_db.select(_db.recipes)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Stream<List<RecipeIngredient>> watchAllIngredients() =>
      _db.select(_db.recipeIngredients).watch();

  Stream<List<RecipeIngredient>> watchIngredients(int recipeId) =>
      (_db.select(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(recipeId)))
          .watch();

  Future<Recipe?> getById(int id) =>
      (_db.select(_db.recipes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Recipe?> watchById(int id) =>
      (_db.select(_db.recipes)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Future<int> count() async {
    final c = countAll();
    final q = _db.selectOnly(_db.recipes)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<int> createRecipe(RecipesCompanion companion) =>
      _db.into(_db.recipes).insert(companion);

  Future<void> updateRecipe(int id, RecipesCompanion companion) =>
      (_db.update(_db.recipes)..where((t) => t.id.equals(id))).write(companion);

  Future<void> deleteRecipe(int id) async {
    await (_db.delete(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(id)))
        .go();
    await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addIngredient({
    required int recipeId,
    required String brand,
    required String code,
    required String paintName,
    required String hex,
    required double percentage,
  }) =>
      _db.into(_db.recipeIngredients).insert(RecipeIngredientsCompanion(
            recipeId: Value(recipeId),
            brand: Value(brand),
            code: Value(code),
            paintName: Value(paintName),
            hex: Value(hex),
            percentage: Value(percentage),
          ));

  Future<void> updateIngredientPercentage(int id, double percentage) =>
      (_db.update(_db.recipeIngredients)..where((t) => t.id.equals(id)))
          .write(RecipeIngredientsCompanion(percentage: Value(percentage)));

  Future<void> deleteIngredient(int id) =>
      (_db.delete(_db.recipeIngredients)..where((t) => t.id.equals(id))).go();

  Future<void> replaceIngredients(
      int recipeId, List<RecipeIngredientsCompanion> ingredients) async {
    await (_db.delete(_db.recipeIngredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .go();
    await _db.batch((b) => b.insertAll(_db.recipeIngredients, ingredients));
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(databaseProvider));
});
