import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// `show` evita la collisione con il widget Flutter `CustomPaint`
import '../../database/app_database.dart' show InventoryPaint, databaseProvider;
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/pro/pro_gate.dart';
import '../../shared/widgets/hex_color_chip.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/gesture_hint_bar.dart';
import 'paint_equivalences.dart';
import 'paints_repository.dart';
import 'photo_color_picker_sheet.dart';

// ── Types ─────────────────────────────────────────────────────────────────────

enum _ViewMode { grid, list }
enum _SortMode { brand, quantity, addedAt }

class _CatalogEntry {
  final String brand;
  final String line;
  final String code;
  final String name;
  final String hex;
  const _CatalogEntry({
    required this.brand,
    required this.line,
    required this.code,
    required this.name,
    required this.hex,
  });
}

class ResolvedPaint {
  final InventoryPaint source;
  final String brand;
  final String code;
  final String name;
  final String hex;
  const ResolvedPaint({
    required this.source,
    required this.brand,
    required this.code,
    required this.name,
    required this.hex,
  });
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kFull  = Color(0xFF2F8F57);
const _kHalf  = Color(0xFFD99B3E);
const _kLow   = Color(0xFFC87A20);
const _kEmpty = Color(0xFF8F3030);

const _kBrands = [
  'tamiya', 'vallejo', 'citadel', 'gunze', 'humbrol', 'lifecolor',
];

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

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _quantityColor(String q) => switch (q) {
  'full'  => _kFull,
  'half'  => _kHalf,
  'low'   => _kLow,
  _       => _kEmpty,
};

int _quantityOrder(String q) => switch (q) {
  'full'  => 0,
  'half'  => 1,
  'low'   => 2,
  _       => 3,
};

String _quantityLabel(AppL10n l, String q) => switch (q) {
  'full'  => l.quantityFull,
  'half'  => l.quantityHalf,
  'low'   => l.quantityLow,
  _       => l.quantityEmpty,
};

String _brandLabel(String b) => switch (b) {
  'tamiya'    => 'Tamiya',
  'vallejo'   => 'Vallejo',
  'citadel'   => 'Citadel',
  'gunze'     => 'Gunze',
  'humbrol'   => 'Humbrol',
  'lifecolor' => 'LifeColor',
  _           => b,
};

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.grey;
  }
}

// ── Catalog loading ───────────────────────────────────────────────────────────

Future<Map<String, _CatalogEntry>> _loadCatalogIndex() async {
  final index = <String, _CatalogEntry>{};
  for (final asset in _kCatalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final line  = (data['line'] as String?) ?? '';
      for (final p in data['paints'] as List) {
        final code = p['code'] as String;
        index['$brand+$code'] = _CatalogEntry(
          brand: brand,
          line: line,
          code: code,
          name: p['name'] as String,
          hex: p['hex'] as String,
        );
      }
    } catch (_) {}
  }
  return index;
}

// ── Providers ─────────────────────────────────────────────────────────────────

// Non-autoDispose: il catalogo non cambia, teniamolo in memoria
final _catalogIndexProvider =
    FutureProvider<Map<String, _CatalogEntry>>((_) => _loadCatalogIndex());

final _rawInventoryProvider =
    StreamProvider.autoDispose<List<InventoryPaint>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchInventoryPaints();
});

final _customIndexProvider =
    StreamProvider.autoDispose<Map<String, CustomPaintRef>>((ref) {
  return ref.watch(paintsRepositoryProvider).watchCustomPaintIndex();
});

final _selectedBrandProvider = StateProvider.autoDispose<String?>((ref) => null);
final _selectedLineProvider  = StateProvider.autoDispose<String?>((ref) => null);
final _searchQueryProvider   = StateProvider.autoDispose<String>((ref) => '');
final _viewModeProvider      = StateProvider.autoDispose<_ViewMode>((ref) => _ViewMode.grid);
final _sortModeProvider      = StateProvider<_SortMode>((ref) => _SortMode.brand);

const int _kFreeInventoryLimit = 20;

// Linee disponibili per la marca selezionata, estratte dal catalogo
final _availableLinesProvider =
    Provider.autoDispose<AsyncValue<List<String>>>((ref) {
  final catAsync = ref.watch(_catalogIndexProvider);
  final brand    = ref.watch(_selectedBrandProvider);
  if (catAsync is! AsyncData || brand == null) {
    return const AsyncValue.data([]);
  }
  final lines = catAsync.value!.values
      .where((e) => e.brand == brand && e.line.isNotEmpty)
      .map((e) => e.line)
      .toSet()
      .toList()
    ..sort();
  return AsyncValue.data(lines);
});

final _resolvedInventoryProvider =
    Provider.autoDispose<AsyncValue<List<ResolvedPaint>>>((ref) {
  final catAsync = ref.watch(_catalogIndexProvider);
  final invAsync = ref.watch(_rawInventoryProvider);
  final cusAsync = ref.watch(_customIndexProvider);
  final brand    = ref.watch(_selectedBrandProvider);
  final query    = ref.watch(_searchQueryProvider).trim().toLowerCase();
  final sort     = ref.watch(_sortModeProvider);

  if (catAsync is AsyncLoading || invAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (catAsync is AsyncError) {
    return AsyncValue.error(catAsync.error!, catAsync.stackTrace!);
  }
  if (invAsync is AsyncError) {
    return AsyncValue.error(invAsync.error!, invAsync.stackTrace!);
  }

  final catalog   = catAsync.value!;
  final inventory = invAsync.value!;
  final custom    = cusAsync.value ?? {};

  final resolved = <ResolvedPaint>[];
  for (final ip in inventory) {
    String? b, c, n, h;
    if (ip.catalogBrand != null && ip.catalogCode != null) {
      final key   = '${ip.catalogBrand}+${ip.catalogCode}';
      final entry = catalog[key];
      b = ip.catalogBrand!;
      c = ip.catalogCode!;
      n = entry?.name ?? c;
      h = entry?.hex  ?? '#808080';
    } else if (ip.customBrand != null && ip.customCode != null) {
      final key   = '${ip.customBrand}+${ip.customCode}';
      final entry = custom[key];
      b = ip.customBrand!;
      c = ip.customCode!;
      n = entry?.name ?? c;
      h = entry?.hex  ?? '#808080';
    } else {
      continue;
    }
    resolved.add(ResolvedPaint(source: ip, brand: b, code: c, name: n, hex: h));
  }

  var out = resolved;
  if (brand != null) {
    if (brand == _kOtherBrandSentinel) {
      out = out.where((p) => !_kBrands.contains(p.brand)).toList();
    } else {
      out = out.where((p) => p.brand == brand).toList();
    }
  }
  if (query.isNotEmpty) {
    out = out
        .where((p) =>
            p.code.toLowerCase().contains(query) ||
            p.name.toLowerCase().contains(query) ||
            p.brand.toLowerCase().contains(query))
        .toList();
  }
  out = switch (sort) {
    _SortMode.brand    => out..sort((a, b) => '${a.brand}${a.code}'.compareTo('${b.brand}${b.code}')),
    _SortMode.quantity => out..sort((a, b) => _quantityOrder(a.source.quantity).compareTo(_quantityOrder(b.source.quantity))),
    _SortMode.addedAt  => out..sort((a, b) => b.source.id.compareTo(a.source.id)),
  };
  return AsyncValue.data(out);
});

const _kOtherBrandSentinel = '_altri';

// ── PaintsScreen ──────────────────────────────────────────────────────────────

class PaintsScreen extends ConsumerStatefulWidget {
  const PaintsScreen({super.key});

  @override
  ConsumerState<PaintsScreen> createState() => _PaintsScreenState();
}

class _PaintsScreenState extends ConsumerState<PaintsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToCatalog() {
    HapticFeedback.lightImpact();
    _tabController.animateTo(1);
  }

  void _showCustomPaintSheet({ResolvedPaint? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomPaintSheet(
        editing: editing,
        onSave: (brand, code, name, hex) async {
          final repo = ref.read(paintsRepositoryProvider);
          if (editing != null) {
            await repo.updateCustomPaint(
              oldBrand: editing.brand,
              oldCode: editing.code,
              brand: brand,
              code: code,
              name: name,
              hex: hex,
            );
          } else {
            await repo.addCustomPaint(
                brand: brand, code: code, name: name, hex: hex);
          }
        },
        onDelete: editing == null
            ? null
            : () => ref
                .read(paintsRepositoryProvider)
                .deleteCustomPaint(editing.brand, editing.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.paintsScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.colorize_outlined),
            tooltip: 'Rileva colore da foto',
            onPressed: () => PhotoColorPickerSheet.show(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: scheme.primary,
          indicatorWeight: 2,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          tabs: [Tab(text: l.paintsTabInventory), Tab(text: l.paintsTabCatalog)],
        ),
      ),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showCustomPaintSheet();
              },
              tooltip: l.customPaintAddTitle,
              child: const Icon(Icons.add),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              const _SearchBar(),
              const _BrandFilterChips(),
              GestureHintBar(
                hintKey: 'hint_inventory',
                message: AppL10n.of(context).hintInventoryLongPress,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [_InventoryTab(), _CatalogTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: l.paintSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    ref.read(_searchQueryProvider.notifier).state = '';
                    setState(() {});
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
        onChanged: (v) {
          ref.read(_searchQueryProvider.notifier).state = v;
          setState(() {});
        },
      ),
    );
  }
}

// ── Brand filter chips ────────────────────────────────────────────────────────

class _BrandFilterChips extends ConsumerWidget {
  const _BrandFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme   = Theme.of(context).colorScheme;
    final selected = ref.watch(_selectedBrandProvider);
    final allPaints = ref.watch(_resolvedInventoryProvider).value ?? [];

    // Conteggi per brand (ignora il filtro brand corrente per mostrare sempre i totali)
    final counts = <String, int>{};
    for (final p in allPaints) {
      final key = _kBrands.contains(p.brand) ? p.brand : _kOtherBrandSentinel;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // Ricalcola dai dati non filtrati (raw)
    final rawAll = ref.watch(_rawInventoryProvider).value ?? [];
    final rawCounts = <String, int>{};
    final catIndex = ref.watch(_catalogIndexProvider).value;
    final custIndex = ref.watch(_customIndexProvider).value ?? {};
    for (final ip in rawAll) {
      final brand = ip.catalogBrand ?? ip.customBrand;
      if (brand == null) continue;
      final key = _kBrands.contains(brand) ? brand : _kOtherBrandSentinel;
      rawCounts[key] = (rawCounts[key] ?? 0) + 1;
    }
    final hasOthers = rawCounts.containsKey(_kOtherBrandSentinel);

    String _chipLabel(String brand, String display) {
      final n = rawCounts[brand];
      return n != null && n > 0 ? '$display ($n)' : display;
    }

    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        scrollDirection: Axis.horizontal,
        children: [
          _BrandChip(
            label: _chipLabel('__all__', l.filterAllLines),
            active: selected == null,
            scheme: scheme,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(_selectedBrandProvider.notifier).state = null;
              ref.read(_selectedLineProvider.notifier).state  = null;
            },
          ),
          ..._kBrands.map((b) => _BrandChip(
                label: _chipLabel(b, _brandLabel(b)),
                active: selected == b,
                scheme: scheme,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(_selectedBrandProvider.notifier).state = b;
                  ref.read(_selectedLineProvider.notifier).state  = null;
                },
              )),
          if (hasOthers)
            _BrandChip(
              label: _chipLabel(_kOtherBrandSentinel, l.filterOtherBrands),
              active: selected == _kOtherBrandSentinel,
              scheme: scheme,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(_selectedBrandProvider.notifier).state =
                    _kOtherBrandSentinel;
                ref.read(_selectedLineProvider.notifier).state = null;
              },
            ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _BrandChip({
    required this.label,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withOpacity(0.18)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? scheme.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inventory tab ─────────────────────────────────────────────────────────────

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedAsync = ref.watch(_resolvedInventoryProvider);
    final viewMode      = ref.watch(_viewModeProvider);

    return Column(
      children: [
        resolvedAsync.when(
          loading: () => const SizedBox(height: 36),
          error: (_, __) => const SizedBox(height: 36),
          data: (paints) => _StatsRow(
            total: paints.length,
            emptyCount: paints
                .where((p) => p.source.quantity == 'empty')
                .length,
            viewMode: viewMode,
            onToggle: (mode) {
              HapticFeedback.lightImpact();
              ref.read(_viewModeProvider.notifier).state = mode;
            },
          ),
        ),
        Expanded(
          child: resolvedAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppL10n.of(context).errorGeneric(e.toString()))),
            data: (paints) {
              if (paints.isEmpty) return const _EmptyInventory();
              if (viewMode == _ViewMode.grid) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  child: _HoneycombGrid(paints: paints),
                );
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(0, 8, 0, 96),
                itemCount: paints.length,
                itemBuilder: (_, i) =>
                    _InventoryListTile(paint: paints[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  final int total;
  final int emptyCount;
  final _ViewMode viewMode;
  final void Function(_ViewMode) onToggle;
  const _StatsRow({
    required this.total,
    required this.emptyCount,
    required this.viewMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme  = Theme.of(context).colorScheme;
    final isFree  = !ProGate.watchProUser(ref);
    final ratio   = isFree ? (total / _kFreeInventoryLimit).clamp(0.0, 1.0) : 0.0;
    final nearLimit = isFree && total >= _kFreeInventoryLimit - 3;

    final barColor = ratio >= 1.0
        ? _kEmpty
        : ratio >= 0.75
            ? _kLow
            : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: scheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                          text: isFree
                              ? l.inventoryFreePaintsCount(total, _kFreeInventoryLimit)
                              : l.inventoryPaintsCount(total)),
                      if (emptyCount > 0) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: l.inventoryEmptyPaints(emptyCount),
                          style: const TextStyle(
                              color: _kEmpty,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _ViewBtn(
                icon: Icons.sort,
                active: ref.watch(_sortModeProvider) != _SortMode.brand,
                scheme: scheme,
                onTap: () => _showSortSheet(context, ref),
              ),
              _ViewBtn(
                icon: Icons.grid_view,
                active: viewMode == _ViewMode.grid,
                scheme: scheme,
                onTap: () => onToggle(_ViewMode.grid),
              ),
              _ViewBtn(
                icon: Icons.list,
                active: viewMode == _ViewMode.list,
                scheme: scheme,
                onTap: () => onToggle(_ViewMode.list),
              ),
            ],
          ),
        ),
        if (isFree) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          if (nearLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                total >= _kFreeInventoryLimit
                    ? l.inventoryLimitReached
                    : l.inventoryFreeNearLimit(_kFreeInventoryLimit - total),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: barColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ViewBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _ViewBtn(
      {required this.icon,
      required this.active,
      required this.scheme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 20,
            color:
                active ? scheme.primary : scheme.onSurfaceVariant),
      ),
    );
  }
}

// ── Honeycomb grid ────────────────────────────────────────────────────────────

class _HoneycombGrid extends ConsumerWidget {
  final List<ResolvedPaint> paints;
  const _HoneycombGrid({required this.paints});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const kCols = 4;
    return LayoutBuilder(builder: (context, constraints) {
      final cellW  = constraints.maxWidth / kCols;
      final hexW   = cellW * 0.84;
      final hexH   = hexW * 0.866; // sqrt(3)/2 per flat-top
      final vGap   = hexH * 0.12;
      final offset = hexH * 0.5;

      final columns = List.generate(kCols, (_) => <ResolvedPaint>[]);
      for (var i = 0; i < paints.length; i++) {
        columns[i % kCols].add(paints[i]);
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(kCols, (col) {
          return SizedBox(
            width: cellW,
            child: Column(
              children: [
                if (col.isOdd) SizedBox(height: offset),
                ...columns[col].map((p) => Padding(
                      padding: EdgeInsets.only(bottom: vGap),
                      child: _HexCell(paint: p, size: hexW),
                    )),
              ],
            ),
          );
        }),
      );
    });
  }
}

class _HexCell extends ConsumerWidget {
  final ResolvedPaint paint;
  final double size;
  const _HexCell({required this.paint, required this.size});

  Future<void> _quickQuantity(BuildContext context, WidgetRef ref, Offset pos) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        pos & const Size(4, 4),
        Offset.zero & overlay.size,
      ),
      items: ['full', 'half', 'low', 'empty'].map((q) {
        final color = _quantityColor(q);
        return PopupMenuItem<String>(
          value: q,
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(_quantityLabel(AppL10n.of(context), q),
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        );
      }).toList(),
    );
    if (result != null && result != paint.source.quantity) {
      HapticFeedback.lightImpact();
      await ref.read(paintsRepositoryProvider).updatePaintQuantity(paint.source.id, result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPaintDetail(context, ref, paint);
      },
      onLongPressStart: (d) {
        HapticFeedback.mediumImpact();
        _quickQuantity(context, ref, d.globalPosition);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              HexColorChip(color: _hexColor(paint.hex), size: size),
              Positioned(
                bottom: size * 0.08,
                right: size * 0.04,
                child: _QuantityDot(quantity: paint.source.quantity),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            paint.code,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: scheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          Text(
            paint.name,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 8,
              color: scheme.onSurfaceVariant.withOpacity(0.65),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Quantity widgets ──────────────────────────────────────────────────────────

class _QuantityDot extends StatelessWidget {
  final String quantity;
  const _QuantityDot({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _quantityColor(quantity),
        shape: BoxShape.circle,
        border: Border.all(
            color: Theme.of(context).colorScheme.surface, width: 1.5),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  final String quantity;
  const _QuantityPill({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final color = _quantityColor(quantity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _quantityLabel(l, quantity),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Inventory list tile ───────────────────────────────────────────────────────

class _InventoryListTile extends ConsumerWidget {
  final ResolvedPaint paint;
  const _InventoryListTile({required this.paint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey(paint.source.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        ref
            .read(paintsRepositoryProvider)
            .deleteInventoryPaint(paint.source.id);
      },
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showPaintDetail(context, ref, paint);
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              HexColorChip(color: _hexColor(paint.hex), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_brandLabel(paint.brand)}  ${paint.code}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (paint.source.customBrand != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: scheme.primary.withOpacity(0.4)),
                            ),
                            child: Text(
                              'C',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      paint.name,
                      style: tt.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _QuantityPill(quantity: paint.source.quantity),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sort sheet ────────────────────────────────────────────────────────────────

void _showSortSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (_) => _SortSheet(
      current: ref.read(_sortModeProvider),
      onSelect: (mode) {
        HapticFeedback.lightImpact();
        ref.read(_sortModeProvider.notifier).state = mode;
      },
    ),
  );
}

class _SortSheet extends StatelessWidget {
  final _SortMode current;
  final void Function(_SortMode) onSelect;
  const _SortSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget tile(_SortMode mode, IconData icon, String label) {
      final active = current == mode;
      return ListTile(
        leading: Icon(icon, color: active ? scheme.primary : scheme.onSurfaceVariant),
        title: Text(label, style: tt.bodyMedium?.copyWith(color: active ? scheme.primary : null)),
        trailing: active ? Icon(Icons.check, color: scheme.primary, size: 20) : null,
        onTap: () {
          onSelect(mode);
          Navigator.pop(context);
        },
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.inventorySortTitle,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, letterSpacing: 1.2, color: scheme.primary)),
          ),
          tile(_SortMode.brand,    Icons.sort_by_alpha,    l.inventorySortBrand),
          tile(_SortMode.quantity, Icons.water_drop_outlined, l.inventorySortQuantity),
          tile(_SortMode.addedAt,  Icons.access_time,      l.inventorySortDate),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _DashedHexPainter(color: scheme.outline),
            ),
          ),
          const SizedBox(height: 20),
          Text(l.inventoryEmptyTitle, style: tt.titleMedium),
          const SizedBox(height: 8),
          Text(
            l.inventoryEmptyBody,
            style:
                tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DashedHexPainter extends CustomPainter {
  final Color color;
  const _DashedHexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pts = [
      Offset(w * 0.25, 0),
      Offset(w * 0.75, 0),
      Offset(w, h * 0.5),
      Offset(w * 0.75, h),
      Offset(w * 0.25, h),
      Offset(0, h * 0.5),
    ];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < pts.length; i++) {
      _dashed(canvas, pts[i], pts[(i + 1) % pts.length], paint);
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 5.0;
    const gap  = 4.0;
    final dx   = b.dx - a.dx;
    final dy   = b.dy - a.dy;
    final len  = math.sqrt(dx * dx + dy * dy);
    var drawn  = 0.0;
    var draw   = true;
    while (drawn < len) {
      final seg = draw ? dash : gap;
      final t0  = drawn / len;
      final t1  = (drawn + seg).clamp(0, len) / len;
      if (draw) {
        c.drawLine(
          Offset(a.dx + dx * t0, a.dy + dy * t0),
          Offset(a.dx + dx * t1, a.dy + dy * t1),
          p,
        );
      }
      drawn += seg;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(_DashedHexPainter old) => old.color != color;
}

// ── Paint detail sheet ────────────────────────────────────────────────────────

void _showCustomPaintSheetFor(
    BuildContext context, WidgetRef ref, ResolvedPaint paint) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CustomPaintSheet(
      editing: paint,
      onSave: (brand, code, name, hex) => ref
          .read(paintsRepositoryProvider)
          .updateCustomPaint(
            oldBrand: paint.brand,
            oldCode: paint.code,
            brand: brand,
            code: code,
            name: name,
            hex: hex,
          ),
      onDelete: () => ref
          .read(paintsRepositoryProvider)
          .deleteCustomPaint(paint.brand, paint.code),
    ),
  );
}

void _showPaintDetail(BuildContext context, WidgetRef ref, ResolvedPaint paint) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaintDetailSheet(
      paint: paint,
      onEdit: paint.source.customBrand != null
          ? () => _showCustomPaintSheetFor(context, ref, paint)
          : null,
    ),
  );
}

class _PaintDetailSheet extends ConsumerStatefulWidget {
  final ResolvedPaint paint;
  final VoidCallback? onEdit;
  const _PaintDetailSheet({required this.paint, this.onEdit});

  @override
  ConsumerState<_PaintDetailSheet> createState() => _PaintDetailSheetState();
}

class _PaintDetailSheetState extends ConsumerState<_PaintDetailSheet> {
  late String _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.paint.source.quantity;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final repo   = ref.read(paintsRepositoryProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  HexColorChip(
                      color: _hexColor(widget.paint.hex), size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.paint.code,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(widget.paint.name, style: tt.bodyMedium),
                        Text(
                          '${_brandLabel(widget.paint.brand)} · ${widget.paint.hex.toUpperCase()}',
                          style: tt.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onEdit != null)
                    Tooltip(
                      message: AppL10n.of(context).actionEdit,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onEdit!();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.edit_outlined,
                              color: scheme.primary, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUANTITÀ',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _quantity,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ['full', 'half', 'low', 'empty'].map((q) {
                      final color = _quantityColor(q);
                      return DropdownMenuItem<String>(
                        value: q,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _quantityLabel(l, q),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (q) async {
                      if (q == null || q == _quantity) return;
                      HapticFeedback.lightImpact();
                      setState(() => _quantity = q);
                      await repo.updatePaintQuantity(
                          widget.paint.source.id, q);
                    },
                  ),
                ],
              ),
            ),
            // 1B.14 — shopping link when paint is running low
            if (_quantity == 'low' || _quantity == 'empty')
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(l.paintGoToShoppingList),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/shopping');
                    },
                  ),
                ),
              ),
            // 1B.15 — cross-brand equivalences
            _EquivalencesSection(paint: widget.paint),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: Icon(Icons.delete_outline,
                      color: scheme.error, size: 18),
                  label: Text(
                    l.paintRemoveFromInventory,
                    style: TextStyle(color: scheme.error),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    repo.deleteInventoryPaint(widget.paint.source.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Equivalences section (1B.15) ─────────────────────────────────────────────

class _EquivalencesSection extends ConsumerWidget {
  final ResolvedPaint paint;
  const _EquivalencesSection({required this.paint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Build the lookup key from brand+code
    final key = '${paint.brand}:${paint.code}';
    final equivalences = kPaintEquivalences[key];
    if (equivalences == null || equivalences.isEmpty) return const SizedBox.shrink();

    final rawInv = ref.watch(_rawInventoryProvider).value ?? [];
    final ownedKeys = <String>{
      for (final ip in rawInv)
        if (ip.catalogBrand != null && ip.catalogCode != null)
          '${ip.catalogBrand}:${ip.catalogCode}',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 6),
          Text(
            l.paintEquivalentsSection,
            style: tt.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: equivalences.map((eq) {
              final eqKey = '${eq.$1}:${eq.$2}';
              final owned = ownedKeys.contains(eqKey);
              return Chip(
                avatar: owned
                    ? Icon(Icons.check_circle_outline,
                        size: 14, color: scheme.primary)
                    : null,
                label: Text(
                  '${eq.$1.toUpperCase()} ${eq.$2}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11),
                ),
                backgroundColor: owned
                    ? scheme.primaryContainer.withOpacity(0.4)
                    : scheme.surfaceContainerHighest,
                side: BorderSide(
                  color: owned ? scheme.primary : scheme.outlineVariant,
                  width: 0.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


// ── Catalog tab ───────────────────────────────────────────────────────────────

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme       = Theme.of(context).colorScheme;
    final tt           = Theme.of(context).textTheme;
    final catalogAsync = ref.watch(_catalogIndexProvider);
    final invAsync     = ref.watch(_rawInventoryProvider);
    final brand        = ref.watch(_selectedBrandProvider);
    final selectedLine = ref.watch(_selectedLineProvider);
    final query        = ref.watch(_searchQueryProvider).trim().toLowerCase();
    final linesAsync   = ref.watch(_availableLinesProvider);

    if (brand == null && query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                size: 48,
                color: scheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              l.catalogEmptyPrompt,
              style: tt.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final lines = linesAsync.value ?? [];

    return Column(
      children: [
        // Sottofiltro per linea — visibile solo se la marca è selezionata e ha più linee
        if (brand != null && lines.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              scrollDirection: Axis.horizontal,
              children: [
                _BrandChip(
                  label: l.filterAllLines,
                  active: selectedLine == null,
                  scheme: scheme,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(_selectedLineProvider.notifier).state = null;
                  },
                ),
                ...lines.map((line) => _BrandChip(
                      label: l.paintLineLabel(line),
                      active: selectedLine == line,
                      scheme: scheme,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(_selectedLineProvider.notifier).state = line;
                      },
                    )),
              ],
            ),
          ),
        Expanded(
          child: catalogAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.errorGeneric(e.toString()))),
            data: (catalog) {
              final inventoryKeys = invAsync.value
                      ?.where((ip) =>
                          ip.catalogBrand != null &&
                          ip.catalogCode != null)
                      .map((ip) =>
                          '${ip.catalogBrand}+${ip.catalogCode}')
                      .toSet() ??
                  {};

              var entries = catalog.values.toList();
              if (brand != null) {
                entries = entries.where((e) => e.brand == brand).toList();
                if (selectedLine != null) {
                  entries = entries.where((e) => e.line == selectedLine).toList();
                }
                entries.sort((a, b) => a.code.compareTo(b.code));
              }
              if (query.isNotEmpty) {
                entries = entries
                    .where((e) =>
                        e.code.toLowerCase().contains(query) ||
                        e.name.toLowerCase().contains(query) ||
                        e.brand.toLowerCase().contains(query))
                    .take(80)
                    .toList();
              }

              if (entries.isEmpty) {
                return Center(
                    child: Text(l.searchNoResults, style: tt.bodySmall));
              }

              // Flatten with group headers (per brand, poi per linea se multi-brand)
              final groups = <String, List<_CatalogEntry>>{};
              for (final e in entries) {
                final key = brand != null ? e.line : e.brand;
                groups.putIfAbsent(key, () => []).add(e);
              }
              final flat = <Object>[];
              for (final g in groups.keys) {
                flat.add(g);
                flat.addAll(groups[g]!);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: flat.length,
                itemBuilder: (_, i) {
                  final item = flat[i];
                  if (item is String) {
                    final label = brand != null
                        ? l.paintLineLabel(item).toUpperCase()
                        : _brandLabel(item).toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    );
                  }
                  final entry       = item as _CatalogEntry;
                  final key         = '${entry.brand}+${entry.code}';
                  final inInventory = inventoryKeys.contains(key);
                  return ListTile(
                    leading: HexColorChip(
                        color: _hexColor(entry.hex), size: 32),
                    title: Text(
                      '${entry.code}  ${entry.name}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      brand == null
                          ? _brandLabel(entry.brand)
                          : l.paintLineLabel(entry.line),
                      style: tt.bodySmall,
                    ),
                    trailing: inInventory
                        ? const Icon(Icons.check_circle,
                            color: _kFull, size: 22)
                        : IconButton(
                            icon: Icon(Icons.add, color: scheme.primary),
                            tooltip: l.paintAddToInventoryTooltip,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(paintsRepositoryProvider)
                                  .addInventoryPaint(
                                    brand: entry.brand,
                                    code: entry.code,
                                  );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(l.paintAddedToInventory(entry.code)),
                              ));
                            },
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Custom paint sheet ────────────────────────────────────────────────────────

class _CustomPaintSheet extends StatefulWidget {
  final ResolvedPaint? editing;
  final Future<void> Function(String brand, String code, String name, String hex)
      onSave;
  final VoidCallback? onDelete;

  const _CustomPaintSheet({
    required this.onSave,
    this.editing,
    this.onDelete,
  });

  @override
  State<_CustomPaintSheet> createState() => _CustomPaintSheetState();
}

class _CustomPaintSheetState extends State<_CustomPaintSheet> {
  late final TextEditingController _brandCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hexCtrl;
  bool _saving = false;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _brandCtrl = TextEditingController(text: e?.brand ?? '');
    _codeCtrl  = TextEditingController(text: e?.code  ?? '');
    _nameCtrl  = TextEditingController(text: e?.name  ?? '');
    _hexCtrl   = TextEditingController(
        text: e != null ? e.hex.toUpperCase() : '#');
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Color? get _previewColor {
    try {
      final h = _hexCtrl.text.trim();
      return Color(int.parse(h.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  bool get _hexValid {
    final h = _hexCtrl.text.trim();
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(h);
  }

  bool get _canSave =>
      !_saving &&
      _brandCtrl.text.trim().isNotEmpty &&
      _codeCtrl.text.trim().isNotEmpty &&
      _nameCtrl.text.trim().isNotEmpty &&
      _hexValid;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await widget.onSave(
      _brandCtrl.text.trim().toLowerCase(),
      _codeCtrl.text.trim(),
      _nameCtrl.text.trim(),
      _hexCtrl.text.trim().toUpperCase(),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.customPaintDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.actionDelete,
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.onDelete!();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l      = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isEdit = widget.editing != null;
    final preview = _previewColor;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title + delete
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit
                        ? l.customPaintEditTitle
                        : l.customPaintAddTitle,
                    style: tt.titleMedium,
                  ),
                ),
                if (isEdit && widget.onDelete != null)
                  Tooltip(
                    message: l.actionDelete,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _confirmDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.delete_outline,
                            color: scheme.error, size: 22),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Brand chips predefiniti
            Text(
              l.customPaintBrandLabel.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _kBrands
                  .map((b) => _BrandChip(
                        label: _brandLabel(b),
                        active: _brandCtrl.text.trim().toLowerCase() == b,
                        scheme: scheme,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _brandCtrl.text = b);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brandCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l.customPaintBrandHint,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Code
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.customPaintCodeLabel,
                hintText: l.customPaintCodeHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Name
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.customPaintNameLabel,
                hintText: l.customPaintNameHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Hex + preview + picker buttons
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l.customPaintHexLabel,
                      hintText: '#D99B3E',
                      errorText: _hexCtrl.text.length > 1 && !_hexValid
                          ? l.customPaintHexInvalid
                          : null,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && !v.startsWith('#')) {
                        _hexCtrl.text = '#$v';
                        _hexCtrl.selection = TextSelection.collapsed(
                            offset: _hexCtrl.text.length);
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  child: preview != null
                      ? HexColorChip(color: preview, size: 48)
                      : Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scheme.outline),
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                // Color wheel
                Tooltip(
                  message: l.colorPickerWheel,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final picked = await showModalBottomSheet<Color>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _ColorWheelSheet(
                          initial: preview ?? Colors.grey,
                        ),
                      );
                      if (picked != null && mounted) {
                        final hex =
                            '#${picked.red.toRadixString(16).padLeft(2, '0')}${picked.green.toRadixString(16).padLeft(2, '0')}${picked.blue.toRadixString(16).padLeft(2, '0')}'
                                .toUpperCase();
                        setState(() => _hexCtrl.text = hex);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.palette_outlined,
                          color: scheme.primary, size: 22),
                    ),
                  ),
                ),
                // Photo picker
                Tooltip(
                  message: l.colorPickerPhoto,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final picked = await showModalBottomSheet<Color>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _PhotoColorPicker(),
                      );
                      if (picked != null && mounted) {
                        final hex =
                            '#${picked.red.toRadixString(16).padLeft(2, '0')}${picked.green.toRadixString(16).padLeft(2, '0')}${picked.blue.toRadixString(16).padLeft(2, '0')}'
                                .toUpperCase();
                        setState(() => _hexCtrl.text = hex);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.colorize,
                          color: scheme.onSurfaceVariant, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? l.actionSaveChanges : l.actionAdd),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color wheel sheet ─────────────────────────────────────────────────────────

class _ColorWheelSheet extends StatefulWidget {
  final Color initial;
  const _ColorWheelSheet({required this.initial});

  @override
  State<_ColorWheelSheet> createState() => _ColorWheelSheetState();
}

class _ColorWheelSheetState extends State<_ColorWheelSheet> {
  late double _hue;
  late double _sat;
  late double _val;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  Color get _color => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  String get _hex =>
      '#${_color.red.toRadixString(16).padLeft(2, '0')}${_color.green.toRadixString(16).padLeft(2, '0')}${_color.blue.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: scheme.outline, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Preview chip + hex
          Row(
            children: [
              HexColorChip(color: _color, size: 48),
              const SizedBox(width: 16),
              Text(
                _hex,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // SV square (saturation × value)
          SizedBox(
            height: 180,
            child: _SvSquare(
              hue: _hue,
              sat: _sat,
              val: _val,
              onChanged: (s, v) => setState(() {
                _sat = s;
                _val = v;
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Hue slider
          _GradientSlider(
            value: _hue / 360.0,
            gradient: const LinearGradient(colors: [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ]),
            onChanged: (v) => setState(() => _hue = v * 360.0),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, _color),
            child: Text(l.colorPickerConfirm),
          ),
        ],
      ),
    );
  }
}

class _SvSquare extends StatelessWidget {
  final double hue, sat, val;
  final void Function(double sat, double val) onChanged;
  const _SvSquare(
      {required this.hue,
      required this.sat,
      required this.val,
      required this.onChanged});

  void _update(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onPanStart: (d) => _update(d.localPosition, size),
        onPanUpdate: (d) => _update(d.localPosition, size),
        onTapDown: (d) => _update(d.localPosition, size),
        child: CustomPaint(
          size: size,
          painter: _SvPainter(hue: hue, sat: sat, val: val),
        ),
      );
    });
  }
}

class _SvPainter extends CustomPainter {
  final double hue, sat, val;
  const _SvPainter({required this.hue, required this.sat, required this.val});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Saturation gradient (white → hue color)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white,
          HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
        ]).createShader(rect),
    );
    // Value gradient (transparent → black)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    // Selector circle
    final cx = sat * size.width;
    final cy = (1.0 - val) * size.height;
    final selColor = HSVColor.fromAHSV(1, hue, sat, val).toColor();
    final isLight = selColor.computeLuminance() > 0.5;
    canvas.drawCircle(
      Offset(cx, cy),
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      8,
      Paint()
        ..color = isLight ? Colors.black26 : Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SvPainter old) =>
      old.hue != hue || old.sat != sat || old.val != val;
}

class _GradientSlider extends StatelessWidget {
  final double value;
  final LinearGradient gradient;
  final ValueChanged<double> onChanged;
  const _GradientSlider(
      {required this.value,
      required this.gradient,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        onPanUpdate: (d) =>
            onChanged((d.localPosition.dx / w).clamp(0.0, 1.0)),
        onTapDown: (d) =>
            onChanged((d.localPosition.dx / w).clamp(0.0, 1.0)),
        child: CustomPaint(
          size: Size(w, 28),
          painter: _GradientSliderPainter(value: value, gradient: gradient),
        ),
      );
    });
  }
}

class _GradientSliderPainter extends CustomPainter {
  final double value;
  final LinearGradient gradient;
  const _GradientSliderPainter(
      {required this.value, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, (size.height - 14) / 2, size.width, 14);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

    canvas.drawRRect(rRect, Paint()..shader = gradient.createShader(rect));

    final cx = value * size.width;
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      11,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      9,
      Paint()
        ..color = HSVColor.fromAHSV(1, value * 360, 1, 1).toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      11,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GradientSliderPainter old) =>
      old.value != value;
}

// ── Photo color picker sheet ──────────────────────────────────────────────────

class _PhotoColorPicker extends StatefulWidget {
  const _PhotoColorPicker();

  @override
  State<_PhotoColorPicker> createState() => _PhotoColorPickerState();
}

class _PhotoColorPickerState extends State<_PhotoColorPicker> {
  String? _imagePath;
  ui.Image? _uiImage;
  Offset _crosshair = Offset.zero; // in image pixels
  Color _sampled = Colors.grey;

  Future<void> _pick(ImageSource source) async {
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await File(file.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    if (!mounted) return;
    setState(() {
      _imagePath = file.path;
      _uiImage = img;
      _crosshair =
          Offset(img.width / 2.0, img.height / 2.0);
    });
    await _sampleAt(_crosshair);
  }

  Future<void> _sampleAt(Offset imgCoord) async {
    final img = _uiImage;
    if (img == null) return;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || !mounted) return;
    final x = imgCoord.dx.round().clamp(0, img.width - 1);
    final y = imgCoord.dy.round().clamp(0, img.height - 1);
    final off = (y * img.width + x) * 4;
    setState(() {
      _sampled = Color.fromARGB(
        255,
        data.getUint8(off),
        data.getUint8(off + 1),
        data.getUint8(off + 2),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: scheme.outline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            if (_imagePath == null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PickBtn(
                    icon: Icons.camera_alt_outlined,
                    label: AppL10n.of(context).photoSourceCamera,
                    onTap: () => _pick(ImageSource.camera),
                  ),
                  _PickBtn(
                    icon: Icons.photo_library_outlined,
                    label: AppL10n.of(context).photoSourceGallery,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Image with draggable crosshair
              LayoutBuilder(builder: (ctx, constraints) {
                final img = _uiImage!;
                final maxH = 280.0;
                final maxW = constraints.maxWidth;
                final scaleX = maxW / img.width;
                final scaleY = maxH / img.height;
                final scale = math.min(scaleX, scaleY);
                final dispW = img.width * scale;
                final dispH = img.height * scale;
                final offX = (maxW - dispW) / 2;

                // crosshair in screen coords
                final scrX = _crosshair.dx * scale + offX;
                final scrY = _crosshair.dy * scale;

                return GestureDetector(
                  onPanUpdate: (d) {
                    final imgX =
                        ((d.localPosition.dx - offX) / scale)
                            .clamp(0.0, img.width.toDouble() - 1);
                    final imgY = (d.localPosition.dy / scale)
                        .clamp(0.0, img.height.toDouble() - 1);
                    setState(() =>
                        _crosshair = Offset(imgX, imgY));
                    _sampleAt(_crosshair);
                  },
                  onTapDown: (d) {
                    final imgX =
                        ((d.localPosition.dx - offX) / scale)
                            .clamp(0.0, img.width.toDouble() - 1);
                    final imgY = (d.localPosition.dy / scale)
                        .clamp(0.0, img.height.toDouble() - 1);
                    setState(() =>
                        _crosshair = Offset(imgX, imgY));
                    _sampleAt(_crosshair);
                  },
                  child: SizedBox(
                    width: maxW,
                    height: dispH,
                    child: Stack(
                      children: [
                        Positioned(
                          left: offX,
                          top: 0,
                          child: Image.file(
                            File(_imagePath!),
                            width: dispW,
                            height: dispH,
                            fit: BoxFit.fill,
                          ),
                        ),
                        // Crosshair ring
                        Positioned(
                          left: scrX - 18,
                          top: scrY - 18,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _sampled,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black45, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              // Preview + confirm
              Row(
                children: [
                  HexColorChip(color: _sampled, size: 40),
                  const SizedBox(width: 12),
                  Text(
                    '#${_sampled.red.toRadixString(16).padLeft(2, '0')}${_sampled.green.toRadixString(16).padLeft(2, '0')}${_sampled.blue.toRadixString(16).padLeft(2, '0')}'
                        .toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _sampled),
                    child: Text(l.colorPickerConfirm),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: scheme.primary),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: scheme.onSurface, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
