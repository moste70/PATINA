import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

const supportedBrands = [
  'Tamiya',
  'Vallejo',
  'Gunze',
  'Humbrol',
  'Lifecolor',
];

// ── Catalog data ──────────────────────────────────────────────────────────────

const _catalogAssets = <(String, String)>[
  ('assets/catalogs/tamiya_xf.json',          'Tamiya XF'),
  ('assets/catalogs/tamiya_x.json',           'Tamiya X'),
  ('assets/catalogs/tamiya_lp.json',          'Tamiya LP'),
  ('assets/catalogs/tamiya_ts.json',          'Tamiya TS'),
  ('assets/catalogs/vallejo_model_color.json','Vallejo Model Color'),
  ('assets/catalogs/vallejo_model_air.json',  'Vallejo Model Air'),
  ('assets/catalogs/gunze_mr_color.json',     'Gunze Mr. Color'),
  ('assets/catalogs/gunze_aqueous.json',      'Gunze Aqueous'),
  ('assets/catalogs/gunze_mr_metal.json',     'Gunze Mr. Metal'),
  ('assets/catalogs/humbrol_enamel.json',     'Humbrol'),
  ('assets/catalogs/lifecolor_lc.json',       'Lifecolor LC'),
  ('assets/catalogs/lifecolor_ua.json',       'Lifecolor UA'),
];

// ── Regex patterns ────────────────────────────────────────────────────────────

final _patterns = <({RegExp re, int group})>[
  (re: RegExp(r'\b(XF|AS|TS|LP)-\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\bX-\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\b(70|71|72|73|74|75|76|77|78|79)\.\d{3}\b'), group: 0),
  (re: RegExp(r'\b[CH]\d{1,3}\b', caseSensitive: false), group: 0),
  (re: RegExp(r'\bHumbrol\s+(\d{1,3})\b', caseSensitive: false), group: 1),
  (re: RegExp(r'\b(LC|UA)-?\d{1,3}\b', caseSensitive: false), group: 0),
];

Set<String> _extractCodes(String text) {
  final codes = <String>{};
  for (final p in _patterns) {
    for (final m in p.re.allMatches(text)) {
      final raw = (p.group == 0 ? m.group(0) : m.group(p.group))
          ?.toUpperCase()
          .trim();
      if (raw != null) codes.add(raw);
    }
  }
  return codes;
}

// ── Scan state (streamed) ─────────────────────────────────────────────────────

sealed class ScanState {}

class ScanStateOcr extends ScanState {}

class ScanStateCatalog extends ScanState {
  final String catalogName;
  final int current;
  final int total;
  final List<ScanPaintResult> found;
  ScanStateCatalog(
      {required this.catalogName,
      required this.current,
      required this.total,
      required this.found});
}

class ScanStateDone extends ScanState {
  final List<ScanPaintResult> results;
  ScanStateDone(this.results);
}

class ScanStateError extends ScanState {
  final String message;
  ScanStateError(this.message);
}

// ── Stream producer ───────────────────────────────────────────────────────────

Stream<ScanState> _runScan(String imagePath) async* {
  yield ScanStateOcr();

  try {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result =
        await recognizer.processImage(InputImage.fromFilePath(imagePath));
    recognizer.close();

    final codes = _extractCodes(result.text);
    final found = <ScanPaintResult>[];
    final seen = <String>{};

    for (var i = 0; i < _catalogAssets.length; i++) {
      final (asset, label) = _catalogAssets[i];
      yield ScanStateCatalog(
        catalogName: label,
        current: i + 1,
        total: _catalogAssets.length,
        found: List.unmodifiable(found),
      );

      try {
        final raw = await rootBundle.loadString(asset);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final brand = data['brand'] as String;
        for (final p in data['paints'] as List<dynamic>) {
          final code = (p['code'] as String).toUpperCase();
          final key = '${brand.toUpperCase()}|$code';
          if (codes.contains(code) && !seen.contains(key)) {
            found.add(ScanPaintResult(
              brand: brand,
              code: p['code'] as String,
              name: p['name'] as String,
              hex: p['hex'] as String,
            ));
            seen.add(key);
          }
        }
      } catch (_) {}

      // Emit updated state with new matches
      yield ScanStateCatalog(
        catalogName: label,
        current: i + 1,
        total: _catalogAssets.length,
        found: List.unmodifiable(found),
      );
    }

    yield ScanStateDone(found);
  } catch (e) {
    yield ScanStateError(e.toString());
  }
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Apre la fotocamera e mostra il bottom sheet di scansione progressiva.
/// Chiama [onComplete] con i risultati trovati quando finisce.
Future<void> showScanSheet(
  BuildContext context, {
  required Future<void> Function(List<ScanPaintResult>) onComplete,
}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );
  if (file == null || !context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useRootNavigator: true,
    builder: (ctx) => _ScanSheet(
      imagePath: file.path,
      onComplete: onComplete,
    ),
  );
}

// ── Scan progress bottom sheet ────────────────────────────────────────────────

class _ScanSheet extends StatefulWidget {
  final String imagePath;
  final Future<void> Function(List<ScanPaintResult>) onComplete;
  const _ScanSheet({required this.imagePath, required this.onComplete});

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  StreamSubscription<ScanState>? _sub;
  ScanState _state = ScanStateOcr();
  bool _inserting = false;

  @override
  void initState() {
    super.initState();
    _sub = _runScan(widget.imagePath).listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state is ScanStateDone) {
        _finalize(state.results);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _finalize(List<ScanPaintResult> results) async {
    if (_inserting) return;
    setState(() => _inserting = true);
    await widget.onComplete(results);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.85,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _buildHeader(scheme, tt),
            ),
            const Divider(height: 1),
            // Found paints list
            Expanded(
              child: _buildResultsList(scheme, tt, scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, TextTheme tt) {
    return switch (_state) {
      ScanStateOcr() => Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Text('Analisi del testo…', style: tt.titleSmall),
          ],
        ),
      ScanStateCatalog(
        catalogName: final label,
        current: final cur,
        total: final tot,
        found: final found,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                    value: cur / tot,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ricerca in $label…',
                    style: tt.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$cur/$tot',
                  style: tt.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (found.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${found.length} vernic${found.length == 1 ? 'e trovata' : 'i trovate'}',
                style: tt.bodySmall
                    ?.copyWith(color: const Color(0xFF2F8F57)),
              ),
            ],
          ],
        ),
      ScanStateDone(results: final r) => Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: const Color(0xFF2F8F57), size: 20),
            const SizedBox(width: 10),
            Text(
              r.isEmpty
                  ? 'Nessun codice riconosciuto'
                  : '${r.length} vernic${r.length == 1 ? 'e aggiunta' : 'i aggiunte'}',
              style: tt.titleSmall,
            ),
          ],
        ),
      ScanStateError(message: final msg) => Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Errore: $msg',
                    style: tt.bodySmall?.copyWith(color: scheme.error))),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildResultsList(
      ColorScheme scheme, TextTheme tt, ScrollController ctrl) {
    final found = switch (_state) {
      ScanStateCatalog(found: final f) => f,
      ScanStateDone(results: final r) => r,
      _ => const <ScanPaintResult>[],
    };

    if (found.isEmpty) {
      return Center(
        child: Text(
          _state is ScanStateOcr
              ? 'Lettura del foglio in corso…'
              : 'Nessuna corrispondenza nei cataloghi supportati',
          style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      controller: ctrl,
      itemCount: found.length,
      itemBuilder: (_, i) {
        final p = found[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hexColor(p.hex),
              shape: BoxShape.circle,
              border:
                  Border.all(color: scheme.outline.withOpacity(0.4), width: 1),
            ),
          ),
          title: Text(
            '${p.code}  ${p.name}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 12, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(p.brand, style: tt.bodySmall),
        );
      },
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
