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
  // drift_flutter usa getApplicationDocumentsDirectory() su tutte le piattaforme.
  // Su Android il path reale è <documents>/patina_db — verifica anche <support>/patina_db
  // come fallback nel caso in cui la versione del package cambi comportamento.
  static Future<File> _dbFile() async {
    final candidates = <File>[];

    final docsDir = await getApplicationDocumentsDirectory();
    final base = Platform.isAndroid ? docsDir.parent.path : docsDir.path;

    for (final name in ['patina_db', 'patina_db.db', 'patina_db.sqlite']) {
      candidates.add(File(p.join(docsDir.path, name)));
      if (Platform.isAndroid) {
        candidates.add(File(p.join(base, 'databases', name)));
        candidates.add(File(p.join(base, 'files', name)));
        candidates.add(File(p.join(base, 'app_flutter', name)));
      }
    }

    if (Platform.isAndroid) {
      final supportDir = await getApplicationSupportDirectory();
      for (final name in ['patina_db', 'patina_db.db']) {
        candidates.add(File(p.join(supportDir.path, name)));
      }
    }

    for (final f in candidates) {
      if (f.existsSync()) return f;
    }

    // In debug, stampa tutti i file trovati nelle directory candidate per diagnosi
    String debugInfo = '';
    if (kDebugMode) {
      final dirs = {docsDir.path, if (Platform.isAndroid) ...['$base/databases', '$base/files', '$base/app_flutter']};
      for (final d in dirs) {
        try {
          final entries = Directory(d).listSync().map((e) => p.basename(e.path)).join(', ');
          debugInfo += '\n  $d: [$entries]';
        } catch (_) {}
      }
    }
    throw Exception('Database not found.$debugInfo');
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

    await Share.shareXFiles(
      [XFile(zipPath)],
      subject: 'Patina backup',
    );
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Returns true if import succeeded, false if user cancelled.
  static Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: false,
      withReadStream: false,
    );
    if (result == null) return false;

    final pickedFile = result.files.single;

    // Su Android il path può essere null se il file è un content:// URI.
    // In quel caso copiamo i bytes in un file temporaneo.
    String zipPath;
    if (pickedFile.path != null) {
      zipPath = pickedFile.path!;
    } else if (pickedFile.bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'patina_import_tmp.zip'));
      await tempFile.writeAsBytes(pickedFile.bytes!);
      zipPath = tempFile.path;
    } else {
      // Riprova con bytes abilitati
      final result2 = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result2 == null || result2.files.single.bytes == null) return false;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'patina_import_tmp.zip'));
      await tempFile.writeAsBytes(result2.files.single.bytes!);
      zipPath = tempFile.path;
    }

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

    // Replace DB — copia nel path reale dove _dbFile() ha trovato il DB esistente.
    // Se non esiste ancora (primo import su dispositivo nuovo) usa docsDir.
    final importedDb = File(p.join(extractDir.path, 'patina_db'));
    if (importedDb.existsSync()) {
      File? liveDb;
      try {
        liveDb = await _dbFile();
      } catch (_) {
        // DB non trovato — primo avvio o dispositivo nuovo: usa docsDir
        liveDb = File(p.join(docsDir.path, 'patina_db'));
      }
      liveDb.parent.createSync(recursive: true);
      importedDb.copySync(liveDb.path);
    }

    // Copy photos into docsDir (stesso dir dove l'app salva le foto).
    final importedPhotosDir = Directory(p.join(extractDir.path, 'photos'));
    if (importedPhotosDir.existsSync()) {
      for (final f in importedPhotosDir.listSync().whereType<File>()) {
        final dest = File(p.join(docsDir.path, p.basename(f.path)));
        dest.parent.createSync(recursive: true);
        f.copySync(dest.path);
      }
    }

    // Cleanup temp extraction dir.
    extractDir.deleteSync(recursive: true);
  }
}
