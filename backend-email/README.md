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
