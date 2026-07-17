# PATINA — Devlog di Sviluppo

> Ordinato dal più recente al meno recente.
> Ogni sessione documenta cosa è stato fatto, le decisioni prese e i problemi risolti.

---

## Sessione 2026-07-15 — Fase 1B completa: ordinamento, quantità rapida, equivalenze ΔE

### Cosa è stato fatto

**Schema DB v9:**
- Aggiunta colonna `createdAt` (int, epoch ms, default 0) a `InventoryPaints`
- Migrazione `if (from < 9)` in `app_database.dart`
- Valorizzata in `addInventoryPaint` e `addCustomPaint` (`paints_repository.dart`)

**1B.10 — Ordinamento inventario:**
- `_SortMode` (brand/quantity/dateAdded) + `_sortModeProvider` in `paints_screen.dart`
- Bottone ordina (`_SortBtn`) nella stats row, popup menu ancorato al bottone
- Refactor: estratta `_resolveAll()` da `_resolvedInventoryProvider` per riuso

**1B.11 — Quantità rapida:**
- Long-press sul chip esagonale in griglia → popup compatto con le 4 quantità, senza aprire il detail sheet completo

**1B.12 — Badge conteggio marca:**
- Nuovo `_brandCountsProvider` (riusa `_resolveAll`); chip filtro mostrano `Marca (N)` solo nel tab Inventario (`showCounts`)

**1B.13 — Nome in griglia:**
- Seconda riga di testo (7.5px) sotto il codice nel chip esagonale

**1B.14 — Link rapido lista della spesa:**
- Bottone "Aggiungi alla lista della spesa" nel detail sheet, visibile solo se quantità `low`/`empty`; crea una voce manuale via `ProjectRepository.addShoppingItem`

**1B.15 — Equivalenze tra marche:**
- Sezione "Colori simili in altre marche" nel detail sheet: ΔE CIELAB (riuso `deltaE()` da `lab_mixer.dart`, già usato per le ricette) contro tutti i cataloghi JSON, un solo match per marca (il più vicino), soglia ΔE ≤ 8, max 5 risultati

### Decisioni

- **1B.15 senza tabella di equivalenze curata**: calcolo ΔE on-the-fly sui 13 cataloghi già bundlati, zero dati da mantenere; consistente con l'approccio già validato per le ricette (Fase 1C)
- **Badge conteggio solo su tab Inventario**: i chip marca sono condivisi tra Inventario e Catalogo; mostrare conteggi inventario nel tab Catalogo sarebbe fuorviante
- **`createdAt` con default 0** anziché nullable: le righe esistenti pre-v9 finiscono in fondo nell'ordinamento per data senza richiedere una migrazione dati speciale

### Problemi risolti

- Bug introdotto e corretto in fase di scrittura: `switch` statement in `_sortPaints` senza `break` tra i case (errore di compilazione in Dart) — aggiunto `break;` esplicito su ogni case

### Nota — ambiente di sessione

Flutter/Dart SDK non disponibile in questo ambiente di esecuzione: le modifiche sono state verificate solo a livello sorgente (bilanciamento parentesi, JSON degli `.arb`, coerenza dei riferimenti). **Eseguire `flutter pub run build_runner build --delete-conflicting-outputs` e `flutter analyze` prima del prossimo build**, come da checklist in `CLAUDE.md`.

---

## Sessione 2026-07-09 — Fase 1C completa: Ricette, collegamento progetti, UX inventario

### Cosa è stato fatto

**Schema DB v6:**
- Aggiunta colonna `finish` (nullable text: `opaco`|`satinato`|`lucido`) a `recipes`
- Aggiunta colonna `coats` (nullable int, numero di mani) a `recipes`
- Migrazione `if (from < 6)` in `app_database.dart`
- Campo `technique` mantenuto in DB per retrocompatibilità ma rimosso dall'UI

**Schermata Ricette — completamento Fase 1C:**
- `create_recipe_screen.dart`: sostituito ChoiceChip tecnica con chip finitura (Opaco/Satinato/Lucido) e chip numero di mani (1–4, deselezionabili)
- `recipe_detail_screen.dart`: sezione dettagli mostra finitura e numero di mani (se presenti); tecnica rimossa
- `recipes_screen.dart`: chip in lista mostra finitura invece di tecnica

**Collegamento Ricette ↔ Progetti (1C.7):**
- Approccio senza nuova tabella: la tabella esistente `project_paints` viene riutilizzata con `brand='ricetta'` e `code=recipeId.toString()` come sentinella
- `project_palette_sliver.dart`: tab "Ricette personali" nel bottom sheet "Aggiungi al kit" via `SegmentedButton`; le ricette appaiono con chip CIELAB e nome; selezione multipla → aggiunta alla palette
- Nella palette del progetto, le voci ricetta appaiono con stile distinto (`_RecipePaletteRow`): bordo primary, label "Ricetta personale", tap naviga alla scheda ricetta
- `project_repository.dart`: aggiunto `watchProjectsUsingRecipe(int recipeId)` — query SQL su `project_paints` WHERE brand='ricetta' AND code=?
- `recipe_detail_screen.dart`: provider `_linkedProjectsProvider` ora è `family<List<Project>, int>` basato su `recipeId`; sezione "PROGETTI CHE USANO QUESTA RICETTA" mostra i progetti collegati con tap verso `/projects/:id`

**UX Inventario — quantità dropdown:**
- `paints_screen.dart`: sostituito il selettore 4-bottoni (GestureDetector+AnimatedContainer) con `DropdownButtonFormField<String>` nel detail sheet; ogni voce ha cerchio colorato 10dp + label JetBrains Mono nel colore corrispondente alla quantità

**i18n:**
- `app_it.arb` / `app_en.arb`: aggiunte chiavi `recipeFinishLabel`, `recipeFinishMatte`, `recipeFinishSatin`, `recipeFinishGloss`, `recipeCoatsLabel`, `paletteCatalogTab`, `paletteRecipesTab`, `paletteRecipeLabel`, `recipeLinkedProjectsSection`; aggiornata `paletteAddPaintsTitle` → "Aggiungi al kit" / "Add to kit"
- `l10n_helpers.dart`: aggiunto helper `finishLabel(String? finish)` usato in dettaglio e lista ricette

### Decisioni

- **Nessuna tabella `project_recipes`**: riutilizzare `project_paints` con brand sentinella evita una migrazione aggiuntiva e integra naturalmente nel flusso palette esistente (shopping list, OCR, swipe-to-delete)
- **Colore ricetta calcolato, non fotografato**: CIELAB blending in tempo reale dagli ingredienti; eliminata la necessità di foto risultato, più utile e consistente
- **Tecnica rimossa dall'UI**: i campi tecnica/pressione/primer hanno senso nelle Note; manteniamo finitura (impatta il risultato visivo) e numero di mani (dato operativo rilevante)
- **Picker unificato**: un unico bottom sheet "Aggiungi al kit" con SegmentedButton Catalogo/Ricette evita frammentazione UX

### Problemi risolti

- SQLite non supporta row-value syntax `(a, b) IN (...)` su tutte le versioni — sostituito con OR conditions `(a = ? AND b = ?)`
- `_linkedProjectsProvider` inizialmente basato su brand+code degli ingredienti (cercava progetti con le stesse vernici) — corretto: ora cerca esplicitamente `brand='ricetta' AND code=recipeId`

---

## Sessione 2026-07-08 — Modello business 3 tier, UX vernici, gestione progetti

### Cosa è stato fatto

**Modello di business ridefinito a 3 tier:**
- Free: max 2 progetti attivi, 20 vernici inventario, 5 foto/progetto, 5 ricette
- Standard (1,99 €/mese · 12,99 €/anno): rimuove tutti i limiti quantitativi
- Pro (3,99 €/mese · 24,99 €/anno): tutto Standard + funzionalità AI Fase 3
- Tutta la documentazione aggiornata (vision.md, roadmap.md, features.md, architecture.md, CLAUDE.md)

**Schermata Vernici — 3 miglioramenti UX:**
- Indicatore limite Free nella stats row: contatore `N/20` + barra progresso 3 colori + messaggio testuale nelle ultime 3 posizioni
- Cambio quantità senza chiudere il detail sheet: `_PaintDetailSheet` diventa `StatefulWidget`, animazione `AnimatedContainer` in place
- Sottofiltro per linea nel catalogo: dopo selezione marca appare riga chip secondaria (es. Tamiya → XF / X / TS / LP); `_CatalogEntry` acquisisce campo `line` dal JSON root; reset automatico al cambio marca

**Gestione Progetti — 1A.6 e 1A.7:**
- Nuovo stato `paused` ("In pausa"): badge blueGrey, card con opacità 0.65, NON conta verso limite Free attivi
- `activeStatuses = {'todo', 'in_progress'}` in AppConstants per il conteggio corretto
- Ricerca per nome: search bar inline nell'AppBar (toggle icona lente → TextField autofocus → X chiude)
- Gate Free sul FAB: a 2 progetti attivi mostra lucchetto + PaywallSheet Standard
- Wizard step2: `paused` escluso dalla selezione stato iniziale

### Decisioni
- "In pausa" non conta come attivo → consente di liberare slot senza eliminare il progetto
- La ricerca per nome si combina col filtro stato esistente (AND logico)
- Il sottofiltro linea compare solo se la marca ha ≥ 2 linee

### Problemi risolti
- Nessun bug critico in questa sessione

---

## Sessione 2026-07-07 — Schermata Vernici completa + fix CI

### Cosa è stato fatto

**Schermata Vernici (`/paints`) completa:**
- Griglia honeycomb 4 colonne con chip esagonali (`HexColorChip`), dot quantità sovrapposto
- Vista lista con swipe-to-delete e detail sheet per cambio quantità
- Tab Inventario / Catalogo con TabController; FAB sull'Inventario naviga al Catalogo
- Aggiunta vernice dal Catalogo via bottone `+` inline (rimosso `_AddFromCatalogSheet`)
- Chip marca filtro condivisi tra i due tab; ricerca per codice/nome/marca
- `CustomPaintRef` per evitare collisione tra `CustomPaint` (Drift row) e `CustomPaint` (Flutter widget)

**Fix condivisione lista della spesa:**
- `share_plus 10.1.4`: API corretta è `Share.share(text)`, non `SharePlus.instance.share(ShareParams(...))`
- `ShoppingItem.done` (non `.checked`) — campo Drift corretto

**Chip colore esagonali unificati (`HexColorChip`):**
- Forma flat-top via `ClipPath` + `CustomPainter` per il bordo
- Usato in inventario, catalogo, palette kit, lista della spesa

**Feature:** bottone condivisione lista della spesa (share sheet nativo Android/iOS)

### Decisioni
- FAB Inventario → naviga al Catalogo (non apre sheet separato): percorso più diretto
- Chip esagonali come standard per tutti i colori vernice nell'app

### Problemi risolti
- CI rotto per `ShareParams` non trovato → downgrade API share_plus
- CI rotto per `item.checked` → corretto in `item.done`

---

## Sessione 2026-07-06 — Scheda progetto, modifica, palette kit

### Cosa è stato fatto

- Modifica progetto dal menu `⋮`: wizard in modalità edit (pre-popola campi, chiama `update`)
- Brand/scala spostati in sovraimpressione sull'header collassabile (overlay sul gradiente)
- Card archivio: foto copertina 80×80, badge stato colorato, filter bar chip per stato
- Fix galleria foto e cancellazione vernici nel dettaglio progetto

### Decisioni
- `CreateProjectWizard(project: ...)` riusa lo stesso wizard per creazione e modifica
- Header collassabile con `SliverAppBar` + parallax: foto visibile → AppBar compatta

---

## Sessione 2026-07-05 — OCR scan istruzioni, lista della spesa, UX palette

### Cosa è stato fatto

- OCR scan istruzioni kit: crop manuale foto → pre-processing in scala di grigi → regex per codici vernice
- Fix regex OCR per famiglie Tamiya e Gunze Aqueous (limite cifre)
- Spunte vernici automatiche nella lista della spesa
- UX palette kit: label, icone e feedback tattile migliorati
- Fix CI: disable R8 minification (impediva output APK), fix path APK

### Decisioni
- OCR come funzionalità placeholder — in Fase 3 sostituita da Claude Vision (AI Pro)
- Pre-processing grigio migliora l'accuratezza del riconoscimento testo

### Problemi risolti
- R8 minification silenziava errori e impediva la generazione dell'APK
- Regex OCR troppo permissiva catturava numeri non validi

---

## Sessione 2026-07-04 — Shopping list, pin su foto, onboarding

### Cosa è stato fatto

- Lista della spesa: sezione automatica (vernici palette kit non in inventario) + voci manuali (DB v4, `shopping_items`)
- Pin su foto: `InteractiveViewer` + overlay pin colore/lavorazione
- Onboarding: schermata primo avvio, richiesta permessi camera/storage, progetto demo
- Schema DB v4: aggiunta tabella `shopping_items`

### Decisioni
- Lista spesa automatica via SQL join (`project_paints` ∖ `inventory_paints`): reattiva, sempre aggiornata
- Voci manuali persistite in DB separato con `done` booleano

---

## Sessione 2026-07-03 — Galleria foto, ricette, DB v3

### Cosa è stato fatto

- Galleria foto progetto: camera + selezione da galleria, miniature 80×80, viewer fullscreen (InteractiveViewer), elimina dall'AppBar
- Palette del kit (`project_paints`): aggiunta/rimozione vernici per progetto, badge "In magazzino"
- Schema DB v3: aggiunta tabella `project_paints`
- Placeholder schermate Ricette e Impostazioni

---

## Sessione 2026-06-25 — Scheda progetto, wizard creazione, DB v2

### Cosa è stato fatto

- Wizard creazione progetto 3 step: nome/categoria/scala → stato iniziale → foto copertina
- Scheda progetto (`/projects/:id`): `SliverAppBar` collassabile con foto copertina, sezioni note e galleria
- `custom_paints` DB v2: vernici inserite manualmente dall'utente
- Navigazione Go Router con ShellRoute a 4 tab

---

## Sessione 2026-06-24 — Fondamenta (Fase 0)

### Cosa è stato fatto

- Inizializzazione progetto Flutter: struttura cartelle, `pubspec.yaml`, dipendenze
- Setup database Drift: schema v1 con tabelle `projects`, `photos`, `catalog_paints`, `inventory_paints`, `recipes`, `recipe_ingredients`, `pins`
- 13 cataloghi vernici JSON bundled (~1.220 colori): Tamiya XF/X/LP/TS, Vallejo Model Color/Air, Citadel Base, Gunze Mr. Color/Aqueous/Metal, Humbrol Enamel, LifeColor UA/LC
- Design system Ottone: accent `#D99B3E` (ottone), secondario `#3FA8A0` (verderame), dark-first
- Font: JetBrains Mono (display/titoli) + IBM Plex Sans (corpo)
- Icone custom bottom nav con `CustomPainter` (esagoni)
- Icona launcher Android: cluster di 7 esagoni
- CI/CD GitHub Actions: build APK debug e release su ogni push
- Documentazione iniziale: vision.md, architecture.md, features.md, roadmap.md

### Decisioni fondanti
- Flutter cross-platform per coprire Android e iOS con un unico codebase
- Riverpod scritto a mano (no codegen `@riverpod`) per semplicità e controllo
- Cataloghi vernici come JSON bundled (no rete, no DB precaricato) — letti on-demand da `rootBundle`
- Chip colore a forma esagonale come elemento visivo distintivo dell'app

### Problemi risolti
- `compileSdk 35` necessario per `sqlite3_flutter_libs`
- Rimozione `riverpod_generator` e `custom_lint` incompatibili con Flutter 3.22
- Struttura Android mancante: aggiunta `MainActivity`, `Gradle`, risorse
