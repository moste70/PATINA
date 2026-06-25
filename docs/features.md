# Patina — Specifiche Funzionalità

## Fase 1 — MVP

---

### 1. Gestione Progetti

#### 1.1 Archivio Progetti
L'archivio è la schermata principale dell'app. Mostra tutti i modelli inseriti
dall'utente con una panoramica visiva immediata dello stato di avanzamento.

**Contenuto di ogni progetto:**
- Nome del modello
- Marca e scala (es. Tamiya 1/35, Revell 1/72)
- Categoria (carro armato, aereo, figura, nave, diorama, altro)
- Foto di copertina (scattata o importata dalla galleria)
- Stato: `Idea` · `In costruzione` · `In pittura` · `Completato` · `In pausa`
- Percentuale di avanzamento (inserita manualmente dall'utente)
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

#### 1.2 Scheda Progetto
Ogni progetto ha una scheda dedicata che raccoglie tutte le informazioni
e le fasi di lavorazione in un'unica vista scorrevole.

**Sezioni della scheda:**
- Header con foto, nome, stato e percentuale avanzamento
- Galleria foto (più immagini del modello in varie fasi)
- Fasi di lavorazione (vedi 1.3)
- Vernici usate in questo progetto (collegate dall'inventario)
- Ricette usate in questo progetto
- Note e diario di lavorazione
- Pin su foto (vedi 1.4)

#### 1.3 Fasi di Lavorazione
Ogni progetto è suddiviso in fasi sequenziali che l'utente può spuntare
man mano che procede. Le fasi sono predefinite ma personalizzabili.

**Fasi predefinite:**
1. Preparazione (pulizia, rimozione canali, controllo parti)
2. Assemblaggio sub-gruppi
3. Assemblaggio finale
4. Stuccatura e correzioni
5. Primer
6. Pittura base
7. Ombreggiatura e luci (shading/highlighting)
8. Decalcomanie
9. Invecchiamento (weathering)
10. Finitura (vernice opaca/lucida/satinata)
11. Base/diorama (opzionale)

**Funzionalità:**
- Spunta ogni fase come completata con data
- Aggiunta di note specifiche per ogni fase
- Possibilità di aggiungere foto a ogni fase
- Aggiunta di fasi personalizzate
- Riordinamento delle fasi tramite drag & drop

---

### 2. Gestione Vernici

#### 2.1 Inventario Personale
L'inventario raccoglie tutte le vernici che l'utente possiede fisicamente.

**Dati di ogni vernice:**
- Marca (Vallejo, Citadel, Tamiya — Fase 1)
- Linea/serie (es. Vallejo Model Color, Citadel Base, Tamiya XF)
- Codice colore (es. 70.950, XF-1)
- Nome colore (es. Black, Flat Black)
- Colore HEX reale (recuperato dal catalogo)
- Chip colore esagonale visualizzato nell'app
- Quantità stimata rimanente: `Piena` · `Metà` · `Quasi finita` · `Finita`
- Note personali (es. "tende a seccarsi, aggiungere ritardante")
- Data acquisto (opzionale)

**Funzionalità:**
- Aggiunta vernice cercando nel catalogo per codice o nome
- Aggiunta manuale per vernici non in catalogo
- Filtro per marca, linea, quantità
- Ricerca per codice o nome
- Vista come griglia di chip esagonali colorati
- Vista come lista con dettagli
- Modifica quantità con tap rapido
- Lista della spesa automatica (vernici finite o quasi finite)

#### 2.2 Cataloghi Marche
Database integrato e precaricato nell'app (offline) con i colori ufficiali
delle marche supportate in Fase 1.

**Marche Fase 1:**
- **Vallejo** — Model Color (~200 colori), Game Color (~100), Mecha Color (~60),
  Model Air (~200), Panzer Aces (~60)
- **Citadel (Games Workshop)** — Base, Layer, Shade, Dry, Technical, Contrast
- **Tamiya** — XF (opache), X (lucide), LP (lacche), AS (aerografo)

**Contenuto per ogni colore del catalogo:**
- Codice ufficiale
- Nome ufficiale
- Colore HEX approssimato
- Linea di appartenenza
- Colori equivalenti nelle altre marche (quando disponibile)

**Funzionalità:**
- Sfoglia catalogo per marca e linea
- Ricerca per codice o nome
- Visualizzazione chip esagonale con colore reale
- Aggiunta diretta all'inventario personale
- Visualizzazione colori equivalenti tra marche diverse

#### 2.3 Gestione Ricette
Le ricette sono miscele personalizzate create dall'utente, salvate con
proporzioni esatte per poterle replicare in futuro.

**Dati di ogni ricetta:**
- Nome ricetta (es. "Grigio Panzer invecchiato", "Ruggine base")
- Foto del risultato ottenuto
- Lista ingredienti: ogni voce contiene vernice + percentuale
- Tecnica di applicazione (pennello, aerografo, spugnatura)
- Diluizione consigliata
- Superficie di applicazione (plastica, metallo, resina)
- Note aggiuntive
- Tag liberi (es. "invecchiamento", "tedesco WWII", "NMM")
- Collegamento ai progetti in cui è stata usata

**Funzionalità:**
- Creazione ricetta con selezione vernici dall'inventario o dal catalogo
- Inserimento proporzioni con slider o valore numerico
- Foto del risultato (scattata o dalla galleria)
- Ricerca per nome o tag
- Duplica ricetta come base per varianti
- Scala automatica delle quantità (es. "raddoppia la ricetta")

#### 2.4 Assistenza alla Miscelazione (Algoritmo Interno)
Funzionalità di supporto per trovare miscele partendo da un colore target.

**Funzionalità algoritmo interno (Fase 1 — gratuito):**
- Inserisci il codice HEX del colore desiderato
- L'app suggerisce quali vernici del tuo inventario mescolare
  per avvicinarsi a quel colore
- Calcolo basato su valori RGB delle vernici nel catalogo
- Risultato: lista di 2-3 ricette suggerite con proporzioni approssimative
- Indicatore di "distanza" dal colore target (quanto è precisa la miscela)

**Funzionalità AI con Claude (Fase 2 — a crediti):**
- Descrizione in linguaggio naturale del colore voluto
- Suggerimento ricette complesse con più ingredienti
- Considerazione della tecnica (aerografo vs pennello cambia la miscela)
- Abbinamenti cromatici per ombreggiature e luci

---

### 3. Pin su Foto

#### 3.1 Pin Colore
Permette di documentare visivamente quale colore è stato applicato
in ogni area del modello, direttamente su una foto.

**Come funziona:**
1. Seleziona una foto del modello dalla scheda progetto
2. Tocca un punto sulla foto per aggiungere un pin
3. Scegli la vernice o la ricetta usata in quel punto
4. Il pin mostra il chip esagonale con il colore reale
5. Tocca un pin esistente per vedere i dettagli o modificarlo

**Dati di ogni pin colore:**
- Posizione (coordinate X/Y sull'immagine)
- Vernice o ricetta associata
- Note aggiuntive (es. "due mani, diluita al 30%")
- Tecnica applicata

#### 3.2 Pin Lavorazione
Come i pin colore, ma documentano la tecnica di lavorazione applicata
in un determinato punto del modello.

**Dati di ogni pin lavorazione:**
- Posizione (coordinate X/Y sull'immagine)
- Tipo di lavorazione (es. "stucco epossidico", "incisione", "rivettatrice",
  "filter", "wash", "chipping", "pigmenti")
- Prodotto usato (testo libero)
- Note aggiuntive
- Fase di lavorazione a cui appartiene

**Funzionalità comuni ai pin:**
- Zoom sulla foto per posizionamento preciso
- Spostamento pin con drag
- Eliminazione pin
- Toggle visibilità pin (mostra/nascondi tutti)
- Filtro: mostra solo pin colore o solo pin lavorazione
- Vista lista di tutti i pin di una foto

---

## Fase 2 — Funzionalità Avanzate

> Le funzionalità di Fase 2 saranno pianificate in dettaglio al termine della Fase 1.
> Sono riportate qui come riferimento per le decisioni architetturali.

### 4. Ricerca da Foto (AI)
- Scatta o importa una foto di un colore reale (un modello, un veicolo,
  una texture naturale)
- L'app analizza il colore usando Claude Vision
- Suggerisce le vernici più vicine nel catalogo e possibili ricette
- Funzionalità a crediti

### 5. Miscelazione AI Avanzata
- Descrizione del colore in linguaggio naturale
- Considerazione di materiale, luce ambiente, tecnica applicativa
- Suggerimento di più opzioni con spiegazione delle differenze
- Funzionalità a crediti

### 6. Espansione Cataloghi
- AK Interactive
- Ammo by Mig Jimenez
- Humbrol
- Mr. Color (GSI Creos)
- Altri su richiesta della community

### 7. Sincronizzazione Cloud
- Backup automatico dei dati su cloud
- Accesso da più dispositivi
- Condivisione opzionale di ricette con la community
