# Patina — Vision

## Il Problema

Il modellismo statico è una disciplina che richiede precisione, pazienza e organizzazione.
Il modellista lavora spesso su più progetti in contemporanea — un carro armato in fase di
assemblaggio, un aereo in attesa di primer, una figura già in pittura — e gestire tutto
questo con carta, memoria o strumenti generici è dispersivo e frustrante.

Nessuna app oggi è pensata specificamente per il modellista statico. Gli strumenti
esistenti sono troppo generici, non capiscono il linguaggio del modellismo, non gestiscono
le vernici, non accompagnano il processo di lavorazione.

## La Soluzione

**Patina** è l'app dedicata esclusivamente al modellismo statico.

Il nome richiama un termine tecnico del mestiere: la *patina* è l'invecchiamento
controllato di una superficie, il tocco finale che trasforma un modello in un'opera.
Come la patina, quest'app è il tocco che completa il processo — organizza, guida, ispira.

## A Chi Si Rivolge

- **Neofiti** che si avvicinano al modellismo e vogliono imparare a gestire materiali
  e fasi di lavorazione in modo guidato
- **Modellisti esperti** che lavorano su più progetti contemporaneamente e hanno bisogno
  di uno strumento preciso per tracciare ogni dettaglio

Età target: 16–60 anni. Appassionati di aerei, carri armati, figure, diorami.

## Cosa Fa Patina

### Gestione dei Progetti
Ogni modello è un progetto con la sua storia: foto, fasi di lavorazione, stato di
avanzamento, note e materiali utilizzati. Tutto in un unico posto.

Le **categorie** supportate sono: carro armato, aereo, figura, nave, diorama, altro.
Gli **stati** del progetto seguono il flusso reale di lavorazione: Idea → In costruzione
→ In pittura → Completato (con possibilità di mettere In pausa in qualsiasi momento).

### Gestione delle Vernici
- **Inventario personale** — tieni traccia di ogni vernice che possiedi, marca, codice,
  quantità rimasta (Piena / Metà / Quasi finita / Finita)
- **Cataloghi offline** — database integrato di Vallejo Model Color, Citadel Base,
  Tamiya XF (Fase 1), espandibile in Fase 2
- **Gestione ricette** — crea e salva le tue miscele con proporzioni esatte e foto
  del risultato ottenuto
- **Assistenza alla miscelazione** — algoritmo interno per operazioni semplici;
  intelligenza artificiale (Claude API) per ricette complesse in Fase 2
- **Ricerca da foto** — trova una vernice o una ricetta partendo da una fotografia (Fase 2)

### Lavorazione del Modello con Pin su Foto
Carica una foto del tuo modello e apponi dei **pin interattivi** direttamente
sull'immagine per indicare:
- Quale colore o ricetta è stato applicato in un determinato punto
- Quale tecnica di lavorazione è stata usata in quell'area

Un modo visivo e immediato per documentare il lavoro e non perdere mai il filo.

## Obiettivo a Lungo Termine

Diventare il **compagno digitale del modellista** — dalla prima scatola aperta
all'ultimo strato di vernice — con la possibilità in futuro di condividere progetti
e ricette con la community.

## Posizionamento

> Patina riempie un vuoto che il mercato non ha ancora colmato:
> uno strumento professionale, bello da usare, pensato da modellisti per modellisti.

---

## Roadmap di Alto Livello

| Fase | Contenuto | Stato |
|------|-----------|-------|
| **Fase 0** | Struttura Flutter, database, cataloghi, design system, navigazione | Completato |
| **Fase 1** | Archivio progetti, inventario vernici, ricette manuali, pin su foto, backup | In corso |
| **Fase 2** | Miscelazione AI, ricerca da foto (Claude Vision), sync cloud, espansione cataloghi | Futuro |
