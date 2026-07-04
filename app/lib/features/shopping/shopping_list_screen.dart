import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../projects/project_repository.dart';

final _shoppingListProvider = StreamProvider<List<ShoppingEntry>>((ref) {
  return ref.watch(projectRepositoryProvider).watchShoppingList();
});

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shoppingListProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista della spesa'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: const Color(0xFF2F8F57)),
                  const SizedBox(height: 16),
                  Text('Tutte le vernici sono in magazzino',
                      style: tt.bodyMedium),
                ],
              ),
            );
          }

          // Group by project name
          final grouped = <String, List<ShoppingEntry>>{};
          for (final e in entries) {
            grouped.putIfAbsent(e.projectName, () => []).add(e);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final project in grouped.keys) ...[
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    project.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final e in grouped[project]!)
                  _ShoppingRow(entry: e, scheme: scheme, tt: tt),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  final ShoppingEntry entry;
  final ColorScheme scheme;
  final TextTheme tt;
  const _ShoppingRow(
      {required this.entry, required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              color: _hexColor(entry.hex),
              shape: BoxShape.circle,
              border:
                  Border.all(color: scheme.outline.withOpacity(0.4), width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.brand}  ${entry.code}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(entry.name,
                    style: tt.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.shopping_bag_outlined,
              size: 18, color: scheme.onSurfaceVariant),
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
