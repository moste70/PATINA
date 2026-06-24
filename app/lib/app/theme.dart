import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const darkBackground   = Color(0xFF12121A);
  static const darkSurface      = Color(0xFF1C1C26);
  static const darkSurfaceVar   = Color(0xFF26263A);
  static const darkAccent       = Color(0xFF7CB87C);
  static const darkAccentAlt    = Color(0xFFB87C3E);
  static const darkOnBg         = Color(0xFFE8E8F0);
  static const darkOnSurface    = Color(0xFFB0B0C8);
  static const darkDivider      = Color(0xFF2A2A3A);

  static const lightBackground  = Color(0xFFF5F4F0);
  static const lightSurface     = Color(0xFFFFFFFF);
  static const lightSurfaceVar  = Color(0xFFEEEDE8);
  static const lightAccent      = Color(0xFF4A7A4A);
  static const lightAccentAlt   = Color(0xFF8A5A20);
  static const lightOnBg        = Color(0xFF1A1A1F);
  static const lightOnSurface   = Color(0xFF3A3A45);
  static const lightDivider     = Color(0xFFE0DED8);
}

class PatinaTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      background: PatinaColors.darkBackground,
      surface: PatinaColors.darkSurface,
      surfaceVariant: PatinaColors.darkSurfaceVar,
      primary: PatinaColors.darkAccent,
      secondary: PatinaColors.darkAccentAlt,
      onBackground: PatinaColors.darkOnBg,
      onSurface: PatinaColors.darkOnSurface,
      onPrimary: Colors.black,
      outline: PatinaColors.darkDivider,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      background: PatinaColors.lightBackground,
      surface: PatinaColors.lightSurface,
      surfaceVariant: PatinaColors.lightSurfaceVar,
      primary: PatinaColors.lightAccent,
      secondary: PatinaColors.lightAccentAlt,
      onBackground: PatinaColors.lightOnBg,
      onSurface: PatinaColors.lightOnSurface,
      onPrimary: Colors.white,
      outline: PatinaColors.lightDivider,
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.background,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.background,
        foregroundColor: scheme.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: scheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        shadowColor: Colors.black26,
        elevation: 8,
        height: 64,
        indicatorColor: scheme.primary.withOpacity(0.15),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(color: scheme.onSurface.withOpacity(0.5), size: 24);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(
              color: scheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            );
          }
          return TextStyle(
            color: scheme.onSurface.withOpacity(0.5),
            fontSize: 11,
          );
        }),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
