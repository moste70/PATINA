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
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
