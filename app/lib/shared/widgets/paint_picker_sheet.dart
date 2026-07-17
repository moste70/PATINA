import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import 'hex_color_chip.dart';

// ── Types ─────────────────────────────────────────────────────────────────────

class PaintSelection {
  final String brand;
  final String code;
  final String name;
  final String hex;
  final String line;
  const PaintSelection({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.line,
  });
}

class _Entry {
  final String brand, line, code, name, hex;
  const _Entry({
    required this.brand,
    required this.line,
    required this.code,
    required this.name,
    required this.hex,
  });
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kAssets = [
  'assets/catalogs/tamiya_xf.json',
  'assets/catalogs/tamiya_x.json',
  'assets/catalogs/tamiya_lp.json',
  'assets/catalogs/tamiya_ts.json',
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

String _brandLabel(String brand) => switch (brand) {
      'tamiya'    => 'Tamiya',
      'vallejo'   => 'Vallejo',
      'citadel'   => 'Citadel',
      'gunze'     => 'Gunze',
      'humbrol'   => 'Humbrol',
      'lifecolor' => 'LifeColor',
      _           => brand.toUpperCase(),
    };

Color _hexColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

Future<PaintSelection?> showPaintPickerSheet(BuildContext context) {
  return showModalBottomSheet<PaintSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _PaintPickerSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _PaintPickerSheet extends StatefulWidget {
  const _PaintPickerSheet();

  @override
  State<_PaintPickerSheet> createState() => _PaintPickerSheetState();
}

class _PaintPickerSheetState extends State<_PaintPickerSheet> {
  final _searchCtrl = TextEditingController();
  String? _brand;
  String? _line;
  String _query = '';

  // All entries, keyed brand→line→[entries]
  Map<String, Map<String, List<_Entry>>> _index = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final index = <String, Map<String, List<_Entry>>>{};
    for (final asset in _kAssets) {
      try {
        final raw = await rootBundle.loadString(asset);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final brand = data['brand'] as String;
        final line = data['line'] as String? ?? '';
        final paints = data['paints'] as List<dynamic>;
        for (final p in paints) {
          final m = p as Map<String, dynamic>;
          final entry = _Entry(
            brand: brand,
            line: line,
            code: m['code'] as String,
            name: m['name'] as String? ?? '',
            hex: m['hex'] as String? ?? '#808080',
          );
          index.putIfAbsent(brand, () => {}).putIfAbsent(line, () => []).add(entry);
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _index = index; _loading = false; });
  }

  List<_Entry> _filtered() {
    final q = _query.trim().toLowerCase();
    var entries = <_Entry>[];
    if (_brand != null) {
      final byLine = _index[_brand] ?? {};
      if (_line != null) {
        entries = byLine[_line] ?? [];
      } else {
        for (final list in byLine.values) {
          entries.addAll(list);
        }
      }
      entries = List.of(entries)..sort((a, b) => a.code.compareTo(b.code));
    }
    if (q.isNotEmpty) {
      if (_brand == null) {
        for (final byLine in _index.values) {
          for (final list in byLine.values) {
            entries.addAll(list);
          }
        }
      }
      entries = entries
          .where((e) =>
              e.code.toLowerCase().contains(q) ||
              e.name.toLowerCase().contains(q) ||
              e.brand.toLowerCase().contains(q))
          .take(80)
          .toList();
    }
    return entries;
  }

  List<String> _lines() {
    if (_brand == null) return [];
    return (_index[_brand] ?? {}).keys.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brands = _index.keys.toList()..sort();
    final lines = _lines();
    final entries = _filtered();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title + search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: l.catalogEmptyPrompt,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // Brand filter
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: l.filterAllLines,
                  active: _brand == null,
                  scheme: scheme,
                  onTap: () => setState(() { _brand = null; _line = null; }),
                ),
                ...brands.map((b) => _Chip(
                      label: _brandLabel(b),
                      active: _brand == b,
                      scheme: scheme,
                      onTap: () => setState(() {
                        _brand = b;
                        _line = null;
                      }),
                    )),
              ],
            ),
          ),
          // Line subfilter
          if (_brand != null && lines.length > 1)
            SizedBox(
              height: 36,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(
                    label: l.filterAllLines,
                    active: _line == null,
                    scheme: scheme,
                    onTap: () => setState(() => _line = null),
                  ),
                  ...lines.map((ln) => _Chip(
                        label: l.paintLineLabel(ln),
                        active: _line == ln,
                        scheme: scheme,
                        onTap: () => setState(() => _line = ln),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _brand == null && _query.isEmpty
                    ? Center(
                        child: Text(
                          l.catalogEmptyPrompt,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : entries.isEmpty
                        ? Center(child: Text(l.searchNoResults))
                        : _EntryList(
                            entries: entries,
                            brand: _brand,
                            scrollCtrl: scroll,
                            onSelected: (e) =>
                                Navigator.of(ctx).pop(PaintSelection(
                              brand: e.brand,
                              code: e.code,
                              name: e.name,
                              hex: e.hex,
                              line: e.line,
                            )),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Entry list ────────────────────────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  final List<_Entry> entries;
  final String? brand;
  final ScrollController scrollCtrl;
  final void Function(_Entry) onSelected;

  const _EntryList({
    required this.entries,
    required this.brand,
    required this.scrollCtrl,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Group by line (brand selected) or by brand
    final groups = <String, List<_Entry>>{};
    for (final e in entries) {
      final key = brand != null ? e.line : e.brand;
      groups.putIfAbsent(key, () => []).add(e);
    }
    final flat = <Object>[];
    for (final g in groups.keys) {
      flat.add(g);
      flat.addAll(groups[g]!);
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final item = flat[i];
        if (item is String) {
          final l = AppL10n.of(ctx);
          final label = brand != null
              ? l.paintLineLabel(item).toUpperCase()
              : _brandLabel(item).toUpperCase();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          );
        }
        final e = item as _Entry;
        return ListTile(
          leading: HexColorChip(color: _hexColor(e.hex), size: 32),
          title: Text(
            '${e.code}  ${e.name}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            brand == null ? _brandLabel(e.brand) : '',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            onSelected(e);
          },
        );
      },
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
