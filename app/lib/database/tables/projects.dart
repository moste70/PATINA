import 'package:drift/drift.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get scale => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get coverPhoto => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('idea'))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

class ProjectPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get path => text()();
  TextColumn get caption => text().nullable()();
  IntColumn get phaseId => integer().nullable()();
  IntColumn get takenAt => integer().nullable()();
}

class ProjectPhases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}
