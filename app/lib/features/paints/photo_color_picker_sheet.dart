import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../database/app_database.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/hex_color_chip.dart';
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

  @override
  void dispose() {
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
  }

  // ── Pixel sampling ─────────────────────────────────────────────────────────

  // Converts the circle's normalised image coords → pixel, reads RGBA.
  Future<Color?> _samplePixel() async {
    final img = _uiImage;
    if (img == null) return null;

    final px = (_circle.dx * _imgW).clamp(0, _imgW - 1).round();
    final py = (_circle.dy * _imgH).clamp(0, _imgH - 1).round();

    // Average a 5×5 patch to reduce noise
    final region = 5;
    int r = 0, g = 0, b = 0, count = 0;
    for (var dy = -region ~/ 2; dy <= region ~/ 2; dy++) {
      for (var dx = -region ~/ 2; dx <= region ~/ 2; dx++) {
        final x = (px + dx).clamp(0, _imgW - 1);
        final y = (py + dy).clamp(0, _imgH - 1);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) continue;
        final offset = (y * _imgW + x) * 4;
        if (offset + 3 >= byteData.lengthInBytes) continue;
        r += byteData.getUint8(offset);
        g += byteData.getUint8(offset + 1);
        b += byteData.getUint8(offset + 2);
        count++;
        break; // toByteData is expensive — sample just the centre pixel
      }
      break;
    }
    if (count == 0) return null;
    return Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
  }

  Future<void> _onSample() async {
    if (_uiImage == null) return;
    setState(() { _sampling = true; _error = null; });
    HapticFeedback.lightImpact();
    try {
      final color = await _samplePixel();
      if (color == null) throw Exception('Impossibile leggere il pixel');
      setState(() { _sampled = color; _sampling = false; });
      await _findMatches(color);
    } catch (e) {
      setState(() { _error = e.toString(); _sampling = false; });
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

  // ── Drag handling ──────────────────────────────────────────────────────────

  // Convert a screen tap/drag position inside the Stack to normalised image coords.
  Offset _toNormalisedImageCoords(Offset local, Size stackSize) {
    // The image is fit inside the stack with BoxFit.contain
    final imgAspect = _imgW / _imgH;
    final stackAspect = stackSize.width / stackSize.height;
    double imgLeft, imgTop, imgWidth, imgHeight;
    if (imgAspect > stackAspect) {
      imgWidth = stackSize.width;
      imgHeight = stackSize.width / imgAspect;
      imgLeft = 0;
      imgTop = (stackSize.height - imgHeight) / 2;
    } else {
      imgHeight = stackSize.height;
      imgWidth = stackSize.height * imgAspect;
      imgTop = 0;
      imgLeft = (stackSize.width - imgWidth) / 2;
    }

    // Invert the viewer transform
    final m = _transformCtrl.value.clone();
    m.invert();
    final transformed = MatrixUtils.transformPoint(m, local);

    final nx = ((transformed.dx - imgLeft) / imgWidth).clamp(0.0, 1.0);
    final ny = ((transformed.dy - imgTop) / imgHeight).clamp(0.0, 1.0);
    return Offset(nx, ny);
  }

  // Convert normalised image coords → screen position inside the current Stack.
  Offset _toScreenCoords(Offset norm, Size stackSize) {
    final imgAspect = _imgW / _imgH;
    final stackAspect = stackSize.width / stackSize.height;
    double imgLeft, imgTop, imgWidth, imgHeight;
    if (imgAspect > stackAspect) {
      imgWidth = stackSize.width;
      imgHeight = stackSize.width / imgAspect;
      imgLeft = 0;
      imgTop = (stackSize.height - imgHeight) / 2;
    } else {
      imgHeight = stackSize.height;
      imgWidth = stackSize.height * imgAspect;
      imgTop = 0;
      imgLeft = (stackSize.width - imgWidth) / 2;
    }

    final imgX = imgLeft + norm.dx * imgWidth;
    final imgY = imgTop + norm.dy * imgHeight;
    return MatrixUtils.transformPoint(_transformCtrl.value, Offset(imgX, imgY));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Icon(Icons.colorize, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Text('Rileva colore da foto',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 64, color: scheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('Scegli una foto', style: tt.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Posiziona il cerchio sul colore da rilevare.\nLe foto scattate non vengono salvate.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.55)),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Fotocamera',
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _SourceButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galleria',
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
    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      children: [
        // ── Photo viewer ──────────────────────────────────────────────────────
        SizedBox(
          height: 340,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackSize = Size(constraints.maxWidth, 340);
              return GestureDetector(
                onPanUpdate: (d) {
                  final norm = _toNormalisedImageCoords(d.localPosition, stackSize);
                  setState(() { _circle = norm; });
                },
                onTapUp: (d) {
                  final norm = _toNormalisedImageCoords(d.localPosition, stackSize);
                  setState(() { _circle = norm; });
                },
                child: Stack(
                  children: [
                    // Background
                    Container(color: Colors.black),
                    // Photo
                    InteractiveViewer(
                      transformationController: _transformCtrl,
                      minScale: 0.5,
                      maxScale: 6,
                      onInteractionUpdate: (_) => setState(() {}),
                      child: Image(
                        key: _imageKey,
                        image: _imageProvider!,
                        fit: BoxFit.contain,
                        width: constraints.maxWidth,
                        height: 340,
                      ),
                    ),
                    // Circle indicator
                    _buildCircleOverlay(stackSize, scheme),
                    // Change photo button
                    Positioned(
                      top: 8, right: 8,
                      child: _IconChip(
                        icon: Icons.photo_library_outlined,
                        label: 'Cambia',
                        onTap: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              );
            },
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
                          : 'Tocca o trascina il cerchio',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'poi premi "Rileva colore"',
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
                ? 'Campionamento…'
                : _matching
                    ? 'Ricerca corrispondenze…'
                    : 'Rileva colore'),
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
              label: 'Dal tuo inventario',
              scheme: scheme,
              tt: tt,
            ),
            const SizedBox(height: 8),
            ..._inventoryMatches.map((m) => _MatchTile(match: m, scheme: scheme, tt: tt)),
          ],
          if (_catalogMatches.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(
              icon: Icons.menu_book_outlined,
              label: 'Dal catalogo',
              scheme: scheme,
              tt: tt,
            ),
            const SizedBox(height: 8),
            ..._catalogMatches.map((m) => _MatchTile(match: m, scheme: scheme, tt: tt)),
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
                      'Nessuna corrispondenza trovata entro ΔE 18.\n'
                      'Prova a spostare il cerchio su un\'area più uniforme.',
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

  Widget _buildCircleOverlay(Size stackSize, ColorScheme scheme) {
    final screen = _toScreenCoords(_circle, stackSize);
    const r = 28.0;
    final sampled = _sampled;

    return Positioned(
      left: screen.dx - r,
      top: screen.dy - r,
      child: IgnorePointer(
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
  const _MatchTile({
    required this.match,
    required this.scheme,
    required this.tt,
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
          ],
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
