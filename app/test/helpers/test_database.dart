// Helper condiviso tra i test: apre un AppDatabase in memoria (SQLite).
// Richiede app_database.g.dart generato — vedi istruzioni in README.

import 'package:drift/native.dart';
import 'package:patina/database/app_database.dart';

/// Ritorna un database Drift in-memory isolato, ideale per i test.
/// Chiudere sempre il DB nel tearDown: await db.close();
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());
