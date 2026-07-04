# PATINA — Guida per Claude Code

## Setup e build

```bash
# Installa dipendenze
cd app && flutter pub get

# Genera codice Drift (obbligatorio dopo ogni modifica alle tabelle DB)
cd app && flutter pub run build_runner build --delete-conflicting-outputs

# Avvia l'app in debug
cd app && flutter run

# Build APK debug
cd app && flutter build apk --debug

# Build APK release
cd app && flutter build apk --release
```

> **Nota:** il file `app/lib/database/app_database.g.dart` è generato da build_runner.
> Se non esiste o è obsoleto, qualsiasi modifica al database non funzionerà finché
> non si riesegue `build_runner build`.

## Struttura del progetto

```
app/lib/
  app/              # Router (Go Router), tema (Ottone design system)
  database/         # AppDatabase Drift + tabelle in tables/
  features/         # Schermate per feature (onboarding, projects, ...)
  shared/           # Widget e costanti condivisi
assets/catalogs/    # 11 JSON cataloghi vernici (v2024.1, ~1.000 colori)
docs/               # Documentazione: vision, features, architecture, roadmap
```

## Convenzioni

- **State management:** Riverpod con `StateNotifierProvider` e `Provider` scritti a mano (no codegen `@riverpod`)
- **Database:** Drift/SQLite. Le tabelle sono in `app/lib/database/tables/`. Dopo ogni modifica alle tabelle, rieseguire build_runner e incrementare `schemaVersion` con la relativa migrazione in `app_database.dart`
- **Cataloghi:** letti on-demand da `rootBundle` (asset JSON), non precaricati nel DB. La tabella `CatalogPaints` è nel schema ma non viene popolata automaticamente
- **Navigazione:** Go Router con ShellRoute per la bottom nav a 4 tab
- **Naming brand:** `vallejo`, `citadel`, `tamiya`, `gunze`, `humbrol`, `lifecolor` (minuscolo, senza spazi)
- **Palette DB:** `quantity` in InventoryPaints può essere: `full` | `half` | `low` | `empty`
- **Stati progetto:** `todo` | `in_progress` | `completed`

## Design system Ottone v1.0

- Accent principale: `#D99B3E` (Ottone/brass)
- Accent secondario: `#3FA8A0` (Verderame)
- Dark-first. Token in `PatinaColors`, tema in `PatinaTheme.dark()` / `.light()`
- Font: JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo)
- Chip colore: forma **esagonale** (flat-top), via `CustomPainter`

## Versioning DB

Schema corrente: **v2**
- v1 → tabelle base (projects, photos, catalog_paints, inventory_paints, recipes, recipe_ingredients, pins)
- v2 → aggiunta `custom_paints` (vernici inserite manualmente dall'utente)

## Debito tecnico noto

Vedere sezione "Debito Tecnico" in `docs/roadmap.md` per la lista completa.
Issue più urgenti: DT.1 (CustomPaints non ancora nel .g.dart — serve build_runner), DT.2 (demo project / onboarding order).
