import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/hex_color_chip.dart';
import 'recipe_repository.dart';

// ── Catalog helpers (shared with palette) ─────────────────────────────────────

class _CatalogPaint {
  final String brand, line, code, name, hex;
  _CatalogPaint(
      {required this.brand,
      required this.line,
      required this.code,
      required this.name,
      required this.hex});
}

const _catalogAssets = [
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

Future<List<_CatalogPaint>> _loadAllCatalogs() async {
  final result = <_CatalogPaint>[];
  for (final asset in _catalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final line = (data['line'] as String?) ?? '';
      for (final p in data['paints'] as List<dynamic>) {
        result.add(_CatalogPaint(
          brand: brand,
          line: line,
          code: p['code'] as String,
          name: p['name'] as String,
          hex: p['hex'] as String,
        ));
      }
    } catch (_) {}
  }
  return result;
}

// ── Local data models ─────────────────────────────────────────────────────────

class _IngredientDraft {
  final String brand, code, name, hex;
  double percentage;
  _IngredientDraft({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.percentage,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;
  const CreateRecipeScreen({super.key, this.recipe});

  @override
  ConsumerState<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  final _nameCtrl = TextEditingController();
  final _dilutionCtrl = TextEditingController();
  final _surfaceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _finish;
  final List<_IngredientDraft> _ingredients = [];
  bool _saving = false;
  bool _showOptional = false;

  bool get _isEdit => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    if (r != null) {
      _nameCtrl.text = r.name;
      _finish = r.finish;

      _dilutionCtrl.text = r.dilution ?? '';
      _surfaceCtrl.text = r.surface ?? '';
      _notesCtrl.text = r.notes ?? '';
      _tagsCtrl.text = r.tags ?? '';
      // Load existing ingredients
      _loadExistingIngredients(r.id);
    }
  }

  Future<void> _loadExistingIngredients(int recipeId) async {
    final repo = ref.read(recipeRepositoryProvider);
    final existing = await repo.watchIngredients(recipeId).first;
    if (mounted) {
      setState(() {
        _ingredients.addAll(existing.map((i) => _IngredientDraft(
              brand: i.brand ?? '',
              code: i.code ?? '',
              name: i.paintName ?? '',
              hex: i.hex ?? '#888888',
              percentage: i.percentage,
            )));
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dilutionCtrl.dispose();
    _surfaceCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Color get _blendedColor {
    final withHex =
        _ingredients.where((i) => i.hex.isNotEmpty).toList();
    if (withHex.isEmpty) return Colors.grey.shade600;
    return blendColorsInLab(
        withHex.map((i) => (hex: i.hex, weight: i.percentage)).toList());
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    // Warning se le percentuali non sommano a 100%
    if (_ingredients.isNotEmpty) {
      final total = _ingredients.fold<double>(0, (s, i) => s + i.percentage);
      if ((total - 100).abs() > 0.5) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppL10n.of(ctx).recipePercentWarningTitle),
            content: Text(AppL10n.of(ctx).recipePercentWarningBody(total.round())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppL10n.of(ctx).actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppL10n.of(ctx).actionSaveChanges),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    setState(() => _saving = true);

    final repo = ref.read(recipeRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_isEdit) {
        await repo.updateRecipe(
          widget.recipe!.id,
          RecipesCompanion(
            name: Value(name),
            finish: Value(_finish),

            dilution: Value(_dilutionCtrl.text.trim().isEmpty
                ? null
                : _dilutionCtrl.text.trim()),
            surface: Value(_surfaceCtrl.text.trim().isEmpty
                ? null
                : _surfaceCtrl.text.trim()),
            notes: Value(
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
            tags: Value(
                _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim()),
            updatedAt: Value(now),
          ),
        );
        await repo.replaceIngredients(
          widget.recipe!.id,
          _ingredients
              .map((i) => RecipeIngredientsCompanion(
                    recipeId: Value(widget.recipe!.id),
                    brand: Value(i.brand),
                    code: Value(i.code),
                    paintName: Value(i.name),
                    hex: Value(i.hex),
                    percentage: Value(i.percentage),
                  ))
              .toList(),
        );
      } else {
        final id = await repo.createRecipe(RecipesCompanion(
          name: Value(name),
          finish: Value(_finish),
          dilution: Value(_dilutionCtrl.text.trim().isEmpty
              ? null
              : _dilutionCtrl.text.trim()),
          surface: Value(_surfaceCtrl.text.trim().isEmpty
              ? null
              : _surfaceCtrl.text.trim()),
          notes: Value(
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
          tags: Value(
              _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim()),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
        for (final i in _ingredients) {
          await repo.addIngredient(
            recipeId: id,
            brand: i.brand,
            code: i.code,
            paintName: i.name,
            hex: i.hex,
            percentage: i.percentage,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.recipeEdit : l.recipeNew),
        actions: [
          TextButton(
            onPressed: _saving || _nameCtrl.text.trim().isEmpty
                ? null
                : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.actionSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Anteprima colore risultante ────────────────────────────────
          _ColorPreviewWidget(
            blended: _blendedColor,
            hasIngredients: _ingredients.isNotEmpty,
            l: l,
            scheme: scheme,
            tt: tt,
          ),
          const SizedBox(height: 20),

          // ── Nome ───────────────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.recipeNameLabel,
              hintText: l.recipeNameHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // ── Finitura ───────────────────────────────────────────────────
          Text(l.recipeFinishLabel,
              style: tt.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['opaco', 'satinato', 'lucido'].map((f) {
              final selected = _finish == f;
              return ChoiceChip(
                label: Text(l.finishLabel(f)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _finish = selected ? null : f),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 20),

          // ── Ingredienti ────────────────────────────────────────────────
          Row(
            children: [
              Text(
                l.recipeIngredientsSection,
                style: tt.labelSmall?.copyWith(
                    color: scheme.primary, letterSpacing: 1.2),
              ),
              const Spacer(),
              if (_ingredients.isNotEmpty)
                Text(
                  l.recipeIngredientCount(_ingredients.length),
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              Tooltip(
                message: l.recipeAddIngredient,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showIngredientPicker(context, l);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._ingredients.asMap().entries.map((e) {
                final othersTotal = _ingredients
                    .where((i) => i != e.value)
                    .fold(0.0, (s, i) => s + i.percentage);
                final maxVal = (100.0 - othersTotal).clamp(e.value.percentage, 100.0);
                return _IngredientEditRow(
                  key: ObjectKey(e.value),
                  index: e.key,
                  draft: e.value,
                  maxValue: maxVal,
                  scheme: scheme,
                  tt: tt,
                  onPercentageChanged: (v) =>
                      setState(() => e.value.percentage = v),
                  onRemove: () => setState(() => _ingredients.removeAt(e.key)),
                );
              }),
          const SizedBox(height: 20),

          // ── Sezione opzionale ──────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _showOptional = !_showOptional),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${l.recipeDilutionLabel} · ${l.recipeSurfaceLabel} · ${l.recipeNotesLabel}',
                    style: tt.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(
                    _showOptional
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_showOptional) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _dilutionCtrl,
              decoration: InputDecoration(
                labelText: l.recipeDilutionLabel,
                hintText: l.recipeDilutionHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _surfaceCtrl,
              decoration: InputDecoration(
                labelText: l.recipeSurfaceLabel,
                hintText: l.recipeSurfaceHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.recipeNotesLabel,
                hintText: l.recipeNotesHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsCtrl,
              decoration: InputDecoration(
                labelText: l.recipeTagsLabel,
                hintText: l.recipeTagsHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  double get _totalPercentage =>
      _ingredients.fold(0.0, (s, i) => s + i.percentage);

  void _showIngredientPicker(BuildContext context, AppL10n l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IngredientPickerSheet(
        onPick: (p) {
          setState(() {
            final remaining = (100.0 - _totalPercentage).clamp(1.0, 100.0);
            _ingredients.add(_IngredientDraft(
              brand: p.brand,
              code: p.code,
              name: p.name,
              hex: p.hex,
              percentage: remaining,
            ));
          });
        },
      ),
    );
  }
}

// ── Color preview widget ──────────────────────────────────────────────────────

class _ColorPreviewWidget extends StatelessWidget {
  final Color blended;
  final bool hasIngredients;
  final AppL10n l;
  final ColorScheme scheme;
  final TextTheme tt;

  const _ColorPreviewWidget({
    required this.blended,
    required this.hasIngredients,
    required this.l,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: HexColorChip(
              key: ValueKey(blended.value),
              color: blended,
              size: 56,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.recipeBlendedColorLabel,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                hasIngredients
                    ? '#${blended.value.toRadixString(16).substring(2).toUpperCase()}'
                    : '—',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ingredient edit row ───────────────────────────────────────────────────────

class _IngredientEditRow extends StatefulWidget {
  final int index;
  final _IngredientDraft draft;
  final double maxValue;
  final ColorScheme scheme;
  final TextTheme tt;
  final ValueChanged<double> onPercentageChanged;
  final VoidCallback onRemove;

  const _IngredientEditRow({
    super.key,
    required this.index,
    required this.draft,
    required this.maxValue,
    required this.scheme,
    required this.tt,
    required this.onPercentageChanged,
    required this.onRemove,
  });

  @override
  State<_IngredientEditRow> createState() => _IngredientEditRowState();
}

class _IngredientEditRowState extends State<_IngredientEditRow> {
  late final TextEditingController _pctCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _pctCtrl = TextEditingController(
        text: widget.draft.percentage.round().toString());
  }

  @override
  void didUpdateWidget(_IngredientEditRow old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final newText = widget.draft.percentage.round().toString();
      if (_pctCtrl.text != newText) _pctCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _pctCtrl.dispose();
    super.dispose();
  }

  void _applyText() {
    final v = double.tryParse(_pctCtrl.text.trim());
    if (v == null) {
      _pctCtrl.text = widget.draft.percentage.round().toString();
      return;
    }
    final clamped = v.clamp(1.0, widget.maxValue);
    _pctCtrl.text = clamped.round().toString();
    widget.onPercentageChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.draft.hex.isNotEmpty
        ? hexToColor(widget.draft.hex)
        : widget.scheme.surfaceContainerHighest;
    final divisions = (widget.maxValue - 1).round().clamp(1, 99);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
              child: Row(
                children: [
                  HexColorChip(color: color, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${widget.draft.brand} ${widget.draft.code}'.trim(),
                            style: widget.tt.labelMedium),
                        Text(widget.draft.name,
                            style: widget.tt.bodySmall?.copyWith(
                                color: widget.scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Campo numerico digitabile
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _pctCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        suffixText: '%',
                        suffixStyle: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: widget.scheme.onSurfaceVariant),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        isDense: true,
                      ),
                      onTap: () => setState(() => _editing = true),
                      onChanged: (_) => setState(() => _editing = true),
                      onSubmitted: (_) {
                        setState(() => _editing = false);
                        _applyText();
                      },
                      onEditingComplete: () {
                        setState(() => _editing = false);
                        _applyText();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Slider(
              value: widget.draft.percentage.clamp(1.0, widget.maxValue),
              min: 1,
              max: widget.maxValue,
              divisions: divisions,
              onChanged: (v) {
                setState(() => _editing = false);
                _pctCtrl.text = v.round().toString();
                widget.onPercentageChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient picker sheet ───────────────────────────────────────────────────

class _IngredientPickerSheet extends StatefulWidget {
  final ValueChanged<_CatalogPaint> onPick;
  const _IngredientPickerSheet({required this.onPick});

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_CatalogPaint>? _catalog;
  String? _selectedBrand;
  String? _selectedLine;

  @override
  void initState() {
    super.initState();
    _loadAllCatalogs().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _linesForBrand {
    if (_catalog == null || _selectedBrand == null) return [];
    return _catalog!
        .where((p) => p.brand == _selectedBrand && p.line.isNotEmpty)
        .map((p) => p.line)
        .toSet()
        .toList()
      ..sort();
  }

  List<_CatalogPaint> get _filtered {
    if (_catalog == null) return [];
    final q = _searchCtrl.text.trim().toLowerCase();
    return _catalog!.where((p) {
      if (_selectedBrand != null && p.brand != _selectedBrand) return false;
      if (_selectedLine != null && p.line != _selectedLine) return false;
      if (q.isEmpty) return true;
      return p.code.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }).take(60).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final brands = _catalog != null
        ? (_catalog!.map((p) => p.brand).toSet().toList()..sort())
        : <String>[];
    final lines = _linesForBrand;
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Brand chips
            if (_catalog != null)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l.filterAllLines),
                        selected: _selectedBrand == null,
                        onSelected: (_) => setState(() {
                          _selectedBrand = null;
                          _selectedLine = null;
                          _searchCtrl.clear();
                        }),
                      ),
                    ),
                    ...brands.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(b),
                        selected: _selectedBrand == b,
                        onSelected: (_) => setState(() {
                          _selectedBrand = b;
                          _selectedLine = null;
                          _searchCtrl.clear();
                        }),
                      ),
                    )),
                  ],
                ),
              ),
            // Line sub-chips — visibili solo se la marca ha più linee
            if (lines.length > 1)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l.filterAllLines),
                        selected: _selectedLine == null,
                        onSelected: (_) => setState(() => _selectedLine = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ...lines.map((ln) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l.paintLineLabel(ln)),
                        selected: _selectedLine == ln,
                        onSelected: (_) => setState(() => _selectedLine = ln),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l.paintSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _searchCtrl.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _catalog == null
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedBrand == null && _searchCtrl.text.isEmpty
                      ? Center(
                          child: Text(l.catalogEmptyPrompt,
                              style: tt.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant)))
                      : filtered.isEmpty
                          ? Center(
                              child: Text(l.searchNoResults,
                                  style: tt.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final p = filtered[i];
                                final color = hexToColor(p.hex);
                                return ListTile(
                                  leading: HexColorChip(color: color, size: 32),
                                  title: Text(
                                    '${p.code}  ${p.name}',
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(p.brand, style: tt.bodySmall),
                                  onTap: () {
                                    widget.onPick(p);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
