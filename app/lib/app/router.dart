import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/placeholder_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/projects',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Progetti', icon: Icons.view_module),
            routes: [
              GoRoute(
                path: ':id',
                name: 'project-detail',
                builder: (context, state) => PlaceholderScreen(
                  title: 'Progetto #${state.pathParameters['id']}',
                  icon: Icons.construction,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/paints',
            name: 'paints',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Vernici', icon: Icons.palette),
          ),
          GoRoute(
            path: '/recipes',
            name: 'recipes',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Ricette', icon: Icons.science),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Impostazioni', icon: Icons.settings),
          ),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFromPath(location),
        onDestinationSelected: (index) => _navigateTo(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_module), label: 'Progetti'),
          NavigationDestination(icon: Icon(Icons.palette), label: 'Vernici'),
          NavigationDestination(icon: Icon(Icons.science), label: 'Ricette'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Impostazioni'),
        ],
      ),
    );
  }

  int _indexFromPath(String path) {
    if (path.startsWith('/paints')) return 1;
    if (path.startsWith('/recipes')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/projects');
      case 1: context.go('/paints');
      case 2: context.go('/recipes');
      case 3: context.go('/settings');
    }
  }
}
