import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final claudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

// Risultato dell'analisi AI di un manuale di montaggio
class ManualAnalysisResult {
  final List<String> phases;
  final List<ColorHint> colorHints;
  final List<String> fittings;
  final bool riggingPagesFound;

  const ManualAnalysisResult({
    required this.phases,
    this.colorHints = const [],
    this.fittings = const [],
    this.riggingPagesFound = false,
  });

  factory ManualAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ManualAnalysisResult(
      phases: List<String>.from(json['phases'] ?? []),
      colorHints: (json['colorHints'] as List<dynamic>? ?? [])
          .map((e) => ColorHint.fromJson(e as Map<String, dynamic>))
          .toList(),
      fittings: List<String>.from(json['fittings'] ?? []),
      riggingPagesFound: json['riggingPagesFound'] == true,
    );
  }
}

class ColorHint {
  final String brand;
  final String code;
  final String? name;
  final String? hex;

  const ColorHint({
    required this.brand,
    required this.code,
    this.name,
    this.hex,
  });

  factory ColorHint.fromJson(Map<String, dynamic> json) => ColorHint(
        brand: json['brand'] as String,
        code: json['code'] as String,
        name: json['name'] as String?,
        hex: json['hex'] as String?,
      );
}

class ClaudeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    // ⚠️  Sostituire con la region Firebase scelta (es. 'europe-west1')
    region: 'us-central1',
  );

  // Analizza pagine di un manuale di montaggio tramite Claude Vision
  // [base64Images]: lista di immagini JPEG in base64 (max 8 per chiamata)
  // [projectCategory]: categoria del kit (tank|aircraft|figure|ship|car|motorcycle|diorama|other)
  Future<ManualAnalysisResult> analyzeManual({
    required List<String> base64Images,
    required String projectCategory,
  }) async {
    final callable = _functions.httpsCallable('analyzeManual');
    final result = await callable.call<Map<String, dynamic>>({
      'images': base64Images,
      'category': projectCategory,
    });
    return ManualAnalysisResult.fromJson(result.data);
  }

  // Suggerisce ricette di miscelazione per un colore target.
  // Restituisce JSON string con { ingredients: [...], notes: "..." }
  Future<String> suggestMixingRecipe({
    required String targetHex,
    required List<String> availableBrands,
  }) async {
    final callable = _functions.httpsCallable('suggestMixingRecipe');
    final result = await callable.call<Map<String, dynamic>>({
      'targetHex': targetHex,
      'availableBrands': availableBrands,
    });
    // La Function restituisce il JSON come stringa per massima compatibilità
    return result.data['recipe'] as String;
  }
}
