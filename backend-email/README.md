# PDG Email Backend

Micro-backend Node.js per inviare email dalla app tramite SMTP.

## Setup

1. Copia il file di esempio:

```bash
cp .env.example .env
```

2. Installa dipendenze (se non già fatto):

```bash
npm install
```

3. Avvia:

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
