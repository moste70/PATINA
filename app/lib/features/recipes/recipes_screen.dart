import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/pro/pro_gate.dart';
import '../../shared/pro/paywall_sheet.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/hex_color_chip.dart';
import 'recipe_repository.dart';
import 'create_recipe_screen.dart';

const _kFreeRecipesLimit = 5;

// ── Providers ─────────────────────────────────────────────────────────────────

final _recipesProvider = StreamProvider<List<Recipe>>((ref) =>
    ref.watch(recipeRepositoryProvider).watchAllRecipes());

final _allIngredientsProvider = StreamProvider<List<RecipeIngredient>>((ref) =>
    ref.watch(recipeRepositoryProvider).watchAllIngredients());

// ── Screen ────────────────────────────────────────────────────────────────────

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final recipesAsync = ref.watch(_recipesProvider);
    final ingredientsAsync = ref.watch(_allIngredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: tt.bodyLarge,
                decoration: InputDecoration(
                  hintText: l.recipeSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              )
            : Text(l.recipesScreenTitle),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? l.actionCancel : l.recipeSearchTooltip,
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchCtrl.clear();
                _query = '';
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.colorize_outlined),
            tooltip: l.recipesFindByColor,
            onPressed: () => _showFindByColor(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFabTap(context, ref),
        tooltip: l.recipesFabTooltip,
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorGeneric(e.toString()))),
        data: (recipes) {
          final allIngredients = ingredientsAsync.value ?? [];

          List<Recipe> filtered = recipes;
          if (_query.isNotEmpty) {
            filtered = recipes.where((r) {
              return r.name.toLowerCase().contains(_query) ||
                  (r.tags?.toLowerCase().contains(_query) ?? false);
            }).toList();
          }

          if (filtered.isEmpty) {
            return _EmptyState(
              isEmpty: recipes.isEmpty,
              hasQuery: _query.isNotEmpty,
              l: l,
              tt: tt,
              scheme: scheme,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final recipe = filtered[i];
              final ingredients = allIngredients
                  .where((ing) => ing.recipeId == recipe.id)
                  .toList();
              return _RecipeCard(
                recipe: recipe,
                ingredients: ingredients,
                onTap: () => context.push('/recipes/${recipe.id}'),
                scheme: scheme,
                tt: tt,
                l: l,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onFabTap(BuildContext context, WidgetRef ref) async {
    if (!ProGate.isProUser(ref)) {
      final count = await ref.read(recipeRepositoryProvider).count();
      if (count >= _kFreeRecipesLimit) {
        if (context.mounted) {
          PaywallSheet.show(context, feature: 'Ricette illimitate');
        }
        return;
      }
    }
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateRecipeScreen(),
      ));
    }
  }

  void _showFindByColor(BuildContext context, WidgetRef ref) {
    final recipes = ref.read(_recipesProvider).value ?? [];
    final allIngredients = ref.read(_allIngredientsProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FindByColorSheet(
        recipes: recipes,
        allIngredients: allIngredients,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isEmpty;
  final bool hasQuery;
  final AppL10n l;
  final TextTheme tt;
  final ColorScheme scheme;
  const _EmptyState({
    required this.isEmpty,
    required this.hasQuery,
    required this.l,
    required this.tt,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.science_outlined,
              size: 56,
              color: scheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? l.searchNoResults : l.recipesEmptyTitle,
              style: tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              Text(
                l.recipesEmptyBody,
                style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Recipe card ───────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final List<RecipeIngredient> ingredients;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final TextTheme tt;
  final AppL10n l;

  const _RecipeCard({
    required this.recipe,
    required this.ingredients,
    required this.onTap,
    required this.scheme,
    required this.tt,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final withHex =
        ingredients.where((i) => i.hex != null && i.hex!.isNotEmpty).toList();
    final blended = withHex.isNotEmpty
        ? blendColorsInLab(
            withHex.map((i) => (hex: i.hex!, weight: i.percentage)).toList())
        : scheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              HexColorChip(color: blended, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name,
                        style: tt.titleSmall,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (recipe.finish != null) ...[
                          _TechChip(
                              label: l.finishLabel(recipe.finish),
                              scheme: scheme,
                              tt: tt),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          l.recipeIngredientCount(ingredients.length),
                          style: tt.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: scheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;
  const _TechChip(
      {required this.label, required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: tt.labelSmall?.copyWith(color: scheme.primary)),
    );
  }
}

// ── Find by color sheet ───────────────────────────────────────────────────────

// Reference colors for quick picks (common modelling paints)
const _refColors = [
  ('Grigio chiaro', '#C8C9C5'),
  ('Grigio medio', '#888A80'),
  ('Grigio scuro', '#4A4C46'),
  ('Nero opaco', '#2A2A2A'),
  ('Bianco', '#F4F4F0'),
  ('Avorio', '#E8DDB0'),
  ('Sand / Sabbia', '#C8AA6E'),
  ('Ocra', '#B08840'),
  ('Marrone terra', '#7A5030'),
  ('Verde NATO', '#4A6741'),
  ('Verde oliva', '#6B7C3A'),
  ('Verde scuro', '#2F4830'),
  ('Azzurro cielo', '#8EB4C8'),
  ('Blu marino', '#2A3D6E'),
  ('Rosso arancio', '#C84820'),
  ('Ruggine', '#8C3818'),
];

class _FindByColorSheet extends StatefulWidget {
  final List<Recipe> recipes;
  final List<RecipeIngredient> allIngredients;
  const _FindByColorSheet(
      {required this.recipes, required this.allIngredients});

  @override
  State<_FindByColorSheet> createState() => _FindByColorSheetState();
}

class _FindByColorSheetState extends State<_FindByColorSheet> {
  Color? _target;
  final _hexCtrl = TextEditingController();

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  List<({Recipe recipe, Color blended, double de})> _computeMatches() {
    if (_target == null) return [];
    final results = <({Recipe recipe, Color blended, double de})>[];
    for (final recipe in widget.recipes) {
      final ings = widget.allIngredients
          .where((i) => i.recipeId == recipe.id && i.hex != null)
          .toList();
      if (ings.isEmpty) continue;
      final blended = blendColorsInLab(
          ings.map((i) => (hex: i.hex!, weight: i.percentage)).toList());
      final de = deltaE(_target!, blended);
      results.add((recipe: recipe, blended: blended, de: de));
    }
    results.sort((a, b) => a.de.compareTo(b.de));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final matches = _computeMatches();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Handle
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
          Text(l.recipesFindByColorTitle, style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(l.recipesFindByColorHint,
              style:
                  tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          // Color grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _refColors.map((c) {
              final color = hexToColor(c.$2);
              final selected = _target == color;
              return GestureDetector(
                onTap: () => setState(() {
                  _target = color;
                  _hexCtrl.text = c.$2;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(color: scheme.primary, width: 2.5)
                        : Border.all(
                            color: scheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Tooltip(
                      message: c.$1,
                      child:
                          Container(width: 36, height: 36, color: color),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hexCtrl,
            decoration: InputDecoration(
              labelText: l.recipeHexInputLabel,
              hintText: l.recipeHexInputHint,
              prefixIcon: _target != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _target,
                          border: Border.all(
                              color: scheme.outline.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : const Icon(Icons.palette_outlined),
            ),
            onChanged: (v) {
              final c = hexToColor(v.trim());
              if (c != Colors.grey) setState(() => _target = c);
            },
          ),
          const SizedBox(height: 16),
          if (_target != null && matches.isEmpty)
            Text(l.recipesNoColoredIngredients,
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          if (matches.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...matches.map((m) {
              final matchLabel = l.deltaELabel(m.de);
              final deStr = m.de.toStringAsFixed(1);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: HexColorChip(color: m.blended, size: 40),
                title: Text(m.recipe.name, style: tt.bodyMedium),
                subtitle: Text(
                  l.recipeDeltaMatchLabel(matchLabel, deStr),
                  style: tt.labelSmall
                      ?.copyWith(color: _deltaColor(m.de, scheme)),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant.withOpacity(0.5)),
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push('/recipes/${m.recipe.id}');
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Color _deltaColor(double de, ColorScheme scheme) {
    if (de <= 2) return const Color(0xFF2F8F57);
    if (de <= 5) return const Color(0xFF3FA8A0);
    if (de <= 10) return scheme.onSurfaceVariant;
    return scheme.error;
  }
}
