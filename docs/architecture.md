# Patina — Architettura Tecnica

## Stack Tecnologico

| Layer | Tecnologia | Versione / Note |
|-------|-----------|-----------------|
| Framework | Flutter (Dart) | Cross-platform Android/iOS, UI ricca, grafica custom |
| State Management | Riverpod (`StateNotifierProvider`, `Provider`) | Reattivo, testabile, supporto async nativo — senza codegen |
| Database locale | Drift (SQLite) via drift_flutter | Type-safe, query reattive, dati relazionali |
| Navigazione | Go Router | Dichiarativo, ShellRoute per bottom nav, deep linking |
| Immagini | image_picker + cached_network_image | Selezione da galleria/camera, cache efficiente |
| Manipolazione foto/pin | InteractiveViewer + Canvas Flutter | Zoom, pan e overlay pin senza librerie esterne |
| Preferenze utente | shared_preferences | Persistenza tema dark/light tra sessioni |
| AI (Fase 2) | Anthropic Claude API | Miscelazione avanzata, riconoscimento colore da foto |
| CI/CD | GitHub Actions | Build APK debug e release su ogni push |

---

## Struttura del Progetto

```
patina/
├── .github/
│   └── workflows/
│       └── build-apk.yml        # CI: build APK debug + release
├── app/                         # Progetto Flutter
│   ├── android/                 # Configurazione Android nativa
│   │   └── app/src/main/res/
│   │       ├── drawable/        # ic_launcher_background.xml, ic_launcher_foreground.xml
│   │       ├── mipmap-anydpi-v26/  # Adaptive icon (API 26+)
│   │       └── values/          # colors.xml, styles.xml
│   ├── assets/
│   │   ├── icon.png             # Icona app 1024x1024 (cluster esagoni)
│   │   └── catalogs/            # JSON cataloghi vernici (bundled)
│   │       ├── vallejo_model_color.json   (30 colori)
│   │       ├── citadel_base.json          (20 colori)
│   │       └── tamiya_xf.json             (28 colori)
│   ├── lib/
│   │   ├── main.dart            # Entry point: init DB, catalogs, runApp
│   │   ├── app/
│   │   │   ├── router.dart      # Go Router: ShellRoute, 4 tab, AppShell
│   │   │   └── theme.dart       # PatinaColors, PatinaFonts, PatinaTheme
│   │   ├── shared/
│   │   │   ├── widgets/
│   │   │   │   ├── placeholder_screen.dart  # Schermo placeholder
│   │   │   │   ├── patina_logo.dart         # PatinaMark (7 esagoni)
│   │   │   │   └── nav_icons.dart           # CustomPainter icone bottom nav
│   │   │   ├── utils/
│   │   │   │   └── permissions.dart         # Gestione permessi camera/storage
│   │   │   └── constants/
│   │   │       └── app_constants.dart       # Categorie, stati, marche, quantità
│   │   ├── features/
│   │   │   ├── onboarding/                  # Splash, onboarding 4 schermate
│   │   │   ├── projects/
│   │   │   │   ├── projects_screen.dart     # Archivio progetti
│   │   │   │   ├── project_repository.dart  # CRUD progetti + foto + palette
│   │   │   │   ├── create_project/          # Wizard 3 step
│   │   │   │   └── project_detail/
│   │   │   │       ├── project_detail_screen.dart
│   │   │   │       └── project_palette_sliver.dart  # Palette del kit
│   │   │   └── settings/
│   │   │       └── settings_screen.dart     # Tema + lingua + info
│   │   └── database/
│   │       ├── app_database.dart            # Drift DB, schemaVersion 3
│   │       ├── app_database.g.dart          # Generato da build_runner
│   │       └── tables/
│   │           ├── projects.dart            # Projects, ProjectPhotos
│   │           ├── paints.dart              # CatalogPaints, CustomPaints, InventoryPaints, ProjectPaints
│   │           ├── recipes.dart             # Recipes, RecipeIngredients
│   │           └── pins.dart                # Pins
│   └── pubspec.yaml
└── docs/                        # Documentazione di progetto
```

---

## Design System

### Palette Colori (`PatinaColors`) — Design System "Ottone" v1.0

Dark-first. Accent Ottone (#D99B3E), superfici grafite a undertone caldo.
Tipografia: JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo).

| Token | Dark | Light | Uso |
|-------|------|-------|-----|
| `background` | `#16171B` | `#F4F2EC` | Sfondo app |
| `surface` | `#1E2025` | `#FFFFFF` | Card, bottom nav |
| `surfaceVariant` | `#282B31` | `#EAE7DF` | Input, chip |
| `primary` — Ottone | `#D99B3E` | `#B07C24` | CTA, selezioni, accent |
| `secondary` — Verderame | `#3FA8A0` | `#2E7D77` | Accento secondario |
| `onBackground` | `#ECEAE4` | `#1C1A16` | Testo principale |
| `onSurface` | `#9A9CA3` | `#57534A` | Testo secondario |
| `outline` | `#3A3E46` | `#DBD6CB` | Divisori, bordi |

**Colori semantici:**

| Token | Valore | Uso |
|-------|--------|-----|
| `successo` | `#2F8F57` | Permessi concessi, completato |
| `warning` | `#E0B84A` | Avvisi, quantità bassa vernice |
| `errore` | `#C8503B` | Permessi negati, errori |

### Navigazione

L'app usa un `ShellRoute` con `NavigationBar` a 4 voci:

| Tab | Percorso | Icona (CustomPainter) |
|-----|----------|-----------------------|
| Progetti | `/projects` | Griglia 2×2 con taglio angolare 60° — `ProjectsIcon` |
| Vernici | `/paints` | Tavolozza da pittore con foro pollice e 5 punti colore — `PaintsIcon` |
| Ricette | `/recipes` | Matraccio da laboratorio con bolla — `RecipesIcon` |
| Impostazioni | `/settings` | Ingranaggio 6 denti a geometria 60° — `SettingsIcon` |

Le icone sono definite in `app/lib/shared/widgets/nav_icons.dart` come `CustomPainter`.
Il colore attivo/inattivo viene letto dall'`IconTheme` del `NavigationBar` — il tono Ottone `#D99B3E` è impostato nel `NavigationBarThemeData` del tema.

Rotta aggiuntiva: `/projects/:id` — scheda progetto (non nel tab, navigata dalla lista).
I pin su foto sono accessibili dalla scheda progetto, non tramite tab dedicato.

### Icona Patina (in-app)

`PatinaMark` in `app/lib/shared/widgets/patina_logo.dart`: cluster di 7 esagoni flat-top
con la stessa palette della splash screen. Usata nell'onboarding e come placeholder.
Parametro `monoColor` forza colore singolo (usato in contesti icon-only).

---

## Schema Database (Drift/SQLite)

Schema corrente: **v3**. Migrazione automatica in `app_database.dart`:
- v1 → tabelle base
- v2 → aggiunta `custom_paints`
- v3 → aggiunta `project_paints`

I cataloghi sono asset JSON bundled, **non** precaricati nel DB — letti on-demand via `rootBundle`.

### `projects`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
name            TEXT NOT NULL
brand           TEXT
scale           TEXT                        -- es. "1/35"
category        TEXT                        -- tank|aircraft|figure|ship|car|motorcycle|diorama|other
cover_photo     TEXT                        -- path locale
status          TEXT DEFAULT 'todo'         -- todo|in_progress|completed
notes           TEXT
created_at      INTEGER NOT NULL            -- timestamp Unix
updated_at      INTEGER NOT NULL
```

### `project_photos`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
project_id      INTEGER NOT NULL REFERENCES projects(id)
path            TEXT NOT NULL
caption         TEXT
taken_at        INTEGER
```

### `project_paints` _(palette del kit — v3)_
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
project_id      INTEGER NOT NULL REFERENCES projects(id)
brand           TEXT NOT NULL               -- es. "tamiya"
code            TEXT NOT NULL               -- es. "XF-85"
name            TEXT NOT NULL               -- denormalizzato per display offline
hex             TEXT NOT NULL               -- es. "#3A3A3A"
added_at        INTEGER NOT NULL
UNIQUE (project_id, brand, code)
```

> Usa `brand+code` come chiave naturale, compatibile con `catalog_paints` e `custom_paints`.
> Il campo `name` e `hex` sono denormalizzati per evitare JOIN in lettura — aggiornati solo
> se il catalogo viene rigenerato. Il badge "In magazzino" viene calcolato live confrontando
> con `inventory_paints.catalog_brand + catalog_code`.

### `catalog_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
brand           TEXT NOT NULL               -- vallejo|citadel|tamiya|gunze|humbrol|lifecolor
line            TEXT NOT NULL               -- model_color|base|xf_flat|x_gloss|…
code            TEXT NOT NULL
name            TEXT NOT NULL
hex             TEXT NOT NULL               -- es. "#4A3728"
UNIQUE (brand, code)                        -- chiave naturale stabile
```

> **Importante:** l'inventario referenzia le vernici tramite `brand+code` (chiave
> naturale), non tramite `id`. Questo garantisce che gli aggiornamenti del catalogo
> (che ricreano i record con nuovi ID) non rompano mai i dati dell'utente.

### `custom_paints` _(vernici manuali utente)_
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
brand           TEXT NOT NULL               -- obbligatorio — es. "scale75"
code            TEXT NOT NULL               -- obbligatorio — es. "SC-01"
name            TEXT NOT NULL
hex             TEXT NOT NULL               -- es. "#2A1F18"
created_at      INTEGER NOT NULL
UNIQUE (brand, code)                        -- chiave naturale
```

> Al momento dell'aggiornamento catalogo, se un `brand+code` presente in
> `custom_paints` viene incluso nel nuovo catalogo ufficiale, la voce manuale
> viene rimossa automaticamente — il colore ufficiale (con HEX verificato) la sostituisce.
> `brand` e `code` sono **obbligatori** nell'inserimento manuale.

### `inventory_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
catalog_brand   TEXT                        -- riferimento a catalog_paints (brand+code)
catalog_code    TEXT                        --
custom_brand    TEXT                        -- riferimento a custom_paints (brand+code)
custom_code     TEXT                        --
quantity        TEXT DEFAULT 'full'         -- full|half|low|empty
notes           TEXT
purchased_at    INTEGER
```

> Uno e uno solo dei due gruppi (catalog_* o custom_*) è valorizzato per riga.

### `recipes`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
name            TEXT NOT NULL
photo_path      TEXT
technique       TEXT                        -- brush|airbrush|sponge
dilution        TEXT
surface         TEXT
notes           TEXT
tags            TEXT                        -- JSON array
created_at      INTEGER NOT NULL
updated_at      INTEGER NOT NULL
```

### `recipe_ingredients`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
recipe_id       INTEGER NOT NULL REFERENCES recipes(id)
paint_id        INTEGER REFERENCES inventory_paints(id)
percentage      REAL NOT NULL
```

### `pins`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
photo_id        INTEGER NOT NULL REFERENCES project_photos(id)
type            TEXT NOT NULL               -- color|technique
x               REAL NOT NULL               -- 0.0-1.0 relativo alla foto
y               REAL NOT NULL               -- 0.0-1.0 relativo alla foto
paint_id        INTEGER REFERENCES inventory_paints(id)
recipe_id       INTEGER REFERENCES recipes(id)
technique_type  TEXT
product_used    TEXT
notes           TEXT
```

---

## Cataloghi Vernici

I cataloghi sono **bundled come asset JSON** in `app/assets/catalogs/` e letti on-demand tramite `rootBundle` — non vengono precaricati nel DB SQLite. Ogni aggiornamento dei cataloghi viene distribuito con una nuova release dell'app.

**Versione corrente: 2024.1** — 11 cataloghi, ~1.000 colori totali.

| File | Marca | Linea (`line`) | Colori |
|------|-------|----------------|--------|
| `vallejo_model_color.json` | `vallejo` | `model_color` | 218 |
| `vallejo_model_air.json` | `vallejo` | `model_air` | 97 |
| `citadel_base.json` | `citadel` | `base` | 31 |
| `tamiya_xf.json` | `tamiya` | `xf_flat` | 92 |
| `tamiya_x.json` | `tamiya` | `x_gloss` | 29 |
| `gunze_aqueous.json` | `gunze` | `aqueous` | 150 |
| `gunze_mr_color.json` | `gunze` | `mr_color` | 256 |
| `gunze_mr_metal.json` | `gunze` | `mr_metal_color` | 9 |
| `humbrol_enamel.json` | `humbrol` | `enamel` | 195 |
| `lifecolor_ua.json` | `lifecolor` | `ua_camouflage` | 139 |
| `lifecolor_lc.json` | `lifecolor` | `lc_basic_gloss` | 27 |

**Formato JSON:**
```json
{
  "brand": "vallejo",
  "line": "model_color",
  "version": "2024.1",
  "paints": [
    { "code": "70.950", "name": "Black", "hex": "#1A1A1A" }
  ]
}
```

Espansione cataloghi (Vallejo Game Color/Panzer Aces, Citadel Layer/Shade/Contrast/Air,
Tamiya LP, AK Interactive, Ammo by Mig, Scale75) pianificata tramite Catalog Tool (repo separato).

---

## Splash Screen (Ibrido Native + Flutter)

L'avvio dell'app usa una strategia **ibrida** per garantire fluidità su Android 12+ e massima espressività visiva.

### Architettura

```
Avvio app
  │
  ├─ [Android OS] Native Splash Screen (API 31+)
  │     Sfondo: #1C1A16 (Fondo)
  │     Icona: marchio PATINA flat (WindowSplashScreenAnimatedIcon)
  │     Durata: ~180ms (fino a Flutter ready)
  │     Sfondo identico → transizione impercettibile
  │
  └─ [Flutter] SplashScreen widget
        Animazione: assemblaggio esagoni orario + wordmark
        Durata totale: 3.4s poi context.go('/projects')
```

### Timeline animazione Flutter

| Fase | Start | Durata | Descrizione |
|------|-------|--------|-------------|
| Ring hex 0 — top | 0ms | 360ms | Primo esagono in alto |
| Ring hex 1 — top-right | 320ms | 360ms | +320ms (STEP) |
| Ring hex 2 — bot-right | 640ms | 360ms | |
| Ring hex 3 — bottom | 960ms | 360ms | |
| Ring hex 4 — bot-left | 1280ms | 360ms | |
| Ring hex 5 — top-left | 1600ms | 360ms | |
| Centrale | 2120ms | 360ms | STEP×6 + 200ms di pausa |
| Wordmark fade+slide | 2600ms | 500ms | +480ms dopo centrale |
| Navigazione | 4000ms | — | `context.go('/projects')` |
| Idle breathing | loop | 4000ms | Pulse glow Ottone (sin wave) |

### Parametri tecnici

```dart
// Timing
const _kTotalMs      = 3400;   // durata AnimationController principale
const _kStep         = 320;    // ms tra ogni hex dell'anello
const _kHexDur       = 360;    // ms durata ingresso singolo hex
const _kCentralDelay = 2120;   // _kStep * 6 + 200
const _kTextStart    = 2600;   // _kCentralDelay + 480
const _kTextDur      = 500;
const _kNavigateDelay = 4000;  // _kTotalMs + 600

// Mark sizing
final markPx = min(screenW, screenH) * 0.38;
final s = markPx / 120.0;       // scala dallo spazio 120×120

// Scala ingresso hex: rimbalzo
scale = 0.45 + 0.55 * easeOutBack(t);

// Breathing idle (sin wave)
pulse = 0.055 * sin(breatheT * 2π);
glowAlpha = 0.20 + pulse * 0.7;  // range ~0.08–0.26 (clamped)
glowRadius = markPx * (0.8 + pulse * 0.5);
```

### Curve di animazione

| Curva | Uso |
|-------|-----|
| `Curves.easeOut` | Alpha fade-in di ogni hex, wordmark |
| `_EaseOutBack` (custom) | Scale ingresso hex — leggero rimbalzo `c1=1.70158` |
| `sin(t × 2π)` | Breathing glow idle |

### Palette esagoni (posizione → colore)

| Posizione | Hex | Note |
|-----------|-----|------|
| top (0) | `#D8CFBE` | Pallido — luce diretta |
| top-right (1) | `#DEC295` | Chiaro |
| bot-right (2) | `#EC9C26` | Oro caldo |
| bottom (3) | `#EF8E08` | Più saturo — profondo |
| bot-left (4) | `#E7A848` | Oro medio |
| top-left (5) | `#E4B56E` | Caldo chiaro — ritorno |
| centrale (6) | `#D99B3E` | Accent Ottone |

### Rendering esagoni (doppio passaggio)

Per giunture uniformi tra esagoni adiacenti il `CustomPainter` usa due passaggi separati:

1. **Fill pass** — tutti e 7 gli esagoni disegnati con:
   - Fill base col colore posizionale
   - Gradiente direzionale lineare: `topLeft(rgba 255,255,255 × 0.20)` → `(rgba 255,255,255 × 0.04 @40%)` → `bottomRight(rgba 0,0,0 × 0.28)`
2. **Stroke pass** — stroke uniforme su tutti: `rgba(0,0,0, 0.50)`, `strokeWidth=1.4`, `strokeJoin=round`

Un singolo passaggio causerebbe stroke doppi non uniformi sugli spigoli condivisi.

### File coinvolti

```
app/lib/features/onboarding/splash_screen.dart   ✅ implementato
app/android/app/src/main/res/values/styles.xml   ⬜ native splash config (da fare)
app/android/app/src/main/res/drawable/           ⬜ ic_splash_foreground.xml (da fare)
app/lib/app/router.dart                          ⬜ aggiungere rotta /splash (da fare)
```

### Integrazione router (da fare)

```dart
// In router.dart — aggiungere prima delle rotte principali
GoRoute(
  path: '/splash',
  builder: (context, state) => const SplashScreen(),
),
```

In `main.dart` impostare `initialLocation: '/splash'` oppure usare un `redirect` che porta a `/splash` solo al primo avvio.

---

## Algoritmo Miscelazione (Fase 1)

Calcolo in spazio colore **CIELAB** per distanza percettiva accurata (Delta-E).
Implementato in Dart puro, senza dipendenze esterne.

**Flusso:**
1. Utente inserisce colore target (HEX o color picker)
2. Conversione HEX → Lab per ogni vernice dell'inventario
3. Calcolo Delta-E tra target e inventario
4. Selezione delle 5 vernici più vicine
5. Mix ponderato per coppie/triplette → 3 ricette suggerite con distanza dal target

---

## Integrazione Claude API (Fase 2)

| Caso d'uso | Modello |
|------------|---------|
| Miscelazione avanzata (testo) | `claude-haiku-4-5-20251001` |
| Riconoscimento colore da foto | `claude-sonnet-4-6` |

Le chiamate AI saranno gestite da un servizio dedicato con:
- Crediti acquistabili via Google Play Billing
- Cache risultati per evitare chiamate duplicate
- Timeout e retry automatici

---

## Dati e Privacy

- **Fase 1:** tutti i dati sono locali sul dispositivo, nessun account richiesto
- **Fase 3:** sync cloud opzionale con account utente

### Archiviazione foto

Le foto dei progetti vengono salvate nella **memoria interna privata dell'app**, non nella galleria pubblica del dispositivo:

```
/data/data/com.patina.app/files/projects/{projectId}/photos/{filename}.jpg
```

Questo percorso è accessibile solo da Patina — altre app e l'utente tramite file manager non possono accedervi direttamente.

**Implicazioni importanti:**

| Scenario | Comportamento |
|----------|--------------|
| Disinstallazione app | Tutte le foto vengono cancellate insieme all'app |
| Backup Google One (automatico) | Le foto **non sono incluse** per default — richiede configurazione esplicita in `AndroidManifest.xml` |
| Export ZIP (Fase 1E) | Unico modo per salvare le foto fuori dall'app in Fase 1 |
| Migrazione dispositivo | Senza backup ZIP le foto vanno perse |

**Configurazione backup Android (`AndroidManifest.xml`):**

Da implementare in Fase 1E: dichiarare le regole di backup per includere la cartella foto nel backup automatico di Android (API 23+), così la migrazione tra dispositivi tramite Google One preserva i dati dell'utente.

```xml
<application
    android:fullBackupContent="@xml/backup_rules"
    android:dataExtractionRules="@xml/data_extraction_rules">
```

### Backup manuale (Fase 1E)

Export ZIP che include:
- Database SQLite completo (`patina.db`)
- Cartella foto (`/files/projects/`)

Import ZIP che ripristina entrambi. Unica soluzione di backup disponibile prima della Fase 3 (sync cloud).
