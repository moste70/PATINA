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
| Avanzamento | Slider 0–100 | ❌ | Visibile solo se stato ≠ `Idea`. Default 0. Label: "X% completato" |
| Note iniziali | TextField multiline | ❌ | Placeholder: "Aggiungi note, riferimenti, obiettivi…" — max 500 caratteri |

Comportamento:
- Lo slider appare/scompare con animazione al cambio stato
- Lo stato `Completato` imposta automaticamente avanzamento a 100
- Lo stato `Da iniziare` imposta automaticamente avanzamento a 0

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
  progress: avanzamento,                 // 0-100
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

#### 1.1 Archivio Progetti (`/projects`)
Schermata principale dell'app. Mostra tutti i modelli con una panoramica visiva.

**Contenuto di ogni card progetto:**
- Foto di copertina (o placeholder con icona categoria)
- Nome del modello
- Categoria + scala (es. "Carro Armato · 1/35")
- Chip stato colorato (`Da iniziare` grigio · `In corso` arancio · `Completato` verde)
- Barra avanzamento 0–100%
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
- Barra avanzamento lineare sottile con percentuale a destra (`X%`)

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
- Modifica avanzamento → bottom sheet con slider 0–100
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
| Avanzamento manuale | Aggiornabile da menu `⋮` → "Modifica avanzamento" con slider 0–100 |
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
- Aggiunta manuale per vernici non in catalogo
- Filtro per marca, linea, quantità
- Vista griglia chip esagonali / vista lista dettagliata (toggle)
- Modifica quantità con tap rapido
- Lista della spesa automatica (vernici `low` o `empty`)

#### 2.2 Cataloghi Marche
Database offline integrato, caricato in SQLite al primo avvio.

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

> Tutte le schermate sono `PlaceholderScreen` — mostra icona + titolo + "In sviluppo".
> L'AppBar mostra l'icona brand Patina (esagono custom painter) e un bottone cerca non funzionale.
> La navigazione tra i 4 tab è funzionante tramite Go Router.

| Schermata | Percorso | Stato |
|-----------|----------|-------|
| Archivio Progetti | `/projects` | Placeholder |
| Scheda Progetto | `/projects/:id` | Placeholder |
| Vernici / Inventario | `/paints` | Placeholder |
| Ricette | `/recipes` | Placeholder |
| Impostazioni | `/settings` | Placeholder |

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
| **Light Mode** | Palette light definita in `PatinaColors` ma da verificare su tutti i componenti — alcuni usano `onBackground` deprecated |
| **Autenticazione** | Necessaria per Fase 2 — provider OAuth, flusso login/registrazione, gestione token |
| **Stati di Sistema** | Loading spinner, empty state con CTA, errori di rete, permessi negati — pattern uniforme da definire |
| **Notifiche** | Promemoria lavorazione, aggiornamenti catalogo — da decidere se e quando implementare |
| **Wizard Nuovo Progetto** | Flusso multi-step creazione: nome → categoria/scala → foto cover → stato iniziale |
| **Catalogo Vernici** | Vista sfoglia separata dall'inventario: raggruppamento per marca/linea, chip colore, aggiunta rapida |

---

## Fase 2 — Funzionalità Avanzate

> Pianificate in dettaglio al completamento della Fase 1.

### 4. Ricerca da Foto (AI)
- Scatta o importa una foto di un colore reale
- Claude Vision analizza e suggerisce vernici dal catalogo e possibili ricette
- Funzionalità a crediti

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
