import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/hex_color_chip.dart';
import '../projects/project_repository.dart';
import 'recipe_repository.dart';
import 'create_recipe_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _recipeProvider =
    StreamProvider.autoDispose.family<Recipe?, int>((ref, id) =>
        ref.watch(recipeRepositoryProvider).watchById(id));

final _ingredientsProvider =
    StreamProvider.autoDispose.family<List<RecipeIngredient>, int>(
        (ref, recipeId) =>
            ref.watch(recipeRepositoryProvider).watchIngredients(recipeId));

final _linkedProjectsProvider =
    StreamProvider.autoDispose.family<List<Project>, int>((ref, recipeId) =>
        ref.watch(projectRepositoryProvider).watchProjectsUsingRecipe(recipeId));

// ── Screen ────────────────────────────────────────────────────────────────────

class RecipeDetailScreen extends ConsumerWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final recipeAsync = ref.watch(_recipeProvider(recipeId));
    final ingredientsAsync = ref.watch(_ingredientsProvider(recipeId));

    return recipeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.errorGeneric(e.toString()))),
      ),
      data: (recipe) {
        if (recipe == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Icon(Icons.error_outline)));
        }
        final ingredients = ingredientsAsync.value ?? [];
        final withHex =
            ingredients.where((i) => i.hex != null && i.hex!.isNotEmpty).toList();
        final blended = withHex.isNotEmpty
            ? blendColorsInLab(
                withHex.map((i) => (hex: i.hex!, weight: i.percentage)).toList())
            : scheme.surfaceContainerHighest;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _RecipeAppBar(
                recipe: recipe,
                blended: blended,
                scheme: scheme,
                tt: tt,
                l: l,
                onEdit: () => _openEdit(context, recipe),
                onDelete: () => _confirmDelete(context, ref, l),
              ),
              // ── Colore risultante ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _ColorPreviewCard(
                  blended: blended,
                  hasIngredients: withHex.isNotEmpty,
                  l: l,
                  scheme: scheme,
                  tt: tt,
                ),
              ),
              // ── Ingredienti ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    l.recipeIngredientsSection,
                    style: tt.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              if (ingredients.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      l.recipeAddIngredient,
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _IngredientRow(
                      ingredient: ingredients[i],
                      totalWeight: ingredients.fold(
                          0.0, (s, e) => s + e.percentage),
                      scheme: scheme,
                      tt: tt,
                    ),
                    childCount: ingredients.length,
                  ),
                ),
              // ── Dettagli opzionali ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _DetailsSection(
                  recipe: recipe,
                  scheme: scheme,
                  tt: tt,
                  l: l,
                ),
              ),
              // ── Progetti collegati ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _LinkedProjectsSection(
                  recipeId: recipeId,
                  scheme: scheme,
                  tt: tt,
                  l: l,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openEdit(context, recipe),
            tooltip: l.actionEdit,
            child: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, Recipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CreateRecipeScreen(recipe: recipe),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AppL10n l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.recipeDeleteTitle),
        content: Text(l.recipeDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              child: Text(l.actionDelete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(recipeRepositoryProvider).deleteRecipe(recipeId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _RecipeAppBar extends StatelessWidget {
  final Recipe recipe;
  final Color blended;
  final ColorScheme scheme;
  final TextTheme tt;
  final AppL10n l;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeAppBar({
    required this.recipe,
    required this.blended,
    required this.scheme,
    required this.tt,
    required this.l,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          recipe.name,
          style: tt.titleMedium?.copyWith(
            shadows: [
              const Shadow(color: Colors.black54, blurRadius: 8)
            ],
          ),
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                blended.withOpacity(0.6),
                scheme.surface,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: HexColorChip(color: blended, size: 64),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l.actionEdit,
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l.actionDelete,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ── Color preview card ────────────────────────────────────────────────────────

class _ColorPreviewCard extends StatelessWidget {
  final Color blended;
  final bool hasIngredients;
  final AppL10n l;
  final ColorScheme scheme;
  final TextTheme tt;

  const _ColorPreviewCard({
    required this.blended,
    required this.hasIngredients,
    required this.l,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HexColorChip(color: blended, size: 40),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.recipeBlendedColorLabel,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              Text(
                hasIngredients
                    ? '#${blended.value.toRadixString(16).substring(2).toUpperCase()}'
                    : '—',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ingredient row ────────────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final double totalWeight;
  final ColorScheme scheme;
  final TextTheme tt;

  const _IngredientRow({
    required this.ingredient,
    required this.totalWeight,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final color = ingredient.hex != null
        ? hexToColor(ingredient.hex!)
        : scheme.surfaceContainerHighest;
    final pct = totalWeight > 0 ? ingredient.percentage / totalWeight : 0.0;
    final pctLabel =
        '${(pct * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          HexColorChip(color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ingredient.brand ?? ''} ${ingredient.code ?? ''}'.trim(),
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (ingredient.paintName != null)
                  Text(
                    ingredient.paintName!,
                    style: tt.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                // Proportion bar
                LayoutBuilder(builder: (ctx, box) {
                  return Stack(children: [
                    Container(
                      height: 4,
                      width: box.maxWidth,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      height: 4,
                      width: box.maxWidth * pct.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ]);
                }),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            pctLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Details section ───────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final Recipe recipe;
  final ColorScheme scheme;
  final TextTheme tt;
  final AppL10n l;

  const _DetailsSection(
      {required this.recipe,
      required this.scheme,
      required this.tt,
      required this.l});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (recipe.finish != null)
      rows.add(_DetailRow(
          label: l.recipeFinishLabel,
          value: l.finishLabel(recipe.finish),
          tt: tt,
          scheme: scheme));
    if (recipe.coats != null)
      rows.add(_DetailRow(
          label: l.recipeCoatsLabel,
          value: '${recipe.coats}',
          tt: tt,
          scheme: scheme));
    if (recipe.dilution != null && recipe.dilution!.isNotEmpty)
      rows.add(_DetailRow(
          label: l.recipeDilutionLabel,
          value: recipe.dilution!,
          tt: tt,
          scheme: scheme));
    if (recipe.surface != null && recipe.surface!.isNotEmpty)
      rows.add(_DetailRow(
          label: l.recipeSurfaceLabel,
          value: recipe.surface!,
          tt: tt,
          scheme: scheme));
    if (recipe.notes != null && recipe.notes!.isNotEmpty)
      rows.add(_DetailRow(
          label: l.recipeNotesLabel,
          value: recipe.notes!,
          tt: tt,
          scheme: scheme));
    if (recipe.tags != null && recipe.tags!.isNotEmpty)
      rows.add(_TagRow(
          tags: recipe.tags!.split(',').map((t) => t.trim()).toList(),
          tt: tt,
          scheme: scheme));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.sectionInfo,
              style: tt.labelSmall
                  ?.copyWith(color: scheme.primary, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme tt;
  final ColorScheme scheme;

  const _DetailRow(
      {required this.label,
      required this.value,
      required this.tt,
      required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: tt.bodySmall)),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final TextTheme tt;
  final ColorScheme scheme;
  const _TagRow(
      {required this.tags, required this.tt, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: tags
            .map((t) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t,
                      style: tt.labelSmall
                          ?.copyWith(color: scheme.onSecondaryContainer)),
                ))
            .toList(),
      ),
    );
  }
}

// ── Progetti collegati ────────────────────────────────────────────────────────

class _LinkedProjectsSection extends ConsumerWidget {
  final int recipeId;
  final ColorScheme scheme;
  final TextTheme tt;
  final AppL10n l;

  const _LinkedProjectsSection({
    required this.recipeId,
    required this.scheme,
    required this.tt,
    required this.l,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(_linkedProjectsProvider(recipeId));
    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        if (projects.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.recipeLinkedProjectsSection,
                style: tt.labelSmall
                    ?.copyWith(color: scheme.primary, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: projects.map((p) {
                    final statusColor = switch (p.status) {
                      'in_progress' => const Color(0xFF3FA8A0),
                      'completed' => const Color(0xFF2F8F57),
                      _ => null,
                    };
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text(p.name, style: tt.bodyMedium),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (statusColor != null)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle),
                            ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right,
                              color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        ],
                      ),
                      onTap: () => context.push('/projects/${p.id}'),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
