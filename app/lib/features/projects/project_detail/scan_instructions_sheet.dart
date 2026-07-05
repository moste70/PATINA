import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../project_repository.dart';

// ── Catalog data ──────────────────────────────────────────────────────────────

class _CatalogEntry {
  final String brand;
  final String code;
  final String name;
  final String hex;
  const _CatalogEntry(
      {required this.brand,
      required this.code,
      required this.name,
      required this.hex});
}

const _catalogAssets = [
  'assets/catalogs/tamiya_xf.json',
  'assets/catalogs/tamiya_x.json',
  'assets/catalogs/vallejo_model_color.json',
  'assets/catalogs/vallejo_model_air.json',
  'assets/catalogs/citadel_base.json',
  'assets/catalogs/gunze_mr_color.json',
  'assets/catalogs/gunze_aqueous.json',
  'assets/catalogs/gunze_mr_metal.json',
  'assets/catalogs/humbrol_enamel.json',
  'assets/catalogs/lifecolor_lc.json',
  'assets/catalogs/lifecolor_ua.json',
];

Future<Map<String, _CatalogEntry>> _buildCatalogIndex() async {
  final index = <String, _CatalogEntry>{};
  for (final asset in _catalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final paints = data['paints'] as List<dynamic>;
      for (final p in paints) {
        final code = (p['code'] as String).toUpperCase();
        index['${brand.toUpperCase()}|$code'] = _CatalogEntry(
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

// ── Regex patterns per brand ──────────────────────────────────────────────────
// Ogni pattern cattura un codice e il gruppo 0 è il match grezzo.

final _patterns = <_BrandPattern>[
  // Tamiya XF-xx / X-xx / AS-xx / TS-xx / LP-xx
  _BrandPattern(
    brands: ['tamiya'],
    regex: RegExp(r'\b(XF|AS|TS|LP)-\d{1,3}\b', caseSensitive: false),
  ),
  // Tamiya X-xx (single letter, non-XF)
  _BrandPattern(
    brands: ['tamiya'],
    regex: RegExp(r'\bX-\d{1,3}\b', caseSensitive: false),
  ),
  // Vallejo 70.xxx / 71.xxx / 72.xxx
  _BrandPattern(
    brands: ['vallejo'],
    regex: RegExp(r'\b(70|71|72|73|74|75|76|77|78|79)\.\d{3}\b'),
  ),
  // Gunze Mr. Color Cxxx / Hxxx
  _BrandPattern(
    brands: ['gunze'],
    regex: RegExp(r'\b[CH]\d{1,3}\b', caseSensitive: false),
  ),
  // Humbrol xx (numero 1-3 cifre, spesso preceduto da "H" o standalone)
  _BrandPattern(
    brands: ['humbrol'],
    regex: RegExp(r'\bHumbrol\s+(\d{1,3})\b', caseSensitive: false),
    groupIndex: 1,
  ),
  // Lifecolor LC-xxx / UA-xxx
  _BrandPattern(
    brands: ['lifecolor'],
    regex: RegExp(r'\b(LC|UA)-?\d{1,3}\b', caseSensitive: false),
  ),
];

class _BrandPattern {
  final List<String> brands;
  final RegExp regex;
  final int groupIndex; // 0 = whole match, 1+ = capture group
  const _BrandPattern(
      {required this.brands, required this.regex, this.groupIndex = 0});
}

List<String> _extractCodes(String text) {
  final codes = <String>{};
  for (final bp in _patterns) {
    for (final m in bp.regex.allMatches(text)) {
      final raw = (bp.groupIndex == 0 ? m.group(0) : m.group(bp.groupIndex))
          ?.toUpperCase()
          .trim();
      if (raw != null) codes.add(raw);
    }
  }
  return codes.toList();
}

List<_CatalogEntry> _matchEntries(
    List<String> codes, Map<String, _CatalogEntry> index) {
  final found = <_CatalogEntry>[];
  for (final code in codes) {
    for (final key in index.keys) {
      // key = "BRAND|CODE" — controlla se il code estratto corrisponde
      if (key.endsWith('|$code')) {
        found.add(index[key]!);
        break;
      }
    }
  }
  return found;
}

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showScanInstructionsSheet(
    BuildContext context, WidgetRef ref, int projectId) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );
  if (file == null || !context.mounted) return;

  // Show loading dialog while processing
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ProcessingDialog(),
  );

  try {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(file.path);
    final result = await recognizer.processImage(inputImage);
    recognizer.close();

    final fullText = result.text;
    final codes = _extractCodes(fullText);
    final catalogIndex = await _buildCatalogIndex();
    final matches = _matchEntries(codes, catalogIndex);

    if (!context.mounted) return;
    Navigator.pop(context); // chiudi loading

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Nessun codice vernice riconosciuto. Riprova con una foto più nitida.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmSheet(
        matches: matches,
        projectId: projectId,
        ref: ref,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione: $e')),
      );
    }
  }
}

// ── Processing dialog ─────────────────────────────────────────────────────────

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Analisi in corso…'),
        ],
      ),
    );
  }
}

// ── Confirm sheet ─────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  final List<_CatalogEntry> matches;
  final int projectId;
  final WidgetRef ref;
  const _ConfirmSheet(
      {required this.matches, required this.projectId, required this.ref});

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  late final List<bool> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.matches.length, true);
  }

  Future<void> _addSelected() async {
    setState(() => _saving = true);
    final repo = widget.ref.read(projectRepositoryProvider);
    for (var i = 0; i < widget.matches.length; i++) {
      if (!_selected[i]) continue;
      final m = widget.matches[i];
      await repo.addProjectPaint(
        projectId: widget.projectId,
        brand: m.brand,
        code: m.code,
        name: m.name,
        hex: m.hex,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedCount = _selected.where((s) => s).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vernici trovate', style: tt.titleMedium),
                      Text(
                        '${widget.matches.length} codici riconosciuti',
                        style:
                            tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                      () => _selected.fillRange(0, _selected.length, true)),
                  child: const Text('Seleziona tutti'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: widget.matches.length,
              itemBuilder: (_, i) {
                final m = widget.matches[i];
                return CheckboxListTile(
                  value: _selected[i],
                  onChanged: (v) => setState(() => _selected[i] = v ?? false),
                  secondary: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hexColor(m.hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: scheme.outline.withOpacity(0.4), width: 1),
                    ),
                  ),
                  title: Text(
                    '${m.code}  ${m.name}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(m.brand, style: tt.bodySmall),
                );
              },
            ),
          ),
          // Add button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: (_saving || selectedCount == 0) ? null : _addSelected,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: Text(selectedCount == 0
                    ? 'Nessuna selezionata'
                    : 'Aggiungi $selectedCount vernic${selectedCount == 1 ? 'e' : 'i'}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
