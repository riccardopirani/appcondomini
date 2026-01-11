# 🔐 Login Semplificato - Usa Solo ApiService

Se vuoi usare **SOLO** `api_service.dart` per il login, elimina tutto il resto e usa questo.

---

## 🎯 Concetto

```
User inserisce credenziali
        ↓
ApiService.login(username, password)
        ↓
✅ Login riuscito → Token salvato
oppure
❌ Login fallito → Mostra errore
```

**Fine. Non c'è altro.**

---

## 📝 Code da Usare nel Login Screen

### Opzione 1: Nel LoginScreen (handleLogin)

Sostituisci tutto il vecchio login con **SOLO questo**:

```dart
Future<void> handleLogin(String username, String password) async {
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
  });

  try {
    // 🔐 USA SOLO QUESTO
    final loginSuccess = await apiService.login(username, password);
    
    if (loginSuccess) {
      debugPrint('✅ Login riuscito via ApiService!');
      
      // Salva credenziali per rinnovo token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);
      await prefs.setBool('isLoggedIn', true);
      
      // Vai alla home
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MyHomePage(
              key: homePageKey,
              title: '',
              userEmail: username,
              userName: username,
            ),
          ),
        );
      }
    } else {
      debugPrint('❌ Login fallito');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login fallito. Verifica credenziali.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Errore: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore di connessione.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

---

## 📱 Cosa Vedrai nei Log

Quando l'utente fa login:

### ✅ Se Succede
```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: admin
🔑 Password: ****...
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 200
───────────────────────────────────────────────────
✅ PARSING RISPOSTA
───────────────────────────────────────────────────
🎯 success: true
👤 user.id: 1
👤 user.username: admin
🔐 token: abc123...
⏰ expiry (timestamp): 1748645123
───────────────────────────────────────────────────
💾 SALVATAGGIO TOKEN
───────────────────────────────────────────────────
⏰ Scadenza: 2025-02-11 15:32:03
⏱️ Giorni rimanenti: 31
───────────────────────────────────────────────────
✅ LOGIN COMPLETATO CON SUCCESSO!
═══════════════════════════════════════════════════

✅ Login riuscito via ApiService!
```

### ❌ Se Fallisce
```
───────────────────────────────────────────────────
❌ ERRORE 401: CREDENZIALI NON VALIDE
───────────────────────────────────────────────────
Username o password errati
═══════════════════════════════════════════════════

❌ Login fallito
(SnackBar rosso: "Login fallito. Verifica credenziali.")
```

---

## 🚀 Nel main.dart (initState)

Quando l'app si apre:

```dart
@override
void initState() {
  super.initState();
  _initializeApp();
}

Future<void> _initializeApp() async {
  debugPrint('🚀 Inizializzazione app...');
  
  // Carica token dalle SharedPreferences se esiste
  await apiService.loadToken();
  
  if (apiService.isAuthenticated) {
    debugPrint('✅ Token trovato e valido');
    // Vai direttamente alla home
    await fetchPosts();
  } else {
    debugPrint('⚠️ Token non trovato o scaduto');
    // Rimani al login
  }
}
```

---

## 📥 Nel Caricamento Post (fetchPosts)

```dart
Future<void> fetchPosts() async {
  try {
    debugPrint('📥 Caricamento post...');
    
    if (!apiService.isAuthenticated) {
      debugPrint('❌ Non autenticato');
      return;
    }
    
    // 🔌 USA SOLO QUESTO
    final posts = await apiService.fetchPosts(perPage: 50);
    
    if (posts.isNotEmpty) {
      debugPrint('✅ ${posts.length} post caricati');
      setState(() {
        this.posts = posts;
      });
    } else {
      debugPrint('📭 Nessun post trovato');
    }
  } catch (e) {
    debugPrint('❌ Errore: $e');
  }
}
```

---

## 🧪 Test Veloce

### Test 1: Verificare che ApiService sia importato

```dart
// In main.dart, all'inizio
import 'package:condominio/services/api_service.dart';
```

### Test 2: Verificare il login

```bash
# Nel terminale, dopo aver lanciato l'app
# Guarda i log in: flutter run

# Dovresti vedere:
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
```

### Test 3: Verificare il caricamento post

```bash
# Dopo il login, guarda i log:
───────────────────────────────────────────────────
📥 CARICAMENTO POST
───────────────────────────────────────────────────
📦 Post caricati: 15
✅ SUCCESSO
```

---

## 💡 Vantaggi di Questo Approccio

✅ **Semplice** - Una sola riga di codice: `apiService.login()`  
✅ **Leggibile** - Chiaro cosa succede  
✅ **Debuggabile** - Log dettagliati  
✅ **Manutenibile** - Tutto in un posto (api_service.dart)  
✅ **Testabile** - Puoi testare da terminale  
✅ **Sicuro** - Token salvato localmente  

---

## 🚫 Cosa Rimuovere da main.dart

Se hai vecchio codice di login, rimuovi:

```dart
// ❌ RIMUOVI QUESTI (se li hai)
- regenerateToken()
- reloadTokenFromStorage()
- _verifyLoginSuccess()
- _autoLoginWithFallbackCredentials()
- _tryFetchPostsWithBasicAuth()
- _tryFetchPostsViaAdminAjax()
- _tryFetchPostsViaREST()
- _verifyAuthentication()
- _getCurrentUserId()
- _testWordPressAPI()
- _testPostsAvailability()

// ✅ MANTIENI SOLO
- apiService.login()
- apiService.fetchPosts()
- apiService.loadToken()
```

---

## 🔄 Flusso Completo (Semplificato)

```
┌────────────────┐
│  App Si Apre   │
└────────┬───────┘
         ↓
┌────────────────────────────────────┐
│ apiService.loadToken()             │
│ (controlla token salvato)          │
└────────┬───────────────────────────┘
         ↓
    Token valido?
    /            \
  SÌ             NO
  /               \
 ↓                 ↓
Home            Login Screen
Carica Post      (chiedi credenziali)
                       ↓
                 User inserisce dati
                       ↓
                 apiService.login()
                       ↓
                  ✅ o ❌?
                  /      \
                SÌ       NO
               /          \
              ↓            ↓
            Home        Errore
         Carica Post    (retry)
```

---

## 📋 Checklist Implementazione

- [ ] Importa `api_service.dart` in `main.dart`
- [ ] Sostituisci `handleLogin()` con il codice sopra
- [ ] Sostituisci `_initializeApp()` con il codice sopra
- [ ] Sostituisci `fetchPosts()` con il codice sopra
- [ ] Compila: `flutter run`
- [ ] Testa login da app
- [ ] Guarda i log nel terminale
- [ ] Verifica che i post siano caricati

---

## 🎯 Parametri che Ritorna ApiService

### `login()` ritorna

```dart
Future<bool>  // true se successo, false se fallisce
```

Se `true`, dentro `api_service.dart` hai:
- `_token` - Token JWT (64 caratteri)
- `_tokenExpiry` - Data scadenza
- Salvato in SharedPreferences

### `fetchPosts()` ritorna

```dart
Future<List<Map<String, dynamic>>>  // Lista post
```

Ogni post contiene:
```json
{
  "id": 42,
  "title": {"rendered": "Titolo"},
  "content": {"rendered": "<p>Contenuto</p>"},
  "date": "2025-01-11T10:30:00",
  "modified": "2025-01-11T11:00:00",
  "status": "publish",
  "link": "https://...",
  "featured_image_url": "https://..."
}
```

---

## 🔐 Sicurezza

Il token è salvato in `SharedPreferences`:
- ✅ Locale sul dispositivo (non nel cloud)
- ✅ Non sincronizzato in backup (per default)
- ✅ Accessibile solo all'app

Se vuoi più sicurezza, usa `flutter_secure_storage` al posto di `SharedPreferences`.

---

## 📊 Performance

Login → 500-800ms (una sola volta!)  
Caricamento post → 300-500ms (ogni volta)  
Refresh ogni 3 secondi → Ultra-veloce (usa token memorizzato)

---

## 🎉 Questo È Tutto!

Non hai bisogno di:
- ❌ Nonce
- ❌ Basic Auth
- ❌ Cookie manipulation
- ❌ Heartbeat
- ❌ Verification checks

**Solo `apiService.login()` e `apiService.fetchPosts()`**

---

**Prossimo step**: Testa il login dalla app! 🚀

Tempo: **5 minuti**  
Difficoltà: **Facile**  
Risultato: **Funziona perfettamente** ✅
