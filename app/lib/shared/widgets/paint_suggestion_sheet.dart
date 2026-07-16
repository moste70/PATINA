import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/app_database.dart';
import '../../features/paints/paints_repository.dart';
import '../../features/recipes/recipe_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../utils/lab_mixer.dart';
import '../utils/paint_suggestion_service.dart';
import 'hex_color_chip.dart';

// ── Catalog entry (same shape used in project_palette_sliver) ─────────────────

typedef _CatalogEntry = ({String brand, String code, String name, String hex});

// ── Providers ─────────────────────────────────────────────────────────────────

final _inventoryProvider = StreamProvider.autoDispose<List<InventoryPaint>>(
    (ref) => ref.watch(paintsRepositoryProvider).watchInventoryPaints());

final _recipesForSuggProvider = StreamProvider.autoDispose<List<Recipe>>(
    (ref) => ref.watch(recipeRepositoryProvider).watchAllRecipes());

final _ingredientsForSuggProvider =
    StreamProvider.autoDispose<List<RecipeIngredient>>(
        (ref) => ref.watch(recipeRepositoryProvider).watchAllIngredients());

// ── Public API ────────────────────────────────────────────────────────────────

Future<void> showPaintSuggestionSheet(
  BuildContext context, {
  required String brand,
  required String code,
  required String name,
  required String hex,
  required List<_CatalogEntry> catalog,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _PaintSuggestionSheet(
        brand: brand,
        code: code,
        name: name,
        hex: hex,
        catalog: catalog,
      ),
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _PaintSuggestionSheet extends ConsumerWidget {
  final String brand;
  final String code;
  final String name;
  final String hex;
  final List<_CatalogEntry> catalog;

  const _PaintSuggestionSheet({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.catalog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final inventoryAsync = ref.watch(_inventoryProvider);
    final recipesAsync = ref.watch(_recipesForSuggProvider);
    final ingredientsAsync = ref.watch(_ingredientsForSuggProvider);

    final loading = inventoryAsync.isLoading ||
        recipesAsync.isLoading ||
        ingredientsAsync.isLoading;

    PaintSuggestionResult? result;
    if (!loading) {
      result = PaintSuggestionService.suggest(
        brand: brand,
        code: code,
        hex: hex,
        catalogEntries: catalog,
        inventory: inventoryAsync.value ?? [],
        recipes: recipesAsync.value ?? [],
        allIngredients: ingredientsAsync.value ?? [],
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                HexColorChip(color: hexToColor(hex), size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.suggestionSheetTitle,
                        style: tt.labelSmall?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '$code  $name',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _brandLabel(brand),
                        style: tt.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : result!.isEmpty
                    ? Center(
                        child: Text(
                          l.suggestionSheetEmpty,
                          style: tt.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        controller: scroll,
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          if (result.equivalences.isNotEmpty) ...[
                            _SectionHeader(
                                label: l.suggestionEquivalentSection),
                            ...result.equivalences.map((s) =>
                                _SuggestionTile(
                                    suggestion: s, scheme: scheme, tt: tt)),
                          ],
                          if (result.similar.isNotEmpty) ...[
                            _SectionHeader(label: l.suggestionSimilarSection),
                            ...result.similar.map((s) => _SuggestionTile(
                                suggestion: s, scheme: scheme, tt: tt)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}

// ── Single suggestion tile ────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final PaintSuggestion suggestion;
  final ColorScheme scheme;
  final TextTheme tt;

  const _SuggestionTile({
    required this.suggestion,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = suggestion;

    return ListTile(
      leading: HexColorChip(color: hexToColor(s.hex), size: 32),
      title: Text(
        s.isRecipe ? s.name : '${s.code}  ${s.name}',
        style: GoogleFonts.jetBrainsMono(
            fontSize: 12, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            s.isRecipe ? l.suggestionRecipeLabel : _brandLabel(s.brand),
            style: tt.bodySmall,
          ),
          if (s.deltaE != null) ...[
            const SizedBox(width: 6),
            Text(
              deltaELabel(s.deltaE!),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: deltaEColor(s.deltaE!, scheme),
              ),
            ),
          ],
        ],
      ),
      trailing: s.inInventory
          ? Tooltip(
              message: l.paletteInStock,
              child: Icon(Icons.check_circle_outline,
                  color: const Color(0xFF2F8F57), size: 18),
            )
          : Tooltip(
              message: l.paletteToBuy,
              child: Icon(Icons.shopping_bag_outlined,
                  color: scheme.onSurfaceVariant, size: 18),
            ),
      onTap: () {
        HapticFeedback.lightImpact();
        if (s.isRecipe) {
          Navigator.pop(context);
          GoRouter.of(context).push('/recipes/${s.recipeId}');
        }
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _brandLabel(String brand) => switch (brand) {
      'tamiya'    => 'Tamiya',
      'vallejo'   => 'Vallejo',
      'citadel'   => 'Citadel',
      'gunze'     => 'Gunze',
      'humbrol'   => 'Humbrol',
      'lifecolor' => 'LifeColor',
      'ricetta'   => 'Ricetta',
      _           => brand.toUpperCase(),
    };
