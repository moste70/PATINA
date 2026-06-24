import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('theme_mode') ?? 'dark';
    state = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
  }
}

class PatinaColors {
  static const darkBackground    = Color(0xFF1A1A1F);
  static const darkSurface       = Color(0xFF25252C);
  static const darkSurfaceVar    = Color(0xFF2E2E38);
  static const darkAccent        = Color(0xFF7CB87C);
  static const darkAccentAlt     = Color(0xFFB87C3E);
  static const darkOnBackground  = Color(0xFFE8E8F0);
  static const darkOnSurface     = Color(0xFFCCCCD8);

  static const lightBackground   = Color(0xFFF5F4F0);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightSurfaceVar   = Color(0xFFEEEDE8);
  static const lightAccent       = Color(0xFF4A7A4A);
  static const lightAccentAlt    = Color(0xFF8A5A20);
  static const lightOnBackground = Color(0xFF1A1A1F);
  static const lightOnSurface    = Color(0xFF3A3A45);
}

class PatinaTheme {
  static ThemeData dark() {
    final base = ColorScheme.dark(
      background: PatinaColors.darkBackground,
      surface: PatinaColors.darkSurface,
      surfaceVariant: PatinaColors.darkSurfaceVar,
      primary: PatinaColors.darkAccent,
      secondary: PatinaColors.darkAccentAlt,
      onBackground: PatinaColors.darkOnBackground,
      onSurface: PatinaColors.darkOnSurface,
      onPrimary: Colors.white,
    );
    return _build(base);
  }

  static ThemeData light() {
    final base = ColorScheme.light(
      background: PatinaColors.lightBackground,
      surface: PatinaColors.lightSurface,
      surfaceVariant: PatinaColors.lightSurfaceVar,
      primary: PatinaColors.lightAccent,
      secondary: PatinaColors.lightAccentAlt,
      onBackground: PatinaColors.lightOnBackground,
      onSurface: PatinaColors.lightOnSurface,
      onPrimary: Colors.white,
    );
    return _build(base);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withOpacity(0.2),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: scheme.primary);
          }
          return IconThemeData(color: scheme.onSurface.withOpacity(0.6));
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: scheme.onSurface.withOpacity(0.6), fontSize: 12);
        }),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
