# Patina — Specifiche Funzionalità

## Fase 1 — MVP

---

### 1. Gestione Progetti

#### 1.0 Creazione Nuovo Progetto — Wizard (`/projects/new`)

> **Spec 1A-DOC.1** — Flusso completo di creazione progetto

##### Trigger di apertura
- Bottone FAB `+` nella schermata Archivio Progetti
- Il wizard si apre come bottom sheet a schermo intero (o pagina modale)

##### Struttura del Wizard — 3 Step

**Indicatore di progresso:** barra lineare in cima con 3 segmenti. Step corrente evidenziato in `primary` (#7CB87C), completati in `primary` solido, futuri in `outline`.

---

**Step 1 — Il Kit**

Campi:

| Campo | Tipo | Obbligatorio | Note |
|-------|------|:---:|-------|
| Nome modello | TextField | ✅ | es. "Tiger I Ausf. E" — max 80 caratteri |
| Marca kit | TextField | ❌ | es. "Tamiya", "Revell", "Hasegawa" — testo libero |
| Scala | TextField | ❌ | es. "1/35", "1/72" — testo libero con suggerimenti chip: 1/35 · 1/48 · 1/72 · 1/100 · 1/144 · Altra |
| Categoria | Chip selector | ✅ | Selezione singola: Carro Armato · Aereo · Figura · Nave · Diorama · Altro |

Comportamento:
- Il campo **Nome** riceve il focus automaticamente all'apertura (tastiera aperta)
- I **chip scala** sono scorrevoli orizzontalmente, toccandone uno compila il campo
- La **categoria** mostra icone + etichette, selezione con tap, chip selezionato in `primary`
- Bottone **Avanti** attivo solo se Nome e Categoria sono compilati

---

**Step 2 — Stato Iniziale**

Campi:

| Campo | Tipo | Obbligatorio | Note |
|-------|------|:---:|-------|
| Stato | Chip selector | ✅ | Default: `Da iniziare`. Opzioni: Da iniziare · In corso · Completato |
| Note iniziali | TextField multiline | ❌ | Placeholder: "Aggiungi note, riferimenti, obiettivi…" — max 500 caratteri |

Comportamento:

---

**Step 3 — Foto Copertina**

| Campo | Tipo | Obbligatorio | Note |
|-------|------|:---:|-------|
| Foto copertina | Image picker | ❌ | Da galleria o camera |

Layout:
- Area centrale 1:1 con bordo tratteggiato `outline`, icona foto + testo "Aggiungi copertina"
- Dopo selezione: preview dell'immagine con bottone `×` per rimuoverla
- Due bottoni sotto: `Fotocamera` (icon: `camera_alt`) e `Galleria` (icon: `photo_library`)
- Testo secondario: "Puoi aggiungere o cambiare la foto in qualsiasi momento"

---

##### Navigazione del Wizard

| Azione | Comportamento |
|--------|--------------|
| `Avanti` (step 1 → 2) | Valida Nome + Categoria, poi avanza |
| `Avanti` (step 2 → 3) | Avanza sempre (step 2 non ha campi obbligatori) |
| `Crea Progetto` (step 3) | Salva e naviga a `/projects/:id` del nuovo progetto |
| `Indietro` | Torna allo step precedente, dati preservati |
| `×` (chiudi) | Dialog conferma se dati inseriti — "Vuoi scartare il progetto?" con azioni Annulla / Scarta |
| Swipe down | Stessa logica del `×` |

##### Salvataggio (logica Dart)
```
Projects(
  name: nome.trim(),
  brand: marca.trim() oppure null,
  scale: scala.trim() oppure null,
  category: categoriaSelezionata,        // 'tank'|'aircraft'|...
  coverPhoto: pathFoto oppure null,
  status: statoSelezionato,              // 'todo'|'in_progress'|'completed'
  notes: note.trim() oppure null,
  createdAt: DateTime.now().millisecondsSinceEpoch,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
)
```

##### Validazioni
- Nome vuoto o solo spazi → bottone Avanti disabilitato + bordo campo rosso al tap
- Nome > 80 caratteri → contatore caratteri visibile, input bloccato a 80
- Foto > 10MB → toast "Immagine troppo grande, scegli un'altra"

##### Stati di errore
- Permesso camera negato → bottom sheet con spiegazione + link alle impostazioni Android
- Permesso galleria negato → stessa logica
- Errore salvataggio DB → snackbar "Errore nel salvataggio, riprova" con retry

---

#### 1.0b Onboarding — Primo Avvio

> **Spec 1A-DOC.3** — Flusso primo avvio, permessi, empty state

##### Trigger

L'onboarding viene mostrato **una sola volta**, al primo avvio dell'app dopo l'installazione.
Un flag `onboarding_completed` in `shared_preferences` controlla se mostrarlo.
Se il flag è `true`, l'app apre direttamente l'Archivio Progetti.

---

##### Struttura — 4 Schermate

**Indicatore di progresso:** punti in fondo (••••), quello attivo in `primary`, animazione laterale al cambio pagina. Swipe orizzontale abilitato in avanti e indietro (tranne dalla schermata 1 verso sinistra).

---

**Schermata 1 — Benvenuto**

Layout verticale centrato:
- Logo Patina (`PatinaMark`, 120dp, colore `primary`)
- Titolo: "Benvenuto in Patina" (display, 28sp)
- Sottotitolo: "Il taccuino digitale per i tuoi modelli in scala." (body, 16sp, `onSurface`)
- Descrizione: "Tutto offline, tutto tuo." (body, 14sp, `onSurface` dimmed)
- Bottone primario `Inizia` in fondo (larghezza piena)

---

**Schermata 2 — Cosa puoi fare**

Lista verticale di 4 feature card. Ogni card:

| Icona | Titolo | Descrizione |
|-------|--------|-------------|
| `view_module` | Progetti | Tieni traccia di ogni modello — stato, foto e note di lavorazione |
| `palette` | Vernici | Il tuo inventario personale con chip colore esagonali e catalogo offline |
| `science` | Ricette | Salva le tue miscele con proporzioni esatte e foto del risultato |
| `push_pin` | Pin su foto | Documenta colori e tecniche direttamente sulle foto del modello |

Layout card: icona in cerchio `primary` (36dp) a sinistra · titolo (label, 600) + descrizione (body small, `onSurface`) a destra. Sfondo `surfaceVariant`, angoli 12dp.

Bottone `Avanti` in fondo (larghezza piena).

---

**Schermata 3 — Permessi**

Richiesta permessi necessari all'app.

| Permesso | Icona | Titolo | Descrizione |
|----------|-------|--------|-------------|
| Camera | `camera_alt` | Fotocamera | Scatta foto dei tuoi modelli durante la lavorazione |
| Galleria / Storage | `photo_library` | Foto e file | Importa immagini dalla galleria e salva i tuoi lavori |

Layout:
- Titolo: "Patina ha bisogno di accedere a:" (title, 18sp)
- 2 card con icona `primary` + titolo + descrizione + badge stato a destra
- Badge stato: `Concesso ✓` (colore `successo` #2F8F57) · `In attesa` (`onSurface` dimmed) · `Negato` (colore `errore` #C8503B)
- Bottone primario: `Concedi permessi` se almeno uno non concesso · `Continua` se entrambi concessi
- Link testo: "Salta per ora — puoi abilitarli in Impostazioni → App → Patina"

Comportamento:
- Al tap `Concedi permessi`: richiede camera e galleria in sequenza, aggiorna i badge in tempo reale
- Se un permesso viene negato: badge `Negato`, la schermata resta mostrando il risultato
- Non bloccante: si può proseguire con `Salta per ora` anche con permessi negati
- Se entrambi già concessi (reinstallazione): bottone è `Continua` senza richiedere nulla

---

**Schermata 4 — Pronto**

Layout verticale centrato:
- Icona ✓ in cerchio `primary` (100dp)
- Titolo: "Sei pronto!" (display, 28sp)
- Testo: "Crea il tuo primo progetto e inizia a documentare il tuo lavoro." (body, 16sp)
- Bottone primario `Inizia` (larghezza piena) → segna flag + naviga a `/projects`
- Nessun link secondario (azione unica)

---

##### Navigazione

| Azione | Comportamento |
|--------|--------------|
| `Inizia` (schermata 1) | Avanza alla schermata 2 |
| `Avanti` (schermata 2) | Avanza alla schermata 3 |
| `Concedi permessi` / `Continua` (schermata 3) | Richiede permessi poi avanza alla schermata 4 |
| `Salta per ora` (schermata 3) | Avanza alla schermata 4 senza richiedere permessi |
| `Inizia` (schermata 4) | Segna `onboarding_completed = true`, naviga a `/projects` |
| Swipe avanti | Equivale al bottone primario della schermata corrente |
| Swipe indietro | Torna alla schermata precedente (non dalla 1) |
| Back Android (schermata 1) | Nessun effetto |
| Back Android (schermate 2–4) | Torna alla schermata precedente |

Dopo aver impostato `onboarding_completed = true`, non viene mai più mostrato.

---

##### Empty State Archivio Progetti

Quando l'onboarding è completato ma non ci sono progetti, l'Archivio Progetti mostra un empty state invece della lista vuota:

- Illustrazione centrale (icona categoria `other`, tratteggiata, 80dp, `onSurface` dimmed)
- Testo: "Nessun progetto ancora" (Inter 600, 18sp)
- Sottotesto: "Inizia aggiungendo il tuo primo modello in scala."
- Bottone `+ Nuovo progetto` (primario, stesso effetto del FAB)

Il FAB `+` è sempre visibile anche sull'empty state.

---

#### 1.1 Archivio Progetti (`/projects`)
Schermata principale dell'app. Mostra tutti i modelli con una panoramica visiva.

**Contenuto di ogni card progetto:**
- Foto di copertina (o placeholder con icona categoria)
- Nome del modello
- Categoria + scala (es. "Carro Armato · 1/35")
- Chip stato colorato (`Da iniziare` grigio · `In corso` arancio · `Completato` verde)
- Data ultima modifica (es. "3 giorni fa")

**Funzionalità:**
- FAB `+` per aprire il wizard creazione
- Modifica di tutti i campi dalla scheda progetto
- Archiviazione progetti completati (rimangono consultabili)
- Eliminazione con dialog di conferma
- Ricerca per nome, categoria o stato
- Ordinamento per: ultima modifica, data inizio, nome, stato
- Toggle vista griglia (2 colonne) / lista

#### 1.2 Scheda Principale Progetto (`/projects/:id`)

> **Spec 1A-DOC.2** — Layout completo e comportamenti della scheda progetto

##### Struttura generale
Pagina con `CustomScrollView` + `SliverAppBar` collassabile. Scorrendo verso il basso la foto di copertina si riduce fino a diventare AppBar compatta con nome progetto e azioni.

---

##### Sezione 1 — Header (SliverAppBar)

**Espanso** (foto visibile, altezza ~260dp):
- Foto di copertina a schermo pieno con gradiente scuro in basso
- In overlay sul gradiente: chip stato colorato (in alto a sinistra) + menu `⋮` (in alto a destra)
- In basso sull'overlay: nome progetto (DM Serif Display, 24sp), marca + scala in grigio

**Collassato** (solo AppBar, altezza standard):
- Back arrow + nome progetto (Inter 600, troncato) + menu `⋮`
- La foto scompare, sfondo `surface`

**Chip stato — colori:**
| Stato | Colore sfondo | Testo |
|-------|--------------|-------|
| Da iniziare | `outline` (grigio) | `onSurface` |
| In corso | `#C87A20` (arancio) | bianco |
| Completato | `primary` (#7CB87C) | nero |

**Menu `⋮` azioni:**
- Modifica progetto → apre wizard in modalità edit (campi pre-compilati)
- Archivia / Riattiva
- Elimina → dialog conferma "Elimina progetto? L'azione è irreversibile."

---

##### Sezione 2 — Galleria Foto

Griglia orizzontale scorrevole di miniature 80×80dp con angoli arrotondati.
Ultima cella è il bottone `+` con icona fotocamera.

**Tap su miniatura:**
- Apre viewer foto a schermo intero (InteractiveViewer, zoom/pan)
- Se la foto ha pin → mostra overlay pin
- Swipe orizzontale per navigare tra le foto del progetto

**Tap su `+`:**
- Bottom sheet: Fotocamera · Galleria · Annulla
- Foto salvata nella cartella privata dell'app (non nella galleria pubblica)

**Long press su miniatura:**
- Modalità selezione multipla → azioni: elimina

---

##### Sezione 4 — Vernici Usate

Lista compatta delle vernici dell'inventario collegate a questo progetto
(tramite i pin di tipo `color` sulla foto).

**Struttura riga:**
```
[chip hex esagonale] Vallejo 70.950 · Black           [→ pin]
```
- Chip esagonale con colore reale
- Marca + codice + nome
- Contatore pin che usano questa vernice (`→ 3 pin`)
- Tap: apre scheda vernice nell'inventario

**Empty state:** "Nessuna vernice collegata — aggiungi pin colore alle foto"

---

##### Sezione 5 — Note Progetto

Campo testo espandibile. In visualizzazione mostra max 4 righe con bottone "Mostra tutto".
Tap attiva editing inline (diventa TextField multiline con autofocus).
Salvataggio automatico on blur (nessun bottone Salva esplicito).

Placeholder: "Aggiungi note, riferimenti, obiettivi del progetto…"

---

##### Sezione 6 — Info Progetto

Row compatta con metadati:

```
Creato il 01 giu 2026  ·  Ultima modifica 3 giorni fa
```

---

##### Comportamenti globali

| Evento | Comportamento |
|--------|--------------|
| Pull to refresh | Ricarica dati dal DB (per futura sync cloud) |
| Back navigation | Torna all'archivio (`/projects`) |
| Empty state foto | Illustrazione + testo "Aggiungi la prima foto del modello" + bottone |

---


### 2. Gestione Vernici

#### 2.1 Inventario Personale (`/paints`)
Raccoglie tutte le vernici che l'utente possiede fisicamente.

**Dati di ogni vernice:**
- Marca (Vallejo / Citadel / Tamiya — Fase 1)
- Linea/serie (es. Model Color, Base, XF)
- Codice colore (es. 70.950, XF-1)
- Nome colore (es. Black, Flat Black)
- HEX reale da catalogo + chip esagonale visualizzato
- Quantità: `Piena` · `Metà` · `Quasi finita` · `Finita`
- Note personali
- Data acquisto (opzionale)

**Funzionalità:**
- Aggiunta da catalogo (cerca per codice o nome)
- Aggiunta manuale per vernici non in catalogo (marca e codice obbligatori)
- Filtro per marca, linea, quantità
- Vista griglia chip esagonali / vista lista dettagliata (toggle)
- Modifica quantità con tap rapido
- Lista della spesa automatica (vernici `low` o `empty`)

#### 2.2 Cataloghi Marche
Database offline integrato, caricato in SQLite al primo avvio tramite `initializeCatalogs()`.

**Cataloghi Fase 1:**

| Marca | Linea | Colori |
|-------|-------|--------|
| Vallejo | Model Color | 30 |
| Citadel | Base | 20 |
| Tamiya | XF (opache) | 28 |

**Funzionalità:**
- Sfoglia per marca e linea
- Ricerca per codice o nome
- Chip esagonale con colore reale
- Aggiunta diretta all'inventario
- Equivalenze tra marche (quando disponibile)

**Aggiornamento cataloghi:**

I cataloghi sono bundled nell'app (Fase 1) e aggiornati con le nuove versioni su Google Play.
Le vernici inserite manualmente dall'utente (`custom_paints`) sono identificate da `brand+code`
come chiave naturale. Al momento dell'aggiornamento, se un colore manuale coincide con uno
nel nuovo catalogo ufficiale, viene rimosso automaticamente e sostituito dal dato verificato.
I dati dell'inventario personale (`inventory_paints`) non vengono mai persi durante gli aggiornamenti
perché referenziano `brand+code` e non l'ID interno del catalogo.

#### 2.3 Gestione Ricette (`/recipes`)
Miscele personalizzate salvate con proporzioni esatte.

**Dati di ogni ricetta:**
- Nome (es. "Grigio Panzer invecchiato")
- Foto del risultato
- Lista ingredienti: vernice + percentuale
- Tecnica: `Pennello` · `Aerografo` · `Spugnatura`
- Diluizione consigliata
- Superficie: plastica, metallo, resina
- Note e tag liberi
- Collegamento ai progetti in cui è stata usata

**Funzionalità:**
- Creazione con selezione vernici da inventario o catalogo
- Proporzioni via slider o valore numerico
- Foto dalla camera o galleria
- Ricerca per nome o tag
- Duplica ricetta come base per varianti
- Scala automatica delle quantità

#### 2.4 Assistenza alla Miscelazione

**Algoritmo interno Fase 1 (gratuito):**
- Input: HEX del colore target
- Output: 2–3 ricette suggerite con proporzioni e indicatore di distanza Delta-E
- Lavora sulle vernici dell'inventario personale
- Calcolo in spazio CIELAB, implementato in Dart puro

**AI con Claude Fase 2 (a crediti):**
- Descrizione in linguaggio naturale del colore voluto
- Ricette complesse con considerazione di tecnica e materiale
- Abbinamenti cromatici per ombreggiature e luci

---

### 3. Pin su Foto

I pin sono accessibili dalla scheda progetto, selezionando una foto dalla galleria.

#### 3.1 Pin Colore
Documenta quale vernice o ricetta è stata applicata in un punto della foto.

**Dati:**
- Coordinate X/Y (valori 0.0–1.0 relativi alla foto)
- Vernice o ricetta associata
- Note (es. "due mani, diluita al 30%")
- Tecnica applicata

#### 3.2 Pin Lavorazione
Documenta la tecnica applicata in un punto specifico del modello.

**Dati:**
- Coordinate X/Y
- Tipo lavorazione (es. wash, chipping, filter, pigmenti, stucco, incisione)
- Prodotto usato (testo libero)
- Note

**Funzionalità comuni:**
- Zoom e pan sulla foto per posizionamento preciso
- Spostamento pin con drag
- Eliminazione pin
- Toggle visibilità (mostra/nascondi tutti)
- Filtro per tipo: solo colore / solo lavorazione
- Vista lista di tutti i pin di una foto

---

## Stato Implementazione Attuale

| Schermata | Percorso | Stato |
|-----------|----------|-------|
| Onboarding | `/onboarding` | ✅ Implementato — 4 schermate (Benvenuto, Funzionalità, Permessi, Pronto) |
| Archivio Progetti | `/projects` | ✅ Implementato — lista, empty state, FAB, navigazione alla scheda |
| Wizard Nuovo Progetto | `/projects/new` (modale) | ✅ Implementato — 3 step (Kit, Stato, Foto) |
| Scheda Progetto | `/projects/:id` | ✅ Implementato — header collassabile, galleria (placeholder), note, info |
| Vernici / Inventario | `/paints` | ⬜ Placeholder |
| Ricette | `/recipes` | ⬜ Placeholder |
| Impostazioni | `/settings` | ⬜ Placeholder |

---

## Aree da Progettare (Buchi)

Funzionalità necessarie ma non ancora specificate. Richiedono design prima
di poter essere inserite nella roadmap.

| Area | Note |
|------|------|
| **Profilo / Impostazioni** | `/settings` placeholder — contenuto da definire: tema dark/light toggle, lingua, backup/restore, info app, versione |
| **Paywall** | Modello monetizzazione Fase 2: crediti, subscription o one-time — da decidere prima dell'implementazione AI |
| **Editor Ricetta** | UX creazione/modifica ricetta: selezione vernici, slider proporzioni, preview colore risultante |
| **Creazione Pin Lavorazione** | Flusso inserimento pin tecnica: selezione tipo lavorazione, prodotto usato, collegamento a fase |
| **Visualizzatore Foto con Pin** | Viewer full-screen: zoom/pan via InteractiveViewer, overlay pin su canvas, controlli visibilità |
| **Light Mode** | Palette light definita in `PatinaColors` (Design System Ottone) — da verificare su tutti i componenti |
| **Autenticazione** | Necessaria per Fase 3 — provider OAuth, flusso login/registrazione, gestione token |
| **Stati di Sistema** | Pattern uniforme da definire: loading spinner, empty state con CTA, errori di rete, permessi negati |
| **Notifiche** | Promemoria lavorazione, aggiornamenti catalogo — da decidere se e quando implementare |
| **Catalogo Vernici** | Vista sfoglia separata dall'inventario: raggruppamento per marca/linea, chip colore, aggiunta rapida |

---

## Fase 2 — Funzionalità Avanzate

> Pianificate in dettaglio al completamento della Fase 1.

### 4. Ricerca da Foto (AI)

L'utente importa una foto — da internet, da una scatola di montaggio, da una rivista o scattata dal vivo — e seleziona con un mirino l'area esatta da analizzare. Claude Vision identifica il colore nel contesto visivo e suggerisce vernici dal catalogo. Funzionalità a crediti.

#### Flusso

```
Importa foto (galleria / fotocamera / URL)
        ↓
Viewer con zoom e pan (InteractiveViewer)
        ↓
Posiziona il mirino (cerchio o rettangolo)
sull'area di colore da rilevare
        ↓
Claude Vision analizza colore + contesto visivo
(tipo di modello, periodo storico, tecnica)
        ↓
Risultato: 3-5 candidati con marca · codice · HEX
e note contestuali (es. "probabile base coat,
il top coat potrebbe essere più chiaro")
        ↓
Utente sceglie → aggiunge a inventario o ricetta
```

#### Sorgenti foto e affidabilità

Le due sorgenti principali hanno affidabilità molto diverse:

| Sorgente | Errore Delta-E tipico | Note |
|----------|----------------------|------|
| **Foto da internet / box art / riviste** | 3-8 unità | Luce da studio controllata, alta risoluzione, superficie asciutta — risultati buoni |
| **Foto dal vivo (fotocamera)** | 10-20 unità | Luce ambiente variabile, WB automatico, riflessi — risultati orientativi |

**Fattori che peggiorano la rilevazione da fotocamera:**

| Fattore | Effetto |
|---------|---------|
| Illuminazione calda/fredda/mista | Sposta la tinta verso giallo/arancio o blu |
| White balance automatico | Compensa in modo imprevedibile |
| Superficie lucida o satinata | Riflessi alterano il colore percepito |
| Ombre sul modello | Stessa vernice, Delta-E fino a 30-50 tra zona in luce e in ombra |
| Vernice bagnata | Differenza fino al 15-20% rispetto all'asciutto |
| Compressione JPEG | Artefatti cromatici sulle tinte piatte |

#### Come viene gestito in Patina

- Il risultato è sempre presentato come **suggerimento orientativo**, mai come risposta definitiva
- Claude Vision restituisce sempre **3-5 candidati** con indicatore di confidenza
- Claude ragiona sul **contesto visivo** (tipo di veicolo, periodo storico, schema mimetico) e sulle vernici nell'inventario dell'utente — non solo sul campione cromatico isolato
- Per foto dal vivo, l'UI mostra un tip con le condizioni ottimali:
  - Luce naturale diffusa, niente flash
  - Superficie asciutta e polimerizzata
  - Distanza 10-15 cm, inquadratura perpendicolare
  - Evitare zone in ombra o in piena luce diretta
- Il **mirino di selezione** permette di isolare l'area precisa da analizzare, escludendo ombre, highlight e zone di transizione che altererebbero il risultato

### 5. Miscelazione AI Avanzata
- Input in linguaggio naturale
- Suggerimento con più opzioni e spiegazione delle differenze
- Considera materiale, luce ambiente, tecnica applicativa
- Funzionalità a crediti

### 6. Espansione Cataloghi
Vallejo Game Color / Air / Panzer Aces, Citadel Layer / Shade / Contrast,
Tamiya X / LP, AK Interactive, Ammo by Mig Jimenez, Humbrol, Mr. Color (GSI Creos)

### 7. Sincronizzazione Cloud
- Backup automatico con account utente
- Accesso da più dispositivi
- Condivisione ricette con la community
