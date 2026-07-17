import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';

class PinRepository {
  final AppDatabase _db;
  PinRepository(this._db);

  Stream<List<Pin>> watchPins(int photoId) =>
      (_db.select(_db.pins)..where((t) => t.photoId.equals(photoId))).watch();

  Future<int> addPin(PinsCompanion pin) => _db.into(_db.pins).insert(pin);

  Future<void> updatePin(int id, PinsCompanion data) =>
      (_db.update(_db.pins)..where((t) => t.id.equals(id))).write(data);

  Future<void> deletePin(int id) =>
      (_db.delete(_db.pins)..where((t) => t.id.equals(id))).go();
}

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(ref.watch(databaseProvider)),
);
