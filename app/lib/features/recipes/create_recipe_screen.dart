import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String brand, code, name, hex;
  _CatalogPaint(
      {required this.brand,
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
      for (final p in data['paints'] as List<dynamic>) {
        result.add(_CatalogPaint(
          brand: brand,
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
  int? _coats;
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
      _coats = r.coats;
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
            coats: Value(_coats),
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
          coats: Value(_coats),
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

          // ── Numero di mani ─────────────────────────────────────────────
          Text(l.recipeCoatsLabel,
              style: tt.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4].map((n) {
              final selected = _coats == n;
              return ChoiceChip(
                label: Text('$n'),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _coats = selected ? null : n),
              );
            }).toList(),
          ),
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
            ],
          ),
          const SizedBox(height: 8),
          ..._ingredients.asMap().entries.map((e) => _IngredientEditRow(
                index: e.key,
                draft: e.value,
                scheme: scheme,
                tt: tt,
                onPercentageChanged: (v) =>
                    setState(() => e.value.percentage = v),
                onRemove: () => setState(() => _ingredients.removeAt(e.key)),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.recipeAddIngredient),
            onPressed: () => _showIngredientPicker(context, l),
          ),
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

  void _showIngredientPicker(BuildContext context, AppL10n l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IngredientPickerSheet(
        onPick: (p) {
          setState(() {
            // Equal share for all ingredients
            final share = 100.0 / (_ingredients.length + 1);
            for (final i in _ingredients) {
              i.percentage = share;
            }
            _ingredients.add(_IngredientDraft(
              brand: p.brand,
              code: p.code,
              name: p.name,
              hex: p.hex,
              percentage: share,
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

class _IngredientEditRow extends StatelessWidget {
  final int index;
  final _IngredientDraft draft;
  final ColorScheme scheme;
  final TextTheme tt;
  final ValueChanged<double> onPercentageChanged;
  final VoidCallback onRemove;

  const _IngredientEditRow({
    required this.index,
    required this.draft,
    required this.scheme,
    required this.tt,
    required this.onPercentageChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = draft.hex.isNotEmpty
        ? hexToColor(draft.hex)
        : scheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
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
                        Text('${draft.brand} ${draft.code}'.trim(),
                            style: tt.labelMedium),
                        Text(draft.name,
                            style: tt.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(
                    '${draft.percentage.round()}%',
                    style: tt.labelLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Slider(
              value: draft.percentage,
              min: 5,
              max: 100,
              divisions: 19,
              onChanged: onPercentageChanged,
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
  String _query = '';

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

  List<_CatalogPaint> get _filtered {
    if (_catalog == null) return [];
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _catalog!
        .where((p) =>
            p.code.toLowerCase().contains(q) ||
            p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q))
        .take(40)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.paintSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _catalog == null
                  ? const Center(child: CircularProgressIndicator())
                  : _query.isEmpty
                      ? Center(
                          child: Text(l.paintSearchPrompt,
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
                                  leading: HexColorChip(
                                      color: color, size: 32),
                                  title: Text('${p.brand}  ${p.code}',
                                      style: tt.labelMedium),
                                  subtitle: Text(p.name,
                                      overflow: TextOverflow.ellipsis),
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
