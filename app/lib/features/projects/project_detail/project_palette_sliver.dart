import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scan_instructions_sheet.dart';
import '../../../database/app_database.dart';
import '../project_repository.dart';

// ── Catalog search ────────────────────────────────────────────────────────────

class _CatalogPaint {
  final String brand;
  final String code;
  final String name;
  final String hex;
  _CatalogPaint(
      {required this.brand,
      required this.code,
      required this.name,
      required this.hex});

}

const _catalogAssets = [
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

Future<List<_CatalogPaint>> _loadAllCatalogs() async {
  final result = <_CatalogPaint>[];
  for (final asset in _catalogAssets) {
    try {
      final raw = await rootBundle.loadString(asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = data['brand'] as String;
      final paints = data['paints'] as List<dynamic>;
      for (final p in paints) {
        result.add(_CatalogPaint(
          brand: brand,
          code: p['code'] as String,
          name: p['name'] as String,
          hex: p['hex'] as String,
        ));
      }
    } catch (_) {}
  }
  return result;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _catalogProvider = FutureProvider<List<_CatalogPaint>>((ref) async {
  return _loadAllCatalogs();
});

final _projectPaintsProvider =
    StreamProvider.autoDispose.family<List<ProjectPaint>, int>((ref, id) {
  return ref.watch(projectRepositoryProvider).watchProjectPaints(id);
});

// ── Main widget ───────────────────────────────────────────────────────────────

class ProjectPaletteSliver extends ConsumerWidget {
  final int projectId;
  const ProjectPaletteSliver({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paintsAsync = ref.watch(_projectPaintsProvider(projectId));
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
              child: Row(
                children: [
                  Text(
                    'COLORI DEL KIT',
                    style: tt.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _HeaderIconButton(
                    icon: Icons.shopping_cart_outlined,
                    tooltip: 'Lista della spesa',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/shopping');
                    },
                    color: scheme.primary,
                  ),
                  _HeaderIconButton(
                    icon: Icons.camera_alt_outlined,
                    tooltip: 'Scansiona istruzioni',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _scan(context, ref);
                    },
                    color: scheme.primary,
                  ),
                  _HeaderIconButton(
                    icon: Icons.add,
                    tooltip: 'Aggiungi vernice',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAddSheet(context, ref);
                    },
                    color: scheme.primary,
                  ),
                ],
              ),
            ),

            paintsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (paints) {
                if (paints.isEmpty) {
                  return _EmptyPalette(
                    onScan: () => _scan(context, ref),
                    onManual: () => _showAddSheet(context, ref),
                    scheme: scheme,
                    tt: tt,
                  );
                }
                return Column(
                  children: paints
                      .map((p) => _PaletteRow(
                            paint: p,
                            projectId: projectId,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(projectRepositoryProvider);
    await showScanSheet(
      context,
      onComplete: (results) async {
        for (final r in results) {
          await repo.addProjectPaint(
            projectId: projectId,
            brand: r.brand,
            code: r.code,
            name: r.name,
            hex: r.hex,
          );
        }
        if (context.mounted && results.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${results.length} vernic${results.length == 1 ? 'e aggiunta' : 'i aggiunte'} alla palette.',
              ),
            ),
          );
        }
      },
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddPaintSheet(projectId: projectId),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

// ── Empty palette state ───────────────────────────────────────────────────────

class _EmptyPalette extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;
  final ColorScheme scheme;
  final TextTheme tt;
  const _EmptyPalette(
      {required this.onScan,
      required this.onManual,
      required this.scheme,
      required this.tt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Auto-load tile (supported brands)
        GestureDetector(
          onTap: onScan,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: scheme.primary.withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.camera_alt_outlined,
                    color: scheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caricamento automatico',
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Fotografia il foglio istruzioni\n'
                        '${supportedBrands.join(' · ')}',
                        style: tt.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
        // Manual add tile
        GestureDetector(
          onTap: onManual,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: scheme.onSurfaceVariant, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cerca nel catalogo',
                    style: tt.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single palette row ────────────────────────────────────────────────────────

class _PaletteRow extends ConsumerWidget {
  final ProjectPaint paint;
  final int projectId;
  const _PaletteRow({required this.paint, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final repo = ref.read(projectRepositoryProvider);

    return FutureBuilder<bool>(
      future: repo.isPaintInInventory(paint.brand, paint.code),
      builder: (context, snap) {
        final inStock = snap.data ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hexColor(paint.hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: scheme.outline.withOpacity(0.4), width: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paint.code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        letterSpacing: 0.3,
                      ),
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
              _StockBadge(inStock: inStock, scheme: scheme),
            ],
          ),
        );
      },
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ── Stock badge ───────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final bool inStock;
  final ColorScheme scheme;
  const _StockBadge({required this.inStock, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: inStock
            ? const Color(0xFF2F8F57).withOpacity(0.15)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: inStock
              ? const Color(0xFF2F8F57).withOpacity(0.5)
              : scheme.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check : Icons.shopping_bag_outlined,
            size: 11,
            color: inStock ? const Color(0xFF2F8F57) : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            inStock ? 'In magazzino' : 'Da acquistare',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: inStock
                  ? const Color(0xFF2F8F57)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add paint bottom sheet ────────────────────────────────────────────────────
// Se initialResults è valorizzato, la sheet mostra quei risultati direttamente
// (modalità post-scansione). L'utente può comunque cercare altro nel catalogo.

class _AddPaintSheet extends ConsumerStatefulWidget {
  final int projectId;
  const _AddPaintSheet({required this.projectId});

  @override
  ConsumerState<_AddPaintSheet> createState() => _AddPaintSheetState();
}

class _AddPaintSheetState extends ConsumerState<_AddPaintSheet> {
  final _controller = TextEditingController();
  List<_CatalogPaint> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query, List<_CatalogPaint> all) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = all
          .where((p) =>
              p.code.toLowerCase().contains(q) ||
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q))
          .take(40)
          .toList();
    });
  }

  Future<void> _add(_CatalogPaint p) async {
    await ref.read(projectRepositoryProvider).addProjectPaint(
          projectId: widget.projectId,
          brand: p.brand,
          code: p.code,
          name: p.name,
          hex: p.hex,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catalogAsync = ref.watch(_catalogProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Aggiungi vernice', style: tt.titleMedium),
          ),
          const SizedBox(height: 12),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: catalogAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (all) => TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cerca per codice, nome o marca…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _search('', all);
                          },
                        )
                      : null,
                ),
                onChanged: (q) => _search(q, all),
              ),
            ),
          ),
          // Results
          Expanded(
            child: catalogAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Errore caricamento catalogo')),
              data: (_) {
                if (_results.isEmpty && _controller.text.isEmpty) {
                  return Center(
                    child: Text('Cerca per trovare una vernice',
                        style: tt.bodySmall),
                  );
                }
                if (_results.isEmpty) {
                  return Center(
                    child: Text('Nessun risultato', style: tt.bodySmall),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hexColor(p.hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: scheme.outline.withOpacity(0.4)),
                        ),
                      ),
                      title: Text(
                        '${p.code}  ${p.name}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(p.brand, style: tt.bodySmall),
                      trailing: IconButton(
                        icon: Icon(Icons.add, color: scheme.primary),
                        onPressed: () => _add(p),
                      ),
                      onTap: () => _add(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
