import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../database/app_database.dart';
import '../../shared/constants/app_constants.dart';
import 'create_project/create_project_wizard.dart';
import 'project_repository.dart';

// Filtro attivo: null = tutti
final _statusFilterProvider = StateProvider<String?>((ref) => null);

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);
    final filter = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progetti')),
      body: StreamBuilder(
        stream: repo.watchAllProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return _EmptyState(onNewProject: () => _openWizard(context));
          }

          final filtered = filter == null
              ? all
              : all.where((p) => p.status == filter).toList();

          return Column(
            children: [
              _FilterBar(current: filter),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyFilter(
                        label: AppConstants.projectStatusLabels[filter] ?? filter!,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _ProjectCard(project: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openWizard(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openWizard(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateProjectWizard(),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final String? current;
  const _FilterBar({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: 'Tutti',
            selected: current == null,
            onTap: () => ref.read(_statusFilterProvider.notifier).state = null,
            scheme: scheme,
          ),
          const SizedBox(width: 8),
          ...AppConstants.projectStatuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: AppConstants.projectStatusLabels[s] ?? s,
                  selected: current == s,
                  onTap: () =>
                      ref.read(_statusFilterProvider.notifier).state = s,
                  scheme: scheme,
                  color: _statusColor(s),
                ),
              )),
        ],
      ),
    );
  }

  Color? _statusColor(String status) => switch (status) {
        'in_progress' => const Color(0xFFC87A20),
        'completed' => const Color(0xFF2F8F57),
        _ => null,
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final Color? color;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? scheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.15) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Project card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final p = project;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final subtitle = [
      if (p.category != null)
        AppConstants.categoryLabels[p.category] ?? p.category!,
      if (p.scale != null) p.scale!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/projects/${p.id}'),
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              // Thumbnail
              SizedBox(
                width: 80,
                height: 80,
                child: p.coverPhoto != null
                    ? Image.file(
                        File(p.coverPhoto!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderThumb(scheme),
                      )
                    : _PlaceholderThumb(scheme),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: tt.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      _StatusBadge(status: p.status),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final ColorScheme scheme;
  const _PlaceholderThumb(this.scheme);

  @override
  Widget build(BuildContext context) => Container(
        color: scheme.surfaceContainerHigh,
        child: Icon(
          Icons.view_module_outlined,
          size: 28,
          color: scheme.onSurface.withOpacity(0.2),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'in_progress' => (
          'In corso',
          const Color(0xFFC87A20).withOpacity(0.15),
          const Color(0xFFC87A20),
        ),
      'completed' => (
          'Completato',
          const Color(0xFF2F8F57).withOpacity(0.15),
          const Color(0xFF2F8F57),
        ),
      _ => (
          'Da iniziare',
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewProject;
  const _EmptyState({required this.onNewProject});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_module_outlined,
                size: 80, color: scheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text('Nessun progetto ancora',
                style: tt.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Inizia aggiungendo il tuo primo modello in scala.',
              style: tt.bodyMedium
                  ?.copyWith(color: scheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuovo progetto'),
              onPressed: onNewProject,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final String label;
  const _EmptyFilter({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Nessun progetto "$label"',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurface.withOpacity(0.5)),
      ),
    );
  }
}
