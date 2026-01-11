# 🚀 Risolvi il Problema dei Post Vuoti con Plugin Deployayo

## 📋 Situazione Attuale
- ✅ Login funziona (token ricevuto)
- ❌ Post non vengono caricati (array vuoto)
- 🎯 Causa: L'utente PdGadmin potrebbe non avere permessi di lettura sui post

## 🔧 Soluzione in 3 Step

### STEP 1: Aggiorna il Plugin con Debug
Il plugin è stato aggiornato con un endpoint `/debug` per testare lo stato.

**File modificato**: `wordpress-plugin/pdg-app-api.php`

### STEP 2: Carica il Plugin su WordPress

1. **Accedi via SSH al server:**
   ```bash
   ssh user@portobellodigallura.it
   cd /var/www/wordpress/wp-content/plugins
   ```

2. **Sostituisci il file plugin:**
   ```bash
   cp /path/locale/pdg-app-api.php ./pdg-app-api.php
   chmod 644 pdg-app-api.php
   ```

3. **Oppure via FTP:**
   - Scarica `wordpress-plugin/pdg-app-api.php`
   - Caricalo in `/wp-content/plugins/pdg-app-api.php` sul server

### STEP 3: Testa il Plugin con l'Endpoint di Debug

#### Opzione A: Da Applicazione Flutter (consigliato)
Nel `main.dart`, aggiungi temporaneamente un pulsante:

```dart
ElevatedButton(
  onPressed: () async {
    final results = await DebugApiService.testPluginAPI();
    DebugApiService.analyzeTestResults(results);
  },
  child: const Text('🔍 Testa Plugin API'),
)
```

Poi:
1. Accedi all'app con PdGadmin
2. Clicca il pulsante "Testa Plugin API"
3. Guarda i log in Flutter console

#### Opzione B: Da Linea di Comando (curl)
```bash
# Recupera un token prima (fai il login tramite app o API)
TOKEN="abc123..."  # Token ottenuto dal login

curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/debug' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -v
```

**Risposta attesa:**
```json
{
  "status": "ok",
  "user": {
    "id": 2,
    "login": "pdgadmin",
    "display_name": "PdG Admin",
    "roles": ["administrator"]
  },
  "posts_found": 5,
  "posts_per_page": 5,
  "readable_posts_count": 5,
  "sample_posts": [
    {
      "id": 1,
      "title": "Post di Test",
      "status": "publish",
      "user_can_read": true
    }
  ]
}
```

## 📊 Interpretazione Risultati

### ✅ Caso 1: `readable_posts_count > 0`
**Bene!** Il plugin funziona. I post non caricano per altre ragioni:
- Controlla che l'app chiami correttamente `apiService.fetchPosts()`
- Verifica nella console se ci sono errori di parsing

### ⚠️ Caso 2: `readable_posts_count == 0` ma `posts_found > 0`
**Il problema è qui!** L'utente non ha permessi:

**Soluzione:**
1. Accedi a WordPress Admin
2. Vai a **Utenti** → **PdGadmin**
3. Scroll a **PublishPress Permissions**
4. Assicurati che l'utente abbia accesso a tutte le categorie

### ⚠️ Caso 3: `posts_found == 0`
**Nessun post nel database!**

**Soluzione:**
1. Crea almeno un post di test
2. Assicurati che sia "Published"
3. Riprova il test

## 🛠️ Troubleshooting Avanzato

### Il plugin non risponde (errore 403)
**Problema**: API Key non corretta o plugin non attivato

**Soluzione**:
```bash
# SSH sul server
cd /var/www/wordpress

# Verifica che il plugin sia attivo
wp plugin list | grep pdg-app

# Se non è attivo:
wp plugin activate pdg-app-api

# Verifica che la API key sia in wp-config.php
grep PDG_APP_API_KEY wp-config.php
```

### Il token scade subito
**Problema**: Token JWT ha scadenza breve

**Soluzione**: Nel plugin, il token è valido per 30 giorni. Se vedi errori 401 dopo poco:
```php
// Aggiungi al wp-config.php per estendere la durata (temp):
define('PDG_APP_TOKEN_DURATION_DAYS', 60);

// Nel plugin, modifica la riga 187:
$exp = time() + (defined('PDG_APP_TOKEN_DURATION_DAYS') ? defined('PDG_APP_TOKEN_DURATION_DAYS') * DAY_IN_SECONDS : 30 * DAY_IN_SECONDS);
```

## 📝 Checklist Finale

- [ ] Plugin `pdg-app-api.php` caricato su server
- [ ] Plugin attivato da WordPress Admin
- [ ] API Key in `wp-config.php` corretta
- [ ] Almeno 1 post pubblicato nel database
- [ ] Utente PdGadmin ha permessi su almeno una categoria
- [ ] Test API debug ritorna post leggibili > 0
- [ ] App Flutter carica con successo i post

## 🎯 Prossimi Step

Una volta che il test API ritorna post leggibili:

1. **Verifica che l'app chiami correttamente il plugin**:
   - Apri la console Flutter
   - Guarda se `_tryFetchPostsViaPluginApi()` viene chiamato
   - Controlla se riceve i dati

2. **Se l'app riceve dati ma non li mostra**:
   - Verifica la logica di rendering
   - Controlla che `posts` sia aggiornato con `setState()`

3. **Se tutto funziona**:
   - Rimuovi l'endpoint debug dal plugin per sicurezza
   - Pubblicare l'aggiornamento

---

**Hai domande?** Contattami con i risultati del test debug!
