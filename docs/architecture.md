# Patina — Architettura Tecnica

## Stack Tecnologico

| Layer | Tecnologia | Versione / Note |
|-------|-----------|-----------------|
| Framework | Flutter (Dart) | Cross-platform Android/iOS, UI ricca, grafica custom |
| State Management | Riverpod + riverpod_generator | Reattivo, testabile, supporto async nativo |
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
│   │   │   │   └── placeholder_screen.dart  # Schermo placeholder con icona Patina
│   │   │   ├── utils/
│   │   │   │   └── permissions.dart         # Gestione permessi camera/storage
│   │   │   └── constants/
│   │   │       └── app_constants.dart       # Categorie, stati, fasi, marche, quantità
│   │   └── database/
│   │       ├── app_database.dart            # Drift DB + initializeCatalogs()
│   │       ├── app_database.g.dart          # Generato da build_runner
│   │       └── tables/
│   │           ├── projects.dart            # Projects, ProjectPhotos, ProjectPhases
│   │           ├── paints.dart              # CatalogPaints, InventoryPaints
│   │           ├── recipes.dart             # Recipes, RecipeIngredients
│   │           └── pins.dart                # Pins
│   └── pubspec.yaml
└── docs/                        # Documentazione di progetto
```

> **Nota:** La cartella `features/` (projects/, paints/, recipes/, pins/) non esiste ancora.
> Tutte le schermate sono attualmente `PlaceholderScreen`. Verrà popolata durante la Fase 1.

---

## Design System

### Palette Colori (`PatinaColors`)

| Token | Dark | Light | Uso |
|-------|------|-------|-----|
| `background` | `#12121A` | `#F5F4F0` | Sfondo app |
| `surface` | `#1C1C26` | `#FFFFFF` | Card, bottom nav |
| `surfaceVariant` | `#26263A` | `#EEEDE8` | Input, chip |
| `primary` (accent) | `#7CB87C` | `#4A7A4A` | CTA, selezioni |
| `secondary` (accentAlt) | `#B87C3E` | `#8A5A20` | Accento caldo |
| `onBackground` | `#E8E8F0` | `#1A1A1F` | Testo principale |
| `onSurface` | `#B0B0C8` | `#3A3A45` | Testo secondario |
| `outline` | `#2A2A3A` | `#E0DED8` | Divisori, bordi |

### Navigazione

L'app usa un `ShellRoute` con `NavigationBar` a 4 voci:

| Tab | Percorso | Icona outline | Icona selected |
|-----|----------|--------------|----------------|
| Progetti | `/projects` | `view_module_outlined` | `view_module` |
| Vernici | `/paints` | `palette_outlined` | `palette` |
| Ricette | `/recipes` | `science_outlined` | `science` |
| Impostazioni | `/settings` | `settings_outlined` | `settings` |

Rotta aggiuntiva: `/projects/:id` — scheda progetto (non nel tab, navigata dalla lista).
I pin su foto sono accessibili dalla scheda progetto, non tramite tab dedicato.

### Icona Patina (in-app)

`PlaceholderScreen` mostra nell'AppBar un'icona custom (`_HexPainter`):
esagono outline con punto centrale, disegnato via `CustomPainter` in colore `primary`.
Questa è l'icona di brand usata nell'interfaccia — distinta dall'icona launcher.

---

## Schema Database (Drift/SQLite)

Il database è inizializzato al primo avvio (`schemaVersion: 1`).
I cataloghi vengono caricati dagli asset JSON una sola volta (`initializeCatalogs()`
verifica se la tabella è già popolata prima di procedere).

### `projects`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
name            TEXT NOT NULL
brand           TEXT
scale           TEXT                        -- es. "1/35"
category        TEXT                        -- tank|aircraft|figure|ship|diorama|other
cover_photo     TEXT                        -- path locale
status          TEXT DEFAULT 'idea'         -- idea|building|painting|completed|paused
progress        INTEGER DEFAULT 0           -- 0-100
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
phase_id        INTEGER REFERENCES project_phases(id)
taken_at        INTEGER
```

### `project_phases`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
project_id      INTEGER NOT NULL REFERENCES projects(id)
name            TEXT NOT NULL
position        INTEGER NOT NULL
completed       BOOLEAN DEFAULT false
completed_at    INTEGER
notes           TEXT
is_custom       BOOLEAN DEFAULT false
```

Fasi predefinite (da `AppConstants.defaultPhases`):
Preparazione → Assemblaggio sub-gruppi → Assemblaggio finale → Stuccatura → Primer
→ Pittura base → Ombreggiatura e luci → Decalcomanie → Invecchiamento → Finitura

### `catalog_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
brand           TEXT NOT NULL               -- vallejo|citadel|tamiya
line            TEXT NOT NULL               -- model_color|base|xf|…
code            TEXT NOT NULL
name            TEXT NOT NULL
hex             TEXT NOT NULL               -- es. "#4A3728"
```

### `inventory_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
catalog_id      INTEGER REFERENCES catalog_paints(id)
custom_brand    TEXT
custom_code     TEXT
custom_name     TEXT
custom_hex      TEXT
quantity        TEXT DEFAULT 'full'         -- full|half|low|empty
notes           TEXT
purchased_at    INTEGER
```

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
catalog_id      INTEGER REFERENCES catalog_paints(id)
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
phase_id        INTEGER REFERENCES project_phases(id)
```

---

## Cataloghi Vernici

I cataloghi sono bundled come asset JSON e caricati in SQLite al primo avvio.

**Cataloghi inclusi in Fase 1** (verificati, dati reali presenti negli asset):

| File | Marca | Linea (`line`) | Colori |
|------|-------|----------------|--------|
| `vallejo_model_color.json` | `vallejo` | `model_color` | 30 |
| `citadel_base.json` | `citadel` | `base` | 20 |
| `tamiya_xf.json` | `tamiya` | `xf` | 28 |

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

Espansione cataloghi (Vallejo Game Color/Air/Panzer Aces, Citadel Layer/Shade/Contrast,
Tamiya X/LP, AK Interactive, Ammo by Mig, Humbrol, Mr. Color) pianificata in Fase 2.

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
- Le foto restano nella memoria interna dell'app (non nella galleria pubblica)
- Backup manuale tramite export ZIP (Fase 1E)
- **Fase 2:** sync cloud opzionale con account utente
