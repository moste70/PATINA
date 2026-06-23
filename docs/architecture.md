# Patina — Architettura Tecnica

## Stack Tecnologico

| Layer | Tecnologia | Motivazione |
|-------|-----------|-------------|
| Framework | Flutter (Dart) | Cross-platform Android/iOS, UI ricca, ottimo per grafica custom |
| State Management | Riverpod | Reattivo, testabile, supporto async nativo |
| Database locale | Drift (SQLite) | Type-safe, query reattive, ottimo per dati relazionali |
| Navigazione | Go Router | Dichiarativo, deep linking, gestione branch di navigazione |
| Immagini | `image_picker` + `cached_network_image` | Selezione da galleria/camera, cache efficiente |
| Manipolazione foto/pin | `InteractiveViewer` + Canvas Flutter | Zoom, pan e overlay pin senza librerie esterne |
| AI (Fase 2) | Anthropic Claude API | Miscelazione avanzata, riconoscimento colore da foto |
| HTTP Client | Dio | Intercettori, retry, gestione errori centralizzata |

---

## Architettura a Layer

```
lib/
├── main.dart
├── app/
│   ├── router.dart              # Go Router — definizione rotte
│   └── theme.dart               # Design system: colori, tipografia, componenti
│
├── features/                    # Un folder per ogni area funzionale
│   ├── projects/
│   │   ├── data/                # Repository, DAO, modelli DB
│   │   ├── domain/              # Entità, use case, interfacce repository
│   │   └── presentation/        # Schermate, widget, provider
│   ├── paints/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── recipes/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── pins/
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── shared/
│   ├── widgets/                 # Componenti riutilizzabili (HexChip, PinOverlay…)
│   ├── utils/                   # Color math, formattatori, helper
│   └── constants/               # Costanti app (marche, categorie, fasi default)
│
└── database/
    ├── app_database.dart        # Definizione Drift database
    └── tables/                  # Tabelle: projects, paints, recipes, pins…
```

---

## Schema Database (Drift/SQLite)

### Tabella: `projects`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
name            TEXT NOT NULL
brand           TEXT
scale           TEXT                        -- es. "1/35"
category        TEXT                        -- tank, aircraft, figure, ship, diorama, other
cover_photo     TEXT                        -- path locale immagine
status          TEXT DEFAULT 'idea'         -- idea, building, painting, completed, paused
progress        INTEGER DEFAULT 0           -- 0-100
notes           TEXT
created_at      INTEGER NOT NULL            -- timestamp Unix
updated_at      INTEGER NOT NULL
```

### Tabella: `project_photos`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
project_id      INTEGER NOT NULL REFERENCES projects(id)
path            TEXT NOT NULL               -- path locale immagine
caption         TEXT
phase_id        INTEGER REFERENCES project_phases(id)
taken_at        INTEGER
```

### Tabella: `project_phases`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
project_id      INTEGER NOT NULL REFERENCES projects(id)
name            TEXT NOT NULL
position        INTEGER NOT NULL            -- ordine di visualizzazione
completed       INTEGER DEFAULT 0           -- 0/1 boolean
completed_at    INTEGER
notes           TEXT
is_custom       INTEGER DEFAULT 0           -- fase predefinita o aggiunta dall'utente
```

### Tabella: `catalog_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
brand           TEXT NOT NULL               -- vallejo, citadel, tamiya
line            TEXT NOT NULL               -- model_color, base, xf, ecc.
code            TEXT NOT NULL
name            TEXT NOT NULL
hex             TEXT NOT NULL               -- es. "#4A3728"
```

### Tabella: `inventory_paints`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
catalog_id      INTEGER REFERENCES catalog_paints(id)
custom_brand    TEXT                        -- per vernici non in catalogo
custom_code     TEXT
custom_name     TEXT
custom_hex      TEXT
quantity        TEXT DEFAULT 'full'         -- full, half, low, empty
notes           TEXT
purchased_at    INTEGER
```

### Tabella: `recipes`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
name            TEXT NOT NULL
photo_path      TEXT
technique       TEXT                        -- brush, airbrush, sponge
dilution        TEXT
surface         TEXT                        -- plastic, metal, resin
notes           TEXT
tags            TEXT                        -- JSON array di stringhe
created_at      INTEGER NOT NULL
updated_at      INTEGER NOT NULL
```

### Tabella: `recipe_ingredients`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
recipe_id       INTEGER NOT NULL REFERENCES recipes(id)
paint_id        INTEGER REFERENCES inventory_paints(id)
catalog_id      INTEGER REFERENCES catalog_paints(id)
percentage      REAL NOT NULL
```

### Tabella: `pins`
```
id              INTEGER PRIMARY KEY AUTOINCREMENT
photo_id        INTEGER NOT NULL REFERENCES project_photos(id)
type            TEXT NOT NULL               -- color, technique
x               REAL NOT NULL               -- 0.0-1.0 relativo alla foto
y               REAL NOT NULL               -- 0.0-1.0 relativo alla foto
paint_id        INTEGER REFERENCES inventory_paints(id)
recipe_id       INTEGER REFERENCES recipes(id)
technique_type  TEXT                        -- per pin di tipo technique
product_used    TEXT
notes           TEXT
phase_id        INTEGER REFERENCES project_phases(id)
```

---

## Cataloghi Vernici — Strategia di Distribuzione

I cataloghi delle marche (Vallejo, Citadel, Tamiya) sono distribuiti come
**asset statici** bundled nell'app in formato JSON e importati nel database
SQLite al primo avvio.

```
assets/
└── catalogs/
    ├── vallejo_model_color.json
    ├── vallejo_game_color.json
    ├── vallejo_model_air.json
    ├── vallejo_mecha_color.json
    ├── vallejo_panzer_aces.json
    ├── citadel_base.json
    ├── citadel_layer.json
    ├── citadel_shade.json
    ├── citadel_contrast.json
    ├── tamiya_xf.json
    ├── tamiya_x.json
    └── tamiya_lp.json
```

**Formato JSON catalogo:**
```json
{
  "brand": "vallejo",
  "line": "model_color",
  "version": "2024.1",
  "paints": [
    {
      "code": "70.950",
      "name": "Black",
      "hex": "#1A1A1A"
    }
  ]
}
```

Aggiornamenti dei cataloghi saranno distribuiti tramite aggiornamenti app.

---

## Algoritmo Miscelazione Colori (Fase 1)

L'algoritmo interno lavora nello spazio colore **Lab (CIELAB)** per calcolare
la distanza percettiva tra colori — più accurato dell'RGB puro.

**Flusso:**
1. Utente inserisce il colore target (HEX o selezione da color picker)
2. Conversione HEX → Lab
3. Calcolo distanza Delta-E tra il target e ogni vernice dell'inventario
4. Selezione delle 5 vernici più vicine
5. Per ogni coppia/tripletta di vernici vicine: calcolo mix ponderato
6. Restituzione delle 3 ricette con minor distanza dal target

**Librerie:** calcolo Lab/Delta-E implementato in Dart puro (nessuna dipendenza esterna).

---

## Integrazione Claude API (Fase 2)

Le chiamate AI sono gestite tramite un servizio dedicato con:
- Gestione crediti lato client (contatore locale)
- Acquisto crediti via in-app purchase (Google Play Billing)
- Timeout e retry automatici
- Cache dei risultati per evitare chiamate duplicate

**Modello:** `claude-haiku-4-5-20251001` per risposte rapide ed economiche;
`claude-sonnet-4-6` per analisi immagini (riconoscimento colore da foto).

---

## Gestione Dati e Privacy

- **Fase 1:** tutti i dati sono **esclusivamente locali** sul dispositivo
- Nessun account richiesto, nessuna registrazione
- Le foto rimangono nella memoria interna dell'app (non nella galleria pubblica)
- Backup manuale tramite export ZIP (da implementare in Fase 1)
- **Fase 2:** sync cloud opzionale con account utente
