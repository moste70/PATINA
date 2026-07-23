import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/lab_mixer.dart';
import '../../shared/widgets/gesture_hint_bar.dart';
import '../../shared/widgets/hex_color_chip.dart';

// Schermata dedicata a tutto schermo per selezionare il colore target della
// Miscelazione AI — HEX manuale o campionamento da foto, con lo stesso
// pattern (fullscreenDialog, bottone chiudi ben visibile) usato dalle altre
// feature di selezione colore dell'app (rileva colore da foto, cerca ricetta
// per colore).
class TargetColorPickerScreen extends StatefulWidget {
  final String? initialHex;
  const TargetColorPickerScreen({super.key, this.initialHex});

  static Future<String?> show(BuildContext context, {String? initialHex}) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TargetColorPickerScreen(initialHex: initialHex),
      ),
    );
  }

  @override
  State<TargetColorPickerScreen> createState() =>
      _TargetColorPickerScreenState();
}

enum _InputMode { hex, photo }

class _TargetColorPickerScreenState extends State<TargetColorPickerScreen> {
  _InputMode _mode = _InputMode.hex;

  // ── HEX input ──────────────────────────────────────────────────────────────
  late final _hexCtrl = TextEditingController(text: widget.initialHex ?? '#');
  bool _hexValid = false;
  String? _hexValue;

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

  static const _kRingRadius = 26.0;
  static const _kHitRadius = 40.0;
  static const _kCircleVisualOffset = 56.0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHex;
    if (initial != null && _isValidHex(initial)) {
      _hexValid = true;
      _hexValue = initial.toUpperCase();
    }
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _transformCtrl.dispose();
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
      if (valid) _hexValue = normalized.toUpperCase();
    });
  }

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
      _transformCtrl.value = Matrix4.identity();
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
      if (color != null) {
        final hex = color.value.toRadixString(16).padLeft(8, '0').substring(2);
        _hexValue = '#${hex.toUpperCase()}';
      }
    });
  }

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

  bool get _canConfirm =>
      _mode == _InputMode.hex ? _hexValid : _hexValue != null;

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(_hexValue);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.aiMixingTargetColorLabel),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.tooltipClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
          Expanded(
            child: _mode == _InputMode.hex
                ? _buildHexMode(scheme, tt, l)
                : _buildPhotoMode(scheme, tt, l),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                icon: const Icon(Icons.check),
                label: Text(l.actionUseColor),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexMode(ColorScheme scheme, TextTheme tt, AppL10n l) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HexColorChip(
              color: _hexValid
                  ? hexToColor(_hexValue!)
                  : scheme.surfaceContainerHigh,
              size: 96,
              child: _hexValid
                  ? null
                  : Icon(Icons.colorize_outlined,
                      color: scheme.onSurface.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _hexCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: tt.titleMedium,
              decoration: InputDecoration(
                labelText: l.recipeHexInputLabel,
                hintText: l.recipeHexInputHint,
                errorText: _hexCtrl.text.length > 1 && !_hexValid
                    ? l.aiMixingHexInvalid
                    : null,
                prefixIcon: const Icon(Icons.tag),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoMode(ColorScheme scheme, TextTheme tt, AppL10n l) {
    if (_xfile == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 56, color: scheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(l.photoPickerChooseTitle, style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(
                l.photoPickerChooseHint,
                textAlign: TextAlign.center,
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurface.withOpacity(0.55)),
              ),
              const SizedBox(height: 24),
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
      );
    }

    // Il visualizzatore foto vive in un Expanded non-scrollabile, fratello
    // (non figlio) di qualunque ListView — vedi la nota analoga in
    // photo_color_picker_sheet.dart sul conflitto InteractiveViewer/Scrollable.
    return Column(
      children: [
        Expanded(child: _buildPhotoStack(scheme)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: GestureHintBar(
            hintKey: 'hint_target_color_picker_zoom',
            message: l.photoPickerZoomHint,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: FilledButton.icon(
            onPressed: _sampling ? null : _onSample,
            icon: _sampling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.colorize),
            label: Text(
                _sampling ? l.photoPickerSampling : l.photoPickerDetectButton),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStack(ColorScheme scheme) {
    final l = AppL10n.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) {
        final norm = _toImageCoords(d.globalPosition);
        if (norm != null) setState(() => _circle = norm);
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
          _buildCircleOverlay(),
          Positioned(
            top: 8,
            right: 8,
            child: _PhotoChangeChip(
              label: l.photoPickerChangePhoto,
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }

  // Durante il trascinamento il punto campionato (_circle) viene spostato
  // sopra al dito di _kCircleVisualOffset — non è un offset solo visivo:
  // finché si trascina, l'anello resta esattamente dove viene disegnato,
  // quindi al rilascio NON scatta più in giù sotto al dito. Il tap sposta
  // invece _circle sulla posizione reale toccata, senza alcun offset — un
  // tocco rapido sposta il punto esattamente dove si è toccato.
  Widget _buildCircleOverlay() {
    final screen = _toScenePos(_circle);
    if (screen == null) return const SizedBox.shrink();
    const r = _kRingRadius;
    const hitR = _kHitRadius;
    final sampled = _sampled;

    Offset offsetGlobal(Offset globalPos) =>
        globalPos - const Offset(0, _kCircleVisualOffset);

    return Positioned(
      left: screen.dx - hitR,
      top: screen.dy - hitR,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          HapticFeedback.selectionClick();
          final norm = _toImageCoords(offsetGlobal(d.globalPosition));
          if (norm != null) setState(() => _circle = norm);
        },
        onPanUpdate: (d) {
          final norm = _toImageCoords(offsetGlobal(d.globalPosition));
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
    );
  }
}

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
            const Icon(Icons.photo_library_outlined,
                size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
