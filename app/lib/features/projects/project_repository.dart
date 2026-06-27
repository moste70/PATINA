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
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
