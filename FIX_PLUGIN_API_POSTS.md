# 🔧 FIX: Plugin API non ritorna i post

## 🚨 Problema
Dopo l'aggiornamento del plugin API a v3.2, l'app non scarica più i post.

## ✅ Causa
Il plugin v3.2 ritorna una risposta strutturata diversamente:
- **OLD (REST standard)**: Array diretto `[{post1}, {post2}, ...]`
- **NEW (Plugin API v3.2)**: Oggetto con chiave `posts`: `{'posts': [{post1}, {post2}, ...], 'current_page': 1, ...}`

## 🔧 Soluzione

### Modifica: `lib/services/api_service.dart`

**Metodo**: `fetchPosts()` (linea ~247)

**Cosa aggiunto**:
1. **Smart Detection**: Rileva se la risposta è un array (REST) o un oggetto (Plugin API)
2. **Dual Support**: Supporta entrambi i formati
3. **Better Logging**: Log dettagliato per debugging

**Codice**:
```dart
// 🔥 Se la risposta è direttamente un array (REST standard)
List<Map<String, dynamic>> posts = [];

if (data is List) {
  debugPrint('✅ Risposta è un ARRAY (REST standard)');
  posts = (data as List).cast<Map<String, dynamic>>();
} else if (data is Map && data.containsKey('posts')) {
  debugPrint('✅ Risposta è un OGGETTO con field "posts" (Plugin API v3.2)');
  final postsList = data['posts'] as List?;
  if (postsList != null) {
    posts = postsList.cast<Map<String, dynamic>>();
  }
} else {
  debugPrint('⚠️ Risposta con struttura sconosciuta: $data');
  return [];
}
```

## 📊 Come Funziona

### Flusso:
```
Plugin API ritorna risposta
  ↓
fetchPosts() riceve risposta
  ↓
Smart Detection:
  ├─ È un List? → REST standard → cast diretto
  ├─ È un Map con 'posts'? → Plugin API v3.2 → estrai field 'posts'
  └─ Altro? → Errore sconosciuto → return []
  ↓
Ritorna posts list
```

### Strutture Supportate:

**REST Standard** (WP REST API):
```json
[
  {"id": 1, "title": {"rendered": "Post 1"}, ...},
  {"id": 2, "title": {"rendered": "Post 2"}, ...}
]
```

**Plugin API v3.2**:
```json
{
  "posts": [
    {"id": 1, "title": {"rendered": "Post 1"}, "categories": [1, 2], ...},
    {"id": 2, "title": {"rendered": "Post 2"}, "categories": [3], ...}
  ],
  "current_page": 1,
  "note": "Total/pages are approximate due to permission filtering"
}
```

## 📋 Log Debug Completo

Adesso il log mostra:
```
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA DAL PLUGIN
───────────────────────────────────────────────────
Tipo risposta: Map or List
Keys risposta: ['posts', 'current_page', 'note'] or null
✅ Risposta è un OGGETTO con field "posts" (Plugin API v3.2)
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
  ID: 123
  Titolo: Titolo del primo post
  Data: 2026-01-10T10:30:00
  Status: publish
  Categories: [1, 2]
Post 2:
  ID: 456
  Titolo: Titolo del secondo post
  Data: 2026-01-09T15:45:00
  Status: private
  Categories: [3]
... e altri 13 post
```

## 🧪 Test

### Test 1: Verifica Plugin Ritorna Dati
```bash
TOKEN="your_jwt_token"
API_KEY="Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe"

curl -X GET 'https://example.com/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

Dovrebbe ritornare:
```json
{
  "posts": [...],
  "current_page": 1,
  "note": "..."
}
```

### Test 2: Verifica Console Debug
1. Accedi app
2. Vai NEWS/ARTICOLI
3. Guarda console debug
4. Dovrebbe mostrare:
   ```
   ✅ Risposta è un OGGETTO con field "posts" (Plugin API v3.2)
   📦 Post caricati: X
   ```

### Test 3: Verifica Post Mostrati
1. Post devono apparire nella lista
2. Ogni post deve avere categoria (se assegnata)
3. Click categoria deve filtrare

## ✅ Checklist

- [x] Smart detection per entrambi i formati
- [x] Support REST API standard (fallback)
- [x] Support Plugin API v3.2 (nuovo)
- [x] Log dettagliato per debugging
- [x] Error handling robusto
- [x] Nessun errore di compilazione
- [ ] Test su device reale
- [ ] Deploy su production

## 🚀 Deployment

### Step 1: Update Flutter Code
```bash
# Il codice è già aggiornato in api_service.dart
flutter clean
flutter pub get
flutter run
```

### Step 2: Test
1. Accedi all'app
2. Verifica che post vengono caricati
3. Guarda console debug per log dettagliato

### Step 3: Se Ancora Non Funziona

**Verifica Plugin su Server**:
```bash
# Verifica che il plugin è aggiornato
curl -X GET 'https://example.com/wp-json/pdg-app/v1/posts?per_page=1' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer TOKEN"

# Se ritorna array [] anziché oggetto, plugin non è aggiornato su server!
```

## 📝 Note Importanti

1. **Backward Compatible**: Supporta sia REST che Plugin API
2. **Smart Detection**: Rileva automaticamente il formato della risposta
3. **Fallback**: Se formato sconosciuto, ritorna array vuoto (no crash)
4. **Categories**: Incluso il field `categories` dal Plugin v3.2

---

**Versione**: 1.0 - Plugin API v3.2 Support  
**Data**: 11 Gennaio 2026  
**Status**: ✅ Ready for Testing
