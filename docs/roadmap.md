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
| 0.6 | Cataloghi vernici — 13 file JSON bundled in `assets/catalogs/`, letti on-demand da `rootBundle`. ~1.220 colori totali (versione 2024.1). Inclusi Tamiya LP (lacquer, 76) e Tamiya TS (spray, 100) aggiunti dopo il lancio iniziale. | ✅ Completato |
| 0.7 | Design system: palette dark/light (`PatinaColors`), tipografia, tema Flutter | ✅ Completato |
| 0.8 | Navigazione con Go Router — ShellRoute, 4 tab, placeholder screens | ✅ Completato |
| 0.9 | CI/CD GitHub Actions — build APK debug e release; deploy Firebase Functions via service account (nessun login interattivo) | ✅ Completato |
| 0.10 | `AppConstants` — categorie, stati, fasi predefinite, marche, quantità | ✅ Completato |
| 0.11 | Icona launcher Android (cluster esagoni) + fix NormalTheme AndroidManifest + fix splash screen Android 12+ (ic_launcher_foreground multi-colore al posto di ic_splash_mark monocromatico) | ✅ Completato |
| 0.12 | Font: JetBrains Mono (display/titoli/label) + IBM Plex Sans (corpo) via `PatinaFonts` | ✅ Completato |
| 0.13 | Icone custom bottom navigation bar — `CustomPainter` per Progetti (griglia), Vernici (tavolozza), Ricette (matraccio), Impostazioni (ingranaggio 60°) | ✅ Completato |

---

## Fase 1A — Gestione Progetti

**Obiettivo:** creare, visualizzare e gestire progetti. Prima funzionalità usabile.

> **Limiti Free:** max 2 progetti attivi contemporaneamente (i progetti Completati non contano). Max 5 foto per progetto.

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
| 1A.3 | 🟡 Media | Dashboard archivio (`/projects`) — card con miniatura cover photo 80×80, badge stato colorato, filter bar chip per stato | ✅ Completato |
| 1A.4 | 🟡 Media | Galleria foto progetto — camera + galleria, miniature, viewer fullscreen con zoom (InteractiveViewer), elimina dall'AppBar | ✅ Completato |
| 1A.5 | 🟡 Media | Sviluppa **Onboarding** — schermata primo avvio, richiesta permessi, progetto di esempio | ✅ Completato |
| 1A.6 | 🟢 Bassa | Modifica (wizard edit mode), stato "In pausa" (non conta verso limite Free), eliminazione con conferma | ✅ Completato |
| 1A.7 | 🟢 Bassa | Ricerca per nome (search bar inline nell'AppBar, toggle icona lente) + filtro per stato (chip bar) + gate Free sul FAB (lock icon + paywall a 2 progetti attivi) | ✅ Completato |
| 1A.8 | 🟡 Media | **Devlog progetto** — timeline verticale nella scheda progetto. Voce: data/ora, testo, foto opzionale. Swipe-to-delete. DB: `project_logs` (schema v8). | ✅ Completato |

---

## Fase 1B — Gestione Vernici

**Obiettivo:** inventario personale e cataloghi marche consultabili offline.

> **Limiti Free:** max 20 vernici in inventario personale. Il catalogo offline è sempre consultabile senza limiti.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1B.1 | Schermata catalogo — sfoglia per marca e linea | ✅ Completato |
| 1B.2 | Ricerca nel catalogo per codice e nome | ✅ Completato |
| 1B.3 | Inventario personale — griglia chip esagonali / lista (toggle) | ✅ Completato |
| 1B.4 | Aggiunta vernice da catalogo con bottone `+` inline | ✅ Completato |
| 1B.5 | Modifica quantità dal detail sheet (senza chiudere il sheet) | ✅ Completato |
| 1B.6 | Lista della spesa — sezione automatica (vernici palette kit non in inventario, checkbox in-memory, ordine checked-in-fondo) + voci manuali (DB, checkbox persistito, swipe-to-delete, FAB); schermata `/shopping` con `ShoppingItems` (DB v4) | ✅ Completato |
| 1B.7 | Indicatore limite Free nella stats row (N/20 + barra progresso) | ✅ Completato |
| 1B.8 | Sottofiltro per linea nel catalogo (dopo selezione marca) | ✅ Completato |
| 1B.9 | Aggiunta vernice manuale (non in catalogo) — UI per `custom_paints`. FAB `+` solo nel tab Catalogo; brand da chip predefiniti o testo libero (non-standard → chip "Altri"); colore HEX selezionabile da ruota HSV o campionamento foto con crosshair; CRUD completo. | ✅ Completato |
| 1B.10 | Ordinamento inventario — per marca, per quantità (esaurite prima), per data aggiunta | ✅ Completato |
| 1B.11 | Long-press sul chip esagonale → cambio quantità rapido senza aprire il sheet | ✅ Completato |
| 1B.12 | Badge conteggio vernici per marca nei chip filtro (es. `Vallejo (12)`) | ✅ Completato |
| 1B.13 | Nome vernice visibile nella griglia esagonale (sotto il codice, font più piccolo) | ✅ Completato |
| 1B.14 | Collegamento rapido lista della spesa dal detail sheet (visibile solo se `low`/`empty`) | ✅ Completato |
| 1B.15 | Equivalenze tra marche | ✅ Completato |

---

## Fase 1C — Ricette

**Obiettivo:** creare e salvare miscele personalizzate con proporzioni.

> **Limiti Free:** max 5 ricette salvate.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1C.1 | Lista ricette con chip colore CIELAB e tag | ✅ Completato |
| 1C.2 | Creazione ricetta — selezione vernici da inventario/catalogo + proporzioni, finitura, numero di mani | ✅ Completato |
| 1C.3 | Foto risultato dalla camera o galleria | ⬜ Non implementato — sostituito da colore CIELAB auto-generato |
| 1C.4 | Tag e ricerca ricette per nome/tag | ✅ Completato |
| 1C.5 | ~~Duplica ricetta~~ | 🚫 Eliminato |
| 1C.6 | Colore miscelato CIELAB calcolato automaticamente dagli ingredienti (chip esagonale in tempo reale) | ✅ Completato |
| 1C.7 | Collegamento ricette ↔ progetti — tab "Ricette personali" nel picker palette kit; sezione progetti nella scheda ricetta | ✅ Completato |
| 1C.8 | Schermata dettaglio ricetta con colore blended, ingredienti, ΔE match e lista progetti collegati | ✅ Completato |
| 1C.9 | Cerca ricetta per colore target (HEX picker → ΔE ranking) | 🔄 Rimosso temporaneamente — UX da riprogettare (vedi DT.14) |

---

## Fase 1D — Pin su Foto

**Obiettivo:** documentazione visiva con pin interattivi sulle foto del modello.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1D.1 | Viewer foto con zoom e pan (InteractiveViewer) | ✅ Completato |
| 1D.2 | Aggiunta pin colore con selezione vernice/ricetta | ✅ Completato |
| 1D.3 | Aggiunta pin lavorazione con tipo e note | ✅ Completato |
| 1D.4 | Visualizzazione chip esagonale sul pin | ✅ Completato |
| 1D.5 | Modifica e spostamento pin esistenti | ✅ Completato |
| 1D.6 | Toggle visibilità e filtro per tipo | ✅ Completato |
| 1D.7 | Vista lista di tutti i pin di una foto | ✅ Completato |

---

## Fase 1E — Rifinitura e Release

**Obiettivo:** polish, test, backup dati e pubblicazione Google Play.

| Task | Descrizione | Stato |
|------|-------------|-------|
| 1E.1 | Export backup ZIP (tutti i dati + foto) | ✅ Completato |
| 1E.2 | Import backup | ✅ Completato |
| 1E.3 | Impostazioni app (tema dark/light, lingua) | ✅ Completato |
| 1E.4 | Empty state e onboarding primo avvio | ✅ Completato |
| 1E.5 | Test su dispositivi reali | ✅ Completato — eseguito manualmente a ogni rilascio APK |
| 1E.6 | Ottimizzazione performance (immagini, DB) | ✅ Completato |
| 1E.7 | Preparazione store listing Google Play | ⬜ Da fare |
| 1E.8 | Release beta (Google Play Internal Testing) | ⬜ Da fare |
| 1E.9 | Discoverability gesti: hint contestuali one-time + pagina "Gesti" in Impostazioni | ✅ Completato |

### ✅ Checklist pre-rilascio — comandi da eseguire

Eseguire nell'ordine prima di ogni build di rilascio:

```bash
cd app

# 1. Dipendenze aggiornate
flutter pub get

# 2. Rigenera codice Drift (obbligatorio se sono cambiate le tabelle)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Test cataloghi (nessun codegen necessario)
flutter test test/catalogs/

# 4. Test database (richiede il .g.dart generato al passo 2)
flutter test test/database/

# 5. Analisi statica
flutter analyze

# 6. Build APK release
flutter build apk --release

# 7. Verifica versionCode e versionName in android/app/build.gradle
#    → incrementare versionCode di 1 ad ogni upload su Play Console
```

> Tutti i test devono passare prima di procedere con il caricamento su Google Play Console.

---

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

## Fase 1F — Supporto Tablet

**Obiettivo:** far funzionare bene l'app su schermi medi e grandi (tablet Android da 8" a 12"+), sfruttando lo spazio extra senza stravolgere il codice esistente.

> Nota: Flutter usa i **Material 3 Window Size Classes** come riferimento:
> - **Compact** — larghezza < 600 dp (smartphone in verticale) → layout attuale
> - **Medium** — 600–840 dp (tablet piccolo, smartphone landscape) → NavigationRail + colonne
> - **Expanded** — > 840 dp (tablet grande, foldable aperto) → pannello maestro-dettaglio

### Fondamenta (da fare prima di qualsiasi altra cosa)

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1F.1 | 🔴 Alta | Crea `AdaptiveLayout` helper — `LayoutBuilder` con breakpoint `compact / medium / expanded`; espone un `WindowSizeClass` usabile ovunque tramite `InheritedWidget` o provider Riverpod | ⬜ Da fare |
| 1F.2 | 🔴 Alta | **Navigazione adattiva** — sostituisce `BottomNavigationBar` con `NavigationRail` su Medium/Expanded; ShellRoute in Go Router rimane invariato, cambia solo il widget shell | ⬜ Da fare |
| 1F.3 | 🔴 Alta | **Max-width constraint globale** — avvolge il contenuto delle schermate principali in un `Center` + `ConstrainedBox(maxWidth: 840)` per evitare layout spalmati su schermi da 12" | ⬜ Da fare |

### Layout adattivi per feature

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1F.4 | 🟡 Media | **Archivio progetti — pannello maestro-dettaglio** — su Expanded, lista progetto a sinistra (330 dp) e scheda dettaglio a destra nella stessa schermata; Go Router aggiorna l'URL normalmente | ⬜ Da fare |
| 1F.5 | 🟡 Media | **Griglia archivio adattiva** — `crossAxisCount` dinamico: 2 su Compact, 3 su Medium, 4 su Expanded | ⬜ Da fare |
| 1F.6 | 🟡 Media | **Wizard nuovo progetto** — su Expanded, layout a due colonne (form a sinistra, anteprima/info a destra) invece di PageView lineare | ⬜ Da fare |
| 1F.7 | 🟡 Media | **Inventario vernici** (Fase 1B) — griglia esagonale con `crossAxisCount` adattivo; sidebar filtri permanente su Expanded | ⬜ Da fare |
| 1F.8 | 🟢 Bassa | **Pin su foto** (Fase 1D) — pannello pin-list a fianco del viewer foto su Expanded | ⬜ Da fare |

### Ottimizzazioni e polish

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1F.9 | 🟡 Media | Supporto tastiera fisica — shortcut `Ctrl+N` (nuovo progetto), `Escape` (chiudi/indietro), frecce nella lista | ⬜ Da fare |
| 1F.10 | 🟢 Bassa | Hover state sui card — `MouseRegion` + elevazione / highlight on hover per uso con mouse/trackpad | ⬜ Da fare |
| 1F.11 | 🟢 Bassa | Drag & drop foto nella galleria progetto — riordino con `ReorderableListView` | ⬜ Da fare |
| 1F.12 | 🟢 Bassa | Test su emulatori tablet (Pixel Tablet, Pixel Fold) e screenshot Google Play per il form factor tablet | ⬜ Da fare |

### Note implementative

- **Non usare `MediaQuery.of(context).size.width` raw** — passare sempre per `AdaptiveLayout` / `WindowSizeClass` per evitare magic numbers sparsi nel codice.
- **Go Router** funziona già bene: su Expanded il pannello maestro-dettaglio viene gestito con una `ShellRoute` che renderizza entrambi i rami, non con due route separate.
- **`NavigationRail`** su Medium/Expanded usa le stesse voci del `BottomNavigationBar` attuale — i label si mostrano solo su Expanded (`.extended = true`).
- Breakpoint consigliati per PATINA (adattati al contenuto grafico): Compact < 600 dp · Medium 600–900 dp · Expanded > 900 dp.

---

## Fase 2 — Internazionalizzazione

**Obiettivo:** rendere l'app accessibile ai mercati internazionali con le maggiori community di modellismo.

> Prerequisito: completamento Fase 1E (release italiana stabile).
> L'infrastruttura (flutter_localizations + intl + file .arb IT/EN) è già predisposta nella Fase 0.

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 2.1 | 🔴 Alta | Setup `flutter_localizations` + `intl` — struttura `.arb` files, delegate in MaterialApp | ✅ Completato |
| 2.2 | 🔴 Alta | Chiavi IT/EN per azioni comuni, validazione, onboarding, categorie, stati, galleria | ✅ Completato |
| 2.3 | 🔴 Alta | Migrazione stringhe hardcoded esistenti → `AppL10n.of(context).*` (feature per feature) | ⬜ Da fare |
| 2.4 | 🟡 Media | Traduzione spagnolo (ES) — community Warhammer/miniature painting hispanofona molto attiva | ⬜ Da fare |
| 2.5 | 🟡 Media | Traduzione francese (FR) — tradizione modellismo statico forte in Francia | ⬜ Da fare |
| 2.6 | 🟢 Bassa | Store listing localizzato per ogni lingua (titolo, descrizione, screenshot) | ⬜ Da fare |
| 2.7 | 🟢 Bassa | Selezione lingua manuale nelle Impostazioni (override locale di sistema) | ✅ Completato |

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

## Fase 3 — Funzionalità AI Pro e Cloud

> Da pianificare in dettaglio al completamento della Fase 2.
> Tutte le funzionalità di questa fase sono **riservate agli utenti Pro** (abbonamento in-app).
> Vedere `docs/vision.md` per il modello di business completo.

### Modello abbonamento (3 tier)
- **Free**: tutte le funzionalità Fase 0–2 con limiti quantitativi (2 progetti attivi, 20 vernici inventario, 5 foto/progetto, 5 ricette)
- **Standard** (1,99 €/mese · 12,99 €/anno): rimuove tutti i limiti quantitativi, funzionalità Fase 0–2 illimitate
- **Pro** (3,99 €/mese · 24,99 €/anno): tutto di Standard + funzionalità AI e cloud di Fase 3
- **Piattaforme**: Google Play Billing (Android) + Apple IAP (iOS)
- **Gate nel codice**: `ProGate.isProUser(ref)` — `false` mostra paywall, `true` esegue la funzione

### Predisposizioni già nel codice
- `app/lib/shared/pro/pro_gate.dart` — `ProGate` helper + `proStatusProvider` (stub `false`, da collegare a billing)
- `app/lib/shared/pro/paywall_sheet.dart` — bottom sheet paywall placeholder da sostituire con UI definitiva in Fase 3

| Milestone | Descrizione |
|-----------|-------------|
| 3.1 | 🔄 **Sistema abbonamento** — Firebase Auth + Google Sign-In implementati; RevenueCat da integrare; paywall UI placeholder presente; `proStatusProvider` stub (`false`) da collegare a Firestore |
| 3.2 | **AI Vision scansione istruzioni** (sostituisce OCR MLKit) — Claude Vision identifica codici colore per marca da foto del libretto; lista pronta da aggiungere alla palette |
| 3.3 | ✅ **Miscelazione AI avanzata** — Firebase Function `suggestMixingRecipe` deployata su `europe-west1`; usa `claude-sonnet-5`; CLAUDE_API_KEY in Secret Manager; `AiMixingSheet` + `ClaudeService` integrati nell'app |
| 3.4 | **Riconoscimento colore da foto** — Claude Vision trova la vernice più vicina a un punto dell'immagine |
| 3.5 | **Istruzioni AR** — overlay esagoni colorati reali su foto libretto istruzioni B/N |
| 3.6 | **Sincronizzazione cloud** — backup automatico e sync multi-dispositivo |
| 3.7 | **Condivisione ricette con la community** |
| 3.8 | **Espansione cataloghi** tramite Catalog Tool (Vallejo Air/Panzer Aces, Citadel Layer/Shade/Contrast, AK, Ammo) |
| 3.9 | **Estrazione fasi di montaggio da istruzioni (AI Vision)** — l'utente fotografa una o più pagine del manuale di montaggio; Claude Vision analizza le immagini ed estrae automaticamente le fasi di lavorazione (numerazione step, nome sotto-assemblaggio, materiali citati), popolando una checklist fasi nel progetto. Applicabile a qualsiasi kit: plastico (Tamiya, Revell), navale in legno (Amati, Mantua, Corel), figure. Il flusso prevede: (1) acquisizione foto pagine con crop/raddrizzamento manuale o automatico, (2) invio a Claude con prompt strutturato per estrarre step ordinati, (3) preview editabile prima dell'import nel progetto. Fattibile con `claude-opus-4-8` o `claude-sonnet-5` vision; qualità dipende dalla leggibilità delle foto. |
| 3.10 | **Wizard acquisizione manuale — contestuale alla tipologia di kit (Pro)** — vedi spec dettagliata sotto |

### Spec milestone 3.1 — Sistema abbonamento

**Stack scelto: RevenueCat + Firebase**

RevenueCat è preferito a Google Play Billing diretto per tre ragioni:
- SDK Flutter unificato (`purchases_flutter`) che astrae sia Google Play che App Store — nessuna riscrittura quando si aggiunge iOS
- Webhook nativo verso Firebase che aggiorna Firestore automaticamente a ogni rinnovo/cancellazione
- Dashboard con metriche MRR, churn, trial — dati non disponibili dalla sola Play Console

**Dipendenze Flutter da aggiungere:**
```yaml
purchases_flutter: ^7.x        # RevenueCat SDK
firebase_core: ^3.x
firebase_auth: ^5.x
cloud_firestore: ^5.x
cloud_functions: ^5.x
```

**Flusso completo:**
```
Google Play / App Store
        │
        ▼
    RevenueCat  ◄──── purchases_flutter (app Flutter)
        │
        │  webhook automatico su ogni evento (acquisto, rinnovo, cancellazione)
        ▼
Firebase Function: updateProStatus
        │
        ▼
    Firestore: users/{uid}/isPro: true|false
        │
        ▼
proStatusProvider (Riverpod) ◄── legge da Firestore in realtime
        │
        ▼
ProGate.isProUser(ref)  →  mostra/nasconde funzioni Pro nell'app
```

**Verifica doppia (sicurezza):**
- Lato app: `ProGate` nasconde/mostra i bottoni (UX)
- Lato Cloud Function: ogni chiamata AI verifica `isPro` su Firestore prima di chiamare Claude — il client non viene mai trusted

**Implementazione lato Flutter (`pro_gate.dart` — Fase 3):**
```dart
// Sostituisce ProStatusNotifier attuale (stub SharedPreferences)
final proStatusProvider = StreamProvider<bool>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.data()?['isPro'] == true);
});
```

**Implementazione Cloud Function (`functions/src/updateProStatus.ts`):**
```typescript
// Webhook RevenueCat → aggiorna Firestore
export const revenueCatWebhook = onRequest(async (req, res) => {
  const event = req.body;
  const uid = event.app_user_id;
  const isPro = ['INITIAL_PURCHASE','RENEWAL','UNCANCELLATION']
    .includes(event.type);
  await db.doc(`users/${uid}`).set({ isPro }, { merge: true });
  res.sendStatus(200);
});
```

**Task implementativi:**
1. Creare progetto Firebase, abilitare Auth + Firestore + Functions
2. Configurare RevenueCat: creare prodotti su Google Play Console, collegarli a RevenueCat Entitlement `pro`
3. Deployare `revenueCatWebhook` e registrare URL su RevenueCat dashboard
4. Sostituire `ProStatusNotifier` (stub) con `StreamProvider` Firestore
5. Implementare paywall UI definitivo (sostituisce `paywall_sheet.dart` placeholder)
6. Testare con account test Google Play (License Testers)

---

### Spec milestone 3.10 — Wizard acquisizione manuale (Pro)

**Entry point:** nella scheda progetto, sezione "MANUALE", bottone `Analizza istruzioni` visibile solo agli utenti Pro (gate `ProGate.isProUser(ref)`); utenti Free vedono il bottone disabilitato con badge `PRO` che apre il paywall.

**Struttura wizard — 3 step comuni + step contestuali per tipologia:**

---

**Step 1 — Selezione modalità di input** (uguale per tutti i tipi)

| Opzione | Descrizione |
|---------|-------------|
| Fotocamera — scansiona pagine | Apre camera con overlay guida (rettangolo di ritaglio), scatto multiplo sequenziale, anteprima stack pagine |
| Galleria — importa immagini | File picker multi-selezione, ordina pagine manualmente drag-and-drop |

---

**Step 2 — Tipo di analisi** (adattivo alla `category` del progetto, pre-selezionato automaticamente)

| Categoria progetto | Analisi estratta | Prompt AI specializzato |
|-------------------|-----------------|------------------------|
| `tank` · `aircraft` · `car` · `motorcycle` | Fasi di verniciatura + codici colore per marca + posizionamento decal | Identifica step numerati, estrai codici colore Tamiya/Vallejo/Citadel con sotto-assemblaggio di riferimento, segnala le pagine decal |
| `figure` | Ricette di pittura per zona anatomica + tecniche (layering, washing, NMM) | Identifica zone (pelle, tessuti, metalli, basi), estrai colori suggeriti e tecniche menzionate per ciascuna |
| `ship` (nave in legno) | Fasi di costruzione per sotto-assemblaggio + lista ferramenta + schema sartiame | Identifica fasi costruttive (chiglia, fasciame, coperta, alberi, rigging), estrai elenco pezzi ferramenteria per fase, segnala le tavole sartiame |
| `diorama` | Fasi ambiente + materiali scenici + sequenza di assemblaggio | Identifica fasi (base, terreno, vegetazione, figure, veicoli), estrai materiali citati per fase |
| `other` | Estrazione generica fasi numerate | Estrai step ordinati, nomi sotto-assemblaggio, materiali o colori menzionati |

---

**Step 3 — Preview e conferma** (uguale per tutti)

- Lista editabile degli step estratti dall'AI: drag-and-drop per riordinare, tap per rinominare/eliminare, bottone `+ Aggiungi step manuale`
- Per categorie con colori estratti: chip colore inline con suggerimento "Aggiungi alla palette?"
- Per `ship`: sezione separata "Ferramenta rilevata" e "Tavole sartiame trovate a pag. X"
- Bottone `Importa nel progetto` → popola checklist fasi nel devlog o in una nuova sezione `FASI` della scheda progetto

---

**Note implementative**
- Ogni tipologia usa un system prompt diverso per Claude; i prompt sono costanti Dart in `lib/features/projects/ai/manual_prompts.dart`
- Le immagini vengono ridimensionate a ≤ 1600 px lato lungo e compresse JPEG 85% prima dell'invio (costo token)
- Invio batch: max 8 immagini per chiamata; pagine in eccesso → chiamate sequenziali con merge risultati
- Risultato AI → struttura `ManualAnalysisResult` con lista `phases`, lista opzionale `colorHints`, lista opzionale `fittings`, flag `riggingPagesFound`
- Tutte le chiamate API sono tracciate in un provider `manualAnalysisProvider` (AsyncNotifier) con stato loading / success / error

---

## Debito Tecnico e Bug Noti

> Emersi dall'audit codice/documentazione del 2025-07-03. Risolvere prima o durante la Fase 1B.

| Task | Priorità | Descrizione | Come risolvere | Stato |
|------|----------|-------------|----------------|-------|
| DT.1 | 🔴 Alta | `CustomPaints` non registrata in `@DriftDatabase` — la tabella non viene creata nel DB SQLite, tutto il flusso vernici manuali è non funzionante a runtime | Aggiungere `CustomPaints` alla lista tables in `app_database.dart` e incrementare `schemaVersion` a 2 con migrazione | ✅ Risolto (serve `build_runner build` per rigenerare .g.dart) |
| DT.2 | 🔴 Alta | Demo project inserito prima che l'utente completi l'onboarding — `main.dart` chiama `initializeDemoProject()` prima che l'utente veda la schermata di benvenuto | Spostare la chiamata a `initializeDemoProject()` nell'ultimo step dell'onboarding, o al primo accesso all'archivio | ✅ Già risolto — `initializeDemoProject()` è chiamata dentro `_finish()` in `onboarding_screen.dart`, cioè solo al tap su "Inizia" nell'ultimo step |
| DT.3 | 🟡 Media | `colorScheme.background` / `onBackground` / `surfaceVariant` deprecati in Flutter 3.18+ — genera warning in build | Migrazione completa: `background→surface`, `onBackground→onSurface`, `surface→surfaceContainer`, `surfaceVariant→surfaceContainerHigh` in tutti i file dart | ✅ Risolto |
| DT.4 | 🟡 Media | Galleria foto in `project_detail_screen.dart` — bottone `+` con `onTap: () {}` vuoto, non collegato ad alcuna funzione | Implementare durante 1A.4 (Galleria foto progetto) | ✅ Risolto |
| DT.5 | 🟡 Media | Note progetto: `features.md` descrive salvataggio automatico on blur, il codice usa bottoni Annulla/Salva espliciti | Allineare la spec o modificare il comportamento del campo note in `project_detail_screen.dart` | ✅ Risolto — bottoni espliciti Annulla/Salva scelti come comportamento definitivo; spec allineata |
| DT.6 | 🟡 Media | Campo `phaseId` orfano in `Pins` — non referenzia nessuna tabella, non documentato, mai popolato dall'UI | Riservato per Fase 1D (fasi di lavorazione) — documentato con commento in `tables/pins.dart`. Aggiungere FK e migrazione quando si implementerà la tabella `phases` | ✅ Documentato |
| DT.7 | 🟡 Media | Campo `catalogId` in `RecipeIngredients` non documentato — doppio riferimento a inventory e catalog non spiegato | Documentato con commento in `tables/recipes.dart`: `paintId` = percorso principale (inventario), `catalogId` = alternativo (vernice non ancora in inventario) | ✅ Documentato |
| DT.8 | 🟢 Bassa | Dipendenze inutilizzate in `pubspec.yaml`: `cached_network_image`, `uuid`, `dio`, `path_provider`, `path`, `intl`, `riverpod_annotation`, `riverpod_generator` | Rimuovere ora, reintrodurre quando effettivamente necessarie | ✅ Risolto |
| DT.9 | 🟢 Bassa | `docs/architecture.md` documenta solo 3 cataloghi (Vallejo MC, Citadel, Tamiya XF) — nella realtà sono 11 con ~1.000 colori | Aggiornare la sezione cataloghi in architecture.md | ✅ Risolto |
| DT.10 | 🟢 Bassa | `CLAUDE.md` mancante — nessuna guida per Claude Code su comandi build, codegen Drift, convenzioni naming | Creare `CLAUDE.md` alla radice con: `cd app && flutter pub get`, `flutter pub run build_runner build`, convenzioni progetto | ✅ Risolto |
| DT.11 | 🟢 Bassa | OCR istruzioni kit — MLKit offline riconosce il testo ma fallisce su font piccoli, layout multi-colonna e codici parzialmente sovrapposti a icone (es. Tamiya). La funzione è utile come aiuto alla compilazione ma non affidabile al 100%. Limite strutturale dell'OCR testuale; da risolvere in Fase 3 con **AI Vision** (vedi milestone 3.8). Nessun intervento necessario ora. | Rimandato a Fase 3 — milestone 3.8 | ⏳ Rimandato |
| DT.12 | 🟢 Bassa | `HexColorChip` — bordo fisso `scheme.outline` non visibile sui colori molto scuri (nero, navy) su sfondo scuro, né sui colori molto chiari (bianco, avorio) su sfondo chiaro | `HexColorChip.build()`: calcola luminanza relativa WCAG del colore; se luminanza > 0.18 applica bordo `nero/25%`, altrimenti `bianco/35%`. Applicato globalmente a tutte le schermate (palette, shopping, scan, inventario, ricette). | ✅ Risolto |
| DT.13 | 🟡 Media | Selector quantità inventario — 4 bottoni GestureDetector+AnimatedContainer sostituiti con `DropdownButtonFormField` nel detail sheet (`paints_screen.dart`). | ✅ Risolto |
| DT.14 | 🟡 Media | "Cerca ricetta per colore target" (1C.9) — funzionalità rimossa temporaneamente perché poco comprensibile (UX confusa). Da riprogettare: entry point più chiaro, tutorial inline, possibilmente fotocamera come input alternativo al HEX picker. | Da riprogettare in fase futura |

---

## Stato Attuale

```
Fase 0       ██████████  100%  — completata (incl. icone nav custom)
Fase 1A      ██████████  100%  — completa: wizard, scheda dettaglio, galleria, ricerca, modifica, eliminazione, stato pausa, devlog
Fase 1B      ██████████  100%  — completa
Fase 1C      ██████████  100%  — completa
Fase 1D      █████████░   86%  — 1D.1-1D.7 completati (UX redesign con PaintPickerSheet e tooltip overlay); manca 1D.6 (toggle visibilità)
Fase 1E      ████████░░   80%  — backup ZIP, empty state, performance, hint gesti completati; mancano store listing e beta release
Fase 1F      ░░░░░░░░░░    0%  — Supporto Tablet (12 task pianificati)
Fase 2       ████░░░░░░   40%  — i18n IT+EN completo per tutte le feature implementate; manca migrazione stringhe legacy + ES/FR
Fase 3       ██░░░░░░░░   18%  — Firebase Auth + Google Sign-In implementati (3.1 parziale); Firebase Functions deployate su europe-west1 con `suggestMixingRecipe` attivo (3.3 ✅); OCR scan istruzioni con crop manuale (3.2 parziale)
Catalog Tool ░░░░░░░░░░    0%  — tool interno Python (repo separato)
Debito Tecnico ████████░░  80% — DT.1÷10/12/13 risolti; DT.14 rimandato
```

### Schema DB attuale: v10
- v1 → tabelle base (projects, photos, catalog_paints, inventory_paints, recipes, recipe_ingredients, pins)
- v2 → aggiunta `custom_paints`
- v3 → aggiunta `project_paints` (palette del kit)
- v4 → aggiunta `shopping_items` (lista della spesa manuale)
- v5 → aggiunta colonne `brand`, `code`, `paintName`, `hex` a `recipe_ingredients`
- v6 → aggiunta colonne `finish`, `coats` a `recipes`
- v7 → aggiunta colonna `exclude_from_shopping` a `project_paints`
- v8 → aggiunta tabella `project_logs` (devlog progetto)
- v9 → aggiunta colonna `created_at` a `inventory_paints`
- v10 → indici su `pins(photo_id)`, `project_photos(project_id)`, `project_logs(project_id)`, `project_paints(project_id)`

### Prossimi step immediati (ordine esecuzione)

1. 🟡 `1E.7/1E.8` — Store listing Google Play + release beta (richiede Play Console)
2. 🟢 `2.3` — Migrazione stringhe hardcoded residue → `AppL10n`
3. 🟢 `1F` — Supporto Tablet (breakpoint + NavigationRail)

---

## Fase 1G — Navale Statico in Legno

**Obiettivo:** feature specializzate per i modellisti di navi in legno in scala — una nicchia con esigenze molto diverse dal modellismo plastico (nessuna vernice spray, rigging complesso, materiali lignei).

> Prerequisito: Fase 1E stabile. Da pianificare dopo il feedback dei primi utenti navali.

| Task | Priorità | Descrizione | Stato |
|------|----------|-------------|-------|
| 1G.1 | 🔴 Alta | **Checklist sartiame** — lista gerarchica delle manovre (fisse e correnti) con nome tecnico (sartie, paterazzi, griselle, drizze…), materiale del cavo, diametro e stato (da fare / in corso / completato); barra avanzamento per gruppo di manovre. Feature unica, assente in qualsiasi app esistente | ⬜ Da fare |
| 1G.2 | 🟡 Media | **Inventario legni e materiali** — traccia essenza (pero, noce, tiglio, bosso, ciliegio…), sezione in mm (es. 2×4, 3×5), lunghezza residua in cm e fornitore. Strutturalmente simile all'inventario vernici, riusa pattern UI esistenti | ⬜ Da fare |
| 1G.3 | 🟢 Bassa | **Schede componenti/ferramenta** — traccia i pezzi prefabbricati del kit (cannoni, bozzelli, biette, ancore, deadeyes) con quantità totale prevista vs installata. Utile per non perdere pezzi durante lavorazioni lunghe (mesi/anni) | ⬜ Da fare |

### Note di design

- **1G.1 (checklist sartiame)** è la priorità assoluta: il rigging di una nave è composto da decine/centinaia di cavi, lavorati nell'arco di mesi. Nessuno strumento digitale copre questa esigenza in modo strutturato. Struttura dati suggerita: tabella `rigging_lines` con `project_id`, `group` (es. "Manovre fisse albero di maestra"), `name`, `material`, `diameter_mm`, `status`.
- **1G.2 (legni)** si distingue dall'inventario vernici perché l'unità è la lunghezza (cm/mm) non la quantità, e la stessa essenza può avere più sezioni diverse in stock.
- Le tre feature sono indipendenti e possono essere rilasciate in ordine, senza dipendenze tra loro.
- Kit brands di riferimento: Amati, Mantua/Sergal, Corel, Mamoli, Occre, Victory Models, Caldercraft.
