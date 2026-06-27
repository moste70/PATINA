import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'database/app_database.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.initializeCatalogs();
  final onboardingDone = await isOnboardingCompleted();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onboardingCompletedProvider.overrideWithValue(onboardingDone),
      ],
      child: const PatinaApp(),
    ),
  );
}

class PatinaApp extends ConsumerWidget {
  const PatinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Patina',
      debugShowCheckedModeBanner: false,
      theme: PatinaTheme.light(),
      darkTheme: PatinaTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
