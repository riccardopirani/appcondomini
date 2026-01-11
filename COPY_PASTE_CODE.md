# 📋 Copy-Paste Code - Tutto il Codice da Copiare

Copia e incolla questo codice nei posti indicati.

---

## 🔐 1. LoginScreen - handleLogin()

**Dove**: `lib/main.dart` → cerca `handleLogin(String username, String password)`

**Elimina tutto il contenuto** e sostituisci con:

```dart
Future<void> handleLogin(String username, String password) async {
  if (_isLoading) return;

  setState(() {
    _isLoading = true;
  });

  try {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('🔐 LOGIN SCREEN: Tentativa login');
    debugPrint('───────────────────────────────────────────────────');

    // 🔐 USA SOLO APISERVICE
    final loginSuccess = await apiService.login(username, password);

    if (loginSuccess) {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('✅ LOGIN SCREEN: Login riuscito!');
      debugPrint('───────────────────────────────────────────────────');

      // Salva credenziali per rinnovo automatico token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);
      await prefs.setBool('isLoggedIn', true);

      debugPrint('💾 Credenziali salvate per rinnovo token automatico');

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
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('❌ LOGIN SCREEN: Login fallito');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('Vedi log sopra per dettagli');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login fallito. Verifica credenziali.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('❌ LOGIN SCREEN: Eccezione');
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('Errore: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore di connessione. Riprova.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
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

## 🏠 2. MyHomePage.initState()

**Dove**: `lib/main.dart` → cerca `class MyHomePage` e il suo `initState()`

**Sostituisci il contenuto di initState() con:**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  currentLanguage = languageProvider.locale.languageCode;
  languageProvider.addListener(_onLanguageChanged);

  // Inizializza translatedPosts con i post originali se la lingua è italiana
  if (currentLanguage == 'it') {
    translatedPosts = posts;
  }

  _loadNotifiedPostsFromCache();
  _initializeApp();  // ← AGGIUNGI QUESTA RIGA
  _startPeriodicPostsRefresh();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _schedulePendingNotificationNavigation();
  });
}
```

**Aggiungi questa funzione DOPO initState():**

```dart
Future<void> _initializeApp() async {
  debugPrint('───────────────────────────────────────────────────');
  debugPrint('🏠 HOME: Inizializzazione app');
  debugPrint('───────────────────────────────────────────────────');
  
  // Carica token dalle SharedPreferences se esiste
  await apiService.loadToken();
  
  if (apiService.isAuthenticated) {
    debugPrint('✅ HOME: Token trovato e valido');
    await fetchPosts();
  } else {
    debugPrint('⚠️ HOME: Token non trovato o scaduto');
  }
}
```

---

## 📥 3. fetchPosts()

**Dove**: `lib/main.dart` → cerca `Future<void> fetchPosts() async {`

**Sostituisci il contenuto INTERO con:**

```dart
Future<void> fetchPosts() async {
  try {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('📥 FETCHPOSTS: Caricamento in corso');
    debugPrint('───────────────────────────────────────────────────');

    if (!apiService.isAuthenticated) {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('❌ FETCHPOSTS: Non autenticato');
      debugPrint('───────────────────────────────────────────────────');
      return;
    }

    // 🔌 USA SOLO APISERVICE
    final newPosts = await apiService.fetchPosts(perPage: 50);

    if (newPosts.isNotEmpty) {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('✅ FETCHPOSTS: ${newPosts.length} post caricati');
      debugPrint('───────────────────────────────────────────────────');
      
      setState(() {
        posts = newPosts;
        urgentPosts = _extractUrgentPosts(newPosts);
        translatedPosts = newPosts;
        isLoadingPosts = false;
      });

      // Avvia il watcher per notifiche
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null) {
        startUrgentNotificationWatcher(currentContext, newPosts);
        debugPrint('🔔 Watcher urgenti avviato');
      }
    } else {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📭 FETCHPOSTS: Nessun post trovato');
      debugPrint('───────────────────────────────────────────────────');
      setState(() {
        isLoadingPosts = false;
      });
    }
  } catch (e) {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('❌ FETCHPOSTS: Errore');
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('Errore: $e');
    
    setState(() {
      isLoadingPosts = false;
    });
  }
}
```

---

## ✅ 4. Import Necessario

**All'inizio di main.dart**, aggiungi:

```dart
import 'package:condominio/services/api_service.dart';
```

Se è già presente, ok!

---

## 🧪 Dopo il Copy-Paste

1. Compila: `flutter run`
2. Testa login nel simulatore
3. Guarda i log nel terminale
4. Dovresti vedere:
   - ✅ `🔐 INIZIO LOGIN`
   - ✅ `success: true`
   - ✅ `token: abc123...`
   - ✅ `LOGIN COMPLETATO`
   - ✅ Home si apre
   - ✅ `📥 CARICAMENTO POST`
   - ✅ Post caricati

---

## 🎯 Se Vedi Errori

| Errore | Fix |
|--------|-----|
| "apiService not defined" | Aggiungi import: `import 'package:condominio/services/api_service.dart';` |
| "401 CREDENZIALI NON VALIDE" | Username/password errati |
| "403 ACCESSO NEGATO" | API Key sbagliata in `api_service.dart` |
| "Cannot access member" | Salva il file e ricompila |

---

## ✨ Fatto!

3 modifiche, 2 minuti, perfetto!

**Prossimo**: Testa l'app! 🚀

---

Se qualcosa non è chiaro, vedi: **[REPLACE_LOGIN_SCREEN.md](./REPLACE_LOGIN_SCREEN.md)**
