# Patina

**Il taccuino digitale per i tuoi modelli in scala.**

Patina è un'app Android per modellisti statici che permette di documentare progetti, gestire l'inventario vernici, salvare ricette di miscelazione e annotare tecniche direttamente sulle foto dei modelli — tutto offline, tutto tuo.

---

## Perché Patina

Le app esistenti per il modellismo hanno UI datate, cataloghi incompleti e coprono al massimo una o due aree. Patina nasce per coprire l'intero flusso di lavoro di un modellista in un'unica app moderna, con un design system curato e dati che restano sul dispositivo.

---

## Funzionalità

### Progetti
Crea una scheda per ogni modello: nome, marca kit, scala, categoria, foto di copertina e stato (`Da iniziare` · `In corso` · `Completato`). La scheda progetto raccoglie la galleria foto, le note di lavorazione e le vernici usate.

### Vernici
Inventario personale con chip colore esagonali e catalogo offline delle principali marche (Vallejo, Citadel, Tamiya — Fase 1). Traccia le quantità, genera automaticamente la lista della spesa per le vernici finite o quasi finite.

### Ricette
Salva le tue miscele personalizzate con proporzioni esatte, foto del risultato, tecnica di applicazione e tag. Algoritmo CIELAB integrato per suggerire ricette a partire da un colore target.

### Pin su Foto
Documenta colori e tecniche direttamente sulle foto del modello con pin interattivi. Ogni pin è collegato a una vernice dell'inventario o a una ricetta, con zoom e pan precisi.

---

## Stack Tecnico

| Layer | Tecnologia |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Database locale | Drift / SQLite |
| Navigazione | Go Router |
| Immagini | image_picker |
| Preferenze | shared_preferences |
| AI (Fase 3) | Claude API (Anthropic) |

**Offline-first** — nessun account richiesto, nessun dato inviato a server esterni in Fase 1.

---

## Design System

Design system **Ottone** v1.0 — dark-first, superfici grafite a undertone caldo.

- **Accent:** Ottone `#D99B3E` / Verderame `#3FA8A0`
- **Tipografia:** JetBrains Mono (display, titoli, label) + IBM Plex Sans (corpo)
- **Icona brand:** cluster di esagoni, CustomPainter nativo Flutter

---

## Struttura del Progetto

```
patina/
├── app/                    # Progetto Flutter
│   ├── lib/
│   │   ├── app/            # Router, tema
│   │   ├── database/       # Drift DB, tabelle, cataloghi JSON
│   │   ├── features/       # Onboarding, Progetti (wizard + scheda + archivio)
│   │   └── shared/         # Widget, costanti, utility
│   └── assets/catalogs/    # JSON cataloghi vernici (bundled)
├── docs/                   # Documentazione
│   ├── features.md         # Specifiche funzionalità
│   ├── architecture.md     # Architettura tecnica e schema DB
│   └── roadmap.md          # Roadmap di sviluppo
└── .github/workflows/      # CI/CD — build APK debug e release
```

---

## Roadmap

| Fase | Descrizione | Stato |
|------|-------------|-------|
| **0** | Fondamenta: DB, design system, navigazione, CI/CD | ✅ Completata |
| **1A** | Gestione Progetti: wizard, scheda, archivio, onboarding | 🔄 In corso |
| **1B** | Gestione Vernici: inventario e catalogo | ⬜ Da fare |
| **1C** | Ricette di miscelazione | ⬜ Da fare |
| **1D** | Pin su foto | ⬜ Da fare |
| **1E** | Rifinitura, backup, release Google Play | ⬜ Da fare |
| **2** | Internazionalizzazione: EN · ES · FR | ⬜ Da fare |
| **3** | Funzionalità AI e cloud (Claude API) | ⬜ Da fare |

Dettaglio completo → [`docs/roadmap.md`](docs/roadmap.md)

---

## Tooling

**[Pigment](https://github.com/moste70/pigment)** — tool interno Python per estrarre i cataloghi colori da PDF e siti web delle case produttrici e generare i file JSON compatibili con Patina. Repository separato.

---

## Documentazione

| Documento | Contenuto |
|-----------|-----------|
| [`docs/features.md`](docs/features.md) | Specifiche UX di ogni funzionalità |
| [`docs/architecture.md`](docs/architecture.md) | Stack, struttura, schema DB, design system |
| [`docs/roadmap.md`](docs/roadmap.md) | Roadmap completa con task e stato |

---

## Build

Il progetto usa GitHub Actions per build automatiche su ogni push.

```bash
cd app
flutter pub get
flutter build apk --release
```

APK debug e release disponibili negli artifact di ogni workflow run.
