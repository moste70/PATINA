import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/pro/pro_gate.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/revenuecat_service.dart';
import '../../shared/utils/backup_service.dart';
import 'login_screen.dart';

// Provider per la lingua selezionata (codice locale, es. 'it', 'en', 'system').
// Usato anche in main.dart per impostare la locale di MaterialApp.
final localePrefProvider =
    StateNotifierProvider<LocaleNotifier, String>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<String> {
  static const _key = 'app_locale';

  LocaleNotifier() : super('system') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? 'system';
  }

  Future<void> set(String locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localePrefProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsScreenTitle),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // ── Aspetto ──────────────────────────────────────────────────────
          _SectionHeader(title: l.settingsAppearanceSection),

          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: l.settingsThemeTitle,
            subtitle: _themeModeLabel(l, themeMode),
            onTap: () => _showThemePicker(context, ref, l, themeMode),
          ),

          // ── Lingua ───────────────────────────────────────────────────────
          _SectionHeader(title: l.settingsLanguageSection),

          _SettingsTile(
            icon: Icons.language_outlined,
            title: l.settingsLanguageTitle,
            subtitle: _localeLabel(l, locale),
            onTap: () => _showLocalePicker(context, ref, l, locale),
          ),

          // ── Dati / Backup ─────────────────────────────────────────────────
          _SectionHeader(title: l.settingsDataSection),

          _SettingsTile(
            icon: Icons.upload_outlined,
            title: l.settingsBackupExportTitle,
            subtitle: l.settingsBackupExportSubtitle,
            onTap: () => _exportBackup(context, l),
          ),

          _SettingsTile(
            icon: Icons.download_outlined,
            title: l.settingsBackupImportTitle,
            subtitle: l.settingsBackupImportSubtitle,
            onTap: () => _importBackup(context, l),
          ),

          // ── Account ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          const _AccountTile(),

          // ── Aiuto ────────────────────────────────────────────────────────
          _SectionHeader(title: l.settingsHelpSection),

          _SettingsTile(
            icon: Icons.swipe_outlined,
            title: l.settingsGesturesTitle,
            subtitle: l.settingsGesturesSubtitle,
            onTap: () => _showGesturesSheet(context, l),
          ),

          // ── Developer (solo debug build) ──────────────────────────────────
          if (kDebugMode) ...[
            _SectionHeader(title: 'Developer'),
            _ProOverrideTile(),
          ],

          // ── Info ─────────────────────────────────────────────────────────
          _SectionHeader(title: l.settingsInfoSection),

          _SettingsTile(
            icon: Icons.info_outline,
            title: l.settingsVersionTitle,
            subtitle: '1.0.0-beta.1',
            onTap: null,
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, AppL10n l) async {
    HapticFeedback.lightImpact();
    try {
      await BackupService.exportBackup();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsBackupExportError)),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, AppL10n l) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return AlertDialog(
          title: Text(ll.settingsBackupImportTitle),
          content: Text(ll.settingsBackupImportWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ll.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ll.actionContinue),
            ),
          ],
        );
      },
    );
    if (confirm != true || !context.mounted) return;
    try {
      final done = await BackupService.importBackup();
      if (!done || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.settingsBackupImportSuccess),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsBackupImportError)),
      );
    }
  }

  void _showGesturesSheet(BuildContext context, AppL10n l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        final scheme = Theme.of(ctx).colorScheme;
        final gestures = [
          (Icons.swipe_left_outlined,      ll.gestureSwipeDelete),
          (Icons.touch_app_outlined,       ll.gestureLongPressQuantity),
          (Icons.touch_app_outlined,       ll.gestureLongPressPin),
          (Icons.touch_app_outlined,       ll.gestureLongPressPalette),
          (Icons.photo_camera_outlined,    ll.gestureTapPhotoEmpty),
          (Icons.zoom_in_outlined,         ll.gesturePinchPhoto),
          (Icons.swipe_right_alt_outlined, ll.gestureSwipeShoppingCheck),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(ll.settingsGesturesTitle,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final (icon, label) in gestures)
                  ListTile(
                    leading: Icon(icon, color: scheme.primary, size: 22),
                    title: Text(label,
                        style: Theme.of(ctx).textTheme.bodyMedium),
                    dense: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeModeLabel(AppL10n l, ThemeMode mode) => switch (mode) {
        ThemeMode.dark => l.settingsThemeDark,
        ThemeMode.light => l.settingsThemeLight,
        ThemeMode.system => l.settingsThemeSystem,
      };

  String _localeLabel(AppL10n l, String locale) => switch (locale) {
        'it' => l.settingsLocaleItalian,
        'en' => l.settingsLocaleEnglish,
        _ => l.settingsLocaleSystem,
      };

  void _showThemePicker(
      BuildContext context, WidgetRef ref, AppL10n l, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(ll.settingsThemeTitle,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final option in [
                  (ThemeMode.dark, Icons.dark_mode_outlined, ll.settingsThemeDark),
                  (ThemeMode.light, Icons.light_mode_outlined, ll.settingsThemeLight),
                  (ThemeMode.system, Icons.brightness_auto_outlined, ll.settingsThemeSystem),
                ])
                  ListTile(
                    leading: Icon(option.$2),
                    title: Text(option.$3),
                    trailing: current == option.$1
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setMode(option.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocalePicker(
      BuildContext context, WidgetRef ref, AppL10n l, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(ll.settingsLanguageSection,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final option in [
                  ('system', Icons.brightness_auto_outlined, ll.settingsLocaleSystem),
                  ('it', Icons.flag_outlined, ll.settingsLocaleItalian),
                  ('en', Icons.flag_outlined, ll.settingsLocaleEnglish),
                ])
                  ListTile(
                    leading: Icon(option.$2),
                    title: Text(option.$3),
                    trailing: current == option.$1
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(localePrefProvider.notifier).set(option.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Widget ausiliari ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: scheme.primary),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: scheme.onSurface.withOpacity(0.6), fontSize: 13),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: scheme.onSurface.withOpacity(0.3))
          : null,
      onTap: onTap,
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return userAsync.when(
      loading: () => const ListTile(
        leading: SizedBox(width: 36, height: 36),
        title: Text('Account'),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (User? user) {
        if (user == null) {
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_outline, size: 20, color: scheme.primary),
            ),
            title: const Text('Accedi o crea account'),
            subtitle: Text(
              'Necessario per attivare Patina Pro',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.6)),
            ),
            trailing: Icon(Icons.chevron_right, color: scheme.onSurface.withOpacity(0.3)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person, size: 20, color: scheme.primary),
              ),
              title: Text(user.email ?? 'Account'),
              subtitle: Text(
                'Connesso',
                style: TextStyle(fontSize: 13, color: scheme.primary),
              ),
            ),
            ListTile(
              leading: const SizedBox(width: 36),
              title: const Text('Esci dall\'account'),
              textColor: scheme.error,
              onTap: () => _signOut(context, ref),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esci dall\'account'),
        content: const Text('Verrai disconnesso. L\'abbonamento Pro sarà disattivato su questo dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Esci')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authServiceProvider).signOut();
    await RevenueCatService().logOut();
    ref.read(proStatusProvider.notifier).onAuthChanged(null);
  }
}

class _ProOverrideTile extends ConsumerWidget {
  const _ProOverrideTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(proStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPro
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.workspace_premium_outlined,
          size: 20,
          color: isPro ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      title: const Text('Simula abbonamento Pro'),
      subtitle: Text(
        isPro ? 'Pro attivo — tutte le funzioni sbloccate' : 'Free — funzioni Pro bloccate',
        style: TextStyle(
          fontSize: 13,
          color: isPro
              ? scheme.primary
              : scheme.onSurface.withOpacity(0.6),
        ),
      ),
      value: isPro,
      onChanged: (v) {
        HapticFeedback.lightImpact();
        ref.read(proStatusProvider.notifier).setDevOverride(v);
      },
    );
  }
}
