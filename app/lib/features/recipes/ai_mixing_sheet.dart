import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/services/claude_service.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/hex_color_chip.dart';
import '../paints/paints_repository.dart';
import 'create_recipe_screen.dart';
import 'target_color_picker_screen.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class MixingSuggestion {
  final List<MixingIngredient> ingredients;
  final String notes;
  final String targetHex;

  const MixingSuggestion({
    required this.ingredients,
    required this.notes,
    required this.targetHex,
  });

  factory MixingSuggestion.fromJson(
      Map<String, dynamic> json, String targetHex) {
    return MixingSuggestion(
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => MixingIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String? ?? '',
      targetHex: targetHex,
    );
  }
}

class MixingIngredient {
  final String brand;
  final String code;
  final String name;
  final String hex;
  final int percentage;

  const MixingIngredient({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.percentage,
  });

  factory MixingIngredient.fromJson(Map<String, dynamic> json) =>
      MixingIngredient(
        brand: json['brand'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        hex: json['hex'] as String? ?? '#888888',
        percentage: (json['percentage'] as num?)?.toInt() ?? 50,
      );
}

// ── Mock per debug senza Firebase Functions ───────────────────────────────────

MixingSuggestion _mockSuggestion(String targetHex, String mockNote) =>
    MixingSuggestion(
      targetHex: targetHex,
      ingredients: [
        const MixingIngredient(
          brand: 'vallejo',
          code: '70.950',
          name: 'Black',
          hex: '#000000',
          percentage: 20,
        ),
        const MixingIngredient(
          brand: 'vallejo',
          code: '70.951',
          name: 'White',
          hex: '#FFFFFF',
          percentage: 30,
        ),
        const MixingIngredient(
          brand: 'tamiya',
          code: 'XF-57',
          name: 'Buff',
          hex: '#C8A96E',
          percentage: 50,
        ),
      ],
      notes: mockNote,
    );

// ── Sheet principale ───────────────────────────────────────────────────────────

class AiMixingSheet extends ConsumerStatefulWidget {
  const AiMixingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AiMixingSheet(),
    );
  }

  @override
  ConsumerState<AiMixingSheet> createState() => _AiMixingSheetState();
}

// Vernici dell'inventario dell'utente, per il selettore "solo censite" vs
// "tutto il catalogo" — deriva l'insieme delle marche già presenti in
// inventario (catalogo o custom) per filtrare i FilterChip marca.
final _inventoryBrandsProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(paintsRepositoryProvider).watchInventoryPaints().map(
        (rows) => rows
            .map((r) => (r.catalogBrand ?? r.customBrand ?? '').toLowerCase())
            .where((b) => b.isNotEmpty)
            .toSet(),
      ),
);

class _AiMixingSheetState extends ConsumerState<AiMixingSheet> {
  String? _targetHex;

  final Set<String> _selectedBrands = {'vallejo', 'tamiya', 'citadel'};
  bool _inventoryOnly = false;
  bool _loading = false;
  MixingSuggestion? _result;
  String? _error;

  static final _kBrands =
      AppConstants.brandLabels.entries.map((e) => (e.key, e.value)).toList();

  Future<void> _pickTargetColor() async {
    final hex =
        await TargetColorPickerScreen.show(context, initialHex: _targetHex);
    if (hex == null || !mounted) return;
    setState(() {
      _targetHex = hex;
      _result = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    final targetHex = _targetHex;
    if (targetHex == null) return;
    if (_selectedBrands.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    HapticFeedback.lightImpact();

    try {
      if (kDebugMode) {
        // Mock in debug — nessuna chiamata Firebase
        await Future.delayed(const Duration(seconds: 2));
        final mockNote = AppL10n.of(context).aiMixingMockNote;
        setState(() => _result = _mockSuggestion(targetHex, mockNote));
      } else {
        final svc = ref.read(claudeServiceProvider);
        // TODO(urgente, backend): vincolare la ricetta a marca/linea unica
        // (non miscelare Tamiya lacquer con Vallejo acrilico, ecc.) va fatto
        // nel prompt della Firebase Function suggestMixingRecipe
        // (functions/index.js), non qui — la selezione degli ingredienti è
        // interamente lato Claude/server. Richiede un redeploy separato
        // (deploy-functions.yml). Vedi docs/roadmap.md § Debito Tecnico.
        final raw = await svc.suggestMixingRecipe(
          targetHex: targetHex,
          availableBrands: _selectedBrands.toList(),
        );
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _result = MixingSuggestion.fromJson(decoded, targetHex));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Color? _blendedResultColor() {
    final ingredients = _result?.ingredients;
    if (ingredients == null || ingredients.isEmpty) return null;
    return blendColorsInLab(ingredients
        .map((i) => (hex: i.hex, weight: i.percentage.toDouble()))
        .toList());
  }

  void _saveAsRecipe() {
    if (_result == null) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(
          prefillFromMixing: _result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final inventoryBrands =
        ref.watch(_inventoryBrandsProvider).valueOrNull ?? {};
    final visibleBrands = _inventoryOnly
        ? _kBrands.where((b) => inventoryBrands.contains(b.$1)).toList()
        : _kBrands;
    final blendedResult = _blendedResultColor();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(l.aiMixingTitle,
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(l.badgePro,
                      style: tt.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // ── Colore target ─────────────────────────────────────────
                Text(l.aiMixingTargetColorLabel,
                    style: tt.labelMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _pickTargetColor,
                      child: Column(
                        children: [
                          HexColorChip(
                            color: _targetHex != null
                                ? hexToColor(_targetHex!)
                                : scheme.surfaceContainerHigh,
                            size: 52,
                            child: _targetHex == null
                                ? Icon(Icons.colorize_outlined,
                                    color: scheme.onSurface.withOpacity(0.3))
                                : null,
                          ),
                          if (blendedResult != null) ...[
                            const SizedBox(height: 8),
                            HexColorChip(color: blendedResult, size: 52),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_targetHex ?? l.aiMixingSelectTargetHint,
                              style: tt.bodyMedium),
                          if (blendedResult != null) ...[
                            const SizedBox(height: 8),
                            Text(l.aiMixingResultColorLabel,
                                style: tt.bodySmall?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.6))),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l.actionChangeColor,
                      onPressed: _pickTargetColor,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Vernici considerate (inventario/catalogo) ──────────────
                Text(l.aiMixingSourceLabel,
                    style: tt.labelMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l.aiMixingSourceCatalog),
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l.aiMixingSourceInventory),
                      icon: const Icon(Icons.checklist_outlined),
                    ),
                  ],
                  selected: {_inventoryOnly},
                  onSelectionChanged: (s) => setState(() {
                    _inventoryOnly = s.first;
                    if (_inventoryOnly) {
                      _selectedBrands
                          .removeWhere((b) => !inventoryBrands.contains(b));
                    }
                  }),
                ),

                const SizedBox(height: 20),

                // ── Marche disponibili ─────────────────────────────────────
                Text(l.aiMixingBrandsLabel,
                    style: tt.labelMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (_inventoryOnly && visibleBrands.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: scheme.onSurface.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.aiMixingNoInventoryBrands,
                              style: tt.bodySmall),
                        ),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: visibleBrands.map((b) {
                      final selected = _selectedBrands.contains(b.$1);
                      return FilterChip(
                        label: Text(b.$2),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedBrands.add(b.$1);
                          } else {
                            _selectedBrands.remove(b.$1);
                          }
                        }),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),

                // ── Bottone genera ─────────────────────────────────────────
                FilledButton.icon(
                  onPressed: (_targetHex != null &&
                          _selectedBrands.isNotEmpty &&
                          !_loading)
                      ? _generate
                      : null,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label:
                      Text(_loading ? l.aiMixingAnalyzing : l.aiMixingGenerate),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),

                // ── Errore ─────────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: scheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: tt.bodySmall
                                  ?.copyWith(color: scheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Risultato ─────────────────────────────────────────────
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _ResultCard(
                    suggestion: _result!,
                    onSave: _saveAsRecipe,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final MixingSuggestion suggestion;
  final VoidCallback onSave;

  const _ResultCard({required this.suggestion, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.primary, size: 18),
            const SizedBox(width: 6),
            Text(l.aiMixingSuggestedRecipe,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),

        // Ingredienti
        ...suggestion.ingredients.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    HexColorChip(color: hexToColor(ing.hex), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ing.name,
                              style: tt.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text('${ing.brand.toUpperCase()} ${ing.code}',
                              style: tt.bodySmall?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Barra percentuale
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${ing.percentage}%',
                            style: tt.labelLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: ing.percentage / 100,
                              backgroundColor: scheme.outline.withOpacity(0.2),
                              valueColor:
                                  AlwaysStoppedAnimation(scheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),

        // Note AI
        if (suggestion.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(suggestion.notes,
                      style: tt.bodySmall
                          ?.copyWith(color: scheme.onSecondaryContainer)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Salva come ricetta
        OutlinedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(l.aiMixingSaveAsRecipe),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}
