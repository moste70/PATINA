import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';

class ProjectRepository {
  final AppDatabase _db;
  ProjectRepository(this._db);

  Future<int> createProject(ProjectsCompanion companion) =>
      _db.into(_db.projects).insert(companion);

  Stream<List<Project>> watchAllProjects() =>
      (_db.select(_db.projects)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Stream<Project> watchProjectById(int id) =>
      (_db.select(_db.projects)..where((t) => t.id.equals(id))).watchSingle();

  Future<void> updateProject(int id, ProjectsCompanion companion) =>
      (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(companion);

  Future<void> deleteProject(int id) =>
      (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();

  Stream<List<ProjectPhoto>> watchProjectPhotos(int projectId) =>
      (_db.select(_db.projectPhotos)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<void> addProjectPhoto(int projectId, String path) =>
      _db.into(_db.projectPhotos).insert(ProjectPhotosCompanion(
            projectId: Value(projectId),
            path: Value(path),
            takenAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));

  Future<void> deleteProjectPhoto(int photoId) =>
      (_db.delete(_db.projectPhotos)..where((t) => t.id.equals(photoId))).go();

  // ── Palette del kit ──────────────────────────────────────────────────────

  Stream<List<ProjectPaint>> watchProjectPaints(int projectId) =>
      (_db.select(_db.projectPaints)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.brand),
                       (t) => OrderingTerm.asc(t.code)]))
          .watch();

  Future<void> addProjectPaint({
    required int projectId,
    required String brand,
    required String code,
    required String name,
    required String hex,
  }) =>
      _db.into(_db.projectPaints).insertOnConflictUpdate(
            ProjectPaintsCompanion(
              projectId: Value(projectId),
              brand: Value(brand),
              code: Value(code),
              name: Value(name),
              hex: Value(hex),
              addedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );

  Future<void> deleteProjectPaint(int id) =>
      (_db.delete(_db.projectPaints)..where((t) => t.id.equals(id))).go();

  // Controlla se una vernice (brand+code) è nell'inventario dell'utente.
  Future<bool> isPaintInInventory(String brand, String code) async {
    final row = await (_db.select(_db.inventoryPaints)
          ..where((t) =>
              t.catalogBrand.equals(brand) & t.catalogCode.equals(code)))
        .getSingleOrNull();
    return row != null;
  }

  // ── Progetti che usano una o più vernici della ricetta ───────────────────

  Stream<List<Project>> watchProjectsUsingRecipe(int recipeId) {
    const sql = '''
      SELECT DISTINCT p.*
      FROM projects p
      JOIN project_paints pp ON pp.project_id = p.id
      WHERE pp.brand = 'ricetta' AND pp.code = ?
      ORDER BY p.updated_at DESC
    ''';
    return _db.customSelect(sql,
        variables: [Variable.withString(recipeId.toString())],
        readsFrom: {_db.projects, _db.projectPaints}).watch().map((rows) =>
        rows.map((r) => Project(
              id: r.read<int>('id'),
              name: r.read<String>('name'),
              brand: r.readNullable<String>('brand'),
              scale: r.readNullable<String>('scale'),
              category: r.readNullable<String>('category'),
              coverPhoto: r.readNullable<String>('cover_photo'),
              status: r.read<String>('status'),
              notes: r.readNullable<String>('notes'),
              createdAt: r.read<int>('created_at'),
              updatedAt: r.read<int>('updated_at'),
            )).toList());
  }

  Stream<List<Project>> watchProjectsUsingPaints(
      List<({String brand, String code})> paints) {
    if (paints.isEmpty) return Stream.value([]);
    final conditions =
        paints.map((_) => '(pp.brand = ? AND pp.code = ?)').join(' OR ');
    final args = paints.expand((p) => [p.brand, p.code]).toList();
    final sql = '''
      SELECT DISTINCT p.*
      FROM projects p
      JOIN project_paints pp ON pp.project_id = p.id
      WHERE $conditions
      ORDER BY p.updated_at DESC
    ''';
    return _db.customSelect(sql,
        variables: args.map(Variable.withString).toList(),
        readsFrom: {_db.projects, _db.projectPaints}).watch().map((rows) =>
        rows.map((r) => Project(
              id: r.read<int>('id'),
              name: r.read<String>('name'),
              brand: r.readNullable<String>('brand'),
              scale: r.readNullable<String>('scale'),
              category: r.readNullable<String>('category'),
              coverPhoto: r.readNullable<String>('cover_photo'),
              status: r.read<String>('status'),
              notes: r.readNullable<String>('notes'),
              createdAt: r.read<int>('created_at'),
              updatedAt: r.read<int>('updated_at'),
            )).toList());
  }

  // ── Lista della spesa — voci manuali ─────────────────────────────────────

  Stream<List<ShoppingItem>> watchShoppingItems() =>
      (_db.select(_db.shoppingItems)
            ..orderBy([(t) => OrderingTerm.asc(t.done),
                       (t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<void> addShoppingItem(String label, {String? notes}) =>
      _db.into(_db.shoppingItems).insert(ShoppingItemsCompanion(
            label: Value(label),
            notes: Value(notes),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));

  Future<void> toggleShoppingItem(int id, bool done) =>
      (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id)))
          .write(ShoppingItemsCompanion(done: Value(done)));

  Future<void> deleteShoppingItem(int id) =>
      (_db.delete(_db.shoppingItems)..where((t) => t.id.equals(id))).go();

  // ── Lista della spesa — vernici automatiche ───────────────────────────────
  // Tutte le project_paints non presenti in inventory_paints, con il nome
  // del progetto. Si aggiorna automaticamente quando cambia inventario o palette.
  Stream<List<ShoppingEntry>> watchShoppingList() {
    const sql = '''
      SELECT pp.brand, pp.code, pp.name, pp.hex, p.name AS project_name
      FROM project_paints pp
      JOIN projects p ON pp.project_id = p.id
      WHERE pp.exclude_from_shopping = 0
        AND NOT EXISTS (
          SELECT 1 FROM inventory_paints ip
          WHERE ip.catalog_brand = pp.brand AND ip.catalog_code = pp.code
        )
      ORDER BY p.name, pp.brand, pp.code
    ''';
    return _db.customSelect(sql, readsFrom: {
      _db.projectPaints,
      _db.projects,
      _db.inventoryPaints,
    }).watch().map((rows) => rows
        .map((r) => ShoppingEntry(
              brand: r.read<String>('brand'),
              code: r.read<String>('code'),
              name: r.read<String>('name'),
              hex: r.read<String>('hex'),
              projectName: r.read<String>('project_name'),
            ))
        .toList());
  }

  Stream<List<ShoppingEntry>> watchExcludedShoppingPaints() {
    const sql = '''
      SELECT pp.brand, pp.code, pp.name, pp.hex, p.name AS project_name
      FROM project_paints pp
      JOIN projects p ON pp.project_id = p.id
      WHERE pp.exclude_from_shopping = 1
        AND NOT EXISTS (
          SELECT 1 FROM inventory_paints ip
          WHERE ip.catalog_brand = pp.brand AND ip.catalog_code = pp.code
        )
      ORDER BY p.name, pp.brand, pp.code
    ''';
    return _db.customSelect(sql, readsFrom: {
      _db.projectPaints,
      _db.projects,
      _db.inventoryPaints,
    }).watch().map((rows) => rows
        .map((r) => ShoppingEntry(
              brand: r.read<String>('brand'),
              code: r.read<String>('code'),
              name: r.read<String>('name'),
              hex: r.read<String>('hex'),
              projectName: r.read<String>('project_name'),
            ))
        .toList());
  }

  Future<void> setShoppingExclusion(String brand, String code, {required bool excluded}) {
    return (_db.update(_db.projectPaints)
          ..where((pp) => pp.brand.equals(brand) & pp.code.equals(code)))
        .write(ProjectPaintsCompanion(
          excludeFromShopping: Value(excluded),
        ));
  }
}

class ShoppingEntry {
  final String brand;
  final String code;
  final String name;
  final String hex;
  final String projectName;
  const ShoppingEntry({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.projectName,
  });
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
