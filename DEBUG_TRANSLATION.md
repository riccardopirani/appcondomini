# 🐛 Debug Traduzione Post

## 📱 Come Testare

### 1. Esegui l'app con debug attivo
```bash
flutter run
```

### 2. Apri la Console/Terminale per vedere i log

Dovresti vedere log come questi:

```
🌍 Inizio traduzione 10 post in en
📝 Traduco post 1/10...
Tradotto: "Benvenuti nel condominio" → "Welcome to the condominium"
📝 Traduco post 2/10...
Tradotto: "Regolamento interno" → "Internal regulations"
...
✅ Traduzione completata! 10 post tradotti
```

### 3. Test nel Simulatore/Dispositivo

1. **Avvia l'app**
2. **Login** (se necessario)
3. **Vai nella sezione Articoli** 
4. **Apri il menu laterale** (icona ☰)
5. **Clicca su "Lingua"**
6. **Seleziona "English"**
7. **Osserva:**
   - Loading indicator (3-5 secondi)
   - Log nella console
   - Post tradotti

## 🔍 Cosa Controllare nei Log

### ✅ Se tutto funziona:
```
🔄 Cambio lingua da it a en
🌍 Inizio traduzione 10 post in en
📝 Traduco post 1/10...
Tradotto: "Ciao" → "Hello"
📝 Traduco post 2/10...
Tradotto: "Grazie" → "Thank you"
✅ Traduzione completata! 10 post tradotti
```

### ❌ Se c'è un errore API:
```
Errore API MyMemory: 403 - {"error": "Quota exceeded"}
```
**Soluzione**: Aspetta qualche ora (limite 10k caratteri/giorno)

### ❌ Se c'è un errore di rete:
```
Errore traduzione: SocketException: Failed host lookup
```
**Soluzione**: Verifica la connessione internet

### ❌ Se i post non hanno contenuto:
```
Tradotto: "" → ""
```
**Soluzione**: I post sono vuoti o mal formattati

## 🧪 Test Manuale API

Per testare l'API direttamente:

```bash
# Test traduzione IT → EN
curl "https://api.mymemory.translated.net/get?q=Benvenuto&langpair=it|en"

# Dovresti vedere:
# {"responseData":{"translatedText":"Welcome",...}
```

## 🔧 Problemi Comuni

### 1. "I post sono in italiano anche dopo il cambio lingua"

**Possibili cause:**
- Cache attiva → Chiudi e riapri l'app
- Errore silenzioso → Controlla i log
- Post non caricati → Verifica che ci siano post

**Debug:**
```dart
// In _buildArticleCard(), stampa:
debugPrint('Post title: ${post['title']['rendered']}');
```

### 2. "Loading infinito"

**Possibili cause:**
- Timeout API (10 sec)
- Troppi post da tradurre
- Connessione lenta

**Soluzione:**
Riduci il timeout o limita i post:
```dart
.timeout(const Duration(seconds: 5))
```

### 3. "API risponde ma i post rimangono in italiano"

**Possibili cause:**
- `translatedPosts` non viene usato
- `_filterPosts()` usa ancora `widget.posts`

**Verifica:**
```dart
// In _buildArticleCard
debugPrint('Usando translatedPosts: ${translatedPosts.length}');
```

## 🎯 Test Step-by-Step

### Test 1: Verifica che l'API funzioni
```bash
curl "https://api.mymemory.translated.net/get?q=Ciao&langpair=it|en"
```
✅ **Aspettato**: `{"responseData":{"translatedText":"Hello",...}`

### Test 2: Verifica che `translateText` funzioni
Aggiungi questo codice temporaneo in `initState`:
```dart
translateText("Prova", "en").then((result) {
  debugPrint("TEST: Prova → $result");
});
```
✅ **Aspettato**: `TEST: Prova → Test`

### Test 3: Verifica che i post abbiano contenuto
```dart
debugPrint('Post 1 title: ${widget.posts[0]['title']['rendered']}');
```
✅ **Aspettato**: Il titolo del primo post

### Test 4: Verifica che `translatedPosts` venga popolato
```dart
// In _translatePostsOnInit dopo traduzione:
debugPrint('Translated posts: ${translatedPosts.length}');
debugPrint('First title: ${translatedPosts[0]['title']['rendered']}');
```
✅ **Aspettato**: Numero di post e titolo tradotto

### Test 5: Verifica che la UI usi `translatedPosts`
Cerca nel codice:
```dart
grep "translatedPosts" lib/main.dart
```
✅ **Aspettato**: Usato in `_buildCategoryMap()` e `_filterPosts()`

## 📊 Checklist Diagnosi

- [ ] L'API MyMemory risponde (test curl)
- [ ] L'app stampa i log di traduzione (🌍 📝 ✅)
- [ ] I post originali hanno contenuto
- [ ] `translatedPosts` viene popolato
- [ ] `_filterPosts()` usa `translatedPosts`
- [ ] `_buildArticleCard()` riceve post tradotti
- [ ] La UI si aggiorna (loading indicator)
- [ ] La connessione internet funziona

## 🚑 Fix Rapidi

### Fix 1: Forza rebuild completo
```dart
// In _onLanguageChanged, dopo setState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  setState(() {});
});
```

### Fix 2: Aumenta timeout
```dart
.timeout(const Duration(seconds: 30))
```

### Fix 3: Traduci solo titolo ed estratto
```dart
// Commenta la traduzione del content:
// if (post['content']?['rendered'] != null) { ... }
```

### Fix 4: Test con meno post
```dart
// Prendi solo i primi 3 post
final postsToTranslate = widget.posts.take(3).toList();
```

## 📞 Se Ancora Non Funziona

1. **Cattura screenshot dei log**
2. **Verifica response API**:
   ```bash
   curl "https://api.mymemory.translated.net/get?q=Test&langpair=it|en" | jq
   ```
3. **Controlla che Flutter sia aggiornato**:
   ```bash
   flutter doctor
   ```
4. **Prova con un post hardcoded**:
   ```dart
   final testPost = {
     'title': {'rendered': 'Ciao'},
     'excerpt': {'rendered': 'Mondo'}
   };
   final translated = await translatePost(testPost, 'en');
   debugPrint('Translated: ${translated['title']['rendered']}');
   ```

---

**Debug completato**: I log ti diranno esattamente dove è il problema! 🎯

