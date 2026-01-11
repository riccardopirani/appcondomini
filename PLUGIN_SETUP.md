# Setup Plugin API PdG App

## Installazione Plugin WordPress

### 1. Copia il plugin nella cartella plugins di WordPress

Copia il file del plugin WordPress nella cartella:
```
wp-content/plugins/pdg-app-api.php
```

### 2. Configura la chiave API in wp-config.php

Aggiungi questa riga in `wp-config.php` **prima** della riga `/* That's all, stop editing! */`:

```php
// PdG App API - Chiave per l'autenticazione dell'app mobile
define('PDG_APP_API_KEY', 'una-chiave-lunga-e-casuale-di-almeno-32-caratteri');
```

Genera una chiave casuale sicura. Puoi usare questo comando PHP:
```php
<?php
echo bin2hex(random_bytes(32));
?>
```

### 3. Attiva il plugin da WordPress Admin

1. Vai a **Plugins** → **Plugin installati**
2. Cerca "PdG App API"
3. Clicca su **Attiva**

### 4. Configura la chiave API nell'app Flutter

Nel file `lib/services/api_service.dart`, aggiorna la costante:

```dart
static const String apiKey = 'la-stessa-chiave-di-wp-config.php';
```

## Endpoint API Disponibili

Il plugin fornisce i seguenti endpoint autenticati:

### 1. Login
**POST** `/wp-json/pdg-app/v1/auth`

Corpo richiesta:
```json
{
  "username": "admin",
  "password": "password"
}
```

Header:
```
x-pdg-api-key: tua-chiave-api
Content-Type: application/json
```

Risposta:
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "admin",
    "display_name": "Administrator"
  },
  "token": "token-lungo-di-64-caratteri",
  "expiry": 1234567890
}
```

### 2. Carica Post
**GET** `/wp-json/pdg-app/v1/posts`

Header:
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer token-ricevuto-dal-login
Content-Type: application/json
```

Query Parameters:
- `page`: numero pagina (default: 1)
- `per_page`: post per pagina (default: 20, max: 50)
- `orderby`: campo ordinamento (default: date)
- `order`: ASC o DESC (default: DESC)
- `category`: ID categoria (opzionale)

Risposta:
```json
{
  "posts": [
    {
      "id": 1,
      "title": {"rendered": "Titolo Post"},
      "content": {"rendered": "Contenuto HTML"},
      "excerpt": {"rendered": "Estratto"},
      "date": "2024-01-01T10:00:00",
      "modified": "2024-01-01T11:00:00",
      "slug": "titolo-post",
      "status": "publish",
      "link": "https://...",
      "featured_image_url": "https://..."
    }
  ],
  "current_page": 1,
  "note": "Total/pages are approximate due to permission filtering"
}
```

### 3. Carica Post Singolo
**GET** `/wp-json/pdg-app/v1/posts/{id}`

Header:
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer token-ricevuto-dal-login
Content-Type: application/json
```

### 4. Carica Categorie
**GET** `/wp-json/pdg-app/v1/categories`

Header:
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer token-ricevuto-dal-login
Content-Type: application/json
```

Risposta:
```json
[
  {
    "id": 1,
    "name": "News",
    "slug": "news",
    "parent": 0
  }
]
```

## Caratteristiche di Sicurezza

✅ **Autenticazione API Key**: Ogni richiesta deve includere la chiave API negli header
✅ **Bearer Token**: Token JWT con scadenza (30 giorni)
✅ **Rate Limiting**: Massimo 10 tentativi di login falliti per IP in 15 minuti
✅ **PublishPress Permissions**: Vengono rispettate le categorie e permessi configurati
✅ **Blocco Endpoint Sensibili**: /users, /settings, /plugins, /themes sono bloccati per non-admin

## Flusso di Autenticazione nell'App

1. **Primo Login**:
   - L'utente inserisce username e password in app
   - L'app invia una richiesta POST a `/auth` con le credenziali
   - Il plugin verifica le credenziali e genera un token
   - Il token viene salvato nelle SharedPreferences

2. **Richieste Successive**:
   - L'app carica il token dalle SharedPreferences
   - Incluse il token nell'header `Authorization: Bearer token`
   - Le richieste vengono elaborate dal plugin

3. **Rinnovo Token**:
   - Quando il token scade, l'app lo rileva (isAuthenticated restituisce false)
   - L'app esegue automaticamente un nuovo login con le credenziali salvate

4. **Fallback Legacy**:
   - Se il plugin API non è disponibile, l'app usa il metodo legacy (cookie WordPress)

## Verifica Installazione

Per verificare che tutto funzioni correttamente:

```bash
# 1. Verifica che il plugin sia attivo
curl -X GET https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories \
  -H "x-pdg-api-key: tua-chiave-api" \
  -H "Authorization: Bearer token-token-token"
```

Dovrebbe ritornare un array di categorie se il token è valido.

## Troubleshooting

### Errore 403 - Forbidden
- Verifica che la chiave API sia corretta
- Verifica che il token non sia scaduto

### Errore 401 - Unauthorized
- Il token è scaduto: rifare il login
- Le credenziali sono errate

### Errore 404 - Post Not Found
- Verifica che l'utente abbia permesso di leggere il post
- Verifica che il post sia pubblicato o privato (non bozza)

### Errore 429 - Too Many Requests
- Troppi tentativi di login falliti
- Aspetta 15 minuti prima di riprovare
