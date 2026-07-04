import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localePrefProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // ── Aspetto ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Aspetto'),

          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            subtitle: _themeModeLabel(themeMode),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),

          // ── Lingua ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Lingua'),

          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Lingua dell\'app',
            subtitle: _localeLabel(locale),
            onTap: () => _showLocalePicker(context, ref, locale),
          ),

          // ── Info ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'Info'),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Versione',
            subtitle: '1.0.0-beta.1',
            onTap: null,
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Scuro',
        ThemeMode.light => 'Chiaro',
        ThemeMode.system => 'Sistema',
      };

  String _localeLabel(String locale) => switch (locale) {
        'it' => 'Italiano',
        'en' => 'English',
        _ => 'Sistema',
      };

  void _showThemePicker(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text('Tema',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final option in [
                (ThemeMode.dark, Icons.dark_mode_outlined, 'Scuro'),
                (ThemeMode.light, Icons.light_mode_outlined, 'Chiaro'),
                (ThemeMode.system, Icons.brightness_auto_outlined, 'Sistema'),
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
      ),
    );
  }

  void _showLocalePicker(
      BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text('Lingua',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final option in [
                ('system', Icons.brightness_auto_outlined, 'Sistema (predefinito)'),
                ('it', Icons.flag_outlined, 'Italiano'),
                ('en', Icons.flag_outlined, 'English'),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  'La modifica della lingua richiede il riavvio dell\'app.',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
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
