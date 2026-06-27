import 'package:drift/drift.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get scale => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get coverPhoto => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

class ProjectPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get path => text()();
  TextColumn get caption => text().nullable()();
  IntColumn get takenAt => integer().nullable()();
}
