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
import 'ai_mixing_sheet.dart';
import '../paints/photo_color_picker_sheet.dart';

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
          if (!_searching) ...[
            IconButton(
              icon: const Icon(Icons.colorize_outlined),
              tooltip: 'Rileva colore da foto',
              onPressed: () => PhotoColorPickerSheet.show(context),
            ),
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Miscelazione AI',
              onPressed: () {
                if (!ProGate.isProUser(ref)) {
                  PaywallSheet.show(context, feature: 'Miscelazione AI');
                  return;
                }
                AiMixingSheet.show(context);
              },
            ),
          ],
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
                  (r.notes?.toLowerCase().contains(_query) ?? false);
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

