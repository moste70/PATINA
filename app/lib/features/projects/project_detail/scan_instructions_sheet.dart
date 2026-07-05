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
  /// true se il codice è stato riconosciuto ma non è presente nel catalogo
  final bool unknownInCatalog;
  const ScanPaintResult({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    this.unknownInCatalog = false,
  });
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

final _patterns = <({RegExp re, int group, String brand})>[
  (re: RegExp(r'\bXF-\d{1,3}\b', caseSensitive: false),  group: 0, brand: 'tamiya'),
  (re: RegExp(r'\bAS-\d{1,3}\b', caseSensitive: false),  group: 0, brand: 'tamiya'),
  (re: RegExp(r'\bTS-\d{1,3}\b', caseSensitive: false),  group: 0, brand: 'tamiya'),
  (re: RegExp(r'\bLP-\d{1,3}\b', caseSensitive: false),  group: 0, brand: 'tamiya'),
  (re: RegExp(r'\bX-\d{1,3}\b',  caseSensitive: false),  group: 0, brand: 'tamiya'),
  (re: RegExp(r'\b(70|71|72|73|74|75|76|77|78|79)\.\d{3}\b'), group: 0, brand: 'vallejo'),
  (re: RegExp(r'\bC\d{1,3}\b',   caseSensitive: false),  group: 0, brand: 'gunze'),
  (re: RegExp(r'\bH\d{1,3}\b',   caseSensitive: false),  group: 0, brand: 'gunze'),
  (re: RegExp(r'\bHumbrol\s+(\d{1,3})\b', caseSensitive: false), group: 1, brand: 'humbrol'),
  (re: RegExp(r'\bLC-?\d{1,3}\b', caseSensitive: false), group: 0, brand: 'lifecolor'),
  (re: RegExp(r'\bUA-?\d{1,3}\b', caseSensitive: false), group: 0, brand: 'lifecolor'),
];

// code → brand
Map<String, String> _extractCodesWithBrand(String text) {
  final codes = <String, String>{};
  for (final p in _patterns) {
    for (final m in p.re.allMatches(text)) {
      final raw = (p.group == 0 ? m.group(0) : m.group(p.group))
          ?.toUpperCase()
          .trim();
      if (raw != null && !codes.containsKey(raw)) {
        codes[raw] = p.brand;
      }
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
  ScanStateCatalog({
    required this.catalogName,
    required this.current,
    required this.total,
    required this.found,
  });
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

    final codeMap = _extractCodesWithBrand(result.text); // code → brand
    final matched = <ScanPaintResult>[];
    final seen = <String>{};

    for (var i = 0; i < _catalogAssets.length; i++) {
      final (asset, label) = _catalogAssets[i];
      yield ScanStateCatalog(
        catalogName: label,
        current: i + 1,
        total: _catalogAssets.length,
        found: List.unmodifiable(matched),
      );

      try {
        final raw = await rootBundle.loadString(asset);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final brand = data['brand'] as String;
        for (final p in data['paints'] as List<dynamic>) {
          final code = (p['code'] as String).toUpperCase();
          final key = '${brand.toUpperCase()}|$code';
          if (codeMap.containsKey(code) && !seen.contains(key)) {
            matched.add(ScanPaintResult(
              brand: brand,
              code: p['code'] as String,
              name: p['name'] as String,
              hex: p['hex'] as String,
            ));
            seen.add(key);
            // mark as resolved
            codeMap.remove(code);
          }
        }
      } catch (_) {}

      yield ScanStateCatalog(
        catalogName: label,
        current: i + 1,
        total: _catalogAssets.length,
        found: List.unmodifiable(matched),
      );
    }

    // Codici riconosciuti ma non trovati in nessun catalogo
    for (final entry in codeMap.entries) {
      matched.add(ScanPaintResult(
        brand: entry.value,
        code: entry.key,
        name: 'Non in catalogo',
        hex: '#808080',
        unknownInCatalog: true,
      ));
    }

    yield ScanStateDone(matched);
  } catch (e) {
    yield ScanStateError(e.toString());
  }
}

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showScanSheet(
  BuildContext context, {
  required Future<void> Function(List<ScanPaintResult>) onComplete,
}) async {
  // Prima mostra le istruzioni su come scattare la foto
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (ctx) => const _TipsSheet(),
  );
  if (proceed != true || !context.mounted) return;

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

// ── Tips sheet ────────────────────────────────────────────────────────────────

class _TipsSheet extends StatelessWidget {
  const _TipsSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Come fotografare il foglio', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Per ottenere il miglior riconoscimento automatico dei colori:',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _Tip(
            icon: Icons.stay_current_portrait,
            label: 'Tieni il telefono verticale',
            detail: 'Orienta il dispositivo in portrait — le tabelle colori sono solitamente orizzontali sul foglio e leggibili meglio così.',
            scheme: scheme, tt: tt,
          ),
          _Tip(
            icon: Icons.crop_free,
            label: 'Inquadra solo la tabella colori',
            detail: 'Avvicinati fino a far occupare la tabella l\'intera schermata. Meno testo inutile = meno errori.',
            scheme: scheme, tt: tt,
          ),
          _Tip(
            icon: Icons.wb_sunny_outlined,
            label: 'Buona illuminazione, senza riflessi',
            detail: 'Evita ombre sul foglio e riflessi della luce. La luce naturale o una lampada da tavolo funzionano bene.',
            scheme: scheme, tt: tt,
          ),
          _Tip(
            icon: Icons.warning_amber_outlined,
            label: 'Marche riconosciute',
            detail: 'Tamiya (XF, X, LP, TS) · Vallejo · Gunze · Humbrol · Lifecolor.\nCitadel usa nomi testuali e non viene riconosciuta automaticamente.',
            scheme: scheme, tt: tt,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scatta foto'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final ColorScheme scheme;
  final TextTheme tt;
  const _Tip({
    required this.icon,
    required this.label,
    required this.detail,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: tt.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      if (state is ScanStateDone) _finalize(state.results);
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

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: _buildHeader(scheme, tt),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResultsList(scheme, tt, scrollCtrl)),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, TextTheme tt) {
    return switch (_state) {
      ScanStateOcr() => Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Text('Analisi del testo…', style: tt.titleSmall),
        ]),
      ScanStateCatalog(
        catalogName: final label,
        current: final cur,
        total: final tot,
        found: final found,
      ) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
                value: cur / tot,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Ricerca in $label…',
                  style: tt.titleSmall, overflow: TextOverflow.ellipsis),
            ),
            Text('$cur/$tot',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          if (found.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${found.length} vernic${found.length == 1 ? 'e trovata' : 'i trovate'}',
              style: tt.bodySmall?.copyWith(color: const Color(0xFF2F8F57)),
            ),
          ],
        ]),
      ScanStateDone(results: final r) => Row(children: [
          Icon(Icons.check_circle_outline,
              color: const Color(0xFF2F8F57), size: 20),
          const SizedBox(width: 10),
          Text(
            r.isEmpty
                ? 'Nessun codice riconosciuto'
                : '${r.length} vernic${r.length == 1 ? 'e aggiunta' : 'i aggiunte'}',
            style: tt.titleSmall,
          ),
        ]),
      ScanStateError(message: final msg) => Row(children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Errore: $msg',
                  style: tt.bodySmall?.copyWith(color: scheme.error))),
        ]),
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
              : 'Nessuna corrispondenza trovata',
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
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hexColor(p.hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: p.unknownInCatalog
                    ? scheme.outline
                    : scheme.outline.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: p.unknownInCatalog
                ? Icon(Icons.question_mark, size: 14, color: scheme.onSurfaceVariant)
                : null,
          ),
          title: Text(
            '${p.code}  ${p.name}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: p.unknownInCatalog ? scheme.onSurfaceVariant : null,
            ),
          ),
          subtitle: Text(
            p.unknownInCatalog ? '${p.brand} · non in catalogo' : p.brand,
            style: tt.bodySmall?.copyWith(
              color: p.unknownInCatalog ? scheme.error.withOpacity(0.7) : null,
            ),
          ),
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
