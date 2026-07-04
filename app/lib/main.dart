import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'database/app_database.dart';
import 'features/onboarding/onboarding_screen.dart';
// AppL10n è generato da `flutter gen-l10n` (lib/l10n/app_it.arb + app_en.arb).
// Uso: AppL10n.of(context).actionSave
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
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
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
