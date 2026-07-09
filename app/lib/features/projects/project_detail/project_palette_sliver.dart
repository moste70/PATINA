import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scan_instructions_sheet.dart';
import '../../../database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/lab_mixer.dart';
import '../../../shared/widgets/hex_color_chip.dart';
import '../../recipes/recipe_repository.dart';
import '../project_repository.dart';

const _kRecipeBrand = 'ricetta';

// ── Catalog search ────────────────────────────────────────────────────────────

class _CatalogPaint {
  final String brand;
  final String code;
  final String name;
  final String hex;
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
      final paints = data['paints'] as List<dynamic>;
      for (final p in paints) {
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

// ── Providers ─────────────────────────────────────────────────────────────────

final _catalogProvider = FutureProvider<List<_CatalogPaint>>((ref) async {
  return _loadAllCatalogs();
});

final _projectPaintsProvider =
    StreamProvider.autoDispose.family<List<ProjectPaint>, int>((ref, id) {
  return ref.watch(projectRepositoryProvider).watchProjectPaints(id);
});

final _allRecipesProvider = StreamProvider.autoDispose<List<Recipe>>((ref) =>
    ref.watch(recipeRepositoryProvider).watchAllRecipes());

final _allIngredientsForSheetProvider =
    StreamProvider.autoDispose<List<RecipeIngredient>>((ref) =>
        ref.watch(recipeRepositoryProvider).watchAllIngredients());

// ── Main widget ───────────────────────────────────────────────────────────────

class ProjectPaletteSliver extends ConsumerWidget {
  final int projectId;
  const ProjectPaletteSliver({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final paintsAsync = ref.watch(_projectPaintsProvider(projectId));
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
              child: Row(
                children: [
                  Text(
                    l.paletteSectionTitle,
                    style: tt.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _HeaderIconButton(
                    icon: Icons.shopping_cart_outlined,
                    tooltip: l.paletteShoppingTooltip,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/shopping');
                    },
                    color: scheme.primary,
                  ),
                  _HeaderIconButton(
                    icon: Icons.camera_alt_outlined,
                    tooltip: l.paletteScanTooltip,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _scan(context, ref);
                    },
                    color: scheme.primary,
                  ),
                  _HeaderIconButton(
                    icon: Icons.add,
                    tooltip: l.paletteAddPaintTooltip,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAddSheet(context, ref);
                    },
                    color: scheme.primary,
                  ),
                ],
              ),
            ),

            paintsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (paints) {
                if (paints.isEmpty) {
                  return _EmptyPalette(
                    onScan: () => _scan(context, ref),
                    onManual: () => _showAddSheet(context, ref),
                    scheme: scheme,
                    tt: tt,
                  );
                }
                return Column(
                  children: paints
                      .map((p) => _PaletteRow(
                            paint: p,
                            projectId: projectId,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final repo = ref.read(projectRepositoryProvider);
    await showScanSheet(
      context,
      onComplete: (results) async {
        for (final r in results) {
          await repo.addProjectPaint(
            projectId: projectId,
            brand: r.brand,
            code: r.code,
            name: r.name,
            hex: r.hex,
          );
        }
        if (context.mounted && results.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.paletteSnackAdded(results.length)),
            ),
          );
        }
      },
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddPaintSheet(projectId: projectId),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

// ── Empty palette state ───────────────────────────────────────────────────────

class _EmptyPalette extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  final ColorScheme scheme;
  final TextTheme tt;
  const _EmptyPalette(
      {required this.onScan,
      required this.onManual,
      required this.scheme,
      required this.tt});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      children: [
        // Auto-load tile (supported brands)
        GestureDetector(
          onTap: onScan,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: scheme.primary.withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.camera_alt_outlined,
                    color: scheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.paletteAutoloadTitle,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        l.paletteAutoloadBody,
                        style: tt.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
        // Manual add tile
        GestureDetector(
          onTap: onManual,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: scheme.onSurfaceVariant, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.paletteCatalogSearch,
                    style: tt.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single palette row ────────────────────────────────────────────────────────

class _PaletteRow extends ConsumerWidget {
  final ProjectPaint paint;
  final int projectId;
  const _PaletteRow({required this.paint, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final repo = ref.read(projectRepositoryProvider);

    return Dismissible(
      key: ValueKey(paint.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) => repo.deleteProjectPaint(paint.id),
      child: paint.brand == _kRecipeBrand
          ? _RecipePaletteRow(paint: paint, scheme: scheme, tt: tt)
          : FutureBuilder<bool>(
              future: repo.isPaintInInventory(paint.brand, paint.code),
              builder: (context, snap) {
                final inStock = snap.data ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      HexColorChip(color: _hexColor(paint.hex), size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paint.code,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(paint.name,
                                style: tt.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StockBadge(inStock: inStock, scheme: scheme),
                    ],
                  ),
                );
              },
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

// ── Recipe palette row ────────────────────────────────────────────────────────

class _RecipePaletteRow extends StatelessWidget {
  final ProjectPaint paint;
  final ColorScheme scheme;
  final TextTheme tt;
  const _RecipePaletteRow(
      {required this.paint, required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/recipes/${paint.code}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: scheme.primary.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            HexColorChip(
              color: Color(
                  int.tryParse(paint.hex.replaceFirst('#', '0xFF')) ??
                      0xFF888888),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paint.name,
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(l.paletteRecipeLabel,
                      style: tt.labelSmall
                          ?.copyWith(color: scheme.primary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: scheme.onSurfaceVariant.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Stock badge ───────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final bool inStock;
  final ColorScheme scheme;
  const _StockBadge({required this.inStock, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: inStock
            ? const Color(0xFF2F8F57).withOpacity(0.15)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: inStock
              ? const Color(0xFF2F8F57).withOpacity(0.5)
              : scheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check : Icons.shopping_bag_outlined,
            size: 11,
            color: inStock ? const Color(0xFF2F8F57) : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            inStock ? l.paletteInStock : l.paletteToBuy,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: inStock
                  ? const Color(0xFF2F8F57)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add paint bottom sheet ────────────────────────────────────────────────────

class _AddPaintSheet extends ConsumerStatefulWidget {
  final int projectId;
  const _AddPaintSheet({required this.projectId});

  @override
  ConsumerState<_AddPaintSheet> createState() => _AddPaintSheetState();
}

const _kRecipesVirtualBrand = '__recipes__';

class _AddPaintSheetState extends ConsumerState<_AddPaintSheet> {
  final _controller = TextEditingController();
  String? _selectedBrand; // null = all, _kRecipesVirtualBrand = recipes mode
  final Set<_CatalogPaint> _selected = {};
  final Set<int> _selectedRecipeIds = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _recipesMode => _selectedBrand == _kRecipesVirtualBrand;

  List<_CatalogPaint> _filtered(List<_CatalogPaint> all) {
    final q = _controller.text.trim().toLowerCase();
    return all.where((p) {
      final brandMatch = _selectedBrand == null || p.brand == _selectedBrand;
      if (!brandMatch) return false;
      if (q.isEmpty) return true;
      return p.code.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }).take(60).toList();
  }

  void _toggle(_CatalogPaint p) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(p)) {
        _selected.remove(p);
      } else {
        _selected.add(p);
      }
    });
  }

  void _toggleRecipe(int recipeId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedRecipeIds.contains(recipeId)) {
        _selectedRecipeIds.remove(recipeId);
      } else {
        _selectedRecipeIds.add(recipeId);
      }
    });
  }

  Future<void> _confirm(
      List<Recipe> recipes, List<RecipeIngredient> allIngredients) async {
    final repo = ref.read(projectRepositoryProvider);
    setState(() => _isSaving = true);

    for (final p in _selected) {
      await repo.addProjectPaint(
        projectId: widget.projectId,
        brand: p.brand,
        code: p.code,
        name: p.name,
        hex: p.hex,
      );
    }
    for (final id in _selectedRecipeIds) {
      final recipe = recipes.firstWhere((r) => r.id == id);
      final ings = allIngredients
          .where((i) => i.recipeId == id && i.hex != null && i.hex!.isNotEmpty)
          .toList();
      final blended = ings.isNotEmpty
          ? blendColorsInLab(
              ings.map((i) => (hex: i.hex!, weight: i.percentage)).toList())
          : const Color(0xFF888888);
      final hex =
          '#${blended.value.toRadixString(16).substring(2).toUpperCase()}';
      await repo.addProjectPaint(
        projectId: widget.projectId,
        brand: _kRecipeBrand,
        code: id.toString(),
        name: recipe.name,
        hex: hex,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  int get _count => _selected.length + _selectedRecipeIds.length;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catalogAsync = ref.watch(_catalogProvider);
    final recipesAsync = ref.watch(_allRecipesProvider);
    final ingredientsAsync = ref.watch(_allIngredientsForSheetProvider);

    final catalog = catalogAsync.value ?? [];
    final brands = catalog.map((p) => p.brand).toSet().toList()..sort();
    final recipes = recipesAsync.value ?? [];
    final allIngs = ingredientsAsync.value ?? [];

    final listItems = _recipesMode
        ? <Widget>[]
        : _filtered(catalog).map<Widget>((p) {
            final sel = _selected.contains(p);
            return ListTile(
              key: ValueKey('${p.brand}${p.code}'),
              leading: HexColorChip(color: _hexColor(p.hex), size: 32),
              title: Text(
                '${p.code}  ${p.name}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(p.brand, style: tt.bodySmall),
              trailing: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: sel
                    ? Icon(Icons.check_circle,
                        key: const ValueKey('on'),
                        color: scheme.primary, size: 24)
                    : Icon(Icons.radio_button_unchecked,
                        key: const ValueKey('off'),
                        color: scheme.outline, size: 24),
              ),
              selected: sel,
              selectedTileColor: scheme.primary.withOpacity(0.08),
              onTap: () => _toggle(p),
            );
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
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
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                Expanded(child: Text(l.paletteAddPaintsTitle, style: tt.titleMedium)),
                if (_count > 0)
                  FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () => _confirm(recipes, allIngs),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.paletteAddCountButton(_count)),
                  ),
              ],
            ),
          ),
          // Brand chips
          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (_) => SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // Ricette personali chip — colore secondary, per prima
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(l.paletteRecipesTab),
                      avatar: const Icon(Icons.science_outlined, size: 14),
                      selected: _recipesMode,
                      selectedColor: scheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color: _recipesMode
                            ? scheme.onSecondaryContainer
                            : scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: scheme.secondary.withOpacity(0.5)),
                      onSelected: (_) => setState(() {
                        _selectedBrand = _kRecipesVirtualBrand;
                        _controller.clear();
                      }),
                    ),
                  ),
                  // "Tutti" chip
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(l.filterAllLines),
                      selected: _selectedBrand == null,
                      onSelected: (_) => setState(() {
                        _selectedBrand = null;
                        _controller.clear();
                      }),
                    ),
                  ),
                  // Brand chips
                  ...brands.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(b),
                      selected: _selectedBrand == b,
                      onSelected: (_) => setState(() {
                        _selectedBrand = b;
                        _controller.clear();
                      }),
                    ),
                  )),
                ],
              ),
            ),
          ),
          // Search field (catalog only)
          if (!_recipesMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l.paintSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _controller.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          // Results
          Expanded(
            child: _recipesMode
                ? recipes.isEmpty
                    ? Center(child: Text(l.recipesEmptyTitle, style: tt.bodySmall))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: recipes.length,
                        itemBuilder: (_, i) {
                          final r = recipes[i];
                          final ings = allIngs
                              .where((ing) =>
                                  ing.recipeId == r.id &&
                                  ing.hex != null &&
                                  ing.hex!.isNotEmpty)
                              .toList();
                          final blended = ings.isNotEmpty
                              ? blendColorsInLab(ings
                                  .map((ing) => (hex: ing.hex!, weight: ing.percentage))
                                  .toList())
                              : scheme.surfaceContainerHighest;
                          final sel = _selectedRecipeIds.contains(r.id);
                          return ListTile(
                            leading: HexColorChip(color: blended, size: 32),
                            title: Text(r.name, style: tt.bodyMedium),
                            subtitle: Text(
                              l.recipeIngredientCount(ings.length),
                              style: tt.bodySmall,
                            ),
                            trailing: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: sel
                                  ? Icon(Icons.check_circle,
                                      key: const ValueKey('on'),
                                      color: scheme.secondary, size: 24)
                                  : Icon(Icons.radio_button_unchecked,
                                      key: const ValueKey('off'),
                                      color: scheme.outline, size: 24),
                            ),
                            selected: sel,
                            selectedTileColor: scheme.secondaryContainer.withOpacity(0.3),
                            onTap: () => _toggleRecipe(r.id),
                          );
                        },
                      )
                : catalogAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(child: Text(l.errorCatalogLoad)),
                    data: (_) {
                      if (_selectedBrand == null && _controller.text.isEmpty) {
                        return Center(child: Text(l.catalogEmptyPrompt, style: tt.bodySmall));
                      }
                      if (listItems.isEmpty) {
                        return Center(child: Text(l.searchNoResults, style: tt.bodySmall));
                      }
                      return ListView(
                        controller: scrollCtrl,
                        children: listItems,
                      );
                    },
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
