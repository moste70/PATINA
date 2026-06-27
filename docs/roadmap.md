# Patina — Roadmap di Sviluppo

## Fase 0 — Fondamenta

**Obiettivo:** struttura del progetto, dipendenze, database, cataloghi, design system, navigazione.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 0.1 | Documentazione Vision, Features, Architecture, Roadmap | ✅ Completato |
| 0.2 | Inizializzazione progetto Flutter + struttura cartelle | ✅ Completato |
| 0.3 | Configurazione dipendenze (Riverpod, Drift, Go Router, image_picker) | ✅ Completato |
| 0.4 | Gestione permessi Android (camera, storage) | ✅ Completato |
| 0.5 | Setup database Drift con tutte le tabelle (schemaVersion 1) | ✅ Completato |
| 0.6 | Caricamento cataloghi JSON in SQLite al primo avvio (`initializeCatalogs`) | ✅ Completato |
| 0.7 | Design system: palette dark/light (`PatinaColors`), tipografia, tema Flutter | ✅ Completato |
| 0.8 | Navigazione con Go Router — ShellRoute, 4 tab, placeholder screens | ✅ Completato |
| 0.9 | CI/CD GitHub Actions — build APK debug e release | ✅ Completato |
| 0.10 | `AppConstants` — categorie, stati, fasi predefinite, marche, quantità | ✅ Completato |
| 0.11 | Icona launcher Android (cluster esagoni) + fix NormalTheme AndroidManifest | ✅ Completato |
| 0.12 | Font Google Fonts: Inter (UI) + DM Serif Display (heading) via `PatinaFonts` | ✅ Completato |

---

## Fase 1A — Gestione Progetti

**Obiettivo:** creare, visualizzare e gestire progetti. Prima funzionalità usabile.

> **Convenzione priorità:** 🔴 Alta — sblocca altre feature · 🟡 Media — necessaria ma non bloccante · 🟢 Bassa — polish/ottimizzazione

### Documentazione (da completare prima dello sviluppo)

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1A-DOC.1 | 🔴 Alta | Riorganizza doc **Scheda Creazione Progetto** — wizard step-by-step, campi obbligatori/opzionali, validazioni, UX flow | ✅ Completato |
| 1A-DOC.2 | 🔴 Alta | Riorganizza doc **Scheda Principale Progetto** — layout sezioni, header, galleria, fasi, vernici usate, azioni | ✅ Completato |
| 1A-DOC.3 | 🟡 Media | Riorganizza doc **Onboarding** — flusso primo avvio, permessi, empty state, call to action | ⬜ Da fare |

### Sviluppo

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1A.1 | 🔴 Alta | Sviluppa **Scheda Creazione Progetto** — wizard multi-step: nome, categoria/scala, stato, foto cover | ⬜ Da fare |
| 1A.2 | 🔴 Alta | Sviluppa **Scheda Principale Progetto** (`/projects/:id`) — header, galleria foto, fasi di lavorazione, info | ⬜ Da fare |
| 1A.3 | 🟡 Media | Dashboard archivio (`/projects`) — griglia/lista card progetto con stato e avanzamento | ⬜ Da fare |
| 1A.4 | 🟡 Media | Galleria foto progetto — camera + galleria, gestione immagini, collega a fase | ⬜ Da fare |
| 1A.5 | 🟡 Media | Fasi di lavorazione — lista ordinata, spunta con data, note per fase, fasi custom | ⬜ Da fare |
| 1A.6 | 🟡 Media | Sviluppa **Onboarding** — schermata primo avvio, richiesta permessi, progetto di esempio | ⬜ Da fare |
| 1A.7 | 🟢 Bassa | Modifica, archiviazione ed eliminazione progetto | ⬜ Da fare |
| 1A.8 | 🟢 Bassa | Ricerca e filtri nell'archivio (nome, categoria, stato) | ⬜ Da fare |

---

## Fase 1B — Gestione Vernici

**Obiettivo:** inventario personale e cataloghi marche consultabili offline.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1B.1 | Schermata catalogo — sfoglia per marca e linea | ⬜ Da fare |
| 1B.2 | Ricerca nel catalogo per codice e nome | ⬜ Da fare |
| 1B.3 | Inventario personale — griglia chip esagonali / lista | ⬜ Da fare |
| 1B.4 | Aggiunta vernice da catalogo o manuale | ⬜ Da fare |
| 1B.5 | Modifica quantità con tap rapido | ⬜ Da fare |
| 1B.6 | Lista della spesa automatica (vernici finite/quasi finite) | ⬜ Da fare |
| 1B.7 | Equivalenze tra marche | ⬜ Da fare |

---

## Fase 1C — Ricette

**Obiettivo:** creare e salvare miscele personalizzate con proporzioni.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1C.1 | Lista ricette con foto anteprima | ⬜ Da fare |
| 1C.2 | Creazione ricetta — selezione vernici + proporzioni | ⬜ Da fare |
| 1C.3 | Foto risultato dalla camera o galleria | ⬜ Da fare |
| 1C.4 | Tag e ricerca ricette | ⬜ Da fare |
| 1C.5 | Duplica ricetta | ⬜ Da fare |
| 1C.6 | Algoritmo miscelazione CIELAB (HEX → suggerimento ricetta) | ⬜ Da fare |
| 1C.7 | Collegamento ricette ↔ progetti | ⬜ Da fare |

---

## Fase 1D — Pin su Foto

**Obiettivo:** documentazione visiva con pin interattivi sulle foto del modello.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1D.1 | Viewer foto con zoom e pan (InteractiveViewer) | ⬜ Da fare |
| 1D.2 | Aggiunta pin colore con selezione vernice/ricetta | ⬜ Da fare |
| 1D.3 | Aggiunta pin lavorazione con tipo e note | ⬜ Da fare |
| 1D.4 | Visualizzazione chip esagonale sul pin | ⬜ Da fare |
| 1D.5 | Modifica e spostamento pin esistenti | ⬜ Da fare |
| 1D.6 | Toggle visibilità e filtro per tipo | ⬜ Da fare |
| 1D.7 | Vista lista di tutti i pin di una foto | ⬜ Da fare |

---

## Fase 1E — Rifinitura e Release

**Obiettivo:** polish, test, backup dati e pubblicazione Google Play.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1E.1 | Export backup ZIP (tutti i dati + foto) | ⬜ Da fare |
| 1E.2 | Import backup | ⬜ Da fare |
| 1E.3 | Impostazioni app (tema dark/light, lingua) | ⬜ Da fare |
| 1E.4 | Empty state e onboarding primo avvio | ⬜ Da fare |
| 1E.5 | Test su dispositivi reali | ⬜ Da fare |
| 1E.6 | Ottimizzazione performance (immagini, DB) | ⬜ Da fare |
| 1E.7 | Preparazione store listing Google Play | ⬜ Da fare |
| 1E.8 | Release beta (Google Play Internal Testing) | ⬜ Da fare |

---

## Fase 2 — Funzionalità AI e Cloud

> Da pianificare in dettaglio al completamento della Fase 1.

| Milestone | Descrizione |
|-----------|-------------|
| 2.1 | Integrazione Claude API — miscelazione AI avanzata |
| 2.2 | Riconoscimento colore da foto (Claude Vision) |
| 2.3 | Sistema crediti in-app (Google Play Billing) |
| 2.4 | Sincronizzazione cloud opzionale |
| 2.5 | Espansione cataloghi (Vallejo Air/Panzer Aces, Citadel Layer/Shade/Contrast, Tamiya X/LP, AK, Ammo, Humbrol, Mr. Color) |
| 2.6 | Condivisione ricette con la community |

---

## Stato Attuale

```
Fase 0  ██████████  100%  — completata
Fase 1  ░░░░░░░░░░    0%  — in corso: 1A (doc → Creazione Progetto, Scheda Progetto, Onboarding)
Fase 2  ░░░░░░░░░░    0%
```

### Prossimi step immediati (ordine esecuzione)

1. 🔴 `1A-DOC.1` — Spec scheda creazione progetto
2. 🔴 `1A-DOC.2` — Spec scheda principale progetto
3. 🟡 `1A-DOC.3` — Spec onboarding
4. 🔴 `1A.1` — Dev scheda creazione (dipende da DOC.1)
5. 🔴 `1A.2` — Dev scheda principale (dipende da DOC.2)
6. 🟡 `1A.3` — Dev dashboard archivio
7. 🟡 `1A.6` — Dev onboarding (dipende da DOC.3)
