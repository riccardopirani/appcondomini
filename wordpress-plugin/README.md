# PdG App API Plugin

Un plugin WordPress che fornisce una REST API sicura per l'app mobile Condominio di Portobello di Gallura.

## Caratteristiche

- ✅ **Autenticazione Sicura**: API Key + Bearer Token JWT
- ✅ **Token con Scadenza**: Validità di 30 giorni
- ✅ **Rate Limiting**: Protezione contro brute force (10 tentativi/15 min)
- ✅ **PublishPress Compatible**: Rispetta i permessi delle categorie
- ✅ **Endpoint Protetti**: Blocca accesso a /users, /settings, /plugins, /themes ai non-admin
- ✅ **Filtro Post Smart**: Mostra solo i post leggibili dall'utente

## Installazione

### 1. Copia il Plugin

```bash
cp pdg-app-api.php /path/to/wordpress/wp-content/plugins/
```

### 2. Genera la Chiave API

```bash
php generate-api-key.php
```

Output:
```
🔑 Chiave API generata:

   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...
```

### 3. Configura wp-config.php

Aggiungi questa riga **prima** di `/* That's all, stop editing! */`:

```php
define('PDG_APP_API_KEY', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...');
```

### 4. Attiva il Plugin

1. Accedi a WordPress Admin
2. Vai a **Plugin** → **Plugin Installati**
3. Cercare "PdG App API"
4. Clicca **Attiva**

## Utilizzo

### Endpoint: Login

```
POST /wp-json/pdg-app/v1/auth
```

**Header:**
```
Content-Type: application/json
x-pdg-api-key: tua-chiave-api
```

**Body:**
```json
{
  "username": "admin",
  "password": "password"
}
```

**Risposta (200):**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "admin",
    "display_name": "Administrator"
  },
  "token": "abc123def456...",
  "expiry": 1705123456
}
```

### Endpoint: Carica Post

```
GET /wp-json/pdg-app/v1/posts?page=1&per_page=20&orderby=date&order=DESC
```

**Header:**
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer abc123def456...
```

**Query Parameters:**
- `page` (int): Numero pagina (default: 1)
- `per_page` (int): Post per pagina (default: 20, max: 50)
- `orderby` (string): Campo ordinamento - `date|modified|title` (default: date)
- `order` (string): Ordinamento - `ASC|DESC` (default: DESC)
- `category` (int): ID categoria (opzionale)

**Risposta (200):**
```json
{
  "posts": [
    {
      "id": 1,
      "title": {"rendered": "Titolo Post"},
      "content": {"rendered": "<p>Contenuto HTML...</p>"},
      "excerpt": {"rendered": "Estratto..."},
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

### Endpoint: Singolo Post

```
GET /wp-json/pdg-app/v1/posts/1
```

**Header:**
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer abc123def456...
```

**Risposta (200):**
```json
{
  "id": 1,
  "title": {"rendered": "Titolo Post"},
  "content": {"rendered": "<p>Contenuto...</p>"},
  ...
}
```

### Endpoint: Categorie

```
GET /wp-json/pdg-app/v1/categories
```

**Header:**
```
x-pdg-api-key: tua-chiave-api
Authorization: Bearer abc123def456...
```

**Risposta (200):**
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

## Codici di Risposta

| Codice | Significato | Azione |
|--------|-------------|--------|
| 200 | OK | Richiesta riuscita |
| 401 | Unauthorized | Token mancante o scaduto - rifare login |
| 403 | Forbidden | API Key non valida oppure utente non ha permessi |
| 404 | Not Found | Risorsa non trovata |
| 429 | Too Many Requests | Troppi tentativi di login falliti - aspetta 15 min |
| 500 | Server Error | Errore interno del server |

## Sicurezza

### API Key
- Lunga 64 caratteri generata da 32 byte casuali
- Memorizzata in `wp-config.php` (non in database)
- Protegge tutte le richieste REST

### Token JWT
- Generato al login
- Valido per 30 giorni
- Hash SHA-256 salvato come user meta
- Non è reversibile (non contiene informazioni sensibili)

### Rate Limiting
- Massimo 10 tentativi di login falliti
- Per IP address
- Durata: 15 minuti
- Risponde con HTTP 429

### Blocco Endpoint Sensibili
Questi endpoint sono bloccati per utenti non-admin:
- `/wp-json/wp/v2/users`
- `/wp-json/wp/v2/settings`
- `/wp-json/wp/v2/plugins`
- `/wp-json/wp/v2/themes`

### Permessi PublishPress
Il plugin rispetta nativamente i permessi configurati in PublishPress Permissions:
- Filtra post per categoria
- Verifica `read_post` capability
- Mostra solo post leggibili dall'utente

## Debug

Abilita il debug aggiungendo a `wp-config.php`:

```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
```

I log saranno salvati in `wp-content/debug.log`

### Test da Linea di Comando

**Login:**
```bash
curl -X POST http://localhost/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: tua-chiave" \
  -d '{"username":"admin","password":"password"}'
```

**Carica Post:**
```bash
curl -X GET 'http://localhost/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: tua-chiave" \
  -H "Authorization: Bearer TOKEN_RICEVUTO"
```

## Troubleshooting

### ❌ Errore 403 - Forbidden
**Cause possibili:**
- API Key non valida
- API Key non corrisponde
- Header `x-pdg-api-key` mancante

**Soluzione:**
- Verifica che la chiave sia identica in wp-config.php e nella richiesta
- Assicurati di includere il header `x-pdg-api-key`

### ❌ Errore 401 - Unauthorized
**Cause possibili:**
- Token mancante
- Token scaduto
- Credenziali di login errate

**Soluzione:**
- Includi header `Authorization: Bearer TOKEN`
- Se il token è scaduto (> 30 giorni), rifare login
- Verifica username e password

### ❌ Errore 429 - Too Many Requests
**Cause possibili:**
- Troppi tentativi di login falliti dall'IP

**Soluzione:**
- Aspetta 15 minuti prima di riprovare
- Oppure cancella il transient:
  ```php
  delete_transient('pdg_app_auth_fail_' . md5($_SERVER['REMOTE_ADDR']));
  ```

### ❌ Errore 500 - Server Error
**Cause possibili:**
- Errore interno di WordPress
- Permessi file errati

**Soluzione:**
- Controlla `wp-content/debug.log`
- Verifica che il plugin sia attivato
- Riavvia WordPress (CTRL+Shift+R nel browser)

## Aggiornamenti

Per aggiornare il plugin:
1. Disattiva il plugin da WordPress Admin
2. Sostituisci il file `pdg-app-api.php`
3. Riattiva il plugin

I token salvati rimangono validi dopo l'aggiornamento.

## Disinstallazione

1. Disattiva il plugin
2. Elimina il file `pdg-app-api.php`
3. I dati del plugin (token, etc.) verranno mantenuti in database per compatibilità

## Support

Per problemi o suggerimenti, contatta il team di sviluppo di Portobello di Gallura.

---

**Versione:** 3.0  
**Autore:** Portobello di Gallura  
**Licenza:** MIT
