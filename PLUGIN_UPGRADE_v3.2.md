# 🚀 Plugin API Upgrade - Versione 3.2

## ✨ Novità Principali

### 1. **Supporto Completo Categorie** 🎯
- ✅ Nuovo endpoint `/categories` che ritorna SOLO categorie leggibili
- ✅ Filtra automaticamente per permessi utente (PublishPress)
- ✅ Mostra flag `readable: true/false` per ogni categoria
- ✅ Supporta parametro `include_empty=1` per mostrare categorie vuote

### 2. **Miglior Handling dei Post**
- ✅ Oversampling intelligente (richiede 6x per_page per compensare filtri)
- ✅ Normalizzazione WP_Post/ID robusta
- ✅ Validazione stringhe sicure in `pdg_app_format_post()`
- ✅ Gestione errori migliorata

### 3. **Sicurezza Aumentata**
- ✅ API Key integrata nel file (per facilità, modifica in wp-config.php)
- ✅ Validazione robusta dei token JWT
- ✅ Rate limiting su login (10 tentativi/15 min)
- ✅ Blocco endpoint sensibili per non-admin

---

## 📋 Endpoint Disponibili

### Autenticazione
```
POST /wp-json/pdg-app/v1/auth
Header: x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe
Body: {"username":"admin","password":"password"}
Response: {"token":"...", "expiry":123456}
```

### Post Leggibili
```
GET /wp-json/pdg-app/v1/posts?page=1&per_page=20&category=5
Header: Authorization: Bearer TOKEN
Response: {"posts":[...], "current_page":1}
```

### Categorie Navigabili
```
GET /wp-json/pdg-app/v1/categories?include_empty=0
Header: Authorization: Bearer TOKEN
Response: [
  {"id":1, "name":"News", "readable":true},
  {"id":2, "name":"Avvisi", "readable":false}
]
```

### Singolo Post
```
GET /wp-json/pdg-app/v1/posts/123
Header: Authorization: Bearer TOKEN
Response: {post_data}
```

---

## 🔧 Configurazione

### Step 1: Carica il Plugin
```bash
scp wordpress-plugin/pdg-app-api.php user@server:/var/www/wordpress/wp-content/plugins/
```

### Step 2: Attiva da WordPress Admin
1. Vai a Plugins → Plugins Installati
2. Cerca "PdG App API"
3. Clicca "Attiva"

### Step 3: Configura API Key (Opzionale)
Nel file, la chiave è hardcoded:
```php
define('PDG_APP_API_KEY', 'Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe');
```

Per cambiarla, modifica `wp-config.php`:
```php
define('PDG_APP_API_KEY', 'TUA_CHIAVE_SEGRETA');
```

---

## 📊 Novità Versione 3.2

| Funzionalità | v3.0 | v3.2 | Note |
|--------------|------|------|-------|
| Login JWT | ✅ | ✅ | Identico |
| Post leggibili | ✅ | ✅ | Migliorato |
| Categorie | ❌ | ✅ | **NUOVO** |
| Filtro permessi | ✅ | ✅ | Robusto |
| Sicurezza | ✅ | ✅ | Rate limiting |
| Debug endpoint | ❌ | ❌ | Rimosso (non serve) |

---

## 🎯 Uso delle Categorie

### Nel tuo dart/flutter:

```dart
// 1. Ottieni categorie leggibili
final categories = await apiService.fetchCategories();

// 2. Filtra SOLO leggibili
final readable = categories.where((c) => c['readable'] == true).toList();

// 3. Carica post per categoria
final posts = await apiService.fetchPosts(category: categoryId);
```

### Risposta Categorie:
```json
[
  {
    "id": 1,
    "name": "Breaking News",
    "slug": "breaking-news",
    "parent": 0,
    "readable": true     // ✅ L'utente può leggere post in questa categoria
  },
  {
    "id": 2,
    "name": "Private Area",
    "slug": "private",
    "parent": 0,
    "readable": false    // ❌ L'utente NON ha accesso
  }
]
```

---

## 🔄 Differenze vs Vecchia Versione

### Prima (v3.0)
```
GET /categories
→ Ritorna TUTTE le categorie
→ L'app deve filtrare per leggibilità
→ Complesso per il frontend
```

### Dopo (v3.2)
```
GET /categories
→ Ritorna SOLO categorie leggibili
→ Flag "readable" esplicito
→ Facile da usare nel frontend
```

---

## ✅ Cosa Cambia nell'App

Niente! L'API è **backward compatible**.

Se l'app chiama:
- `/posts` → Funziona come prima ✅
- `/categories` → Adesso ritorna categorie filtrate ✅

Se l'app NON chiama `/categories`, continua a funzionare perfettamente.

---

## 🧪 Test della Nuova Funzionalità

```bash
# 1. Ottieni token
TOKEN=$(curl -s -X POST 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Content-Type: application/json" \
  -d '{"username":"pdgadmin","password":"PASSWORD"}' | jq -r '.token')

# 2. Testa endpoint categorie
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 3. Testa con include_empty
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories?include_empty=1' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

---

## 📈 Performance

- **Sampling intelligente**: Queries 6x per_page per compensare filtri
- **Cache-friendly**: No `no_found_rows` disabilitato → MySQL calcola total
- **Limit categorie**: Max 300 per payload
- **Sample posts**: 8 post per categoria per verificare leggibilità

---

## 🆘 Troubleshooting

### "Categorie non appaiono"
- Verifica che i post abbiano categorie assegnate
- Verifica permessi PublishPress su categoria
- Testa con `include_empty=1` per debug

### "Categoria ritorna readable=false"
- Normale! L'utente non ha permessi
- Verifica PublishPress Permissions
- Controlla che l'utente abbia accesso alla categoria

### "API ritorna errore 403"
- API Key errata
- Check header: `x-pdg-api-key`
- Verifica che sia: `Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe`

---

## 📝 Changelog Completo

### v3.2
- ✅ Nuovo endpoint `/categories` con filtro permessi
- ✅ Flag `readable` per ogni categoria
- ✅ Supporto `include_empty` parameter
- ✅ Validazione robusta WP_Post
- ✅ Oversampling intelligente per post
- ✅ Rimosso endpoint `/debug` (non necessario)

### v3.0
- ✅ Login JWT
- ✅ Post leggibili con PublishPress
- ✅ Singolo post
- ✅ Rate limiting
- ✅ Hardening endpoint sensibili

---

## 🚀 Prossimi Step

1. **Carica il plugin** sul server
2. **Attiva** da WordPress Admin
3. **Testa** l'endpoint `/categories`
4. **Aggiorna l'app** per usare le categorie (opzionale)
5. **Goditi** la nuova funzionalità! 🎉

---

**Versione**: 3.2  
**Data**: 11 Gennaio 2026  
**Status**: ✅ Pronto per il deploy
