import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../projects/project_repository.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/hex_color_chip.dart';

final _shoppingListProvider = StreamProvider<List<ShoppingEntry>>((ref) {
  return ref.watch(projectRepositoryProvider).watchShoppingList();
});

final _shoppingItemsProvider = StreamProvider<List<ShoppingItem>>((ref) {
  return ref.watch(projectRepositoryProvider).watchShoppingItems();
});

// Stato in-memory per le vernici automatiche spuntate (brand+code)
final _checkedPaintsProvider = StateProvider<Set<String>>((ref) => {});

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final paintsAsync = ref.watch(_shoppingListProvider);
    final itemsAsync = ref.watch(_shoppingItemsProvider);
    final checkedPaints = ref.watch(_checkedPaintsProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shoppingScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l.shoppingShareTooltip,
            onPressed: () => _shareList(
              context: context,
              paints: paintsAsync.value ?? [],
              items: itemsAsync.value ?? [],
              checkedPaints: checkedPaints,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Sezione vernici mancanti ──────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: l.shoppingPaintsSection,
              scheme: scheme,
              tt: tt,
            ),
          ),
          paintsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.errorGeneric(e.toString())),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.check_circle_outline,
                    iconColor: const Color(0xFF2F8F57),
                    label: l.shoppingPaintsEmpty,
                    tt: tt,
                  ),
                );
              }
              final sorted = [
                ...entries.where((e) => !checkedPaints.contains('${e.brand}+${e.code}')),
                ...entries.where((e) => checkedPaints.contains('${e.brand}+${e.code}')),
              ];
              final grouped = <String, List<ShoppingEntry>>{};
              for (final e in sorted) {
                grouped.putIfAbsent(e.projectName, () => []).add(e);
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final flat = _flattenGroups(grouped);
                    final item = flat[index];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          item.toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 1.0,
                          ),
                        ),
                      );
                    }
                    final e = item as ShoppingEntry;
                    final key = '${e.brand}+${e.code}';
                    final checked = checkedPaints.contains(key);
                    return _PaintRow(
                      entry: e,
                      scheme: scheme,
                      tt: tt,
                      checked: checked,
                      onToggle: (v) {
                        ref.read(_checkedPaintsProvider.notifier).update((s) {
                          final next = Set<String>.from(s);
                          if (v) next.add(key); else next.remove(key);
                          return next;
                        });
                      },
                    );
                  },
                  childCount: _flattenGroups(grouped).length,
                ),
              );
            },
          ),

          // ── Sezione voci manuali ──────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: l.shoppingOtherSection,
              scheme: scheme,
              tt: tt,
            ),
          ),
          itemsAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (items) {
              if (items.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.add_shopping_cart_outlined,
                    iconColor: scheme.onSurfaceVariant,
                    label: l.shoppingOtherEmpty,
                    tt: tt,
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ManualItemRow(
                    item: items[i],
                    scheme: scheme,
                    tt: tt,
                    ref: ref,
                  ),
                  childCount: items.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  List<Object> _flattenGroups(Map<String, List<ShoppingEntry>> grouped) {
    final flat = <Object>[];
    for (final project in grouped.keys) {
      flat.add(project);
      flat.addAll(grouped[project]!);
    }
    return flat;
  }

  void _shareList({
    required BuildContext context,
    required List<ShoppingEntry> paints,
    required List<ShoppingItem> items,
    required Set<String> checkedPaints,
  }) {
    final l = AppL10n.of(context);
    final buf = StringBuffer();
    buf.writeln('${l.shoppingShareHeader}\n');

    if (paints.isNotEmpty) {
      buf.writeln(l.shoppingPaintsSection);
      final byProject = <String, List<ShoppingEntry>>{};
      for (final e in paints) {
        byProject.putIfAbsent(e.projectName, () => []).add(e);
      }
      for (final project in byProject.keys) {
        buf.writeln('\n$project');
        for (final e in byProject[project]!) {
          final done = checkedPaints.contains('${e.brand}+${e.code}') ? '✓' : '○';
          buf.writeln('  $done ${e.brand}  ${e.code}  ${e.name}');
        }
      }
    }

    if (items.isNotEmpty) {
      if (paints.isNotEmpty) buf.writeln();
      buf.writeln(l.shoppingOtherSection);
      for (final item in items) {
        final done = item.done ? '✓' : '○';
        buf.writeln('  $done ${item.label}');
        if (item.notes != null && item.notes!.isNotEmpty) {
          buf.writeln('     ${item.notes}');
        }
      }
    }

    if (paints.isEmpty && items.isEmpty) {
      buf.writeln(l.shoppingShareEmpty);
    }

    Share.share(buf.toString());
  }

  void _showAddItemSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddItemSheet(
        onAdd: (label, notes) async {
          await ref.read(projectRepositoryProvider).addShoppingItem(
                label,
                notes: notes.isEmpty ? null : notes,
              );
        },
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;
  const _SectionHeader(
      {required this.label, required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: scheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextTheme tt;
  const _EmptyState(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: tt.bodySmall)),
        ],
      ),
    );
  }
}

// ── Paint row (automatic) ─────────────────────────────────────────────────────

class _PaintRow extends StatelessWidget {
  final ShoppingEntry entry;
  final ColorScheme scheme;
  final TextTheme tt;
  final bool checked;
  final ValueChanged<bool> onToggle;
  const _PaintRow({
    required this.entry,
    required this.scheme,
    required this.tt,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: checked
            ? scheme.surfaceContainerHigh.withOpacity(0.5)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (v) => onToggle(v ?? false),
            visualDensity: VisualDensity.compact,
          ),
          HexColorChip(
            color: _hexColor(entry.hex),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.brand}  ${entry.code}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: checked ? scheme.onSurfaceVariant : scheme.onSurface,
                    letterSpacing: 0.3,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  entry.name,
                  style: tt.bodySmall?.copyWith(
                    color: checked ? scheme.onSurfaceVariant.withOpacity(0.6) : null,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

// ── Manual item row ───────────────────────────────────────────────────────────

class _ManualItemRow extends StatelessWidget {
  final ShoppingItem item;
  final ColorScheme scheme;
  final TextTheme tt;
  final WidgetRef ref;
  const _ManualItemRow(
      {required this.item,
      required this.scheme,
      required this.tt,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) =>
          ref.read(projectRepositoryProvider).deleteShoppingItem(item.id),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: (v) => ref
                  .read(projectRepositoryProvider)
                  .toggleShoppingItem(item.id, v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: tt.bodyMedium?.copyWith(
                      decoration:
                          item.done ? TextDecoration.lineThrough : null,
                      color: item.done ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty)
                    Text(item.notes!,
                        style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add item bottom sheet ─────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final Future<void> Function(String label, String notes) onAdd;
  const _AddItemSheet({required this.onAdd});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _labelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() => _saving = true);
    await widget.onAdd(label, _notesCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(l.shoppingAddItemTitle, style: tt.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.shoppingItemDescriptionLabel,
              hintText: l.shoppingItemDescriptionHint,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: l.shoppingItemNotesLabel,
              hintText: l.shoppingItemNotesHint,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.actionAdd),
          ),
        ],
      ),
    );
  }
}
