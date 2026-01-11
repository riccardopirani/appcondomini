# 📋 FIX CATEGORIE - Guida Completa Step by Step

## 🎯 Problema
I post non mostravano la categoria ("Senza categoria" su tutti i post).

## ✅ Soluzione Implementata

### Step 1: Plugin API - Aggiungi Campo `categories`

**File**: `wordpress-plugin/pdg-app-api.php`

**Modifica**: Funzione `pdg_app_format_post()` (linea ~385)

**Cosa aggiunto**:
```php
// 🔥 Estrai categorie dal post
$categories = [];
$post_categories = get_the_category($post->ID);
if (!empty($post_categories) && !is_wp_error($post_categories)) {
    foreach ($post_categories as $cat) {
        $categories[] = (int) $cat->term_id;
    }
}

// Nel return array aggiunto:
'categories' => $categories, // 🔥 NUOVO: ID delle categorie
```

**Effetto**: Ora ogni post ritornato dal plugin API include gli ID delle categorie in cui si trova.

---

### Step 2: Flutter - Metodo Arricchimento Categorie

**File**: `lib/main.dart`

**Nuovo Metodo**: `_enrichPostsWithCategories()` (linea ~5783)

**Cosa fa**:
1. Carica tutte le categorie disponibili dal plugin API
2. Per ogni post ricevuto:
   - Se non ha `_embedded.wp:term` (categorie standard REST)
   - Legge gli ID dal campo `categories` aggiunto dal plugin
   - Mappa gli ID alle info categoria (nome, slug, etc.)
   - Aggiunge la struttura `_embedded.wp:term` al post
3. Ritorna i post arricchiti

**Log dettagliato per debug**:
```
🏷️ Arricchimento post con categorie dal plugin API...
🏷️ Categorie caricate: 5
   - Breaking News (ID: 1)
   - Comunicati (ID: 2)
   - ...
🔍 Post: "Titolo Post"
   - Ha _embedded? false
   - Ha wp:term? false
   - Ha categories field? true
   - Category IDs: [1, 2]
   - Mapping ID 1 -> Breaking News
   - Categorie mappate: 2
  ✅ Post arricchito con 2 categorie: Breaking News, Comunicati
🏷️ Arricchimento completato: 15 post
```

---

### Step 3: Flutter - Modifica `_processPosts()` per usare Arricchimento

**File**: `lib/main.dart`

**Modifica**: Funzione `_processPosts()` (linea ~5841)

**Cosa cambia**:
- Ora è `async` (era `void`)
- Se utente è autenticato, chiama `await _enrichPostsWithCategories()`
- Processa i post arricchiti

**Codice**:
```dart
Future<void> _processPosts(List<dynamic> data) async {
  // ...
  // 🔥 ARRICCHISCI CON CATEGORIE SE AUTENTICATO
  List<dynamic> processedData = data;
  if (apiService.isAuthenticated) {
    processedData = await _enrichPostsWithCategories(data);
  }
  
  // Continua con processedData anziché data
  // ...
}
```

**Impatto**: Tutte le 6 chiamate a `_processPosts()` ora usano `await`.

---

### Step 4: Flutter - Migliora `_loadPostsByCategory()`

**File**: `lib/main.dart`

**Modifica**: Funzione `_loadPostsByCategory()` (linea ~1115)

**Cosa cambia**:
- Quando carica post per una categoria, aggiunge la struttura `_embedded.wp:term`
- Così il post ha le categorie anche quando caricato tramite filtro categoria

---

## 🔄 Flusso Completo

```
1. App avvia → _initializeData()
   ↓
2. fetchPosts() → carica post da plugin API
   ↓
3. _processPosts(data) → async, chiama:
   ├─ _enrichPostsWithCategories(data)
   │  ├─ Carica categorie dal plugin
   │  ├─ Per ogni post:
   │  │  ├─ Legge field 'categories': [1, 2, ...]
   │  │  ├─ Mappa IDs a info categorie
   │  │  └─ Aggiunge _embedded.wp:term
   │  └─ Ritorna post arricchiti
   └─ Salva post nello state
   ↓
4. _buildCategoryMap() → estrae categorie da _embedded
   ↓
5. ModernArticlesScreen → mostra post con categorie
   ├─ _buildArticleCard() → legge da post['_embedded']['wp:term'][0]
   └─ Mostra categoria nel UI ✅
```

---

## 🧪 Test Manuale

### Test 1: Verifica Log
1. Accedi all'app
2. Vai a NEWS/ARTICOLI
3. **Attendi** il caricamento (non salta subito)
4. **Apri Console Debug** (terminal con Flutter run)
5. Guarda i log:
   - `🏷️ Arricchimento post con categorie dal plugin API...`
   - `🏷️ Categorie caricate: X`
   - `🔍 Post: "Titolo Post"`
   - `✅ Post arricchito con N categorie: ...`

### Test 2: Verifica UI
1. Guarda i post nella lista
2. Ogni post deve mostrare UNA categoria (blu, sotto al titolo)
3. Click su categoria → filtra i post
4. Ogni post nella categoria deve avere categoria mostrata

### Test 3: Verifica Per-Categoria
1. Click su una categoria
2. Vedi "Caricamento post per categoria: ..."
3. Post caricati mostrano la categoria

---

## 📊 Struttura Dati

### Prima (POST dal REST standard)
```json
{
  "id": 1,
  "title": {"rendered": "Titolo"},
  "_embedded": {
    "wp:term": [[
      {"id": 1, "name": "Breaking News", "slug": "breaking-news"}
    ]]
  }
}
```

### Dopo Plugin v3.2 (POST dal plugin API custom)
```json
{
  "id": 1,
  "title": {"rendered": "Titolo"},
  "categories": [1, 2],  // 🔥 NUOVO CAMPO
  "_embedded": null      // ← Ma Flask lo aggiunge qui
}
```

### Dopo Arricchimento in Flutter
```json
{
  "id": 1,
  "title": {"rendered": "Titolo"},
  "categories": [1, 2],
  "_embedded": {         // 🔥 AGGIUNTO DAL FLUTTER
    "wp:term": [[
      {"id": 1, "name": "Breaking News", "slug": "breaking-news"},
      {"id": 2, "name": "Comunicati", "slug": "comunicati"}
    ]]
  }
}
```

---

## 🚀 Deployment

### Step A: Update Plugin su Server
```bash
# Copia il file aggiornato
scp wordpress-plugin/pdg-app-api.php user@server:/var/www/wordpress/wp-content/plugins/

# Da WordPress admin
# Plugins → Plugins Installati → PdG App API → Disattiva & Attiva
```

### Step B: Deploy App Flutter
```bash
flutter clean
flutter pub get
flutter run -v  # Esegui con verbose per vedere i debug log
```

### Step C: Test
1. **Console debug**: Verifica log dettagliato
2. **App UI**: Verifica categoria mostrata
3. **Click categoria**: Verifica filtraggio funziona

---

## ✅ Checklist Verifiche

- [ ] Plugin file aggiornato con `'categories' => $categories`
- [ ] Flutter ha `_enrichPostsWithCategories()` metodo
- [ ] `_processPosts()` è `async` e chiama arricchimento
- [ ] Tutte le 6 chiamate a `_processPosts()` hanno `await`
- [ ] `_loadPostsByCategory()` aggiunge `_embedded` ai post
- [ ] App compilata senza errori di sintassi
- [ ] Log console mostra arricchimento categorie
- [ ] Post mostrano categoria nel UI
- [ ] Click categoria filtra correttamente

---

## 🔍 Debug

Se ancora non vedi categorie:

### Verifica 1: Plugin API ritorna field `categories`?
```bash
# Testa endpoint del plugin
curl -X GET 'https://example.com/wp-json/pdg-app/v1/posts?per_page=1' \
  -H "x-pdg-api-key: KEY" \
  -H "Authorization: Bearer TOKEN" | jq '.[] | .categories'
```
Dovrebbe ritornare: `[1, 2, ...]` (array di IDs)

### Verifica 2: Endpoint `/categories` funziona?
```bash
curl -X GET 'https://example.com/wp-json/pdg-app/v1/categories' \
  -H "x-pdg-api-key: KEY" \
  -H "Authorization: Bearer TOKEN" | jq '.'
```
Dovrebbe ritornare: `[{"id": 1, "name": "Breaking News", ...}, ...]`

### Verifica 3: Console debug mostra arricchimento?
```
Look for: 🏷️ Arricchimento post con categorie dal plugin API...
         🏷️ Categorie caricate: X
         🔍 Post: "Titolo Post"
         ✅ Post arricchito con N categorie
```

Se manca → Utente non autenticato oppure errore nella API

### Verifica 4: Post ha il campo `categories` nel JSON?
In Flutter, aggiungi log:
```dart
debugPrint('Post JSON: ${json.encode(post)}');
```

---

## 📝 Note Importanti

1. **Performance**: L'arricchimento è in-memory, nessun impatto network
2. **Async**: `_processPosts()` è ora async, assicurati tutti gli await siano presenti
3. **Fallback**: Se arricchimento fallisce, ritorna post originali (no crash)
4. **Backward Compatible**: Se POST ha già `_embedded`, non lo modifica
5. **Debug**: Log molto dettagliato, utile per risolvere problemi

---

**Versione**: 3.1 - Categories Fixed  
**Data**: 11 Gennaio 2026  
**Status**: ✅ Pronto per test e deployment
