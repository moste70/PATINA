# Patina — Specifiche Funzionalità

## Fase 1 — MVP

---

### 1. Gestione Progetti

#### 1.1 Archivio Progetti
Schermata principale dell'app (`/projects`). Mostra tutti i modelli con
una panoramica visiva dello stato di avanzamento.

**Contenuto di ogni progetto:**
- Nome del modello
- Marca e scala (es. Tamiya 1/35, Revell 1/72)
- Categoria: Carro Armato · Aereo · Figura · Nave · Diorama · Altro
- Foto di copertina (scattata o importata dalla galleria)
- Stato: `Idea` · `In costruzione` · `In pittura` · `Completato` · `In pausa`
- Percentuale di avanzamento (0–100, inserita manualmente)
- Data di inizio e ultima modifica
- Note libere

**Funzionalità:**
- Creazione nuovo progetto con wizard guidato
- Modifica di tutti i campi in qualsiasi momento
- Archiviazione progetti completati (rimangono consultabili)
- Eliminazione con conferma
- Ricerca per nome, categoria o stato
- Ordinamento per: ultima modifica, data inizio, nome, stato
- Vista griglia e vista lista (toggle)

#### 1.2 Scheda Progetto (`/projects/:id`)
Vista scorrevole che raccoglie tutte le informazioni di un progetto.

**Sezioni:**
- Header con foto, nome, stato e percentuale avanzamento
- Galleria foto (più immagini in varie fasi)
- Fasi di lavorazione (vedi 1.3)
- Vernici usate nel progetto (collegate dall'inventario)
- Ricette usate nel progetto
- Note e diario di lavorazione
- Pin su foto (vedi sezione 3)

#### 1.3 Fasi di Lavorazione
Fasi sequenziali che l'utente spunta man mano che procede.
Predefinite da `AppConstants.defaultPhases`, personalizzabili.

**Fasi predefinite (10):**
1. Preparazione — pulizia, rimozione canali, controllo parti
2. Assemblaggio sub-gruppi
3. Assemblaggio finale
4. Stuccatura e correzioni
5. Primer
6. Pittura base
7. Ombreggiatura e luci — shading/highlighting
8. Decalcomanie
9. Invecchiamento — weathering
10. Finitura — vernice opaca/lucida/satinata

**Funzionalità:**
- Spunta fase come completata con data
- Note specifiche per ogni fase
- Foto collegate a ogni fase
- Aggiunta fasi personalizzate (`is_custom = 1`)
- Riordinamento con drag & drop

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
- Fase di lavorazione di riferimento

#### 3.2 Pin Lavorazione
Documenta la tecnica applicata in un punto specifico del modello.

**Dati:**
- Coordinate X/Y
- Tipo lavorazione (es. wash, chipping, filter, pigmenti, stucco, incisione)
- Prodotto usato (testo libero)
- Note e fase di riferimento

**Funzionalità comuni:**
- Zoom e pan sulla foto per posizionamento preciso
- Spostamento pin con drag
- Eliminazione pin
- Toggle visibilità (mostra/nascondi tutti)
- Filtro per tipo: solo colore / solo lavorazione
- Vista lista di tutti i pin di una foto

---

## Aree da Progettare (Buchi)

Funzionalità necessarie ma non ancora specificate. Richiedono design prima
di poter essere inserite nella roadmap.

| Area | Note |
|------|------|
| **Profilo / Impostazioni** | Schermata `/settings` attualmente placeholder — da definire contenuto (tema, lingua, backup, info app) |
| **Paywall** | Modello di monetizzazione per Fase 2: acquisto crediti, subscription o one-time — da decidere |
| **Editor Ricetta** | UX dettagliata per la creazione/modifica ricetta con ingredienti e proporzioni |
| **Creazione Pin Lavorazione** | Flusso di inserimento pin tecnica: selezione tipo, prodotto, collegamento a fase |
| **Visualizzatore Foto** | Viewer full-screen con zoom, pan, overlay pin e controlli — da specificare le interazioni |
| **Light Mode** | Adattamenti UI per il tema chiaro (palette definita, da verificare su tutti i componenti) |
| **Autenticazione** | Necessaria per Fase 2 (sync cloud) — provider, flusso login/registrazione, gestione token |
| **Stati di Sistema** | Loading, empty state, errori di rete, permessi negati — pattern da definire e applicare uniformemente |
| **Notifiche** | Promemoria lavorazione, aggiornamenti catalogo — da decidere se e quando implementare |

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
