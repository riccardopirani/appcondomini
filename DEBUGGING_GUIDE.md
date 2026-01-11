# 🔍 Guida al Debug - Comprendi i Log

Ora che hai aggiornato `api_service.dart` con log dettagliati, ecco cosa vedrai nel terminale quando testi il login e il caricamento post.

---

## 🔐 Log di Login Riuscito

Quando il login va bene, vedrai:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: admin
🔑 Password: ************************** (12 char)
🌐 Endpoint: https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth
🔐 API Key: Tz7Wq8GlWV...lOc8AHe
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 200
📏 Content-Length: 324 bytes
📝 Response Body: {"success":true,"user":{"id":1,"username":"admin","display_name":"Administrator"},"token":"abc123def456ghi789jkl...","expiry":1748645123}
───────────────────────────────────────────────────
✅ PARSING RISPOSTA
───────────────────────────────────────────────────
🎯 success: true
👤 user.id: 1
👤 user.username: admin
👤 user.display_name: Administrator
🔐 token: abc123def456ghi789jk...d8c9d0e1f2
⏰ expiry (timestamp): 1748645123
───────────────────────────────────────────────────
💾 SALVATAGGIO TOKEN
───────────────────────────────────────────────────
🔐 Token salvato: abc123def456ghi789jk...
⏰ Scadenza: 2025-02-11 15:32:03.000Z
⏱️ Giorni rimanenti: 31
───────────────────────────────────────────────────
✅ LOGIN COMPLETATO CON SUCCESSO!
═══════════════════════════════════════════════════
```

### Cosa Significa Ogni Riga

| Log | Significato |
|-----|-------------|
| `🔐 INIZIO LOGIN` | Login iniziato |
| `📧 Username: admin` | Username usato |
| `🔑 Password: **...` | Password (mascherata per sicurezza) |
| `🌐 Endpoint: https://...` | URL endpoint chiamato |
| `🔐 API Key: Tz7W...AHe` | Chiave API (parziale per sicurezza) |
| `📊 HTTP Status Code: 200` | ✅ Successo HTTP (200 = OK) |
| `📏 Content-Length: 324 bytes` | Dimensione risposta |
| `📝 Response Body: {...}` | Corpo intero della risposta |
| `🎯 success: true` | ✅ Server dice che login è ok |
| `👤 user.id: 1` | ID utente ricevuto |
| `👤 user.username: admin` | Username ricevuto |
| `👤 user.display_name: Administrator` | Nome visualizzazione utente |
| `🔐 token: abc123...` | Token JWT generato (parziale) |
| `⏰ expiry (timestamp): 1748645123` | Scadenza token (timestamp Unix) |
| `⏰ Scadenza: 2025-02-11...` | Data/ora scadenza leggibile |
| `⏱️ Giorni rimanenti: 31` | Quanti giorni prima che scada |
| `✅ LOGIN COMPLETATO` | ✅ Tutto ok! |

---

## ❌ Log di Login Fallito (Credenziali Errate)

Se password è sbagliata:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: admin
🔑 Password: ************************** (12 char)
🌐 Endpoint: https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth
🔐 API Key: Tz7Wq8GlWV...lOc8AHe
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 401
📏 Content-Length: 98 bytes
📝 Response Body: {"code":"invalid_credentials","message":"Invalid credentials","data":{"status":401}}
───────────────────────────────────────────────────
❌ ERRORE 401: CREDENZIALI NON VALIDE
───────────────────────────────────────────────────
Username o password errati
Response: {"code":"invalid_credentials","message":"Invalid credentials","data":{"status":401}}
═══════════════════════════════════════════════════
```

### Cosa Fare

1. ✅ Verifica username: è **esattamente** quello di WordPress?
2. ✅ Verifica password: è **corretta**?
3. ✅ Accedi a WordPress da browser per verificare

---

## ❌ Log di Login Fallito (API Key Errata)

Se la chiave API è sbagliata:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
...
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 403
📏 Content-Length: 82 bytes
📝 Response Body: {"code":"rest_forbidden","message":"Invalid API key","data":{"status":403}}
───────────────────────────────────────────────────
❌ ERRORE 403: ACCESSO NEGATO
───────────────────────────────────────────────────
Verifica API Key in wp-config.php
Response: {"code":"rest_forbidden","message":"Invalid API key","data":{"status":403}}
═══════════════════════════════════════════════════
```

### Cosa Fare

1. ✅ Verifica chiave API in `lib/services/api_service.dart`
2. ✅ Verifica che sia **identica** a quella in `wp-config.php`
3. ✅ Non ci devono essere spazi extra
4. ✅ Maiuscole/minuscole importano!

---

## ❌ Log di Login Fallito (Troppi Tentativi)

Dopo 10 tentativi falliti in 15 minuti:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
...
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 429
📏 Content-Length: 92 bytes
📝 Response Body: {"code":"rate_limited","message":"Too many attempts. Try again later."}
───────────────────────────────────────────────────
❌ ERRORE 429: TROPPI TENTATIVI
───────────────────────────────────────────────────
Troppi login falliti dall'IP
Aspetta 15 minuti
Response: {"code":"rate_limited","message":"Too many attempts. Try again later."}
═══════════════════════════════════════════════════
```

### Cosa Fare

⏳ **Aspetta 15 minuti** prima di riprovare

Il rate limiting è una **feature di sicurezza** per proteggerti da brute force!

---

## ❌ Log di Login Fallito (Connessione)

Se il server non è raggiungibile:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: admin
🔑 Password: ************************** (12 char)
🌐 Endpoint: https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth
🔐 API Key: Tz7Wq8GlWV...lOc8AHe
═══════════════════════════════════════════════════
❌ ECCEZIONE DURANTE LOGIN
═══════════════════════════════════════════════════
Errore: SocketException: Failed to lookup 'www.portobellodigallura.it' (OS Error: nodename nor servname provided, or not a member of some group, errno = 8)
═══════════════════════════════════════════════════
```

### Cosa Fare

1. ✅ Verifica che il computer sia **online**
2. ✅ Ping del server: `ping www.portobellodigallura.it`
3. ✅ Verifica che WordPress sia **online**
4. ✅ Verifica che il plugin sia **attivato**

---

## 📥 Log di Caricamento Post Riuscito

Quando carica i post:

```
───────────────────────────────────────────────────
📥 CARICAMENTO POST
───────────────────────────────────────────────────
📄 Pagina: 1
📊 Per pagina: 20
🔤 Ordina per: date (DESC)
📡 Status Code: 200
───────────────────────────────────────────────────
✅ SUCCESSO
───────────────────────────────────────────────────
📦 Post caricati: 15
📄 Pagina attuale: 1
📝 Nota: Total/pages are approximate due to permission filtering
───────────────────────────────────────────────────
📋 DETTAGLI POST
───────────────────────────────────────────────────
Post 1:
  ID: 42
  Titolo: Prima comunicazione importante del condominio...
  Data: 2025-01-11T10:30:00
  Status: publish
Post 2:
  ID: 41
  Titolo: Avviso urgente manutenzione ascensore...
  Data: 2025-01-10T14:20:00
  Status: publish
Post 3:
  ID: 40
  Titolo: Calendario raccolta rifiuti gennaio...
  Data: 2025-01-09T09:15:00
  Status: publish
... e altri 12 post
```

### Cosa Significa

| Log | Significato |
|-----|-------------|
| `📄 Pagina: 1` | Sei sulla pagina 1 |
| `📊 Per pagina: 20` | Massimo 20 post per pagina |
| `🔤 Ordina per: date (DESC)` | Ordinati per data (più recenti prima) |
| `📦 Post caricati: 15` | Sono arrivati 15 post |
| `📄 Pagina attuale: 1` | Conferma pagina |
| `📝 Nota: Total/pages...` | Log informativo del plugin |
| `ID: 42` | ID del post su WordPress |
| `Titolo: ...` | Titolo del post (primi 50 caratteri) |
| `Data: 2025-01-11...` | Data di pubblicazione |
| `Status: publish` | Post pubblico (o private) |

---

## ❌ Log di Caricamento Post Fallito (Non Autenticato)

Se il token non è valido:

```
───────────────────────────────────────────────────
📥 CARICAMENTO POST
───────────────────────────────────────────────────
📄 Pagina: 1
📊 Per pagina: 20
🔤 Ordina per: date (DESC)
📡 Status Code: 401
───────────────────────────────────────────────────
❌ ERRORE 401
───────────────────────────────────────────────────
Response: {"code":"rest_forbidden","message":"Invalid or expired token","data":{"status":401}}
```

### Cosa Significa

- ❌ Token **scaduto** oppure **non valido**
- ✅ **Soluzione**: Rifare login

---

## ❌ Log di Caricamento Post Fallito (Non Autorizzato)

Se l'utente non ha permesso di leggere i post:

```
───────────────────────────────────────────────────
📥 CARICAMENTO POST
───────────────────────────────────────────────────
📄 Pagina: 1
📊 Per pagina: 20
🔤 Ordina per: date (DESC)
📡 Status Code: 403
───────────────────────────────────────────────────
❌ ERRORE 403
───────────────────────────────────────────────────
Response: {"code":"rest_forbidden","message":"User does not have permission to read posts","data":{"status":403}}
```

### Cosa Significa

- ❌ Utente **non ha permessi** di lettura
- ✅ **Soluzione**: Configura permessi in WordPress (PublishPress Permissions)

---

## 🧪 Come Testare

### Test 1: Verifica che il Login Funzioni

```bash
# Sostituisci USERNAME e PASSWORD
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -d '{"username":"admin","password":"password"}' \
  -v
```

**Output atteso**:
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "admin",
    "display_name": "Administrator"
  },
  "token": "abc123...",
  "expiry": 1748645123
}
```

### Test 2: Verifica che Carica Post

Prendi il TOKEN dal Test 1:

```bash
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer TOKEN_RICEVUTO" \
  -v
```

**Output atteso**:
```json
{
  "posts": [
    {
      "id": 42,
      "title": {"rendered": "Titolo Post"},
      ...
    }
  ],
  "current_page": 1
}
```

---

## 📊 Decodifica dei Codici di Errore

| Codice | Nome | Causa | Azione |
|--------|------|-------|--------|
| **200** | OK | ✅ Successo | Continua |
| **401** | Unauthorized | Token scaduto/invalido oppure credenziali errate | Rifare login |
| **403** | Forbidden | API Key errata oppure permessi insufficienti | Verifica chiave API e permessi |
| **404** | Not Found | Endpoint non esiste | Controlla URL endpoint |
| **429** | Too Many Requests | Troppi tentativi di login falliti | Aspetta 15 minuti |
| **500** | Server Error | Errore interno WordPress | Controlla debug.log su server |

---

## 🎯 Checklist di Verifica

Quando vedi i log, controlla:

### ✅ Login
- [ ] `HTTP Status Code: 200` ← Successo
- [ ] `success: true` ← Server conferma
- [ ] `token: abc123...` ← Token ricevuto
- [ ] `expiry: 1748...` ← Scadenza presente
- [ ] `Giorni rimanenti: 31` ← Valido per 30+ giorni

### ✅ Caricamento Post
- [ ] `HTTP Status Code: 200` ← Successo
- [ ] `Post caricati: 15` (o più) ← Post arrivati
- [ ] Vedete i dettagli post (ID, Titolo, Data, Status)
- [ ] Status è `publish` oppure `private` (non draft)

### ❌ Se Qualcosa Non Va

1. **Primo**: Controlla il codice HTTP
2. **Secondo**: Leggi il messaggio di errore
3. **Terzo**: Usa la tabella "Decodifica Codici di Errore" sopra
4. **Quarto**: Esegui i test da terminale per isolare il problema

---

## 💡 Pro Tips

1. **Copia i log** per il debug
2. **Guarda HTTP Status** come primo indizio
3. **Leggi il `Response Body`** per dettagli
4. **Controlla data scadenza** token
5. **Verifica chiave API** (non ci devono essere spazi)

---

## 🆘 Se Hai Ancora Problemi

1. **Copia TUTTO il log** (da `═══` a `═══`)
2. **Copia il Response Body** intero
3. **Verifica credenziali** (accedi a WordPress da browser)
4. **Verifica chiave API** (confronta wp-config.php con api_service.dart)
5. **Controlla `/wp-content/debug.log`** su WordPress

---

**Con questi log dovresti riuscire a risolvere qualsiasi problema! 🎯**
