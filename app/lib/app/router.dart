import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/projects/project_detail/project_detail_screen.dart';
import '../shared/widgets/nav_icons.dart';
import '../features/settings/settings_screen.dart';
import '../features/shopping/shopping_list_screen.dart';
import '../features/paints/paints_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/recipes/recipe_detail_screen.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/adaptive_layout.dart';

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
            builder: (context, state) => const RecipesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'recipe-detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return RecipeDetailScreen(recipeId: id);
                },
              ),
            ],
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
    final sizeClass = AdaptiveLayout.of(context);
    final selectedIndex = _indexFromPath(location);

    final destinations = [
      _NavEntry(icon: (c) => ProjectsIcon(color: c), label: l.navProjects),
      _NavEntry(icon: (c) => PaintsIcon(color: c), label: l.navPaints),
      _NavEntry(icon: (c) => RecipesIcon(color: c), label: l.navRecipes),
      _NavEntry(icon: (c) => SettingsIcon(color: c), label: l.navSettings),
    ];

    // Compact: BottomNavigationBar (NavigationBar M3) attuale.
    if (sizeClass == WindowSizeClass.compact) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _navigateTo(context, index),
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: _NavIcon(builder: d.icon),
                  selectedIcon: _NavIcon(builder: d.icon),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    // Medium/Expanded: NavigationRail laterale al posto della bottom bar.
    // Label estese solo su Expanded (rail non extended su Medium).
    final extended = sizeClass == WindowSizeClass.expanded;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: scheme.surface,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _navigateTo(context, index),
            extended: extended,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: _NavIcon(builder: d.icon),
                  selectedIcon: _NavIcon(builder: d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outline),
          Expanded(child: child),
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

class _NavEntry {
  final Widget Function(Color color) icon;
  final String label;
  const _NavEntry({required this.icon, required this.label});
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
