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
| 0.6 | Cataloghi vernici — 11 file JSON bundled in `assets/catalogs/`, letti on-demand da `rootBundle`. Aggiornamenti distribuiti con nuove release app (versione 2024.1 = lancio). | ✅ Completato |
| 0.7 | Design system: palette dark/light (`PatinaColors`), tipografia, tema Flutter | ✅ Completato |
| 0.8 | Navigazione con Go Router — ShellRoute, 4 tab, placeholder screens | ✅ Completato |
| 0.9 | CI/CD GitHub Actions — build APK debug e release | ✅ Completato |
| 0.10 | `AppConstants` — categorie, stati, fasi predefinite, marche, quantità | ✅ Completato |
| 0.11 | Icona launcher Android (cluster esagoni) + fix NormalTheme AndroidManifest | ✅ Completato |
| 0.12 | Font: JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo) via `PatinaFonts` | ✅ Completato |

---

## Fase 1A — Gestione Progetti

**Obiettivo:** creare, visualizzare e gestire progetti. Prima funzionalità usabile.

> **Convenzione priorità:** 🔴 Alta — sblocca altre feature · 🟡 Media — necessaria ma non bloccante · 🟢 Bassa — polish/ottimizzazione

### Documentazione (da completare prima dello sviluppo)

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1A-DOC.1 | 🔴 Alta | Riorganizza doc **Scheda Creazione Progetto** — wizard step-by-step, campi obbligatori/opzionali, validazioni, UX flow | ✅ Completato |
| 1A-DOC.2 | 🔴 Alta | Riorganizza doc **Scheda Principale Progetto** — layout sezioni, header, galleria, fasi, vernici usate, azioni | ✅ Completato |
| 1A-DOC.3 | 🟡 Media | Riorganizza doc **Onboarding** — flusso primo avvio, permessi, empty state, call to action | ✅ Completato |

### Sviluppo

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1A.1 | 🔴 Alta | Sviluppa **Scheda Creazione Progetto** — wizard multi-step: nome, categoria/scala, stato, foto cover | ✅ Completato |
| 1A.2 | 🔴 Alta | Sviluppa **Scheda Principale Progetto** (`/projects/:id`) — header, galleria foto, fasi di lavorazione, info | ✅ Completato |
| 1A.3 | 🟡 Media | Dashboard archivio (`/projects`) — griglia/lista card progetto con stato e avanzamento | ✅ Completato |
| 1A.4 | 🟡 Media | Galleria foto progetto — camera + galleria, gestione immagini, collega a fase | ⬜ Da fare |
| 1A.5 | 🟡 Media | Sviluppa **Onboarding** — schermata primo avvio, richiesta permessi, progetto di esempio | ✅ Completato |
| 1A.6 | 🟢 Bassa | Modifica, archiviazione ed eliminazione progetto | ⬜ Da fare |
| 1A.7 | 🟢 Bassa | Ricerca e filtri nell'archivio (nome, categoria, stato) | ⬜ Da fare |

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

### Note pre-lancio — Adempimenti amministrativi

#### Account e pagamenti

- **Google Play Console** — registrazione una tantum $25 USD su [play.google.com/console](https://play.google.com/console)
- **Profilo pagamenti** — dati fiscali italiani (CF o P.IVA) obbligatori solo se si abilitano acquisti in-app (crediti AI, Fase 3). Per app gratuita in Fase 1 non è necessario.
- **Commissione Google** — 15% sui ricavi (ridotta dal 30% per i primi 1 M€/anno)

#### Configurazione app (obbligatoria prima del primo upload)

- `applicationId` definitivo in `build.gradle` — es. `com.patina.app`. **Non modificabile** dopo la pubblicazione.
- `versionCode` incrementale (intero), `versionName` leggibile (es. `1.0.0`)
- APK/AAB firmato con **keystore di produzione** — conservare in luogo sicuro. Perderlo = impossibile pubblicare aggiornamenti.
- Target SDK ≥ API 34 (requisito Google dal 2024)

#### Store listing (necessario per la pubblicazione)

- Titolo (max 30 car.), descrizione breve (max 80 car.), descrizione lunga (max 4000 car.)
- Almeno 2 screenshot per telefono (min 1080×1920 px)
- Feature graphic 1024×500 px (banner orizzontale)
- Icona alta risoluzione 512×512 PNG
- Categoria: **Produttività** o **Stile di vita**
- Questionario classificazione contenuti (Patina → "Everyone")
- **Privacy Policy URL** — obbligatoria anche se non si raccolgono dati. Deve dichiarare: dati locali sul dispositivo, nessun invio a server terzi in Fase 1, futuro uso Claude API in Fase 3. Una pagina su GitHub Pages è sufficiente.

#### Marchio

Il marchio **"PATINA"** è registrato in Italia (UIBM, reg. 362015000027630, cl. 1/2/22 — prodotti fisici industriali). Le classi **9** (software) e **42** (servizi IT) sono **libere**.

> Registrare il marchio in classe 9 + 42 **prima** della pubblicazione su Google Play.
> - Via nazionale UIBM: ~150–300 € → [uibm.gov.it](https://www.uibm.gov.it)
> - Via comunitaria EUIPO (copertura UE): ~850–1.000 €

#### Strategia di lancio consigliata

1. **Internal Testing** — 5-10 modellisti di fiducia per feedback reali
2. **Closed Testing (Beta)** — amplia a 50-100 utenti
3. **Open Testing** — beta pubblica prima del lancio definitivo
4. **Production** — rilascio graduale (10% → 50% → 100% degli utenti)

> La prima review di Google richiede tipicamente 3–7 giorni. Gli aggiornamenti successivi 1–2 giorni.

---

## Fase 2 — Internazionalizzazione

**Obiettivo:** rendere l'app accessibile ai mercati internazionali con le maggiori community di modellismo.

> Prerequisito: completamento Fase 1E (release italiana stabile).

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 2.1 | 🔴 Alta | Setup `flutter_localizations` + `intl` — struttura `.arb` files, estrazione tutte le stringhe UI | ⬜ Da fare |
| 2.2 | 🔴 Alta | Traduzione inglese (EN) — testi UI, onboarding, store listing Google Play | ⬜ Da fare |
| 2.3 | 🟡 Media | Traduzione spagnolo (ES) — community Warhammer/miniature painting hispanofona molto attiva | ⬜ Da fare |
| 2.4 | 🟡 Media | Traduzione francese (FR) — tradizione modellismo statico forte in Francia | ⬜ Da fare |
| 2.5 | 🟢 Bassa | Store listing localizzato per ogni lingua (titolo, descrizione, screenshot) | ⬜ Da fare |
| 2.6 | 🟢 Bassa | Selezione lingua manuale nelle Impostazioni (override locale di sistema) | ⬜ Da fare |

---

## Tooling — Patina Catalog Tool (repo separato)

**Obiettivo:** tool desktop interno (Python) per estrarre i colori dai cataloghi ufficiali delle case produttrici e generare i file JSON compatibili con `initializeCatalogs()` di Patina.

> Repository separato: `patina-catalog-tool`. Non fa parte del bundle app.
> Uso esclusivamente interno — automatizza un lavoro che si potrebbe fare a mano.

### Stack tecnico

| Componente | Libreria |
|------------|----------|
| PDF parsing | `pdfplumber` o `PyMuPDF` |
| Web scraping (siti statici) | `httpx` + `BeautifulSoup` |
| Web scraping (siti con JS) | `playwright-python` |
| UI desktop | `Tkinter` (semplice) o `PySide6` |
| Output | JSON → compatibile con Patina |

### Approccio per casa produttrice

| Casa | Come espone il catalogo | Strategia estrazione |
|------|------------------------|----------------------|
| **Vallejo** | PDF scaricabili + sito web strutturato | PDF parsing + scraping HTML |
| **Citadel (Games Workshop)** | Sito web con JS rendering | Browser headless (Playwright) |
| **Scale75** | PDF catalogo + shop online | PDF parsing |
| **Tamiya** | Sito statico + PDF | HTML scraping semplice |
| **AK Interactive** | PDF catalogo + shop | PDF parsing |
| **Humbrol** | Sito web + PDF | HTML scraping |
| **Mr. Color (GSI Creos)** | Sito statico giapponese + PDF | HTML scraping |
| **Ammo by Mig** | PDF catalogo + shop | PDF parsing |

### Task

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| CT.1 | 🔴 Alta | Setup repo Python + struttura moduli extractor per marca | ⬜ Da fare |
| CT.2 | 🔴 Alta | Extractor Vallejo Model Color (PDF) — marca principale nei cataloghi attuali | ⬜ Da fare |
| CT.3 | 🔴 Alta | Extractor Citadel (Playwright) — seconda marca più richiesta dalla community | ⬜ Da fare |
| CT.4 | 🟡 Media | Extractor Scale75, Tamiya, AK Interactive | ⬜ Da fare |
| CT.5 | 🟡 Media | Extractor Humbrol, Mr. Color, Ammo by Mig | ⬜ Da fare |
| CT.6 | 🟡 Media | UI desktop: selezione marca, fonte (URL/PDF), preview tabella colori con HEX | ⬜ Da fare |
| CT.7 | 🟢 Bassa | Validazione output: controllo duplicati, HEX validi, campi obbligatori | ⬜ Da fare |
| CT.8 | 🟢 Bassa | Export differenziale — aggiorna solo i colori modificati rispetto alla versione precedente | ⬜ Da fare |

---

## Fase 3 — Funzionalità AI e Cloud

> Da pianificare in dettaglio al completamento della Fase 2.

| Milestone | Descrizione |
|-----------|-------------|
| 3.1 | Integrazione Claude API — miscelazione AI avanzata |
| 3.2 | Riconoscimento colore da foto (Claude Vision) |
| 3.3 | Sistema crediti in-app (Google Play Billing) |
| 3.4 | Sincronizzazione cloud opzionale |
| 3.5 | Espansione cataloghi tramite Catalog Tool (Vallejo Air/Panzer Aces, Citadel Layer/Shade/Contrast, Tamiya X/LP, AK, Ammo, Humbrol, Mr. Color) |
| 3.6 | Condivisione ricette con la community |
| 3.7 | **Istruzioni AR** — fotografia libretto istruzioni in B/N, Claude Vision riconosce i codici colore e sovrappone esagoni colorati reali (overlay interattivo, salvato nel progetto, funzionalità a crediti) |

---

## Debito Tecnico e Bug Noti

> Emersi dall'audit codice/documentazione del 2025-07-03. Risolvere prima o durante la Fase 1B.

| Task | Priorità | Descrizione | Come risolvere | Stato |
|------|----------|-------------|----------------|-------|
| DT.1 | 🔴 Alta | `CustomPaints` non registrata in `@DriftDatabase` — la tabella non viene creata nel DB SQLite, tutto il flusso vernici manuali è non funzionante a runtime | Aggiungere `CustomPaints` alla lista tables in `app_database.dart` e incrementare `schemaVersion` a 2 con migrazione | ✅ Risolto (serve `build_runner build` per rigenerare .g.dart) |
| DT.2 | 🔴 Alta | Demo project inserito prima che l'utente completi l'onboarding — `main.dart` chiama `initializeDemoProject()` prima che l'utente veda la schermata di benvenuto | Spostare la chiamata a `initializeDemoProject()` nell'ultimo step dell'onboarding, o al primo accesso all'archivio | ⬜ Da fare |
| DT.3 | 🟡 Media | `colorScheme.background` / `onBackground` / `surfaceVariant` deprecati in Flutter 3.18+ — genera warning in build | Migrazione completa: `background→surface`, `onBackground→onSurface`, `surface→surfaceContainer`, `surfaceVariant→surfaceContainerHigh` in tutti i file dart | ✅ Risolto |
| DT.4 | 🟡 Media | Galleria foto in `project_detail_screen.dart` — bottone `+` con `onTap: () {}` vuoto, non collegato ad alcuna funzione | Implementare durante 1A.4 (Galleria foto progetto) | ⬜ Da fare |
| DT.5 | 🟡 Media | Note progetto: `features.md` descrive salvataggio automatico on blur, il codice usa bottoni Annulla/Salva espliciti | Allineare la spec o modificare il comportamento del campo note in `project_detail_screen.dart` | ⬜ Da fare |
| DT.6 | 🟡 Media | Campo `phaseId` orfano in `Pins` — non referenzia nessuna tabella, non documentato, mai popolato dall'UI | Riservato per Fase 1D (fasi di lavorazione) — documentato con commento in `tables/pins.dart`. Aggiungere FK e migrazione quando si implementerà la tabella `phases` | ✅ Documentato |
| DT.7 | 🟡 Media | Campo `catalogId` in `RecipeIngredients` non documentato — doppio riferimento a inventory e catalog non spiegato | Documentato con commento in `tables/recipes.dart`: `paintId` = percorso principale (inventario), `catalogId` = alternativo (vernice non ancora in inventario) | ✅ Documentato |
| DT.8 | 🟢 Bassa | Dipendenze inutilizzate in `pubspec.yaml`: `cached_network_image`, `uuid`, `dio`, `path_provider`, `path`, `intl`, `riverpod_annotation`, `riverpod_generator` | Rimuovere ora, reintrodurre quando effettivamente necessarie | ✅ Risolto |
| DT.9 | 🟢 Bassa | `docs/architecture.md` documenta solo 3 cataloghi (Vallejo MC, Citadel, Tamiya XF) — nella realtà sono 11 con ~1.000 colori | Aggiornare la sezione cataloghi in architecture.md | ✅ Risolto |
| DT.10 | 🟢 Bassa | `CLAUDE.md` mancante — nessuna guida per Claude Code su comandi build, codegen Drift, convenzioni naming | Creare `CLAUDE.md` alla radice con: `cd app && flutter pub get`, `flutter pub run build_runner build`, convenzioni progetto | ✅ Risolto |

---

## Stato Attuale

```
Fase 0       ██████████  100%  — completata
Fase 1A      ███████░░░   70%  — completata la base (1A.1/2/3/5); mancano galleria foto, modifica/elimina, ricerca
Fase 1B      ░░░░░░░░░░    0%  — Vernici: catalogo + inventario (prossima fase)
Fase 1C      ░░░░░░░░░░    0%  — Ricette
Fase 1D      ░░░░░░░░░░    0%  — Pin su foto
Fase 1E      ░░░░░░░░░░    0%  — Rifinitura e Release
Fase 2       ░░░░░░░░░░    0%  — Internazionalizzazione
Fase 3       ░░░░░░░░░░    0%  — AI e Cloud
Catalog Tool ░░░░░░░░░░    0%  — tool interno Python (repo separato)
Debito Tecnico ░░░░░░░░░░  0%  — 10 issue aperte (vedi sezione sopra)
```

### Prossimi step immediati (ordine esecuzione)

1. 🔴 `DT.1` — Aggiungere `CustomPaints` al DB (blocca tutto il flusso vernici manuali)
2. 🔴 `DT.2` — Fix ordine demo project / onboarding
3. 🔴 `1A.4` — Galleria foto progetto (sblocca 1D)
4. 🟡 `1A.6` — Modifica, archiviazione, eliminazione progetto
5. 🟡 `1B.1` — Schermata catalogo vernici (sfoglia per marca e linea, legge JSON on-demand)
6. 🟡 `1B.2` — Ricerca nel catalogo per codice e nome
7. 🟡 `1B.3` — Inventario personale — griglia chip esagonali / lista
8. 🟢 `DT.8` — Rimozione dipendenze inutilizzate da pubspec.yaml
