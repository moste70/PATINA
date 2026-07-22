import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/gesture_hint_bar.dart';
import '../../shared/widgets/hex_color_chip.dart';
import '../projects/project_repository.dart';
import 'paints_repository.dart';

// ── Catalog loading ───────────────────────────────────────────────────────────

const _kCatalogAssets = [
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

class _CatalogEntry {
  final String brand, code, name, hex;
  const _CatalogEntry({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
  });
}

Future<List<_CatalogEntry>> _loadAllCatalogEntries() async {
  final result = <_CatalogEntry>[];
  for (final asset in _kCatalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final paints = data['paints'] as List<dynamic>;
      for (final p in paints) {
        final m = p as Map<String, dynamic>;
        final hex = m['hex'] as String? ?? '';
        if (hex.isEmpty) continue;
        result.add(_CatalogEntry(
          brand: brand,
          code: m['code'] as String? ?? '',
          name: m['name'] as String? ?? '',
          hex: hex,
        ));
      }
    } catch (_) {}
  }
  return result;
}

// ── Result model ──────────────────────────────────────────────────────────────

class _ColorMatch {
  final String brand, code, name, hex;
  final double deltaE;
  final bool fromInventory;

  const _ColorMatch({
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
    required this.deltaE,
    required this.fromInventory,
  });

  // Precisione 0–100: ΔE=0 → 100%, ΔE≥20 → 0%
  int get precision => (((20.0 - deltaE.clamp(0, 20)) / 20.0) * 100).round();
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class PhotoColorPickerSheet extends ConsumerStatefulWidget {
  const PhotoColorPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PhotoColorPickerSheet(),
    );
  }

  @override
  ConsumerState<PhotoColorPickerSheet> createState() => _State();
}

class _State extends ConsumerState<PhotoColorPickerSheet> {
  // Image state
  XFile? _xfile;
  ui.Image? _uiImage;
  ImageProvider? _imageProvider;

  // Circle position in normalised image coordinates (0–1)
  Offset _circle = const Offset(0.5, 0.5);

  // Viewer transform
  final _transformCtrl = TransformationController();

  // Sampled color
  Color? _sampled;
  bool _sampling = false;

  // Match results
  bool _matching = false;
  List<_ColorMatch> _inventoryMatches = [];
  List<_ColorMatch> _catalogMatches = [];

  String? _error;

  // Image size in pixels
  int _imgW = 1, _imgH = 1;

  // Layout size of the image widget inside the viewer
  final _imageKey = GlobalKey();
  // Scene box (background + InteractiveViewer + circle overlay) — used to
  // convert the image's global position into a Positioned-friendly local one.
  final _sceneKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Rebuild whenever zoom/pan changes so the (overlay) circle position
    // updates — same approach as PinViewerScreen.
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() => setState(() {});

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── Source picker ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    await _loadImage(file);
  }

  Future<void> _loadImage(XFile file) async {
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
      _inventoryMatches = [];
      _catalogMatches = [];
      _error = null;
      _transformCtrl.value = Matrix4.identity();
    });
    // The circle overlay needs the Image's RenderBox to be laid out before it
    // can position itself (see _toScenePos) — force one more frame once that
    // first layout has happened, so the circle shows up immediately instead
    // of only appearing after the user's first tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // ── Pixel sampling ─────────────────────────────────────────────────────────

  // Converts the circle's normalised image coords → pixel, reads RGBA.
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
    setState(() { _sampling = true; _error = null; });
    HapticFeedback.lightImpact();
    try {
      final color = await _samplePixel();
      if (color == null) {
        setState(() {
          _error = AppL10n.of(context).photoPickerSampleError;
          _sampling = false;
        });
        return;
      }
      setState(() { _sampled = color; _sampling = false; });
      await _findMatches(color);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppL10n.of(context).photoPickerSampleError;
        _sampling = false;
      });
    }
  }

  // ── ΔE matching ───────────────────────────────────────────────────────────

  Future<void> _findMatches(Color target) async {
    setState(() { _matching = true; });

    const kMaxDeltaE = 18.0;
    const kMaxEach = 2;

    // Load catalog once — used for both inventory hex resolution and catalog search
    final catalog = await _loadAllCatalogEntries();
    // Build index brand+code → entry
    final catalogIndex = <String, _CatalogEntry>{
      for (final e in catalog) '${e.brand}+${e.code}': e,
    };

    // Custom paints index for hex resolution
    final customIndex = ref.read(_customIndexProvider).valueOrNull ?? {};

    // Inventory — resolve hex from catalog or custom index
    final inventory = ref.read(rawInventoryProvider).valueOrNull ?? [];
    final invKeys = <String>{};

    final invMatches = <_ColorMatch>[];
    for (final p in inventory) {
      String brand, code, name, hex;
      if (p.catalogBrand != null && p.catalogCode != null) {
        brand = p.catalogBrand!;
        code = p.catalogCode!;
        final entry = catalogIndex['$brand+$code'];
        if (entry == null) continue;
        name = entry.name;
        hex = entry.hex;
      } else if (p.customBrand != null && p.customCode != null) {
        brand = p.customBrand!;
        code = p.customCode!;
        final entry = customIndex['$brand+$code'];
        if (entry == null) continue;
        name = entry.name;
        hex = entry.hex;
      } else {
        continue;
      }
      invKeys.add('$brand+$code');
      final de = deltaE(target, hexToColor(hex));
      if (de > kMaxDeltaE) continue;
      invMatches.add(_ColorMatch(
        brand: brand,
        code: code,
        name: name,
        hex: hex,
        deltaE: de,
        fromInventory: true,
      ));
    }
    invMatches.sort((a, b) => a.deltaE.compareTo(b.deltaE));

    // Catalog — skip what's already in inventory
    final catMatches = <_ColorMatch>[];
    for (final e in catalog) {
      if (invKeys.contains('${e.brand}+${e.code}')) continue;
      final de = deltaE(target, hexToColor(e.hex));
      if (de > kMaxDeltaE) continue;
      catMatches.add(_ColorMatch(
        brand: e.brand,
        code: e.code,
        name: e.name,
        hex: e.hex,
        deltaE: de,
        fromInventory: false,
      ));
    }
    catMatches.sort((a, b) => a.deltaE.compareTo(b.deltaE));

    setState(() {
      _inventoryMatches = invMatches.take(kMaxEach).toList();
      _catalogMatches = catMatches.take(kMaxEach).toList();
      _matching = false;
    });
  }

  // ── Actions on a match ──────────────────────────────────────────────────────

  Future<void> _addToShoppingList(_ColorMatch match) async {
    HapticFeedback.lightImpact();
    final brandLabel = AppConstants.brandLabels[match.brand] ?? match.brand;
    await ref.read(projectRepositoryProvider).addShoppingItem(
        '$brandLabel ${match.code} · ${match.name}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppL10n.of(context).paintAddedToShoppingList),
    ));
  }

  // ── Tap handling ───────────────────────────────────────────────────────────
  //
  // Same technique as PinViewerScreen: the Image's own RenderBox (found via
  // _imageKey) already reflects BoxFit.contain letterboxing *and* the current
  // InteractiveViewer pan/zoom transform, because we never give it an
  // explicit width+height — it self-sizes to the visible picture inside the
  // bounded constraints from its parent. globalToLocal/localToGlobal on that
  // box then do all the transform math for us, so tap-to-sample never needs
  // to fight InteractiveViewer's own pan/zoom gesture recognizer for the
  // pointer (they're siblings, not nested).

  // Global screen position → normalised [0,1]×[0,1] image coords.
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

  // Normalised image coords → position inside the scene Stack (for Positioned).
  Offset? _toScenePos(Offset norm) {
    final imgBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final sceneBox = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    if (imgBox == null || sceneBox == null || !imgBox.hasSize) return null;
    final global = imgBox.localToGlobal(
        Offset(norm.dx * imgBox.size.width, norm.dy * imgBox.size.height));
    return sceneBox.globalToLocal(global);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Keep these autoDispose stream providers alive and loaded for the whole
    // life of the sheet — _findMatches only `ref.read`s them, so without a
    // `watch` here they may still be AsyncLoading (or already disposed) the
    // first time the user taps "Rileva colore", silently yielding an empty
    // inventory-matches list.
    ref.watch(rawInventoryProvider);
    ref.watch(_customIndexProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
            child: Row(
              children: [
                Icon(Icons.colorize, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(AppL10n.of(context).colorPickerPhoto,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: AppL10n.of(context).tooltipClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _xfile == null
                ? _buildSourcePicker(context, scheme, tt)
                : _buildViewer(context, scheme, tt, scrollCtrl),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePicker(BuildContext context, ColorScheme scheme, TextTheme tt) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 64, color: scheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(l.photoPickerChooseTitle, style: tt.titleMedium),
            const SizedBox(height: 8),
            Text(
              l.photoPickerChooseHint,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.55)),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: l.photoSourceCamera,
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _SourceButton(
                  icon: Icons.photo_library_outlined,
                  label: l.photoSourceGallery,
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(
    BuildContext context,
    ColorScheme scheme,
    TextTheme tt,
    ScrollController scrollCtrl,
  ) {
    final l = AppL10n.of(context);
    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      children: [
        // ── Photo viewer ──────────────────────────────────────────────────────
        // Same architecture as PinViewerScreen: the tap handler and the
        // circle overlay are *siblings* of InteractiveViewer (not nested
        // inside its child), so pan/zoom is fully owned by
        // InteractiveViewer's own gesture recognizer and never competes with
        // tap-to-sample for the same pointer.
        SizedBox(
          height: 340,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) {
              final norm = _toImageCoords(d.globalPosition);
              if (norm == null) return;
              setState(() { _circle = norm; });
            },
            child: Stack(
              key: _sceneKey,
              children: [
                // Background
                Container(color: Colors.black),
                // Photo, pannable/zoomable
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
                // Circle indicator — overlay, outside InteractiveViewer
                _buildCircleOverlay(scheme),
                // Change photo button
                Positioned(
                  top: 8, right: 8,
                  child: _IconChip(
                    icon: Icons.photo_library_outlined,
                    label: l.photoPickerChangePhoto,
                    onTap: () => _pickPhoto(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureHintBar(
            hintKey: 'hint_photo_color_picker_zoom',
            message: l.photoPickerZoomHint,
          ),
        ),

        const SizedBox(height: 16),

        // ── Sampled color + sample button ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Preview swatch
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _sampled ?? scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outline.withOpacity(0.4)),
                ),
                child: _sampled == null
                    ? Icon(Icons.colorize_outlined,
                        color: scheme.onSurface.withOpacity(0.3))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sampled != null
                          ? '#${(_sampled!.value & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}'
                          : l.photoPickerTapToSample,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      l.photoPickerThenDetect,
                      style: tt.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton.icon(
            onPressed: (_sampling || _matching) ? null : _onSample,
            icon: (_sampling || _matching)
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.colorize),
            label: Text(_sampling
                ? l.photoPickerSampling
                : _matching
                    ? l.photoPickerSearching
                    : l.photoPickerDetectButton),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),

        // ── Error ────────────────────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!,
                  style: tt.bodySmall?.copyWith(color: scheme.onErrorContainer)),
            ),
          ),
        ],

        // ── Results ──────────────────────────────────────────────────────────
        if (_sampled != null &&
            !_matching &&
            (_inventoryMatches.isNotEmpty || _catalogMatches.isNotEmpty)) ...[
          const SizedBox(height: 24),
          if (_inventoryMatches.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.inventory_2_outlined,
              label: l.photoPickerFromInventory,
              scheme: scheme,
              tt: tt,
            ),
            const SizedBox(height: 8),
            ..._inventoryMatches
                .map((m) => _MatchTile(match: m, scheme: scheme, tt: tt)),
          ],
          if (_catalogMatches.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(
              icon: Icons.menu_book_outlined,
              label: l.photoPickerFromCatalog,
              scheme: scheme,
              tt: tt,
            ),
            const SizedBox(height: 8),
            ..._catalogMatches.map((m) => _MatchTile(
                  match: m,
                  scheme: scheme,
                  tt: tt,
                  onAdd: () => _addToShoppingList(m),
                )),
          ],
        ],

        if (_sampled != null &&
            !_matching &&
            _inventoryMatches.isEmpty &&
            _catalogMatches.isEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: scheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.photoPickerNoMatches,
                      style: tt.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCircleOverlay(ColorScheme scheme) {
    final screen = _toScenePos(_circle);
    if (screen == null) return const SizedBox.shrink();
    const r = 28.0;      // raggio visivo dell'anello
    const hitR = 40.0;   // raggio dell'area trascinabile — più grande dell'anello
                         // visivo per rendere il trascinamento affidabile su schermo
                         // touch (con hit area == anello visivo il dito manca spesso
                         // il bersaglio e finisce sul pan/zoom della foto sottostante)
    final sampled = _sampled;

    return Positioned(
      left: screen.dx - hitR,
      top: screen.dy - hitR,
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
        child: SizedBox(
          width: hitR * 2,
          height: hitR * 2,
          child: Center(
            child: Container(
              width: r * 2,
              height: r * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                color: sampled?.withOpacity(0.35),
              ),
              child: Center(
                child: Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconChip({required this.icon, required this.label, required this.onTap});

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
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.5),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final _ColorMatch match;
  final ColorScheme scheme;
  final TextTheme tt;
  // Present only for catalog matches — adds the paint to the inventory.
  // Inventory matches (already owned) have no action, just a status icon.
  final VoidCallback? onAdd;
  const _MatchTile({
    required this.match,
    required this.scheme,
    required this.tt,
    this.onAdd,
  });

  Color get _deColor {
    if (match.deltaE < 4) return const Color(0xFF2F8F57);
    if (match.deltaE < 10) return const Color(0xFFC87A20);
    return scheme.onSurfaceVariant;
  }

  String get _brandLabel => switch (match.brand) {
        'tamiya'    => 'Tamiya',
        'vallejo'   => 'Vallejo',
        'citadel'   => 'Citadel',
        'gunze'     => 'Gunze',
        'humbrol'   => 'Humbrol',
        'lifecolor' => 'Lifecolor',
        _           => match.brand,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            HexColorChip(color: hexToColor(match.hex), size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.name,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('$_brandLabel · ${match.code}',
                      style: tt.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${match.precision}%',
                    style: tt.labelLarge?.copyWith(
                        color: _deColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: match.precision / 100,
                      backgroundColor: scheme.outline.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(_deColor),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('ΔE ${match.deltaE.toStringAsFixed(1)}',
                    style: tt.labelSmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.45))),
              ],
            ),
            const SizedBox(width: 4),
            _buildAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    final l = AppL10n.of(context);
    if (match.fromInventory) {
      return Tooltip(
        message: l.paletteInStock,
        child: Icon(Icons.check_circle,
            color: const Color(0xFF2F8F57), size: 22),
      );
    }
    return Tooltip(
      message: l.paintAddToShoppingList,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.add_shopping_cart_outlined, color: scheme.primary, size: 22),
        ),
      ),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final rawInventoryProvider = StreamProvider.autoDispose<List<InventoryPaint>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchInventoryPaints();
});

final _customIndexProvider =
    StreamProvider.autoDispose<Map<String, CustomPaintRef>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchCustomPaintIndex();
});
