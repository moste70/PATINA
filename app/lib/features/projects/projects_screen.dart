import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/pro/pro_gate.dart';
import '../../shared/pro/paywall_sheet.dart';
import '../../shared/widgets/gesture_hint_bar.dart';
import '../../shared/widgets/adaptive_layout.dart';
import 'create_project/create_project_wizard.dart';
import 'project_repository.dart';

// Filtro stato attivo: null = tutti
final _statusFilterProvider = StateProvider<String?>((ref) => null);
// Testo ricerca
final _searchQueryProvider = StateProvider<String>((ref) => '');
// Mostra/nascondi search bar
final _searchActiveProvider = StateProvider<bool>((ref) => false);

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final repo        = ref.watch(projectRepositoryProvider);
    final filter      = ref.watch(_statusFilterProvider);
    final query       = ref.watch(_searchQueryProvider).trim().toLowerCase();
    final searchActive = ref.watch(_searchActiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: searchActive
            ? _SearchField(
                hint: l.projectSearchHint,
                onChanged: (v) =>
                    ref.read(_searchQueryProvider.notifier).state = v,
                onClose: () {
                  ref.read(_searchActiveProvider.notifier).state = false;
                  ref.read(_searchQueryProvider.notifier).state = '';
                },
              )
            : Text(l.projectsScreenTitle),
        actions: [
          if (!searchActive)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l.projectSearchTooltip,
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(_searchActiveProvider.notifier).state = true;
              },
            ),
        ],
      ),
      body: StreamBuilder(
        stream: repo.watchAllProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? [];
          if (all.isEmpty && query.isEmpty) {
            return _EmptyState(onNewProject: () => _openWizard(context, ref));
          }

          // Applica filtro stato
          var filtered = filter == null
              ? all
              : all.where((p) => p.status == filter).toList();

          // Applica ricerca per nome
          if (query.isNotEmpty) {
            filtered = filtered
                .where((p) => p.name.toLowerCase().contains(query))
                .toList();
          }

          final sizeClass = AdaptiveLayout.of(context);

          return AdaptiveMaxWidth(
            child: Column(
              children: [
                _FilterBar(current: filter),
                GestureHintBar(
                  hintKey: 'hint_projects',
                  message: l.hintProjectsSwipe,
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyFilter(
                          query: query,
                          label: filter != null
                              ? AppL10n.of(context).projectStatusLabel(filter)
                              : null,
                        )
                      : _ProjectList(projects: filtered, sizeClass: sizeClass),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _FabNewProject(
        onTap: () => _openWizard(context, ref),
        repoStream: repo.watchAllProjects(),
        ref: ref,
      ),
    );
  }

  void _openWizard(BuildContext context, WidgetRef ref) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateProjectWizard(),
      ),
    );
  }
}

// ── FAB con gate Free ─────────────────────────────────────────────────────────

class _FabNewProject extends ConsumerWidget {
  final VoidCallback onTap;
  final Stream<List<Project>> repoStream;
  final WidgetRef ref;
  const _FabNewProject({
    required this.onTap,
    required this.repoStream,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final isPro = ProGate.watchProUser(ref);
    return StreamBuilder<List<Project>>(
      stream: repoStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final activeCount = all
            .where((p) => AppConstants.activeStatuses.contains(p.status))
            .length;
        final atLimit = !isPro && activeCount >= 2;

        return FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            if (atLimit) {
              PaywallSheet.show(context,
                  feature: l.filterAll); // placeholder feature name
            } else {
              onTap();
            }
          },
          tooltip: atLimit ? l.projectFabLimitTooltip : l.projectFabNewTooltip,
          child: atLimit
              ? const Icon(Icons.lock_outline)
              : const Icon(Icons.add),
        );
      },
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchField({
    required this.hint,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: true,
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose,
        ),
      ),
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
    );
  }
}

// ── Lista/griglia progetti (1F.5 — adattiva per WindowSizeClass) ──────────────

class _ProjectList extends StatelessWidget {
  final List<Project> projects;
  final WindowSizeClass sizeClass;
  const _ProjectList({required this.projects, required this.sizeClass});

  @override
  Widget build(BuildContext context) {
    if (sizeClass == WindowSizeClass.compact) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: projects.length,
        itemBuilder: (context, i) => _ProjectCard(project: projects[i]),
      );
    }

    final crossAxisCount = sizeClass == WindowSizeClass.medium ? 2 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisExtent: 90, // altezza fissa _ProjectCard (80) + margin (10)
      ),
      itemCount: projects.length,
      itemBuilder: (context, i) => _ProjectCard(project: projects[i]),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final String? current;
  const _FilterBar({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: l.filterAll,
            selected: current == null,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(_statusFilterProvider.notifier).state = null;
            },
            scheme: scheme,
          ),
          const SizedBox(width: 8),
          ...AppConstants.projectStatuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: l.projectStatusLabel(s),
                  selected: current == s,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(_statusFilterProvider.notifier).state = s;
                  },
                  scheme: scheme,
                  color: _statusColor(scheme, s),
                ),
              )),
        ],
      ),
    );
  }

  Color? _statusColor(ColorScheme scheme, String status) => switch (status) {
        'in_progress' => const Color(0xFFC87A20),
        'completed'   => const Color(0xFF2F8F57),
        'paused'      => Colors.blueGrey,
        _             => null,
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
    final l = AppL10n.of(context);
    final p      = project;
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    final subtitle = [
      if (p.category != null) l.categoryLabel(p.category!),
      if (p.scale != null) p.scale!,
    ].join(' · ');

    final isPaused = p.status == 'paused';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/projects/${p.id}'),
        child: Opacity(
          opacity: isPaused ? 0.65 : 1.0,
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
                          cacheWidth: 240, // 80 dp × 3× density
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderThumb(scheme),
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
                          style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: tt.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant),
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
    final l = AppL10n.of(context);
    final label = l.projectStatusLabel(status);
    final (bg, fg) = switch (status) {
      'in_progress' => (
          const Color(0xFFC87A20).withOpacity(0.15),
          const Color(0xFFC87A20),
        ),
      'completed' => (
          const Color(0xFF2F8F57).withOpacity(0.15),
          const Color(0xFF2F8F57),
        ),
      'paused' => (
          Colors.blueGrey.withOpacity(0.15),
          Colors.blueGrey,
        ),
      _ => (
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
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_module_outlined,
                size: 80, color: scheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(l.projectEmptyTitle,
                style: tt.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l.projectEmptyBody,
              style: tt.bodyMedium
                  ?.copyWith(color: scheme.onSurface.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.projectFabNewTooltip),
              onPressed: onNewProject,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final String? label;
  final String query;
  const _EmptyFilter({this.label, required this.query});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final msg = query.isNotEmpty
        ? l.projectSearchEmpty(query)
        : l.projectFilterEmpty(label ?? '');
    return Center(
      child: Text(
        msg,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurface.withOpacity(0.5)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
