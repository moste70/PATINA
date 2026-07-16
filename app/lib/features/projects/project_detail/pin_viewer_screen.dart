import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/hex_color_chip.dart';
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
  // Dimensioni reali dell'immagine, lette una volta
  Size? _imageSize;
  // Dimensioni del widget Image nell'layout
  final _imageKey = GlobalKey();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  // Converte coordinate globali del tap in coordinate normalizzate [0,1]×[0,1]
  // rispetto all'immagine, tenendo conto della trasformazione zoom/pan.
  Offset? _toImageCoords(Offset globalPos) {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    // Inverti la trasformazione del viewer
    final invMatrix = Matrix4.inverted(_transformCtrl.value);
    final transformed = MatrixUtils.transformPoint(invMatrix, local);
    final w = box.size.width;
    final h = box.size.height;
    if (w == 0 || h == 0) return null;
    final nx = (transformed.dx / w).clamp(0.0, 1.0);
    final ny = (transformed.dy / h).clamp(0.0, 1.0);
    return Offset(nx, ny);
  }

  void _onTapUp(TapUpDetails details, List<Pin> pins) {
    // Ignora se c'è stato uno zoom significativo (scale > 1.05)
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    if (scale > 1.5) return; // Lascia lo zoom libero senza aggiungere pin

    final coords = _toImageCoords(details.globalPosition);
    if (coords == null) return;
    _showAddPinSheet(coords);
  }

  void _showAddPinSheet(Offset coords) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPinSheet(
        photoId: widget.photo.id,
        x: coords.dx,
        y: coords.dy,
      ),
    );
  }

  void _showEditPinSheet(Pin pin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditPinSheet(pin: pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pinsAsync = ref.watch(_pinsProvider(widget.photo.id));
    final pins = pinsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          l.pinViewerTitle,
          style: GoogleFonts.jetBrainsMono(fontSize: 14),
        ),
        actions: [
          // Toggle lista pin
          if (pins.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_outlined),
              tooltip: l.pinListTooltip,
              onPressed: () => _showPinList(pins),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l.photoDeleteTooltip,
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTapUp: (d) => _onTapUp(d, pins),
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.5,
                maxScale: 8.0,
                child: Stack(
                  children: [
                    Image.file(
                      File(widget.photo.path),
                      key: _imageKey,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                    // Pin overlay — usa LayoutBuilder per conoscere le dimensioni
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          return Stack(
                            children: pins.map((pin) {
                              return _PinMarker(
                                pin: pin,
                                containerSize: constraints.biggest,
                                onTap: () => _showEditPinSheet(pin),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Hint aggiunta pin
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.pinAddHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinList(List<Pin> pins) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _PinListSheet(
        pins: pins,
        onEdit: _showEditPinSheet,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
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
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          ],
        );
      },
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pop();
      widget.onDelete();
    }
  }
}

// ── Pin marker ────────────────────────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  final Pin pin;
  final Size containerSize;
  final VoidCallback onTap;

  const _PinMarker({
    required this.pin,
    required this.containerSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = pin.x * containerSize.width;
    final top = pin.y * containerSize.height;

    Widget marker;
    if (pin.type == 'color' && pin.notes != null) {
      // Leggi hex dal campo notes (formato: "hex:#RRGGBB|label:testo")
      final hex = _parseHex(pin.notes);
      final label = _parseLabel(pin.notes);
      marker = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HexColorChip(
            color: hex != null ? _hexToColor(hex) : scheme.primary,
            size: 28,
          ),
          if (label != null && label.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 8, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    } else {
      // Pin note
      final label = pin.notes ?? '';
      marker = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.sticky_note_2_outlined,
                color: Colors.white, size: 14),
          ),
          if (label.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 8, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      );
    }

    return Positioned(
      left: left - 14, // centra il marker
      top: top - 14,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: marker,
      ),
    );
  }

  String? _parseHex(String? notes) {
    if (notes == null) return null;
    final m = RegExp(r'hex:([#\w]+)').firstMatch(notes);
    return m?.group(1);
  }

  String? _parseLabel(String? notes) {
    if (notes == null) return null;
    final m = RegExp(r'label:(.*)').firstMatch(notes);
    return m?.group(1)?.trim();
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ── Add pin sheet ─────────────────────────────────────────────────────────────

class _AddPinSheet extends ConsumerStatefulWidget {
  final int photoId;
  final double x;
  final double y;
  const _AddPinSheet(
      {required this.photoId, required this.x, required this.y});

  @override
  ConsumerState<_AddPinSheet> createState() => _AddPinSheetState();
}

class _AddPinSheetState extends ConsumerState<_AddPinSheet> {
  String _type = 'color'; // 'color' | 'note'
  final _labelCtrl = TextEditingController();
  final _hexCtrl = TextEditingController();
  String? _selectedInventoryKey; // 'brand:code'

  @override
  void dispose() {
    _labelCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(pinRepositoryProvider);
    String? notesPayload;
    if (_type == 'color') {
      final hex = _hexCtrl.text.trim().isNotEmpty
          ? _hexCtrl.text.trim()
          : '#808080';
      final label = _labelCtrl.text.trim();
      notesPayload = 'hex:$hex|label:$label';
    } else {
      notesPayload = _labelCtrl.text.trim();
    }
    await repo.addPin(PinsCompanion(
      photoId: Value(widget.photoId),
      type: Value(_type),
      x: Value(widget.x),
      y: Value(widget.y),
      notes: Value(notesPayload),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final invAsync = ref.watch(_rawInventoryForPinProvider);
    final inventory = invAsync.value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.pinAddTitle,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: scheme.primary)),
          const SizedBox(height: 12),
          // Tipo pin
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'color',
                  label: Text(l.pinTypeColor),
                  icon: const Icon(Icons.palette_outlined, size: 16)),
              ButtonSegment(
                  value: 'note',
                  label: Text(l.pinTypeNote),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 16)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          if (_type == 'color') ...[
            // Picker vernice dall'inventario
            if (inventory.isNotEmpty) ...[
              Text(l.pinPickFromInventory,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: inventory.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final p = inventory[i];
                    final key = '${p.brand}:${p.code}';
                    final selected = _selectedInventoryKey == key;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedInventoryKey = key;
                          _hexCtrl.text = p.hex;
                          _labelCtrl.text = '${p.brand.toUpperCase()} ${p.code}';
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HexColorChip(
                            color: _hexToColor(p.hex),
                            size: selected ? 32 : 26,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _hexCtrl,
              decoration: InputDecoration(
                labelText: l.pinHexLabel,
                hintText: '#D4A017',
                prefixIcon: _hexCtrl.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: _hexToColor(_hexCtrl.text),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: _type == 'color' ? l.pinLabelLabel : l.pinNoteLabel,
              hintText: _type == 'color' ? 'XF-1 Flat Black' : l.pinNoteHint,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(l.actionSave),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// Provider leggero per l'inventario vernici (brand+code+hex)
// Carica cataloghi JSON una volta sola e li usa per risolvere l'hex
final _rawInventoryForPinProvider =
    FutureProvider.autoDispose<List<_PinPaint>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.inventoryPaints).get();

  // Indice catalogo: 'brand+code' → hex
  final catalogIndex = <String, String>{};
  const assets = [
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
  for (final asset in assets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final paints = data['paints'] as List<dynamic>;
      for (final p in paints) {
        final m = p as Map<String, dynamic>;
        catalogIndex['${brand}+${m['code']}'] = m['hex'] as String? ?? '#808080';
      }
    } catch (_) {}
  }

  // Indice custom paints
  final customRows = await db.select(db.customPaints).get();
  final customIndex = <String, String>{
    for (final r in customRows) '${r.brand}+${r.code}': r.hex,
  };

  final result = <_PinPaint>[];
  for (final ip in rows) {
    if (ip.catalogBrand != null && ip.catalogCode != null) {
      final key = '${ip.catalogBrand}+${ip.catalogCode}';
      result.add(_PinPaint(
        brand: ip.catalogBrand!,
        code: ip.catalogCode!,
        hex: catalogIndex[key] ?? '#808080',
      ));
    } else if (ip.customBrand != null && ip.customCode != null) {
      final key = '${ip.customBrand}+${ip.customCode}';
      result.add(_PinPaint(
        brand: ip.customBrand!,
        code: ip.customCode!,
        hex: customIndex[key] ?? '#808080',
      ));
    }
  }
  return result;
});

class _PinPaint {
  final String brand, code, hex;
  const _PinPaint({required this.brand, required this.code, required this.hex});
}

// ── Edit pin sheet ────────────────────────────────────────────────────────────

class _EditPinSheet extends ConsumerStatefulWidget {
  final Pin pin;
  const _EditPinSheet({required this.pin});

  @override
  ConsumerState<_EditPinSheet> createState() => _EditPinSheetState();
}

class _EditPinSheetState extends ConsumerState<_EditPinSheet> {
  late TextEditingController _labelCtrl;
  late TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.pin.type == 'color') {
      _hexCtrl = TextEditingController(
          text: _parseField(widget.pin.notes, 'hex') ?? '');
      _labelCtrl = TextEditingController(
          text: _parseField(widget.pin.notes, 'label') ?? '');
    } else {
      _hexCtrl = TextEditingController();
      _labelCtrl = TextEditingController(text: widget.pin.notes ?? '');
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  String? _parseField(String? notes, String key) {
    if (notes == null) return null;
    final m = RegExp('$key:([^|]*)').firstMatch(notes);
    return m?.group(1)?.trim();
  }

  Future<void> _save() async {
    final repo = ref.read(pinRepositoryProvider);
    String? notesPayload;
    if (widget.pin.type == 'color') {
      final hex = _hexCtrl.text.trim().isNotEmpty
          ? _hexCtrl.text.trim()
          : '#808080';
      notesPayload = 'hex:$hex|label:${_labelCtrl.text.trim()}';
    } else {
      notesPayload = _labelCtrl.text.trim();
    }
    await repo.updatePin(
        widget.pin.id, PinsCompanion(notes: Value(notesPayload)));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(pinRepositoryProvider).deletePin(widget.pin.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.pinEditTitle,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: scheme.primary)),
              const Spacer(),
              TextButton.icon(
                icon: Icon(Icons.delete_outline,
                    color: scheme.error, size: 16),
                label: Text(l.actionDelete,
                    style: TextStyle(color: scheme.error)),
                onPressed: _delete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.pin.type == 'color') ...[
            TextField(
              controller: _hexCtrl,
              decoration: InputDecoration(labelText: l.pinHexLabel),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: widget.pin.type == 'color'
                  ? l.pinLabelLabel
                  : l.pinNoteLabel,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(l.actionSave),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pin list sheet ────────────────────────────────────────────────────────────

class _PinListSheet extends StatelessWidget {
  final List<Pin> pins;
  final void Function(Pin) onEdit;
  const _PinListSheet({required this.pins, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.pinListTitle,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: scheme.primary)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: pins.length,
              itemBuilder: (_, i) {
                final pin = pins[i];
                final isColor = pin.type == 'color';
                final label = isColor
                    ? _parseField(pin.notes, 'label') ?? ''
                    : (pin.notes ?? '');
                final hex = isColor
                    ? _parseField(pin.notes, 'hex')
                    : null;

                return ListTile(
                  leading: isColor && hex != null
                      ? HexColorChip(
                          color: _hexToColor(hex), size: 32)
                      : CircleAvatar(
                          backgroundColor: scheme.tertiary,
                          radius: 16,
                          child: const Icon(
                              Icons.sticky_note_2_outlined,
                              color: Colors.white,
                              size: 14),
                        ),
                  title: Text(label.isNotEmpty ? label : '—',
                      style: tt.bodyMedium),
                  subtitle: Text(
                    isColor ? l.pinTypeColor : l.pinTypeNote,
                    style: tt.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.edit_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit(pin);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _parseField(String? notes, String key) {
    if (notes == null) return null;
    final m = RegExp('$key:([^|]*)').firstMatch(notes);
    return m?.group(1)?.trim();
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
