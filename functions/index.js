const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const Anthropic = require('@anthropic-ai/sdk');

const claudeApiKey = defineSecret('CLAUDE_API_KEY');

// ── scanManualColors ──────────────────────────────────────────────────────────
// Riceve: { imageBase64: string }  (JPEG base64, max ~1.5 MB)
// Restituisce: { result: string }  dove result è JSON con { codes: [{brand, code}] }

exports.scanManualColors = onCall(
  { secrets: [claudeApiKey], region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Devi essere autenticato.');
    }

    const { imageBase64 } = request.data;
    if (!imageBase64 || typeof imageBase64 !== 'string') {
      throw new HttpsError('invalid-argument', 'imageBase64 mancante.');
    }

    const client = new Anthropic.default({ apiKey: claudeApiKey.value() });

    const prompt = `Analizza questa pagina di istruzioni di montaggio per modelli in scala.
Identifica TUTTI i codici colore vernice presenti nella pagina.

I codici possono essere di queste marche con i rispettivi formati:
- Tamiya: XF-1 XF-63 X-1 X-14 AS-1 TS-1 LP-1 (lettera/i + trattino + numero)
- Vallejo: 70.950 71.001 72.001 (due cifre + punto + tre cifre)
- Gunze Mr. Color: C1 C40 C100 (C + numero)
- Gunze Aqueous: H1 H47 H90 (H + numero)
- Humbrol: 33 64 147 (numero puro, spesso preceduto da "H" o "Humbrol")
- Lifecolor: LC01 LC49 UA210 (LC o UA + numero)

Rispondi SOLO con un JSON valido in questo formato esatto:
{
  "codes": [
    { "brand": "tamiya", "code": "XF-63" },
    { "brand": "vallejo", "code": "70.950" },
    { "brand": "gunze", "code": "C40" }
  ]
}

Includi TUTTI i codici visibili nella pagina. Se non trovi nessun codice colore rispondi { "codes": [] }.
Non includere numeri di step di montaggio (1, 2, 3…), solo codici colore vernice.`;

    const message = await client.messages.create({
      model: 'claude-sonnet-5',
      max_tokens: 1024,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: 'image/jpeg',
              data: imageBase64,
            },
          },
          { type: 'text', text: prompt },
        ],
      }],
    });

    const text = message.content[0].type === 'text' ? message.content[0].text : '{}';
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const jsonStr = jsonMatch ? jsonMatch[0] : '{"codes":[]}';

    try {
      JSON.parse(jsonStr);
    } catch {
      throw new HttpsError('internal', 'Risposta AI non valida.');
    }

    return { result: jsonStr };
  }
);

// ── suggestMixingRecipe ───────────────────────────────────────────────────────
// Riceve: { targetHex: string, availableBrands: string[] }
// Restituisce: { recipe: string } dove recipe è JSON con { ingredients, notes }

exports.suggestMixingRecipe = onCall(
  { secrets: [claudeApiKey], region: 'europe-west1' },
  async (request) => {
    // Verifica autenticazione
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Devi essere autenticato.');
    }

    const { targetHex, availableBrands } = request.data;

    if (!targetHex || typeof targetHex !== 'string') {
      throw new HttpsError('invalid-argument', 'targetHex mancante.');
    }

    const brands = Array.isArray(availableBrands) ? availableBrands : ['vallejo', 'tamiya'];

    const client = new Anthropic.default({ apiKey: claudeApiKey.value() });

    const prompt = `Sei un esperto di verniciatura per modellismo statico.
L'utente vuole ottenere il colore HEX ${targetHex} miscelando vernici delle marche: ${brands.join(', ')}.

Suggerisci una ricetta di miscelazione precisa. Rispondi SOLO con un JSON valido in questo formato esatto:
{
  "ingredients": [
    { "brand": "vallejo", "code": "70.950", "name": "Black", "hex": "#000000", "percentage": 30 },
    { "brand": "tamiya", "code": "XF-57", "name": "Buff", "hex": "#C8A96E", "percentage": 70 }
  ],
  "notes": "Mescola prima il colore base, poi aggiungi progressivamente il secondo componente controllando il risultato."
}

Regole:
- Le percentuali devono sommare esattamente a 100
- Usa solo vernici reali delle marche richieste con codici esistenti
- Massimo 4 ingredienti
- Il campo notes deve contenere consigli pratici di miscelazione in italiano
- Rispondi SOLO con il JSON, nessun testo aggiuntivo`;

    const message = await client.messages.create({
      model: 'claude-sonnet-5',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    });

    const text = message.content[0].type === 'text' ? message.content[0].text : '{}';

    // Estrai JSON dalla risposta (Claude potrebbe aggiungere ```json ... ```)
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const jsonStr = jsonMatch ? jsonMatch[0] : text;

    // Valida che sia JSON valido
    try {
      JSON.parse(jsonStr);
    } catch {
      throw new HttpsError('internal', 'Risposta AI non valida.');
    }

    return { recipe: jsonStr };
  }
);
