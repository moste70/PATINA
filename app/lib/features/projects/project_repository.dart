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
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
