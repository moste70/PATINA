import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../database/app_database.dart' hide CustomPaint, CustomPainter;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/hex_color_chip.dart';
import '../../../shared/widgets/paint_picker_sheet.dart';
import 'pin_repository.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _pinsProvider =
    StreamProvider.autoDispose.family<List<Pin>, int>((ref, photoId) =>
        ref.watch(pinRepositoryProvider).watchPins(photoId));

// ── Screen ────────────────────────────────────────────────────────────────────

class PinViewerScreen extends ConsumerStatefulWidget {
  final ProjectPhoto photo;
  final VoidCallback onDelete;

  const PinViewerScreen({
    super.key,
    required this.photo,
    required this.onDelete,
  });

  @override
  ConsumerState<PinViewerScreen> createState() => _PinViewerScreenState();
}

class _PinViewerScreenState extends ConsumerState<PinViewerScreen> {
  final _transformCtrl = TransformationController();
  final _imageKey = GlobalKey();

  // Pin whose tooltip is currently shown (null = none)
  Pin? _tooltipPin;
  // Screen position of the tooltip origin
  Offset _tooltipPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever zoom/pan changes so overlay pin positions update.
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() => setState(() {});

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  // Converts a global screen position → normalized [0,1]×[0,1] image coords.
  // box.globalToLocal already traverses all parent transforms (including
  // InteractiveViewer), so no manual matrix math is needed.
  Offset? _toImageCoords(Offset globalPos) {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    final w = box.size.width;
    final h = box.size.height;
    if (w == 0 || h == 0) return null;
    return Offset((local.dx / w).clamp(0.0, 1.0), (local.dy / h).clamp(0.0, 1.0));
  }

  // Global screen position of a normalised pin coord.
  // box.localToGlobal already applies all parent transforms.
  Offset _toScreenPos(double nx, double ny) {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(nx * box.size.width, ny * box.size.height));
  }

  void _closeTooltip() {
    if (_tooltipPin != null) setState(() => _tooltipPin = null);
  }

  void _onBackgroundTapUp(TapUpDetails d, List<Pin> pins) {
    if (_tooltipPin != null) {
      _closeTooltip();
      return;
    }
    final coords = _toImageCoords(d.globalPosition);
    if (coords == null) return;
    _showContextMenu(d.globalPosition, coords);
  }

  Future<void> _showContextMenu(Offset screenPos, Offset imageCoords) async {
    final l = AppL10n.of(context);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        screenPos.dx, screenPos.dy, screenPos.dx + 1, screenPos.dy + 1),
      items: [
        PopupMenuItem(
          value: 'color',
          child: Row(children: [
            const Icon(Icons.palette_outlined, size: 18),
            const SizedBox(width: 10),
            Text(l.pinTypeColor),
          ]),
        ),
        PopupMenuItem(
          value: 'note',
          child: Row(children: [
            const Icon(Icons.build_outlined, size: 18),
            const SizedBox(width: 10),
            Text(l.pinTypeNote),
          ]),
        ),
      ],
    );

    if (!mounted || result == null) return;

    if (result == 'color') {
      await _addColorPin(imageCoords);
    } else {
      await _addNotePin(imageCoords);
    }
  }

  Future<void> _addColorPin(Offset coords) async {
    final selection = await showPaintPickerSheet(context);
    if (!mounted || selection == null) return;
    await ref.read(pinRepositoryProvider).addPin(PinsCompanion(
      photoId: Value(widget.photo.id),
      type: const Value('color'),
      x: Value(coords.dx),
      y: Value(coords.dy),
      notes: Value('hex:${selection.hex}|brand:${selection.brand}'
          '|code:${selection.code}|name:${selection.name}'),
    ));
  }

  Future<void> _addNotePin(Offset coords) async {
    final text = await _showNoteInput(context);
    if (!mounted || text == null || text.isEmpty) return;
    await ref.read(pinRepositoryProvider).addPin(PinsCompanion(
      photoId: Value(widget.photo.id),
      type: const Value('note'),
      x: Value(coords.dx),
      y: Value(coords.dy),
      notes: Value(text),
    ));
  }

  void _onPinLongPress(Pin pin) {
    HapticFeedback.mediumImpact();
    // Tooltip appears near the chip (top-left of the callout widget).
    final dotPos = _toScreenPos(pin.x, pin.y);
    setState(() {
      _tooltipPin = pin;
      _tooltipPos = dotPos.translate(-_kDotCx, -_kDotCy);
    });
  }

  Future<void> _editColorPin(Pin pin) async {
    _closeTooltip();
    final selection = await showPaintPickerSheet(context);
    if (!mounted || selection == null) return;
    await ref.read(pinRepositoryProvider).updatePin(
      pin.id,
      PinsCompanion(
        notes: Value('hex:${selection.hex}|brand:${selection.brand}'
            '|code:${selection.code}|name:${selection.name}'),
      ),
    );
  }

  Future<void> _editNotePin(Pin pin) async {
    _closeTooltip();
    final text = await _showNoteInput(context, initial: pin.notes ?? '');
    if (!mounted || text == null) return;
    await ref.read(pinRepositoryProvider).updatePin(
      pin.id,
      PinsCompanion(notes: Value(text)),
    );
  }

  Future<void> _deletePin(Pin pin) async {
    _closeTooltip();
    await ref.read(pinRepositoryProvider).deletePin(pin.id);
  }

  Future<void> _confirmDeletePhoto() async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return AlertDialog(
          title: Text(ll.photoDeleteTitle),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ll.actionCancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ll.actionDelete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop();
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pinsAsync = ref.watch(_pinsProvider(widget.photo.id));
    final pins = pinsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => _onBackgroundTapUp(d, pins),
        child: Stack(
          children: [
            // ── Photo ───────────────────────────────────────────────────────
            InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.5,
              maxScale: 8.0,
              child: SizedBox.expand(
                child: Center(
                  child: Image.file(
                    File(widget.photo.path),
                    key: _imageKey,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),

            // ── Pin markers (overlay — outside InteractiveViewer so
            //    GestureDetector.onLongPress doesn't compete with pan) ────────
            ...pins.map((pin) {
              final pos = _toScreenPos(pin.x, pin.y);
              // Dot (bottom-right) anchored to exact image coordinate.
              return Positioned(
                left: pos.dx - _kDotCx,
                top: pos.dy - _kDotCy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  onLongPress: () => _onPinLongPress(pin),
                  child: _PinMarkerWidget(pin: pin),
                ),
              );
            }),

            // ── Delete photo button (top-right) ─────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _confirmDeletePhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.delete_outline,
                            color: Colors.white70, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Hint ────────────────────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.pinAddHint,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ),

            // ── Tooltip overlay ─────────────────────────────────────────────
            if (_tooltipPin != null)
              _PinTooltipOverlay(
                pin: _tooltipPin!,
                screenPos: _tooltipPos,
                onClose: _closeTooltip,
                onEdit: _tooltipPin!.type == 'color'
                    ? () => _editColorPin(_tooltipPin!)
                    : () => _editNotePin(_tooltipPin!),
                onDelete: () => _deletePin(_tooltipPin!),
                scheme: scheme,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

String? _parseField(String? notes, String key) {
  if (notes == null) return null;
  final m = RegExp('$key:([^|]*)').firstMatch(notes);
  return m?.group(1)?.trim();
}

Future<String?> _showNoteInput(BuildContext context,
    {String initial = ''}) async {
  final ctrl = TextEditingController(text: initial);
  final l = AppL10n.of(context);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppL10n.of(ctx).pinNoteLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Theme.of(ctx).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: AppL10n.of(ctx).pinNoteHint),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text(AppL10n.of(ctx).actionSave),
            ),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return result;
}

// ── Pin marker constants ───────────────────────────────────────────────────────
//
// Layout (chip always top-left, dot always bottom-right):
//
//   [chip 28×28]╲
//                ╲
//                 ● dot (6px) ← exact image coord, touched by finger
//
// The chip is always top-left so the finger never covers it.

const _kPinChip  = 28.0;   // chip side
const _kPinExtW  = 18.0;   // horizontal extension for callout line
const _kPinExtH  = 14.0;   // vertical extension for callout line
const _kPinDot   =  6.0;   // dot diameter

// Total widget bounding box
const _kPinW = _kPinChip + _kPinExtW + _kPinDot;
const _kPinH = _kPinChip + _kPinExtH + _kPinDot;

// Dot centre in widget-local coordinates (bottom-right anchor)
const _kDotCx = _kPinChip + _kPinExtW + _kPinDot / 2;
const _kDotCy = _kPinChip + _kPinExtH + _kPinDot / 2;

// ── Pin marker widget ─────────────────────────────────────────────────────────

class _PinMarkerWidget extends StatelessWidget {
  final Pin pin;
  const _PinMarkerWidget({required this.pin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip;
    if (pin.type == 'color') {
      final hex = _parseField(pin.notes, 'hex') ?? '#808080';
      chip = HexColorChip(color: _hexColor(hex), size: _kPinChip);
    } else {
      chip = Container(
        width: _kPinChip,
        height: _kPinChip,
        decoration: BoxDecoration(
          color: scheme.tertiary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.build_outlined, color: Colors.white, size: 14),
      );
    }

    return SizedBox(
      width: _kPinW,
      height: _kPinH,
      child: Stack(
        children: [
          // Callout line + dot
          Positioned.fill(
            child: CustomPaint(
              painter: _CalloutPainter(
                lineFrom: const Offset(_kPinChip, _kPinChip),
                lineTo: const Offset(_kDotCx, _kDotCy),
                dotRadius: _kPinDot / 2,
              ),
            ),
          ),
          // Chip always top-left
          Positioned(left: 0, top: 0, child: chip),
        ],
      ),
    );
  }
}

class _CalloutPainter extends CustomPainter {
  final Offset lineFrom;
  final Offset lineTo;
  final double dotRadius;
  const _CalloutPainter({
    required this.lineFrom,
    required this.lineTo,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(lineFrom, lineTo, linePaint);
    canvas.drawCircle(lineTo, dotRadius,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_CalloutPainter old) =>
      old.lineFrom != lineFrom || old.lineTo != lineTo;
}

// ── Tooltip overlay ───────────────────────────────────────────────────────────

class _PinTooltipOverlay extends StatelessWidget {
  final Pin pin;
  final Offset screenPos;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ColorScheme scheme;

  const _PinTooltipOverlay({
    required this.pin,
    required this.screenPos,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Position tooltip above/below the pin, keeping it on-screen
    const tooltipW = 220.0;
    const tooltipH = 130.0;
    double left = (screenPos.dx - tooltipW / 2).clamp(8.0, size.width - tooltipW - 8);
    double top = screenPos.dy - tooltipH - 16;
    if (top < 60) top = screenPos.dy + 28;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onClose,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: tooltipW,
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: pin.type == 'color'
                    ? _ColorTooltipContent(pin: pin, scheme: scheme)
                    : _NoteTooltipContent(pin: pin, scheme: scheme),
              ),
            ),
          ),
          // Action row outside the card area — centred below/above tooltip
          Positioned(
            left: left,
            top: top + (pin.type == 'color' ? 104 : 80),
            width: tooltipW,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TooltipAction(
                  icon: Icons.edit_outlined,
                  color: scheme.primary,
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
                _TooltipAction(
                  icon: Icons.delete_outline,
                  color: scheme.error,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorTooltipContent extends StatelessWidget {
  final Pin pin;
  final ColorScheme scheme;
  const _ColorTooltipContent({required this.pin, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final hex   = _parseField(pin.notes, 'hex')   ?? '#808080';
    final brand = _parseField(pin.notes, 'brand')  ?? '';
    final code  = _parseField(pin.notes, 'code')   ?? '';
    final name  = _parseField(pin.notes, 'name')   ?? '';
    // Backward compat with old 'label:' format
    final label = _parseField(pin.notes, 'label')  ?? '';

    final displayCode  = code.isNotEmpty  ? code  : label;
    final displayBrand = brand.isNotEmpty ? brand.toUpperCase() : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HexColorChip(color: _hexColor(hex), size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (displayBrand.isNotEmpty)
                Text(displayBrand,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: scheme.primary,
                        letterSpacing: 1)),
              if (displayCode.isNotEmpty)
                Text(displayCode,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                    overflow: TextOverflow.ellipsis),
              if (name.isNotEmpty)
                Text(name,
                    style: GoogleFonts.ibmPlexSans(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              Text(hex.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteTooltipContent extends StatelessWidget {
  final Pin pin;
  final ColorScheme scheme;
  const _NoteTooltipContent({required this.pin, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.build_outlined, color: scheme.tertiary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pin.notes ?? '',
            style: GoogleFonts.ibmPlexSans(
                fontSize: 13, color: scheme.onSurface),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TooltipAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TooltipAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
