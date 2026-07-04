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
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
