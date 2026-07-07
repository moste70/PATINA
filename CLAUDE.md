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
assets/catalogs/    # 13 JSON cataloghi vernici (v2024.1, ~1.220 colori)
docs/               # Documentazione: vision, features, architecture, roadmap
```

## Internazionalizzazione (i18n)

Sistema: `flutter_localizations` + `intl` + file `.arb` — generatore ufficiale Flutter.

```bash
# Dopo aver aggiunto/modificato chiavi nei file .arb, rigenera il codice:
cd app && flutter gen-l10n
# (oppure basta flutter pub get / flutter build, che lo eseguono automaticamente)
```

**File:**
- `app/l10n.yaml` — configurazione del generatore
- `app/lib/l10n/app_it.arb` — stringhe italiane (file template, lingua di riferimento)
- `app/lib/l10n/app_en.arb` — stringhe inglesi
- `package:flutter_gen/gen_l10n/app_localizations.dart` — file generato (non committare)

**Uso nel codice:**
```dart
// Accesso
final l = AppL10n.of(context);
Text(l.actionSave)        // "Salva" / "Save"
Text(l.errorScaleFormat)  // "Formato non valido (es. 1/35)"

// Con parametri (aggiungere al .arb con {placeholder}):
// "greeting": "Ciao, {name}!"
// "@greeting": { "placeholders": { "name": { "type": "String" } } }
Text(l.greeting(user.name))
```

**Regole:**
1. Ogni nuova stringa visibile all'utente va prima nell'`.arb` italiano, poi tradotta nell'inglese
2. Naming chiavi: `<area><NomeStringa>` — es. `projectNameLabel`, `actionSave`, `errorRequired`
3. Le stringhe hardcoded esistenti si migrano gradualmente feature per feature
4. Non usare mai stringhe hardcoded per testi nuovi

## UX — Principio dei passi minimi

Usare più passaggi **solo** se aumentano chiarezza o comprensione per l'utente.
In tutti gli altri casi preferire sempre il minor numero di passaggi possibile:
inserire, confermare o navigare in un tap solo quando fattibile, senza sheet o
dialoghi intermedi non necessari.

## Convenzioni

- **State management:** Riverpod con `StateNotifierProvider` e `Provider` scritti a mano (no codegen `@riverpod`)
- **Database:** Drift/SQLite. Le tabelle sono in `app/lib/database/tables/`. Dopo ogni modifica alle tabelle, rieseguire build_runner e incrementare `schemaVersion` con la relativa migrazione in `app_database.dart`
- **Cataloghi:** letti on-demand da `rootBundle` (asset JSON), non precaricati nel DB. La tabella `CatalogPaints` è nel schema ma non viene popolata automaticamente
- **Navigazione:** Go Router con ShellRoute per la bottom nav a 4 tab
- **Naming brand:** `vallejo`, `citadel`, `tamiya`, `gunze`, `humbrol`, `lifecolor` (minuscolo, senza spazi)
- **Palette DB:** `quantity` in InventoryPaints può essere: `full` | `half` | `low` | `empty`
- **Stati progetto:** `todo` | `in_progress` | `completed`

## Supporto Tablet (Fase 1F)

Breakpoint Material 3 adottati per PATINA:

| Classe | Larghezza | Layout |
|--------|-----------|--------|
| Compact | < 600 dp | Smartphone verticale — layout attuale, `BottomNavigationBar` |
| Medium | 600–900 dp | Tablet piccolo / smartphone landscape — `NavigationRail`, colonne |
| Expanded | > 900 dp | Tablet grande / foldable — `NavigationRail` estesa, pannello maestro-dettaglio |

**Regole da rispettare in ogni nuova schermata:**
1. **Non usare** `MediaQuery.of(context).size.width` raw — usare sempre `AdaptiveLayout` / `WindowSizeClass` (Fase 1F.1) quando sarà implementato; nel frattempo aggiungere un `TODO(tablet)` come commento
2. **Max-width** — i contenuti delle schermate a colonna singola non devono superare `840 dp`; avvolgere con `Center` + `ConstrainedBox(maxWidth: 840)` (Fase 1F.3)
3. **Griglie** — dichiarare `crossAxisCount` come variabile calcolata dalla larghezza, non come costante hardcoded
4. La `ShellRoute` di Go Router rimane invariata — il supporto tablet cambia solo il widget shell (nav rail vs bottom bar), non la struttura delle route

## Design system Ottone v1.0

- Accent principale: `#D99B3E` (Ottone/brass)
- Accent secondario: `#3FA8A0` (Verderame)
- Dark-first. Token in `PatinaColors`, tema in `PatinaTheme.dark()` / `.light()`
- Font: JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo)
- Chip colore: forma **esagonale** (flat-top), via `CustomPainter`

## UX — Pattern consolidati

- **Chip colore esagonale:** usare sempre `HexColorChip` (`app/lib/shared/widgets/hex_color_chip.dart`) per rappresentare un colore vernice — in liste, palette kit, risultati OCR, shopping list. Non usare `BoxShape.circle` per i chip colore. Eccezione: elementi decorativi UI non legati a una vernice specifica (es. avatar, icone) possono restare circolari se è la forma più appropriata.
- **Swipe-to-delete:** usare `Dismissible` (swipe da destra) con sfondo `scheme.error` e icona `delete_outline` per eliminare voci da liste (palette kit, voci manuali shopping, foto galleria)
- **Pulsanti header sezione:** usare `_HeaderIconButton` (InkWell + padding 8dp → area tap 40×40dp, Tooltip) con `HapticFeedback.lightImpact()` — non usare `GestureDetector` nudo con icone piccole
- **Viewer foto fullscreen:** `MaterialPageRoute(fullscreenDialog: true)` + `InteractiveViewer` + AppBar scura con azione elimina — non long-press
- **Overlay su immagine:** testo bianco con `Shadow(color: Colors.black54, blurRadius: 6)` sul gradiente scuro; opacità `Colors.white70` per testo secondario
- **Condivisione lista:** usare `SharePlus.instance.share(ShareParams(text: ...))` di `share_plus` per esporre testo tramite lo share sheet nativo Android/iOS

## Versioning DB

Schema corrente: **v4**
- v1 → tabelle base (projects, photos, catalog_paints, inventory_paints, recipes, recipe_ingredients, pins)
- v2 → aggiunta `custom_paints` (vernici inserite manualmente dall'utente)
- v3 → aggiunta `project_paints` (palette del kit — vernici associate a un progetto)
- v4 → aggiunta `shopping_items` (lista della spesa manuale)

## Debito tecnico noto

Vedere sezione "Debito Tecnico" in `docs/roadmap.md` per la lista completa.
Issue più urgenti: DT.2 (demo project / onboarding order), DT.5 (note progetto: autosave vs bottoni).
