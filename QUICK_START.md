# ⚡ Quick Start - Setup in 5 Minuti

Segui questi passi velocemente per configurare il plugin API.

## 1️⃣ Genera Chiave API (1 minuto)

```bash
cd wordpress-plugin
php generate-api-key.php
```

Copia l'output della chiave (stringa di 64 caratteri)

## 2️⃣ Configura WordPress (2 minuti)

Aggiungi a `wp-config.php` (prima di `/* That's all, stop editing! */`):

```php
define('PDG_APP_API_KEY', 'CHIAVE_GENERATA_AL_PASSO_1');
```

## 3️⃣ Copia Plugin (30 secondi)

```bash
cp wordpress-plugin/pdg-app-api.php /path/to/wordpress/wp-content/plugins/
```

## 4️⃣ Attiva Plugin (30 secondi)

1. Vai a WordPress Admin → Plugin
2. Cerca "PdG App API"
3. Clicca Attiva

## 5️⃣ Aggiorna App Flutter (30 secondi)

Apri `lib/services/api_service.dart` e aggiorna:

```dart
static const String apiKey = 'CHIAVE_GENERATA_AL_PASSO_1';
```

## ✅ Fatto!

```bash
flutter run
```

L'app dovrebbe ora:
1. ✅ Fare login senza Basic Auth
2. ✅ Caricare post ogni 3 secondi senza nuovo login
3. ✅ Rinnovare token automaticamente quando scade

---

## 🧪 Verifica Rapida

Testa che tutto funzioni:

```bash
# Test 1: Plugin attivo?
curl https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories \
  -H "x-pdg-api-key: CHIAVE" -H "Authorization: Bearer DUMMY"

# Output atteso: 401 Unauthorized (plugin è online)

# Test 2: Login funziona?
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: CHIAVE" \
  -d '{"username":"admin","password":"password"}'

# Output atteso: {"success":true,"token":"...","expiry":...}
```

---

## 📋 File Modificati

- ✅ `lib/services/api_service.dart` - Nuovo servizio API (copia fornita)
- ✅ `lib/main.dart` - Integrazione nel login + fetchPosts
- ✅ `wordpress-plugin/pdg-app-api.php` - Plugin WordPress

## 📚 Documentazione Completa

Vedi `SETUP_INSTRUCTIONS.md` per step-by-step dettagliato con screenshot.

---

## 🎯 Come Funziona

```
[App Login] 
    ↓
[POST /auth con credenziali]
    ↓
[Plugin valida + genera token]
    ↓
[App salva token in SharedPreferences]
    ↓
[Ogni refresh: usa token memorizzato]
    ↓
[Niente nuovo login ogni 3 secondi! 🎉]
```

---

**Pronto!** Ora l'app scarica i post con un'unica autenticazione all'inizio. 🚀
