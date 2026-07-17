import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/claude_service.dart';
import '../../shared/widgets/hex_color_chip.dart';
import 'create_recipe_screen.dart';

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

  factory MixingSuggestion.fromJson(Map<String, dynamic> json, String targetHex) {
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

  factory MixingIngredient.fromJson(Map<String, dynamic> json) => MixingIngredient(
        brand: json['brand'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        hex: json['hex'] as String? ?? '#888888',
        percentage: (json['percentage'] as num?)?.toInt() ?? 50,
      );
}

// ── Mock per debug senza Firebase Functions ───────────────────────────────────

MixingSuggestion _mockSuggestion(String targetHex) => MixingSuggestion(
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
      notes: '[MOCK] Questa è una risposta di test. Configura Firebase Functions '
          'con la Claude API key per ottenere suggerimenti reali.',
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

class _AiMixingSheetState extends ConsumerState<AiMixingSheet> {
  final _hexCtrl = TextEditingController(text: '#');
  final _hexFocus = FocusNode();
  String _hexPreview = '#888888';
  bool _hexValid = false;

  final Set<String> _selectedBrands = {'vallejo', 'tamiya', 'citadel'};
  bool _loading = false;
  MixingSuggestion? _result;
  String? _error;

  static const _kBrands = [
    ('vallejo', 'Vallejo'),
    ('tamiya', 'Tamiya'),
    ('citadel', 'Citadel'),
    ('gunze', 'Gunze'),
    ('humbrol', 'Humbrol'),
    ('lifecolor', 'Lifecolor'),
  ];

  @override
  void dispose() {
    _hexCtrl.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  bool _isValidHex(String v) {
    final s = v.startsWith('#') ? v.substring(1) : v;
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(s);
  }

  void _onHexChanged(String v) {
    final normalized = v.startsWith('#') ? v : '#$v';
    final valid = _isValidHex(normalized);
    setState(() {
      _hexValid = valid;
      if (valid) _hexPreview = normalized.toUpperCase();
    });
  }

  Color _previewColor() {
    try {
      final hex = _hexPreview.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _generate() async {
    if (!_hexValid) return;
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
        setState(() => _result = _mockSuggestion(_hexPreview));
      } else {
        final svc = ref.read(claudeServiceProvider);
        final raw = await svc.suggestMixingRecipe(
          targetHex: _hexPreview,
          availableBrands: _selectedBrands.toList(),
        );
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        setState(() => _result = MixingSuggestion.fromJson(decoded, _hexPreview));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
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
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
              width: 40, height: 4,
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
                Text('Miscelazione AI',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('PRO',
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
                Text('Colore target', style: tt.labelMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                    letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _previewColor(),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _hexCtrl,
                        focusNode: _hexFocus,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Codice HEX',
                          hintText: '#A3B18A',
                          errorText: _hexCtrl.text.length > 1 && !_hexValid
                              ? 'Formato non valido (es. #4A7A3D)'
                              : null,
                          prefixIcon: const Icon(Icons.colorize_outlined),
                        ),
                        onChanged: _onHexChanged,
                        inputFormatters: [
                          TextInputFormatter.withFunction((old, newVal) {
                            var text = newVal.text.toUpperCase();
                            if (!text.startsWith('#')) text = '#$text';
                            if (text.length > 7) text = text.substring(0, 7);
                            return newVal.copyWith(
                              text: text,
                              selection: TextSelection.collapsed(offset: text.length),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Marche disponibili ─────────────────────────────────────
                Text('Marche disponibili', style: tt.labelMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                    letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _kBrands.map((b) {
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
                  onPressed: (_hexValid && _selectedBrands.isNotEmpty && !_loading)
                      ? _generate
                      : null,
                  icon: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_loading ? 'Analisi in corso…' : 'Genera ricetta AI'),
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
                        Icon(Icons.error_outline, color: scheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: tt.bodySmall?.copyWith(color: scheme.onErrorContainer)),
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

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '').padLeft(6, '0');
  return Color(int.parse('FF$h', radix: 16));
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final MixingSuggestion suggestion;
  final VoidCallback onSave;

  const _ResultCard({required this.suggestion, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.primary, size: 18),
            const SizedBox(width: 6),
            Text('Ricetta suggerita',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),

        // Ingredienti
        ...suggestion.ingredients.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    HexColorChip(color: _hexToColor(ing.hex), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ing.name,
                              style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500)),
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
                              valueColor: AlwaysStoppedAnimation(scheme.primary),
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
                      style: tt.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer)),
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
          label: const Text('Salva come ricetta'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}
