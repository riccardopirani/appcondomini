# Riepilogo Modifiche - Integrazione Plugin API

## 📋 Panoramica

Implementazione di un nuovo sistema di autenticazione e caricamento post tramite un plugin WordPress custom (`PdG App API`) che:

✅ Utilizza un'unica autenticazione centralizzata  
✅ Supporta token JWT con scadenza (30 giorni)  
✅ Implementa rate limiting per la sicurezza  
✅ Rispetta i permessi PublishPress  
✅ Include fallback ai metodi legacy per compatibilità  

---

## 🔧 Modifiche Apportate

### 1. **Nuovo Servizio API** (`lib/services/api_service.dart`)

Servizio Singleton che gestisce:
- **Login**: Autenticazione con username/password
- **Token Management**: Salvataggio e caricamento token da SharedPreferences
- **API Requests**: Metodi get() e post() autenticati
- **Post Operations**: Caricamento post, singoli, categorie

**Classe**: `ApiService`
**Istanza globale**: `apiService`

### 2. **Modifiche a main.dart**

#### Import aggiunto:
```dart
import 'package:condominio/services/api_service.dart';
```

#### 🔐 Login Screen - handleLogin()
- Aggiunto login tramite `apiService.login(username, password)`
- Mantiene fallback al metodo legacy WordPress

#### 🏠 Home Screen - _initializeWithTokenReload()
- Al primo avvio carica il token dal servizio API
- Se scaduto, tenta nuovo login automatico
- Fallback ai metodi legacy se plugin API non disponibile

#### 📥 Caricamento Post - fetchPosts()
- **Primo tentativo**: Usa `apiService.fetchPosts()` se autenticato
- **Fallback**: Metodi legacy se plugin API non risponde
- Mantiene cache e logica di aggiornamento

#### ⏱️ Refresh Periodico (3 secondi) - _checkSessionAndReauth()
- Verifica validità token API plugin
- Rigenera token automaticamente se scaduto
- Fallback a cookie WordPress se necessario

#### 🆕 Nuova Funzione - _tryFetchPostsViaPluginApi()
- Tenta caricamento post via plugin API
- Gestisce autenticazione e errori
- Integra result in _processPosts()

### 3. **Plugin WordPress** (`wordpress-plugin/pdg-app-api.php`)

#### Endpoint REST API:
- `POST /wp-json/pdg-app/v1/auth` - Login
- `GET /wp-json/pdg-app/v1/posts` - Carica post
- `GET /wp-json/pdg-app/v1/posts/{id}` - Singolo post
- `GET /wp-json/pdg-app/v1/categories` - Categorie

#### Sicurezza:
- Validazione API Key negli header
- Token JWT con scadenza
- Rate limiting (10 tentativi falliti in 15 min)
- Blocco endpoint sensibili (/users, /settings, etc)
- Rispetto permessi PublishPress

### 4. **Documentazione**

- `PLUGIN_SETUP.md` - Guida di installazione e configurazione
- `CHANGES_SUMMARY.md` - Questo file

---

## 🚀 Flusso di Autenticazione

### Primo Login
```
User → App: username + password
App → Plugin: POST /auth (x-pdg-api-key + credenziali)
Plugin → DB: Verifica credenziali + generat token
Plugin → App: token (scadenza 30 giorni)
App → SharedPreferences: Salva token
```

### Richieste Successive
```
App → SharedPreferences: Carica token
App → Plugin: GET /posts (x-pdg-api-key + Bearer token)
Plugin: Verifica token + permessi PublishPress
Plugin → App: Post leggibili
```

### Rinnovo Automatico Token
```
App: Rileva token scaduto (ogni 30 min)
App → Plugin: POST /auth (credenziali salvate)
Plugin → App: Nuovo token
App: Aggiorna SharedPreferences
```

---

## ⚙️ Configurazione Richiesta

### 1. WordPress (wp-config.php)
```php
define('PDG_APP_API_KEY', 'chiave-casuale-sicura-almeno-32-caratteri');
```

### 2. App Flutter (api_service.dart)
```dart
static const String apiKey = 'la-stessa-chiave-di-wp-config.php';
```

### 3. WordPress Plugin Activation
1. Copia `pdg-app-api.php` in `wp-content/plugins/`
2. Attiva da WordPress Admin

---

## 🔄 Compatibilità e Fallback

| Scenario | Comportamento |
|----------|---------------|
| Plugin API disponibile ✅ | Usa token JWT plugin |
| Plugin API non disponibile | Fallback cookie WordPress |
| Token API scaduto | Rigenerazione automatica |
| Cookie WordPress scaduto | Rigenerazione automatica |
| Server offline | Usa cache locale |

---

## 🔍 Test e Verifica

### Test Login
```bash
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: tua-chiave" \
  -d '{"username":"admin","password":"password"}'
```

### Test Caricamento Post
```bash
# Sostituisci TOKEN con il token ricevuto dal login
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=10' \
  -H "x-pdg-api-key: tua-chiave" \
  -H "Authorization: Bearer TOKEN"
```

---

## 📊 Vantaggi della Nuova Implementazione

✅ **Una sola autenticazione** al startup, non ad ogni refresh  
✅ **Token statico per 30 giorni** (non scade come i cookie)  
✅ **Rate limiting** integrato contro brute force  
✅ **Rispetto permessi PublishPress** nativamente  
✅ **Fallback automatico** a metodi legacy  
✅ **Refresh ogni 3 secondi senza login** (usa token memorizzato)  
✅ **Endpoint sicuri** (bloccati per non-admin)  

---

## ⚠️ Rimozione Test Backend

I test backend (`_testWordPressAPI`, `_testPostsAvailability`) rimangono nel codice per compatibilità ma non vengono più usati nella logica principale. Possono essere rimossi in futuro se non necessari.

---

## 📝 Note Importanti

1. **Chiave API**: Mantieni la chiave segura, non commitarla su GitHub
2. **Token Expiry**: 30 giorni, configurable nel plugin
3. **SharedPreferences**: Token salvato localmente (sicuro su dispositivo)
4. **Credenziali**: Salvate localmente per rinnovo automatico token
5. **Rate Limit**: 10 tentativi falliti per IP in 15 minuti

---

## 🎯 Prossimi Passi Opzionali

- [ ] Implementare refresh token separato
- [ ] Aggiungere logout endpoint specifico
- [ ] Implementare 2FA nel plugin
- [ ] Dashboard admin nel plugin
- [ ] Webhook per notifiche post urgenti
- [ ] Caching server-side di post per prestazioni
