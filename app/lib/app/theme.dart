import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// PATINA Design System v1.0 — tema "Ottone".
// Dark-first. Accent Ottone (#D99B3E), superfici grafite a undertone caldo,
// tipografia JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo).
// ─────────────────────────────────────────────────────────────────────────

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

/// Token colore PATINA (nomi-pigmento).
class PatinaColors {
  // ── Dark (default) ──
  static const darkBackground   = Color(0xFF16171B); // Antracite — scaffold/page bg   → surface
  static const darkSurface      = Color(0xFF1E2025); // Ferro     — card/navBar bg     → surfaceContainer
  static const darkSurfaceVar   = Color(0xFF282B31); // Lastra    — input/chip bg      → surfaceContainerHigh
  static const darkAccent       = Color(0xFFD99B3E); // Ottone  ★
  static const darkAccentAlt    = Color(0xFF3FA8A0); // Verderame (secondario)
  static const darkOnBg         = Color(0xFFECEAE4); // Calce     — testo primario     → onSurface
  static const darkOnSurface    = Color(0xFF9A9CA3); // Calce smorzato — testo secondario → onSurfaceVariant
  static const darkDivider      = Color(0xFF3A3E46); // Limatura

  // ── Light ──
  static const lightBackground  = Color(0xFFF4F2EC); // Gesso     — scaffold/page bg   → surface
  static const lightSurface     = Color(0xFFFFFFFF); // Carta     — card/navBar bg     → surfaceContainer
  static const lightSurfaceVar  = Color(0xFFEAE7DF); // Gesso scuro — input/chip bg   → surfaceContainerHigh
  static const lightAccent      = Color(0xFFB07C24); // Ottone Light
  static const lightAccentAlt   = Color(0xFF2E7D77); // Verderame scuro
  static const lightOnBg        = Color(0xFF1C1A16); // Inchiostro — testo primario   → onSurface
  static const lightOnSurface   = Color(0xFF57534A); // Inchiostro smorzato          → onSurfaceVariant
  static const lightDivider     = Color(0xFFDBD6CB); // Hairline chiaro

  // ── Accent extra / semantici ──
  static const ottoneScuro      = Color(0xFF9E6E22);
  static const ottoneChiaro     = Color(0xFFECC079);
  static const verderame        = Color(0xFF3FA8A0);
  static const successo         = Color(0xFF2F8F57); // Verde Cromo
  static const warning          = Color(0xFFE0B84A); // Giallo Napoli
  static const errore           = Color(0xFFC8503B); // Minio
}

// JetBrains Mono — display, titoli, dati/codici vernice, label.
// IBM Plex Sans — corpo, descrizioni, liste.
class PatinaFonts {
  static TextTheme textTheme(ColorScheme scheme) {
    // Corpo in IBM Plex Sans.
    final body = GoogleFonts.ibmPlexSansTextTheme().copyWith(
      bodyLarge:  GoogleFonts.ibmPlexSans(color: scheme.onSurface,         fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: GoogleFonts.ibmPlexSans(color: scheme.onSurface,         fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall:  GoogleFonts.ibmPlexSans(color: scheme.onSurfaceVariant,  fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
      // Label in JetBrains Mono, tracking ampio (carattere "tecnico").
      labelLarge: GoogleFonts.jetBrainsMono(color: scheme.onSurface,        fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      labelMedium:GoogleFonts.jetBrainsMono(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.0),
      labelSmall: GoogleFonts.jetBrainsMono(color: scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.2),
    );
    return body.copyWith(
      // Display & H1/H2 in JetBrains Mono.
      displayLarge:  GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 36, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
      displayMedium: GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2,  letterSpacing: -0.3),
      displaySmall:  GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
      headlineLarge: GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
      // H3 → IBM Plex Sans semibold (più leggibile nel corpo).
      headlineMedium:GoogleFonts.ibmPlexSans(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600, height: 1.35),
      headlineSmall: GoogleFonts.ibmPlexSans(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      // Titoli/dati in JetBrains Mono.
      titleLarge:    GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      titleMedium:   GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      titleSmall:    GoogleFonts.jetBrainsMono(color: scheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    );
  }
}

class PatinaTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      // surface = scaffold/page background (rimpiazza il deprecato background)
      surface: PatinaColors.darkBackground,
      surfaceContainer: PatinaColors.darkSurface,
      surfaceContainerHigh: PatinaColors.darkSurfaceVar,
      primary: PatinaColors.darkAccent,
      secondary: PatinaColors.darkAccentAlt,
      // onSurface = testo primario su sfondi (rimpiazza onBackground)
      onSurface: PatinaColors.darkOnBg,
      // onSurfaceVariant = testo secondario/smorzato
      onSurfaceVariant: PatinaColors.darkOnSurface,
      onPrimary: const Color(0xFF16171B),
      error: PatinaColors.errore,
      outline: PatinaColors.darkDivider,
    );
    return _build(scheme, Brightness.dark);
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      surface: PatinaColors.lightBackground,
      surfaceContainer: PatinaColors.lightSurface,
      surfaceContainerHigh: PatinaColors.lightSurfaceVar,
      primary: PatinaColors.lightAccent,
      secondary: PatinaColors.lightAccentAlt,
      onSurface: PatinaColors.lightOnBg,
      onSurfaceVariant: PatinaColors.lightOnSurface,
      onPrimary: Colors.white,
      error: PatinaColors.errore,
      outline: PatinaColors.lightDivider,
    );
    return _build(scheme, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final textTheme = PatinaFonts.textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      textTheme: textTheme,
      // scheme.surface = scaffold background (ex scheme.background)
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.jetBrainsMono(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // scheme.surfaceContainer = card/navBar bg (ex scheme.surface)
        backgroundColor: scheme.surfaceContainer,
        shadowColor: Colors.black38,
        elevation: 8,
        height: 64,
        indicatorColor: scheme.primary.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.jetBrainsMono(
              color: scheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            );
          }
          return GoogleFonts.jetBrainsMono(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.6,
          );
        }),
      ),
      cardTheme: CardThemeData(
        // scheme.surfaceContainer = card bg (ex scheme.surface)
        color: scheme.surfaceContainer,
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
        // scheme.surfaceContainerHigh = input bg (ex scheme.surfaceVariant)
        fillColor: scheme.surfaceContainerHigh,
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
        hintStyle: GoogleFonts.ibmPlexSans(color: scheme.onSurfaceVariant.withOpacity(0.6), fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: const Color(0xFF16171B),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withOpacity(0.2),
        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline, width: 1),
        ),
        textStyle: GoogleFonts.ibmPlexSans(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.ibmPlexSans(
            color: scheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
