# PDG Email Backend

Micro-backend Node.js per inviare email dalla app tramite SMTP.

## Setup

La configurazione SMTP e la porta sono definite in `server.js` (costanti in cima al file).

1. Installa dipendenze:

```bash
npm install
```

2. Avvia:

```bash
npm run dev
```

## Endpoint

### `GET /health`
Controllo rapido servizio.

### `POST /send-email`
Body JSON:

```json
{
  "to": "destinatario@example.com",
  "subject": "Oggetto",
  "text": "Messaggio testo",
  "html": "<b>Messaggio HTML</b>",
  "replyTo": "utente@example.com",
  "fromName": "pdg"
}
```

`to`, `subject` e almeno uno tra `text` o `html` sono obbligatori.

## Cache post (velocizza il download nell'app)

Il backend fa da proxy con cache verso il plugin WordPress `pdg-app/v1`,
replicando la logica che prima girava sul dispositivo:

- scarica i post e le categorie dal plugin;
- arricchisce ogni post con `_embedded.wp:term` (mapping ID → categoria),
  così l'app non deve più fare chiamate extra né elaborare lato client;
- mette in cache il risultato con strategia **stale-while-revalidate**: la
  prima richiesta scalda la cache, le successive rispondono all'istante e il
  refresh dal WordPress avviene in background.

La cache è segmentata per token utente (i post privati dipendono dai ruoli).

### `GET /posts`
Inoltra gli header di autenticazione dell'app (`x-pdg-api-key`,
`Authorization: Bearer <token>`, `x-pdg-token`). Query: `page`, `per_page`,
`orderby`, `order`, `category` (opzionale).

Risposta:

```json
{
  "ok": true,
  "posts": [ { "id": 1, "title": {"rendered": "..."}, "_embedded": { "wp:term": [[ {"id": 45, "name": "Avvisi"} ]] } } ],
  "current_page": 1,
  "total": 12,
  "note": null,
  "cache": { "hit": true, "stale": false, "ageMs": 1200 }
}
```

### `GET /categories`
Stessi header. Ritorna un array di categorie (stesso shape del plugin).

### `POST /cache/clear`
Svuota la cache (utile dopo la pubblicazione di nuovi post). Se è impostata la
variabile `CACHE_CLEAR_SECRET`, va passato l'header `x-cache-secret`.

### Variabili d'ambiente (opzionali)

| Variabile | Default | Note |
| --- | --- | --- |
| `WP_API_BASE` | `https://www.portobellodigallura.it/wp-json/pdg-app/v1` | Base del plugin WP |
| `WP_API_KEY` | (chiave plugin) | Fallback se il client non invia `x-pdg-api-key` |
| `POSTS_TTL_MS` | `120000` | Finestra cache "fresca" (2 min) |
| `POSTS_STALE_MS` | `900000` | Finestra stale-while-revalidate (15 min) |
| `CATEGORIES_TTL_MS` | `1800000` | TTL cache categorie (30 min) |
| `WP_TIMEOUT_MS` | `25000` | Timeout verso WordPress |
| `CACHE_CLEAR_SECRET` | — | Protegge `POST /cache/clear` |
