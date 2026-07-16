import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

// ── BackupService ─────────────────────────────────────────────────────────────
//
// Format of the ZIP:
//   patina_backup_<timestamp>/
//     patina_db           ← raw SQLite file
//     photos/             ← all referenced image files, flat (basename only)
//
// On import the ZIP is extracted to a temp dir, then:
//   - patina_db  → replaces the live DB file (app must restart)
//   - photos/*   → copied to the app documents dir, preserving basenames

class BackupService {
  // Drift stores the DB here on Android/iOS.
  static Future<File> _dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'patina_db'));
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  static Future<void> exportBackup() async {
    final dbFile = await _dbFile();
    if (!dbFile.existsSync()) throw Exception('Database file not found');

    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();

    final ts = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(tempDir.path, 'patina_backup_$ts.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // Add the raw DB file.
    encoder.addFile(dbFile, 'patina_db');

    // Collect all image files referenced anywhere inside the docs dir.
    final photosInDocs = docsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.jpg') ||
            f.path.endsWith('.jpeg') ||
            f.path.endsWith('.png'))
        .toList();

    for (final img in photosInDocs) {
      if (img.existsSync()) {
        encoder.addFile(img, 'photos/${p.basename(img.path)}');
      }
    }

    encoder.close();

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipPath)],
        subject: 'Patina backup',
      ),
    );
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Returns true if import succeeded, false if user cancelled.
  static Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return false;

    final zipPath = result.files.single.path!;
    await compute(_extractAndReplace, zipPath);
    return true;
  }

  // Runs in an isolate to avoid blocking the UI during extraction.
  static Future<void> _extractAndReplace(String zipPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(p.join(tempDir.path, 'patina_import_${DateTime.now().millisecondsSinceEpoch}'));
    extractDir.createSync(recursive: true);

    // Decode ZIP.
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outPath = p.join(extractDir.path, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      }
    }

    // Replace DB.
    final importedDb = File(p.join(extractDir.path, 'patina_db'));
    if (importedDb.existsSync()) {
      final liveDb = File(p.join(docsDir.path, 'patina_db'));
      importedDb.copySync(liveDb.path);
    }

    // Copy photos.
    final importedPhotosDir = Directory(p.join(extractDir.path, 'photos'));
    if (importedPhotosDir.existsSync()) {
      for (final f in importedPhotosDir.listSync().whereType<File>()) {
        final dest = File(p.join(docsDir.path, p.basename(f.path)));
        f.copySync(dest.path);
      }
    }

    // Cleanup temp extraction dir.
    extractDir.deleteSync(recursive: true);
  }
}
