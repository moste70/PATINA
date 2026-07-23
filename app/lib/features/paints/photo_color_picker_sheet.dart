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
  final int? projectId;
  const PhotoColorPickerSheet({super.key, this.projectId});

  /// [projectId] — se presente, i suggerimenti mostrano "+" per aggiungere il
  /// colore alla palette/kit di quel progetto invece del carrello lista spesa.
  static Future<void> show(BuildContext context, {int? projectId}) {
    // Fullscreen, non bottom sheet: stesso pattern del viewer foto
    // fullscreen già usato altrove nell'app (MaterialPageRoute con
    // fullscreenDialog:true) — bottone chiudi sempre visibile in AppBar,
    // invece di icone overlay facili da non notare sopra la foto.
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoColorPickerSheet(projectId: projectId),
      ),
    );
  }

  @override
  ConsumerState<PhotoColorPickerSheet> createState() => _State();
}

class _State extends ConsumerState<PhotoColorPickerSheet> {
  static const _kCircleVisualOffset = 56.0; // il cerchio resta sopra il dito
  static const _kRingRadius = 28.0; // raggio visivo dell'anello

  // Image state
  XFile? _xfile;
  ui.Image? _uiImage;
  ImageProvider? _imageProvider;

  // Circle position in normalised image coordinates (0–1) — corrisponde
  // sempre al punto reale sotto al dito, non alla posizione disegnata.
  Offset _circle = const Offset(0.5, 0.5);

  // Viewer transform
  final _transformCtrl = TransformationController();

  // Sampled color + suggerimenti (mostrati nel tooltip su tap prolungato).
  // Inventario prima, catalogo dopo; ordine alfabetico all'interno di ognuno.
  Color? _sampled;
  bool _tooltipVisible = false;
  bool _matching = false;
  bool _isDragging = false; // true solo mentre si trascina l'anello
  List<_ColorMatch> _inventoryMatches = [];
  List<_ColorMatch> _catalogMatches = [];

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
      _tooltipVisible = false;
      _inventoryMatches = [];
      _catalogMatches = [];
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

  // Tap prolungato ovunque sulla foto: NON sposta il cerchio (per
  // riposizionarlo si trascina l'anello), campiona la posizione attuale e
  // apre subito il tooltip con i suggerimenti — nessun bottone separato.
  Future<void> _onLongPress() async {
    setState(() {
      _tooltipVisible = true;
      _sampled = null;
      _inventoryMatches = [];
      _catalogMatches = [];
      _matching = true;
    });
    HapticFeedback.mediumImpact();
    final color = await _samplePixel();
    if (!mounted) return;
    if (color == null) {
      setState(() {
        _tooltipVisible = false;
        _matching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppL10n.of(context).photoPickerSampleError),
      ));
      return;
    }
    setState(() => _sampled = color);
    await _findMatches(color);
  }

  // ── ΔE matching ───────────────────────────────────────────────────────────

  Future<void> _findMatches(Color target) async {
    const kMaxDeltaE = 18.0;
    const kMaxEach = 3;

    // Load catalog once — used for both inventory hex resolution and catalog search
    final catalog = await _loadAllCatalogEntries();
    final catalogIndex = <String, _CatalogEntry>{
      for (final e in catalog) '${e.brand}+${e.code}': e,
    };
    final customIndex = ref.read(_customIndexProvider).valueOrNull ?? {};
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

    // Inventario prima, poi catalogo; ordine alfabetico all'interno di ognuno
    // (non per ΔE — la percentuale di somiglianza resta comunque mostrata).
    invMatches.sort((a, b) => a.name.compareTo(b.name));
    catMatches.sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
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
    await ref
        .read(projectRepositoryProvider)
        .addShoppingItem('$brandLabel ${match.code} · ${match.name}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppL10n.of(context).paintAddedToShoppingList),
    ));
  }

  Future<void> _addToProjectKit(_ColorMatch match) async {
    final projectId = widget.projectId;
    if (projectId == null) return;
    HapticFeedback.lightImpact();
    await ref.read(projectRepositoryProvider).addProjectPaint(
          projectId: projectId,
          brand: match.brand,
          code: match.code,
          name: match.name,
          hex: match.hex,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppL10n.of(context).paletteSnackAdded(1)),
    ));
  }

  // ── Tap / long-press handling ────────────────────────────────────────────
  //
  // Same technique as PinViewerScreen: the Image's own RenderBox (found via
  // _imageKey) already reflects BoxFit.contain letterboxing *and* the current
  // InteractiveViewer pan/zoom transform, because we never give it an
  // explicit width+height — it self-sizes to the visible picture inside the
  // bounded constraints from its parent. globalToLocal/localToGlobal on that
  // box then do all the transform math for us, so tap/long-press never needs
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
    final l = AppL10n.of(context);

    // Keep these autoDispose stream providers alive and loaded for the whole
    // life of the sheet — _findMatches only `ref.read`s them, so without a
    // `watch` here they may still be AsyncLoading (or already disposed) the
    // first time the user fa un tap prolungato, silently yielding an empty
    // inventory-matches list.
    ref.watch(rawInventoryProvider);
    ref.watch(_customIndexProvider);

    // Fullscreen come il viewer foto già usato altrove nell'app: AppBar
    // scura con bottone chiudi sempre visibile (mai un'icona overlay sopra
    // la foto, facile da non notare), solo icone con tooltip — mai testo.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.tooltipClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_xfile != null)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: l.photoPickerChangePhoto,
              onPressed: () => _pickPhoto(ImageSource.gallery),
            ),
        ],
      ),
      body: _xfile == null
          ? _buildSourcePicker(context, scheme, tt)
          : _buildViewer(context, scheme, tt),
    );
  }

  Widget _buildSourcePicker(
      BuildContext context, ColorScheme scheme, TextTheme tt) {
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
              style: tt.bodySmall
                  ?.copyWith(color: scheme.onSurface.withOpacity(0.55)),
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

  Widget _buildViewer(BuildContext context, ColorScheme scheme, TextTheme tt) {
    final l = AppL10n.of(context);
    return Column(
      children: [
        Expanded(child: _buildPhotoStack(context, scheme, tt)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: GestureHintBar(
            hintKey: 'hint_photo_color_picker_zoom',
            message: l.photoPickerZoomHint,
          ),
        ),
      ],
    );
  }

  // Il visualizzatore foto NON deve mai stare dentro una ListView: un
  // InteractiveViewer annidato in uno Scrollable compete con lo scroll/resize
  // del bottom sheet per lo stesso gesto di trascinamento, e lo Scrollable
  // tende a vincere l'arena — pan/pinch sulla foto finiva per scorrere/
  // ridimensionare il sheet invece di spostare/zoomare l'immagine. Qui la
  // foto occupa tutto lo spazio disponibile (Expanded) e non c'è più nessuna
  // ListView in gioco.
  Widget _buildPhotoStack(
      BuildContext context, ColorScheme scheme, TextTheme tt) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        final norm = _toImageCoords(d.globalPosition);
        if (norm == null) return;
        setState(() {
          _circle = norm;
          _tooltipVisible = false;
        });
      },
      onLongPressStart: (_) => _onLongPress(),
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
          if (_tooltipVisible) _buildTooltip(context, scheme, tt),
        ],
      ),
    );
  }

  Widget _buildCircleOverlay(ColorScheme scheme) {
    final screen = _toScenePos(_circle);
    if (screen == null) return const SizedBox.shrink();
    const r = _kRingRadius;
    const hitR = 40.0; // area trascinabile, più larga dell'anello per essere
    // facile da afferrare su schermo touch.
    final sampled = _sampled;

    // A riposo l'anello è disegnato esattamente nella posizione reale (hit
    // test e disegno coincidono, quindi toccarlo per iniziare a trascinare
    // funziona sempre). SOLO mentre lo si sta trascinando (_isDragging) il
    // disegno viene spostato sopra al dito (Transform.translate, non tocca
    // l'hit test) così l'anello resta visibile e non coperto; il gesto è
    // comunque già "catturato" dal puntatore quindi lo spostamento visivo
    // non interrompe il trascinamento. Al rilascio l'anello torna a
    // disegnarsi esattamente nel punto campionato.
    return Positioned(
      left: screen.dx - hitR,
      top: screen.dy - hitR,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          HapticFeedback.selectionClick();
          setState(() {
            _isDragging = true;
            _tooltipVisible = false;
          });
        },
        onPanUpdate: (d) {
          final norm = _toImageCoords(d.globalPosition);
          if (norm != null) setState(() => _circle = norm);
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
        child: SizedBox(
          width: hitR * 2,
          height: hitR * 2,
          child: Center(
            child: Transform.translate(
              offset: _isDragging
                  ? const Offset(0, -_kCircleVisualOffset)
                  : Offset.zero,
              transformHitTests: false,
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4),
                  ],
                  color: sampled?.withOpacity(0.35),
                ),
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
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
      ),
    );
  }

  Widget _buildTooltip(BuildContext context, ColorScheme scheme, TextTheme tt) {
    final l = AppL10n.of(context);
    final screen = _toScenePos(_circle);
    final sceneBox = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    if (screen == null || sceneBox == null) return const SizedBox.shrink();
    final size = sceneBox.size;

    // Inventario prima, poi catalogo — l'ordine di visualizzazione segue
    // esattamente questo elenco concatenato.
    final allMatches = [..._inventoryMatches, ..._catalogMatches];

    const tooltipW = 260.0;
    const rowH = 50.0;
    final tooltipH =
        _matching || allMatches.isEmpty ? 56.0 : allMatches.length * rowH + 16;

    final maxLeft = (size.width - tooltipW - 8).clamp(8.0, size.width);
    final left = (screen.dx - tooltipW / 2).clamp(8.0, maxLeft);
    // Il tooltip appare dopo un tap prolungato (l'anello non è in
    // trascinamento, quindi è nella sua posizione reale): prova sopra
    // l'anello; se non c'è spazio, sotto al punto reale.
    double top = screen.dy - _kRingRadius - tooltipH - 12;
    if (top < 8) top = screen.dy + _kRingRadius + 12;

    return Positioned(
      left: left,
      top: top,
      width: tooltipW,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: (_matching || allMatches.isEmpty)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_matching) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ] else
                      Icon(Icons.search_off,
                          color: scheme.onSurface.withOpacity(0.5), size: 18),
                    if (!_matching) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _matching
                            ? l.photoPickerSearching
                            : l.photoPickerNoMatches,
                        style: tt.bodySmall,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allMatches.map((m) {
                    final hasProject = widget.projectId != null;
                    IconData? icon;
                    String? tip;
                    VoidCallback? onTap;
                    if (hasProject) {
                      icon = Icons.add_circle_outline;
                      tip = l.paletteAddPaintTooltip;
                      onTap = () => _addToProjectKit(m);
                    } else if (!m.fromInventory) {
                      icon = Icons.add_shopping_cart_outlined;
                      tip = l.paintAddToShoppingList;
                      onTap = () => _addToShoppingList(m);
                    }
                    return _TooltipRow(
                      match: m,
                      scheme: scheme,
                      tt: tt,
                      actionIcon: icon,
                      actionTooltip: tip,
                      onAction: onTap,
                    );
                  }).toList(),
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
  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

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

class _TooltipRow extends StatelessWidget {
  final _ColorMatch match;
  final ColorScheme scheme;
  final TextTheme tt;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  const _TooltipRow({
    required this.match,
    required this.scheme,
    required this.tt,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  String get _brandLabel =>
      AppConstants.brandLabels[match.brand] ?? match.brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          HexColorChip(color: hexToColor(match.hex), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$_brandLabel · ${match.code}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${match.precision}%',
            style: tt.labelSmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          if (actionIcon != null)
            Tooltip(
              message: actionTooltip ?? '',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(actionIcon, color: scheme.primary, size: 20),
                ),
              ),
            )
          else
            const Icon(Icons.check_circle, color: Color(0xFF2F8F57), size: 20),
        ],
      ),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final rawInventoryProvider =
    StreamProvider.autoDispose<List<InventoryPaint>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchInventoryPaints();
});

final _customIndexProvider =
    StreamProvider.autoDispose<Map<String, CustomPaintRef>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchCustomPaintIndex();
});
