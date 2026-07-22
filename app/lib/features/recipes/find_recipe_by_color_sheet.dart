import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/gesture_hint_bar.dart';
import '../../shared/widgets/hex_color_chip.dart';
import 'recipe_repository.dart';

// ── 1C.9 — Cerca ricetta per colore target ────────────────────────────────────
//
// Algoritmo interno Fase 1 (gratuito, offline): l'utente sceglie un colore
// (HEX manuale o campionato da foto) e vede le ricette salvate più vicine in
// spazio CIELAB (vedi docs/features.md §2.4). Riusa il motore ΔE già esistente
// in lab_mixer.dart (usato anche da paint_suggestion_service.dart) e le label
// ΔE già pronte in l10n_helpers.dart, rimaste orfane dopo la rimozione
// temporanea della feature (vedi DT.14 in docs/roadmap.md).

enum _InputMode { hex, photo }

class _RecipeColorMatch {
  final Recipe recipe;
  final Color blended;
  final double deltaE;
  const _RecipeColorMatch({
    required this.recipe,
    required this.blended,
    required this.deltaE,
  });
}

final _recipesProvider = StreamProvider.autoDispose<List<Recipe>>(
    (ref) => ref.watch(recipeRepositoryProvider).watchAllRecipes());

final _allIngredientsProvider = StreamProvider.autoDispose<List<RecipeIngredient>>(
    (ref) => ref.watch(recipeRepositoryProvider).watchAllIngredients());

class FindRecipeByColorSheet extends ConsumerStatefulWidget {
  const FindRecipeByColorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FindRecipeByColorSheet(),
    );
  }

  @override
  ConsumerState<FindRecipeByColorSheet> createState() => _State();
}

class _State extends ConsumerState<FindRecipeByColorSheet> {
  static const _kMaxDeltaE = 25.0;
  static const _kMaxResults = 5;

  _InputMode _mode = _InputMode.hex;

  // ── HEX input ──────────────────────────────────────────────────────────────
  final _hexCtrl = TextEditingController(text: '#');
  bool _hexValid = false;
  String _hexPreview = '#888888';

  // ── Photo input ────────────────────────────────────────────────────────────
  XFile? _xfile;
  ui.Image? _uiImage;
  ImageProvider? _imageProvider;
  Offset _circle = const Offset(0.5, 0.5);
  final _transformCtrl = TransformationController();
  Color? _sampled;
  bool _sampling = false;
  int _imgW = 1, _imgH = 1;
  final _imageKey = GlobalKey();
  final _sceneKey = GlobalKey();

  // ── Results ────────────────────────────────────────────────────────────────
  List<_RecipeColorMatch> _matches = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() => setState(() {});

  @override
  void dispose() {
    _hexCtrl.dispose();
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── HEX handling ───────────────────────────────────────────────────────────

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
    if (valid) _runSearch(hexToColor(_hexPreview));
  }

  // ── Photo handling ─────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    setState(() {
      _xfile = file;
      _uiImage = img;
      _imgW = img.width;
      _imgH = img.height;
      _imageProvider = MemoryImage(bytes);
      _circle = const Offset(0.5, 0.5);
      _sampled = null;
      _matches = [];
      _searched = false;
      _transformCtrl.value = Matrix4.identity();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<Color?> _samplePixel() async {
    final img = _uiImage;
    if (img == null) return null;
    final x = (_circle.dx * _imgW).clamp(0, _imgW - 1).round();
    final y = (_circle.dy * _imgH).clamp(0, _imgH - 1).round();
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final offset = (y * _imgW + x) * 4;
    if (offset + 3 >= byteData.lengthInBytes) return null;
    return Color.fromARGB(
      255,
      byteData.getUint8(offset),
      byteData.getUint8(offset + 1),
      byteData.getUint8(offset + 2),
    );
  }

  Future<void> _onSample() async {
    if (_uiImage == null) return;
    setState(() => _sampling = true);
    HapticFeedback.lightImpact();
    final color = await _samplePixel();
    if (!mounted) return;
    setState(() {
      _sampled = color;
      _sampling = false;
    });
    if (color != null) _runSearch(color);
  }

  Offset? _toImageCoords(Offset globalPos) {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPos);
    final w = box.size.width;
    final h = box.size.height;
    if (w == 0 || h == 0) return null;
    return Offset(
      (local.dx / w).clamp(0.0, 1.0),
      (local.dy / h).clamp(0.0, 1.0),
    );
  }

  Offset? _toScenePos(Offset norm) {
    final imgBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final sceneBox = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    if (imgBox == null || sceneBox == null || !imgBox.hasSize) return null;
    final global = imgBox.localToGlobal(
        Offset(norm.dx * imgBox.size.width, norm.dy * imgBox.size.height));
    return sceneBox.globalToLocal(global);
  }

  // ── ΔE ranking ─────────────────────────────────────────────────────────────

  void _runSearch(Color target) {
    final recipes = ref.read(_recipesProvider).valueOrNull ?? [];
    final ingredients = ref.read(_allIngredientsProvider).valueOrNull ?? [];

    final matches = <_RecipeColorMatch>[];
    for (final recipe in recipes) {
      final ings = ingredients
          .where((i) =>
              i.recipeId == recipe.id && i.hex != null && i.hex!.isNotEmpty)
          .toList();
      if (ings.isEmpty) continue;
      final blended = blendColorsInLab(
          ings.map((i) => (hex: i.hex!, weight: i.percentage)).toList());
      final de = deltaE(target, blended);
      if (de > _kMaxDeltaE) continue;
      matches.add(_RecipeColorMatch(recipe: recipe, blended: blended, deltaE: de));
    }
    matches.sort((a, b) => a.deltaE.compareTo(b.deltaE));
    setState(() {
      _matches = matches.take(_kMaxResults).toList();
      _searched = true;
    });
  }

  bool _anyRecipeHasColor() {
    final recipes = ref.read(_recipesProvider).valueOrNull ?? [];
    final ingredients = ref.read(_allIngredientsProvider).valueOrNull ?? [];
    return recipes.any((r) => ingredients
        .any((i) => i.recipeId == r.id && i.hex != null && i.hex!.isNotEmpty));
  }

  void _openRecipe(Recipe recipe) {
    Navigator.of(context).pop();
    context.push('/recipes/${recipe.id}');
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Mantiene vivi gli stream mentre lo sheet è aperto.
    ref.watch(_recipesProvider);
    ref.watch(_allIngredientsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Icon(Icons.search, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(l.recipesFindByColorTitle,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureHintBar(
              hintKey: 'hint_recipes_find_by_color',
              message: l.recipesFindByColorHint,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<_InputMode>(
              segments: [
                ButtonSegment(
                  value: _InputMode.hex,
                  label: Text(l.recipesColorInputHexMode),
                  icon: const Icon(Icons.tag),
                ),
                ButtonSegment(
                  value: _InputMode.photo,
                  label: Text(l.recipesColorInputPhotoMode),
                  icon: const Icon(Icons.camera_alt_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (_mode == _InputMode.hex)
                  ..._buildHexMode(scheme, tt, l)
                else
                  ..._buildPhotoMode(scheme, tt, l),
                ..._buildResults(scheme, tt, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHexMode(ColorScheme scheme, TextTheme tt, AppL10n l) {
    return [
      Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _hexValid ? hexToColor(_hexPreview) : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outline.withOpacity(0.4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _hexCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.recipeHexInputLabel,
                hintText: l.recipeHexInputHint,
                errorText: _hexCtrl.text.length > 1 && !_hexValid
                    ? l.aiMixingHexInvalid
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
    ];
  }

  List<Widget> _buildPhotoMode(ColorScheme scheme, TextTheme tt, AppL10n l) {
    if (_xfile == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 56, color: scheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(l.photoPickerChooseTitle, style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(
                l.photoPickerChooseHint,
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.55)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l.photoSourceCamera),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l.photoSourceGallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      ];
    }

    return [
      SizedBox(
        height: 280,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final norm = _toImageCoords(d.globalPosition);
            if (norm == null) return;
            setState(() => _circle = norm);
          },
          child: Stack(
            key: _sceneKey,
            children: [
              Container(color: Colors.black),
              InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.5,
                maxScale: 6,
                child: SizedBox.expand(
                  child: Center(
                    child: Image(
                      key: _imageKey,
                      image: _imageProvider!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              _buildCircleOverlay(scheme),
              Positioned(
                top: 8, right: 8,
                child: _PhotoChangeChip(
                  label: l.photoPickerChangePhoto,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(l.photoPickerZoomHint,
          style: tt.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.55))),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _sampling ? null : _onSample,
        icon: _sampling
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.colorize),
        label: Text(_sampling ? l.photoPickerSampling : l.photoPickerDetectButton),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];
  }

  Widget _buildCircleOverlay(ColorScheme scheme) {
    final screen = _toScenePos(_circle);
    if (screen == null) return const SizedBox.shrink();
    const r = 26.0;
    return Positioned(
      left: screen.dx - r,
      top: screen.dy - r,
      // Opaque + onPanUpdate: un trascinamento che parte dal cerchio lo
      // riposiziona direttamente, senza competere con il pan/zoom di
      // InteractiveViewer sottostante (bloccato dall'hit test opaco).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => HapticFeedback.selectionClick(),
        onPanUpdate: (d) {
          final norm = _toImageCoords(d.globalPosition);
          if (norm != null) setState(() => _circle = norm);
        },
        child: Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
            color: _sampled?.withOpacity(0.35),
          ),
          child: Center(
            child: Container(
              width: 4, height: 4,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResults(ColorScheme scheme, TextTheme tt, AppL10n l) {
    if (!_searched) return const [];

    if (_matches.isEmpty) {
      final message = _anyRecipeHasColor()
          ? l.recipesColorNoMatch
          : l.recipesNoColoredIngredients;
      return [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.search_off, color: scheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: tt.bodySmall)),
            ],
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 24),
      Text(l.recipesSimilarLabel.toUpperCase(),
          style: tt.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.5), letterSpacing: 0.8)),
      const SizedBox(height: 8),
      ..._matches.map((m) => _RecipeMatchTile(
            match: m,
            onTap: () => _openRecipe(m.recipe),
          )),
    ];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PhotoChangeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PhotoChangeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RecipeMatchTile extends StatelessWidget {
  final _RecipeColorMatch match;
  final VoidCallback onTap;
  const _RecipeMatchTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              HexColorChip(color: match.blended, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.recipe.name,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      l.recipeDeltaMatchLabel(
                          l.deltaELabel(match.deltaE), match.deltaE.toStringAsFixed(1)),
                      style: tt.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurface.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
