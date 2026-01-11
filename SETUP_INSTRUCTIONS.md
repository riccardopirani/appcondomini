# 🚀 Setup Completo - Plugin API PdG App

Questo documento contiene le istruzioni passo-passo per installare e configurare completamente il sistema di autenticazione tramite plugin API.

## 📋 Indice

1. [Setup WordPress Plugin](#setup-wordpress-plugin)
2. [Configurazione API Key](#configurazione-api-key)
3. [Configurazione App Flutter](#configurazione-app-flutter)
4. [Test e Verifica](#test-e-verifica)
5. [Troubleshooting](#troubleshooting)

---

## Setup WordPress Plugin

### Passo 1: Genera la Chiave API

Dalla cartella `wordpress-plugin`, esegui:

```bash
cd wordpress-plugin
php generate-api-key.php
```

Output:
```
========================================
  Generatore Chiave API PdG App
========================================

🔑 Chiave API generata:

   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2

Copia questa chiave in wp-config.php:

define('PDG_APP_API_KEY', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...');

E poi in lib/services/api_service.dart:

static const String apiKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...';

========================================
```

**Copla la chiave da qualche parte** - te servirà nel passo 3 e 4.

### Passo 2: Copia il Plugin in WordPress

```bash
# Sostituisci /path/to/wordpress con il percorso reale
cp wordpress-plugin/pdg-app-api.php /path/to/wordpress/wp-content/plugins/
```

### Passo 3: Configura wp-config.php

Apri il file `wp-config.php` sulla macchina che ospita WordPress:

```bash
nano /path/to/wordpress/wp-config.php
```

Trova questa riga (verso la fine del file):
```php
/* That's all, stop editing! */
```

Aggiungi PRIMA di questa riga:
```php
// PdG App API - Chiave per autenticazione app mobile
define('PDG_APP_API_KEY', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2');
```

✅ **Salva il file (CTRL+O, INVIO, CTRL+X)**

### Passo 4: Attiva il Plugin da WordPress Admin

1. Accedi al tuo WordPress Admin:
   - URL: `https://www.portobellodigallura.it/wp-admin/`

2. Vai a **Plugin** (menu a sinistra)

3. Nella lista "Plugin installati", cercaci "PdG App API"

4. Se vedi il plugin, clicca **Attiva**

   ![Plugin Screenshot](./docs/plugin-activate.png)

5. Dovresti vedere: ✅ **PdG App API** is activated

---

## Configurazione API Key

### Passo 5: Aggiorna lib/services/api_service.dart

Apri il file `lib/services/api_service.dart` nel progetto Flutter:

Cerca questa riga (circa linea 22):
```dart
static const String apiKey = 'CHANGE_ME_IN_WP_CONFIG';
```

Sostituiscila con:
```dart
static const String apiKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2';
```

⚠️ **IMPORTANTE**: Usa la STESSA chiave che hai generato nel Passo 1

✅ **Salva il file**

---

## Configurazione App Flutter

### Passo 6: Verifica l'import in main.dart

Il file `lib/main.dart` dovrebbe già contenere:

```dart
import 'package:condominio/services/api_service.dart';
```

Se non c'è, aggiungilo tra gli altri import.

### Passo 7: Compila e Testa

```bash
# Da dentro la cartella del progetto Flutter
flutter clean
flutter pub get
flutter run
```

---

## Test e Verifica

### Test 1: Verifica Plugin Attivo (Linea di Comando)

```bash
curl -X GET https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2" \
  -H "Authorization: Bearer DUMMY_TOKEN" \
  -v
```

**Output atteso:**
```
< HTTP/1.1 401 Unauthorized
```

Questo è corretto! Significa che il plugin è attivo e richiede un token valido.

### Test 2: Login via API (Linea di Comando)

Sostituisci USERNAME e PASSWORD con credenziali WordPress reali:

```bash
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2" \
  -d '{"username":"WORDPRESS_USERNAME","password":"WORDPRESS_PASSWORD"}' \
  -v
```

**Output atteso:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "WORDPRESS_USERNAME",
    "display_name": "Display Name"
  },
  "token": "abc123def456...",
  "expiry": 1705123456
}
```

### Test 3: Carica Post con Token (Linea di Comando)

Sostituisci TOKEN con il valore ricevuto nel Test 2:

```bash
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2" \
  -H "Authorization: Bearer TOKEN" \
  -v
```

**Output atteso:**
```json
{
  "posts": [
    {
      "id": 1,
      "title": {"rendered": "Titolo Post"},
      "content": {"rendered": "..."},
      ...
    }
  ],
  "current_page": 1
}
```

### Test 4: Testa l'App Flutter

1. Avvia l'app sul tuo dispositivo/emulatore
2. Accedi con le credenziali WordPress
3. Dovresti vederedei post nella home

Se vedi post = **✅ Plugin funziona correttamente!**

---

## Flusso di Dati Dopo Setup

```
┌─────────────────────────────────────────────────────────────┐
│                      APP FLUTTER                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1️⃣  User Login → ApiService.login(username, password)     │
│                                                               │
│  2️⃣  ApiService invia POST /auth                            │
│      Header: x-pdg-api-key + credenziali                    │
│                                                              │
│  3️⃣  Plugin riceve richiesta                                │
│      ├─ Valida API Key ✅                                   │
│      ├─ Verifica credenziali contro DB ✅                   │
│      ├─ Genera token JWT ✅                                 │
│      └─ Ritorna token all'app                               │
│                                                              │
│  4️⃣  App salva token in SharedPreferences                   │
│                                                              │
│  5️⃣  App chiede post: GET /posts                            │
│      Header: x-pdg-api-key + Authorization: Bearer token    │
│                                                              │
│  6️⃣  Plugin riceve richiesta                                │
│      ├─ Valida API Key ✅                                   │
│      ├─ Verifica token ✅                                   │
│      ├─ Filtra per permessi PublishPress ✅                │
│      └─ Ritorna post leggibili all'app                      │
│                                                              │
│  7️⃣  App mostra post in home                                │
│                                                              │
│  ⏰  Ogni 3 secondi: Refresh post (usa token memorizzato)   │
│  🔄  Ogni 30 giorni: Token scade, app riautentica           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### ❌ Plugin non appare in WordPress Admin

**Causa**: File non copiato correttamente

**Soluzione**:
```bash
# Verifica che il file esista
ls -la /path/to/wordpress/wp-content/plugins/ | grep pdg

# Se manca, ricopia
cp wordpress-plugin/pdg-app-api.php /path/to/wordpress/wp-content/plugins/
```

### ❌ Errore 403 nel Test 1

**Causa**: API Key non configurata o non corrisponde

**Soluzione**:
1. Verifica che wp-config.php abbia la riga `define('PDG_APP_API_KEY', '...')`
2. Verifica che sia la STESSA chiave del curl command
3. Controlla che NON ci siano spazi extra

### ❌ Errore 401 nel Test 2

**Causa**: Credenziali non valide

**Soluzione**:
1. Verifica che USERNAME e PASSWORD siano corretti
2. Accedi a WordPress con queste credenziali per verificare
3. Se non ricordi la password, resettala da WordPress Admin

### ❌ Token non salvato nell'app

**Causa**: SharedPreferences non funziona

**Soluzione**:
1. Controlla che il plugin `shared_preferences` sia installato: `flutter pub get`
2. Ripulisci cache: `flutter clean && flutter pub get`
3. Ricrea l'app: `flutter run`

### ❌ App mostra "errore caricamento post"

**Causa**: Plugin API non raggiungibile

**Soluzione**:
1. Verifica che WordPress sia online: `ping www.portobellodigallura.it`
2. Verifica che il plugin sia attivato da WordPress Admin
3. Prova il Test 1 da terminale per isolare il problema
4. Controlla `wp-content/debug.log` su WordPress per errori

### ❌ Errore 429 Too Many Requests

**Causa**: Troppi tentativi di login falliti

**Soluzione**:
```
Aspetta 15 minuti oppure esegui da WordPress (WP-CLI):

wp post meta delete --meta-key='pdg_app_auth_fail_*'
```

---

## Checklist Finale

Prima di considerare il setup completato, verifica:

- [ ] Chiave API generata con `generate-api-key.php`
- [ ] Plugin copiato in `wp-content/plugins/`
- [ ] `wp-config.php` contiene `define('PDG_APP_API_KEY', '...')`
- [ ] Plugin attivato da WordPress Admin
- [ ] `lib/services/api_service.dart` aggiornato con la stessa chiave
- [ ] Progetto Flutter compilato senza errori
- [ ] Test 1 (categories endpoint) ritorna 401 ✅
- [ ] Test 2 (login) ritorna token ✅
- [ ] Test 3 (posts) ritorna lista post ✅
- [ ] App Flutter mostra post dopo login ✅

---

## 📚 Documentazione Completa

Per più dettagli, vedi:

- **PLUGIN_SETUP.md** - Guida installazione plugin
- **CHANGES_SUMMARY.md** - Modifiche al codice Flutter
- **wordpress-plugin/README.md** - Documentazione API dettagliata

---

## 🆘 Support

Se hai problemi:

1. **Controlla i log**:
   - WordPress: `wp-content/debug.log`
   - Flutter: Logcat/Xcode

2. **Ripeti i test da linea di comando** per isolare il problema

3. **Verifica le istruzioni step-by-step** di questo documento

4. **Contatta lo sviluppatore** con:
   - Output degli errori
   - Risultati dei test da linea di comando
   - Screenshot della sezione problematica

---

## ✅ Completato!

Se sei arrivato qui e tutti i test passano, il tuo sistema è pronto per l'uso in produzione! 🎉

Per domande sugli aggiornamenti futuri, consulta la sezione "Prossimi Passi" in CHANGES_SUMMARY.md.
