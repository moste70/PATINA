import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

// ── Public result type ────────────────────────────────────────────────────────

class ScanPaintResult {
  final String brand;
  final String code;
  final String name;
  final String hex;
  const ScanPaintResult(
      {required this.brand,
      required this.code,
      required this.name,
      required this.hex});
}

// Marche supportate dal riconoscimento automatico
const supportedBrands = [
  'Tamiya',
  'Vallejo',
  'Gunze',
  'Humbrol',
  'Lifecolor',
];

// ── Catalog index ─────────────────────────────────────────────────────────────

const _catalogAssets = [
  'assets/catalogs/tamiya_xf.json',
  'assets/catalogs/tamiya_x.json',
  'assets/catalogs/vallejo_model_color.json',
  'assets/catalogs/vallejo_model_air.json',
  'assets/catalogs/gunze_mr_color.json',
  'assets/catalogs/gunze_aqueous.json',
  'assets/catalogs/gunze_mr_metal.json',
  'assets/catalogs/humbrol_enamel.json',
  'assets/catalogs/lifecolor_lc.json',
  'assets/catalogs/lifecolor_ua.json',
];

Future<Map<String, ScanPaintResult>> _buildIndex() async {
  final index = <String, ScanPaintResult>{};
  for (final asset in _catalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      for (final p in data['paints'] as List<dynamic>) {
        final code = (p['code'] as String).toUpperCase();
        index['${brand.toUpperCase()}|$code'] = ScanPaintResult(
          brand: brand,
          code: p['code'] as String,
          name: p['name'] as String,
          hex: p['hex'] as String,
        );
      }
    } catch (_) {}
  }
  return index;
}

// ── Regex patterns ────────────────────────────────────────────────────────────

final _patterns = <({RegExp re, int group})>[
  (re: RegExp(r'\b(XF|AS|TS|LP)-\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\bX-\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\b(70|71|72|73|74|75|76|77|78|79)\.\d{3}\b'), group: 0),
  (re: RegExp(r'\b[CH]\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\bHumbrol\s+(\d{1,3})\b', caseSensitive: false), group: 1),
  (re: RegExp(r'\b(LC|UA)-?\d{1,3}\b', caseSensitive: false), group: 0),
];

List<String> _extractCodes(String text) {
  final codes = <String>{};
  for (final p in _patterns) {
    for (final m in p.re.allMatches(text)) {
      final raw = (p.group == 0 ? m.group(0) : m.group(p.group))
          ?.toUpperCase()
          .trim();
      if (raw != null) codes.add(raw);
    }
  }
  return codes.toList();
}

List<ScanPaintResult> _matchEntries(
    List<String> codes, Map<String, ScanPaintResult> index) {
  final found = <ScanPaintResult>[];
  final seen = <String>{};
  for (final code in codes) {
    for (final key in index.keys) {
      if (key.endsWith('|$code') && !seen.contains(key)) {
        found.add(index[key]!);
        seen.add(key);
        break;
      }
    }
  }
  return found;
}

// ── Public API ────────────────────────────────────────────────────────────────
// Apre la fotocamera, esegue l'OCR e restituisce le vernici trovate.
// Restituisce null se l'utente annulla o si verifica un errore.
// Restituisce [] se nessun codice è stato riconosciuto.

Future<List<ScanPaintResult>?> scanKitInstructions(
    BuildContext context) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );
  if (file == null) return null;
  if (!context.mounted) return null;

  // Processing dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Analisi in corso…'),
        ],
      ),
    ),
  );

  try {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result =
        await recognizer.processImage(InputImage.fromFilePath(file.path));
    recognizer.close();

    final codes = _extractCodes(result.text);
    final index = await _buildIndex();
    final matches = _matchEntries(codes, index);

    if (context.mounted) Navigator.pop(context); // chiudi loading
    return matches;
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione: $e')),
      );
    }
    return null;
  }
}
