import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/projects/project_detail/project_detail_screen.dart';
import '../shared/widgets/placeholder_screen.dart';
import '../shared/widgets/nav_icons.dart';
import '../features/settings/settings_screen.dart';
import '../features/shopping/shopping_list_screen.dart';
import '../features/paints/paints_screen.dart';
import '../l10n/app_localizations.dart';

// Provider che espone se l'onboarding è già stato completato.
// Caricato una sola volta in main.dart e passato come override.
final onboardingCompletedProvider = Provider<bool>(
  (ref) => throw UnimplementedError('override in main'),
);

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    // Lo splash decide sempre lui dove andare dopo l'animazione
    initialLocation: '/splash',
    routes: [
      // Splash — fuori dallo ShellRoute, niente bottom nav
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => SplashScreen(
          onboardingCompleted: onboardingDone,
        ),
      ),
      // Onboarding — fuori dallo ShellRoute (no bottom nav)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) => const ProjectsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'project-detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ProjectDetailScreen(projectId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/paints',
            name: 'paints',
            builder: (context, state) => const PaintsScreen(),
          ),
          GoRoute(
            path: '/recipes',
            name: 'recipes',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Ricette',
              icon: Icons.science_outlined,
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/shopping',
            name: 'shopping',
            builder: (context, state) => const ShoppingListScreen(),
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
    final scheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;
    final l = AppL10n.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outline, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _indexFromPath(location),
          onDestinationSelected: (index) => _navigateTo(context, index),
          destinations: [
            NavigationDestination(
              icon: _NavIcon(builder: (c) => ProjectsIcon(color: c)),
              selectedIcon: _NavIcon(builder: (c) => ProjectsIcon(color: c)),
              label: l.navProjects,
            ),
            NavigationDestination(
              icon: _NavIcon(builder: (c) => PaintsIcon(color: c)),
              selectedIcon: _NavIcon(builder: (c) => PaintsIcon(color: c)),
              label: l.navPaints,
            ),
            NavigationDestination(
              icon: _NavIcon(builder: (c) => RecipesIcon(color: c)),
              selectedIcon: _NavIcon(builder: (c) => RecipesIcon(color: c)),
              label: l.navRecipes,
            ),
            NavigationDestination(
              icon: _NavIcon(builder: (c) => SettingsIcon(color: c)),
              selectedIcon: _NavIcon(builder: (c) => SettingsIcon(color: c)),
              label: l.navSettings,
            ),
          ],
        ),
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

// Reads icon color from the surrounding IconTheme (set by NavigationBar).
class _NavIcon extends StatelessWidget {
  final Widget Function(Color color) builder;
  const _NavIcon({required this.builder});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return builder(color);
  }
}
