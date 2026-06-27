import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/constants/app_constants.dart';
import 'create_project/create_project_wizard.dart';
import 'project_repository.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progetti')),
      body: StreamBuilder(
        stream: repo.watchAllProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data ?? [];
          if (projects.isEmpty) {
            return _EmptyState(
              onNewProject: () => _openWizard(context),
            );
          }
          // 1A.3 will implement the full grid/list view
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              final statusLabel =
                  AppConstants.projectStatusLabels[p.status] ?? p.status;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(p.name),
                  subtitle: Text(
                    [
                      if (p.category != null)
                        AppConstants.categoryLabels[p.category] ?? p.category!,
                      if (p.scale != null) p.scale!,
                    ].join(' · '),
                  ),
                  trailing: Text(statusLabel),
                  onTap: () => context.go('/projects/${p.id}'),
                ),
              );
            },
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
            Icon(
              Icons.view_module_outlined,
              size: 80,
              color: scheme.onSurface.withOpacity(0.2),
            ),
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
