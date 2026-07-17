const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const Anthropic = require('@anthropic-ai/sdk');

const claudeApiKey = defineSecret('CLAUDE_API_KEY');

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
