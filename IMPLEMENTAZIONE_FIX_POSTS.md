# 🎯 Implementazione Fix - Post Vuoti con Plugin Deployayo

## 📋 Riepilogo del Problema

La tua app **autentica correttamente gli utenti** ma **non carica i post** dal server usando il plugin API PdG.

```
Login: ✅ Funziona
Token: ✅ Ricevuto
Posts: ❌ Array vuoto []
```

## 🔍 Analisi Root Cause

Dopo analisi del codice, il problema è nel **plugin PdG App API**:

1. ✅ Il plugin autentica correttamente
2. ❌ Quando carica i post, **applica il filtro `current_user_can('read_post', $post_id)`**
3. ❌ Se l'utente non ha permessi, **nessun post viene ritornato**

```php
// Questo è il filtro nel plugin (pdg-app-api.php, linea 257)
if (pdg_app_user_can_read_post($user_id, (int)$p->ID)) {
    $posts[] = pdg_app_format_post($p);  // ← aggiunge solo se leggibile
}
```

## ✨ Soluzione Implementata

Ho creato **3 file di debug e risoluzione**:

### 1️⃣ **Plugin Aggiornato** 
- **File**: `wordpress-plugin/pdg-app-api.php`
- **Cambiamento**: Aggiunto endpoint `/wp-json/pdg-app/v1/debug`
- **Cosa fa**: Mostra se l'utente ha permessi di lettura sui post

### 2️⃣ **Servizio Debug Dart**
- **File**: `lib/services/debug_api_service.dart` ⭐ NUOVO
- **Cosa fa**: Testa il plugin e interpreta i risultati
- **Output**: Log dettagliato dello stato

### 3️⃣ **Guide Complete**
- `DEBUG_PLUGIN_INSTALLATION.md` - Installazione dettagliata
- `RISOLVI_POST_VUOTI.md` - Risoluzione passo per passo
- `PLUGIN_API_FIX_SUMMARY.md` - Riepilogo tecnico

---

## 🚀 Come Implementare (3 Passi Semplici)

### PASSO 1: Carica il Plugin Aggiornato sul Server
**Opzione A (SSH):**
```bash
scp wordpress-plugin/pdg-app-api.php user@portobellodigallura.it:/var/www/wordpress/wp-content/plugins/
```

**Opzione B (FTP):**
- Scarica: `wordpress-plugin/pdg-app-api.php`
- Carica in: `/wp-content/plugins/pdg-app-api.php`

### PASSO 2: Aggiungi un Pulsante di Test Temporaneo nell'App

Nel `main.dart`, dopo il login, aggiungi:

```dart
// Nel build() method, in una sezione di debug (es: dopo login):
Row(
  children: [
    ElevatedButton.icon(
      onPressed: () async {
        final results = await DebugApiService.testPluginAPI();
        if (mounted) {
          DebugApiService.analyzeTestResults(results);
        }
      },
      icon: const Icon(Icons.bug_report),
      label: const Text('🔍 Test Plugin'),
    ),
  ],
)
```

### PASSO 3: Interpreta i Risultati

**Leggi i log di Flutter:**

```
✅ SUCCESSO COMPLETO:
  readable_posts_count: 5
  posts_found: 5
  → Problema è nell'app, non nel server
  
❌ PERMESSI INSUFFICIENTI:
  readable_posts_count: 0
  posts_found: 5
  → Utente PdGadmin non ha permessi
  → Soluzione: accedi a WordPress e configura PublishPress
  
❌ NESSUN POST:
  posts_found: 0
  → Crea un post di test e pubblicalo
```

---

## 📊 Cosa Fa il Debug Endpoint

L'endpoint `/pdg-app/v1/debug` ritorna:

```json
{
  "status": "ok",
  "user": {
    "id": 2,
    "login": "pdgadmin",
    "display_name": "PdG Admin",
    "roles": ["administrator"]
  },
  "posts_found": 5,           // ← Quanti post totali nel DB
  "readable_posts_count": 3,   // ← Quanti di questi può leggere
  "sample_posts": [
    {
      "id": 1,
      "title": "Post Titolo",
      "status": "publish",
      "user_can_read": true     // ← Questo è il check critico
    }
  ]
}
```

---

## 🧪 Come Testare Senza App (opzionale)

Se vuoi testare da terminale:

```bash
# 1. Ottieni un token (simula login)
TOKEN=$(curl -X POST 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth' \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -d '{"username":"pdgadmin","password":"PASSWORD"}' \
  | jq -r '.token')

echo "Token: $TOKEN"

# 2. Testa il debug endpoint
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/debug' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.'
```

---

## ✅ Checklist di Verificazione

**Prima di implementare:**
- [ ] Hai backuppato il plugin originale
- [ ] File `pdg-app-api.php` aggiornato
- [ ] Plugin è stato ricaricato sul server

**Durante il test:**
- [ ] Accedi all'app con PdGadmin
- [ ] Clicchi il pulsante "Test Plugin"
- [ ] Leggi i log di Flutter

**Risultati attesi:**
- [ ] `readable_posts_count > 0` oppure diagnosi chiara del problema
- [ ] Log mostra numero di post nel database
- [ ] Log mostra permessi dell'utente

---

## 🔧 Se Continua a Non Funzionare

### Scenario A: Test ritorna `readable_posts_count: 0`
**Azione**: Configura i permessi PublishPress
```
1. WordPress Admin → Utenti → PdGadmin
2. Scroll a "PublishPress Permissions"
3. Assicurati che l'utente abbia accesso alle categorie
```

### Scenario B: Test ritorna errore 403
**Azione**: Verifica API Key
```bash
ssh user@portobellodigallura.it
grep "PDG_APP_API_KEY" /var/www/wordpress/wp-config.php
# Deve corrispondere alla chiave nel dart: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe
```

### Scenario C: Test ritorna `posts_found: 0`
**Azione**: Crea post di test
```
1. WordPress Admin → Post → Crea nuovo
2. Titolo: "Test Post"
3. Contenuto: "Contenuto di test"
4. Pubblica
```

---

## 🧹 Pulizia Finale

Una volta che il test funziona:

1. **Rimuovi il pulsante di test** dall'app
2. **Rimuovi l'import del debug service**:
   ```dart
   // Rimuovi questa riga dal main.dart
   import 'package:condominio/services/debug_api_service.dart';
   ```
3. **Rimuovi l'endpoint debug dal plugin** (linee 393-460 in `pdg-app-api.php`)
4. **Ricarica il plugin** sul server

---

## 📞 Support

Se hai domande:
1. Controlla i log Flutter durante il test
2. Leggi i messaggi di diagnosi forniti da `DebugApiService.analyzeTestResults()`
3. Consulta la documentazione in `RISOLVI_POST_VUOTI.md`

---

**Versione**: 1.0  
**Data**: 11 Gennaio 2026  
**Status**: 🟢 Pronto per implementazione
