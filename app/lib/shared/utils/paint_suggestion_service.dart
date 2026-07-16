import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../database/app_database.dart';
import '../../features/paints/paint_equivalences.dart';
import 'lab_mixer.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum SuggestionKind { equivalent, similar }

class PaintSuggestion {
  final String brand;
  final String code;
  final String name;
  final String hex;
  final SuggestionKind kind;
  final bool inInventory;
  final double? deltaE; // null for certified equivalences
  final int? recipeId;

  const PaintSuggestion({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.kind,
    required this.inInventory,
    this.deltaE,
    this.recipeId,
  });

  bool get isRecipe => recipeId != null;
}

// ── Service ───────────────────────────────────────────────────────────────────

class PaintSuggestionResult {
  final List<PaintSuggestion> equivalences;
  final List<PaintSuggestion> similar;
  const PaintSuggestionResult({required this.equivalences, required this.similar});
  bool get isEmpty => equivalences.isEmpty && similar.isEmpty;
}

class PaintSuggestionService {
  /// Builds a suggestion result for a paint that is not in inventory.
  ///
  /// [catalogEntries] — all catalog paints, pre-loaded.
  /// [inventory] — current inventory rows.
  /// [recipes] — all archived recipes.
  /// [allIngredients] — all recipe ingredients (used to compute recipe hex).
  static PaintSuggestionResult suggest({
    required String brand,
    required String code,
    required String hex,
    required List<({String brand, String code, String name, String hex})> catalogEntries,
    required List<InventoryPaint> inventory,
    required List<Recipe> recipes,
    required List<RecipeIngredient> allIngredients,
  }) {
    final inventoryKeys = _buildInventoryKeys(inventory);
    final targetColor = hexToColor(hex);

    // ── Level 1: certified equivalences ──────────────────────────────────────
    final equivKey = '$brand:$code';
    final rawEquivs = kPaintEquivalences[equivKey] ?? [];
    final equivalences = <PaintSuggestion>[];
    for (final (eqBrand, eqCode) in rawEquivs) {
      final entry = catalogEntries
          .where((e) => e.brand == eqBrand && e.code == eqCode)
          .firstOrNull;
      if (entry == null) continue;
      final inInv = inventoryKeys.contains('$eqBrand:$eqCode');
      equivalences.add(PaintSuggestion(
        brand: eqBrand,
        code: eqCode,
        name: entry.name,
        hex: entry.hex,
        kind: SuggestionKind.equivalent,
        inInventory: inInv,
      ));
    }
    // Sort: in-inventory first
    equivalences.sort((a, b) => (b.inInventory ? 1 : 0) - (a.inInventory ? 1 : 0));

    // ── Level 2: color similarity ─────────────────────────────────────────────
    final similar = <PaintSuggestion>[];
    const kMaxDeltaE = 20.0;
    const kMaxResults = 8;

    // Catalog paints
    final equivPairs = rawEquivs.map((e) => '${e.$1}:${e.$2}').toSet();
    for (final e in catalogEntries) {
      if (e.brand == brand && e.code == code) continue; // skip self
      if (equivPairs.contains('${e.brand}:${e.code}')) continue; // already in level 1
      final de = deltaE(targetColor, hexToColor(e.hex));
      if (de > kMaxDeltaE) continue;
      final inInv = inventoryKeys.contains('${e.brand}:${e.code}');
      similar.add(PaintSuggestion(
        brand: e.brand,
        code: e.code,
        name: e.name,
        hex: e.hex,
        kind: SuggestionKind.similar,
        inInventory: inInv,
        deltaE: de,
      ));
    }

    // Recipes
    for (final recipe in recipes) {
      final ings = allIngredients
          .where((i) => i.recipeId == recipe.id && i.hex != null && i.hex!.isNotEmpty)
          .toList();
      if (ings.isEmpty) continue;
      final blended = blendColorsInLab(
          ings.map((i) => (hex: i.hex!, weight: i.percentage)).toList());
      final blendedHex =
          '#${blended.value.toRadixString(16).substring(2).toUpperCase()}';
      final de = deltaE(targetColor, blended);
      if (de > kMaxDeltaE) continue;
      similar.add(PaintSuggestion(
        brand: 'ricetta',
        code: recipe.id.toString(),
        name: recipe.name,
        hex: blendedHex,
        kind: SuggestionKind.similar,
        inInventory: true, // recipes are always "available"
        deltaE: de,
        recipeId: recipe.id,
      ));
    }

    similar.sort((a, b) {
      // In-inventory first, then by ΔE
      final stockDiff = (b.inInventory ? 1 : 0) - (a.inInventory ? 1 : 0);
      if (stockDiff != 0) return stockDiff;
      return (a.deltaE ?? 999).compareTo(b.deltaE ?? 999);
    });

    return PaintSuggestionResult(
      equivalences: equivalences,
      similar: similar.take(kMaxResults).toList(),
    );
  }

  static Set<String> _buildInventoryKeys(List<InventoryPaint> inventory) {
    final keys = <String>{};
    for (final p in inventory) {
      if (p.catalogBrand != null && p.catalogCode != null) {
        keys.add('${p.catalogBrand}:${p.catalogCode}');
      }
    }
    return keys;
  }
}

// ── ΔE label helper ───────────────────────────────────────────────────────────

String deltaELabel(double de) {
  if (de < 3) return '≈ ΔE ${de.toStringAsFixed(1)}';
  if (de < 8) return '~ ΔE ${de.toStringAsFixed(1)}';
  return '≈≈ ΔE ${de.toStringAsFixed(1)}';
}

Color deltaEColor(double de, ColorScheme scheme) {
  if (de < 3) return const Color(0xFF2F8F57);
  if (de < 8) return scheme.primary;
  return scheme.onSurfaceVariant;
}
