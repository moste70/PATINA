# Patina — Roadmap di Sviluppo

## Fase 0 — Fondamenta (attuale)

**Obiettivo:** struttura del progetto, configurazione, permessi, database vuoto.
Nessuna schermata definitiva — solo lo scheletro funzionante.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 0.1 | Documentazione Vision, Features, Architecture | ✅ Completato |
| 0.2 | Inizializzazione progetto Flutter | 🔄 In corso |
| 0.3 | Configurazione dipendenze (Riverpod, Drift, Go Router) | ⬜ Da fare |
| 0.4 | Gestione permessi Android (camera, storage) | ⬜ Da fare |
| 0.5 | Setup database Drift con tutte le tabelle | ⬜ Da fare |
| 0.6 | Caricamento cataloghi JSON in SQLite al primo avvio | ⬜ Da fare |
| 0.7 | Design system base (colori dark, tipografia, tema Flutter) | ⬜ Da fare |
| 0.8 | Struttura navigazione con Go Router (rotte placeholder) | ⬜ Da fare |

---

## Fase 1A — Gestione Progetti

**Obiettivo:** creare, visualizzare e gestire progetti. Prima funzionalità usabile.

| Task | Descrizione |
|------|-------------|
| 1A.1 | Dashboard progetti — lista/griglia con card |
| 1A.2 | Creazione nuovo progetto (wizard) |
| 1A.3 | Scheda progetto — header, info base, note |
| 1A.4 | Galleria foto progetto (camera + galleria) |
| 1A.5 | Fasi di lavorazione — lista, spunta, note per fase |
| 1A.6 | Modifica e archiviazione progetto |
| 1A.7 | Ricerca e filtri nell'archivio |

---

## Fase 1B — Gestione Vernici

**Obiettivo:** inventario personale e cataloghi marche consultabili offline.

| Task | Descrizione |
|------|-------------|
| 1B.1 | Schermata catalogo — sfoglia per marca e linea |
| 1B.2 | Ricerca nel catalogo per codice e nome |
| 1B.3 | Inventario personale — lista con chip esagonali |
| 1B.4 | Aggiunta vernice da catalogo o manuale |
| 1B.5 | Modifica quantità con tap rapido |
| 1B.6 | Lista della spesa automatica (vernici finite/quasi finite) |
| 1B.7 | Equivalenze tra marche |

---

## Fase 1C — Ricette

**Obiettivo:** creare e salvare miscele personalizzate con proporzioni.

| Task | Descrizione |
|------|-------------|
| 1C.1 | Lista ricette con foto anteprima |
| 1C.2 | Creazione ricetta — selezione vernici + proporzioni |
| 1C.3 | Foto risultato dalla camera o galleria |
| 1C.4 | Tag e ricerca ricette |
| 1C.5 | Duplica ricetta |
| 1C.6 | Algoritmo miscelazione (HEX → suggerimento ricetta) |
| 1C.7 | Collegamento ricette ↔ progetti |

---

## Fase 1D — Pin su Foto

**Obiettivo:** documentazione visiva con pin interattivi sulle foto del modello.

| Task | Descrizione |
|------|-------------|
| 1D.1 | Viewer foto con zoom e pan |
| 1D.2 | Aggiunta pin colore con selezione vernice/ricetta |
| 1D.3 | Aggiunta pin lavorazione con tipo e note |
| 1D.4 | Visualizzazione chip esagonale sul pin |
| 1D.5 | Modifica e spostamento pin esistenti |
| 1D.6 | Toggle visibilità e filtro per tipo |
| 1D.7 | Vista lista di tutti i pin di una foto |

---

## Fase 1E — Rifinitura e Release

**Obiettivo:** polish, test, export dati e pubblicazione Google Play.

| Task | Descrizione |
|------|-------------|
| 1E.1 | Export backup ZIP (tutti i dati + foto) |
| 1E.2 | Import backup |
| 1E.3 | Impostazioni app (tema dark/light, lingua) |
| 1E.4 | Empty state e onboarding primo avvio |
| 1E.5 | Test su dispositivi reali |
| 1E.6 | Ottimizzazione performance (immagini, DB) |
| 1E.7 | Preparazione store listing Google Play |
| 1E.8 | Release beta (Google Play Internal Testing) |

---

## Fase 2 — Funzionalità AI e Cloud

> Da pianificare in dettaglio al completamento della Fase 1.

| Milestone | Descrizione |
|-----------|-------------|
| 2.1 | Integrazione Claude API — miscelazione AI avanzata |
| 2.2 | Riconoscimento colore da foto (Claude Vision) |
| 2.3 | Sistema crediti in-app (Google Play Billing) |
| 2.4 | Sincronizzazione cloud opzionale |
| 2.5 | Espansione cataloghi (AK, Ammo, Humbrol, Mr. Color) |
| 2.6 | Condivisione ricette con la community |

---

## Stato Attuale

```
Fase 0  ████░░░░░░  40%  — documentazione completa, Flutter da avviare
Fase 1  ░░░░░░░░░░   0%
Fase 2  ░░░░░░░░░░   0%
```
