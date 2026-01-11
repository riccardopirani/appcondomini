# 🔄 Sostituisci LoginScreen - Usa Solo ApiService

Ecco **ESATTAMENTE** cosa fare nel `LoginScreen` di `main.dart`.

---

## 📍 Dove Trovare il LoginScreen

Nel file `lib/main.dart`, cerca:

```dart
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ← MODIFICA QUI
}
```

---

## 🔍 Encuentra la Funzione `handleLogin`

Dentro `_LoginScreenState`, cerca:

```dart
Future<void> handleLogin(String username, String password) async {
  // ← SOSTITUISCI TUTTO QUESTO
}
```

---

## ✂️ Elimina Tutto quello che c'è Dentro

Seleziona **tutto il contenuto** da:
- `if (_isLoading) return;`
- fino a
- `}`

---

## 📝 Sostituisci Con QUESTO Codice

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

## ✅ Verifica che Sia Importato

All'inizio di `main.dart`, verifica che ci sia:

```dart
import 'package:condominio/services/api_service.dart';
```

Se non c'è, aggiungilo!

---

## 📱 Testa Subito

1. Compila: `flutter run`
2. Nel simulatore/dispositivo:
   - Inserisci username (es. `admin`)
   - Inserisci password
   - Clicca Login
3. Guarda i log nel terminale
4. Dovresti vedere:

```
───────────────────────────────────────────────────
🔐 LOGIN SCREEN: Tentativa login
───────────────────────────────────────────────────

═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: admin
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
📊 HTTP Status Code: 200
───────────────────────────────────────────────────
✅ PARSING RISPOSTA
───────────────────────────────────────────────────
🎯 success: true
───────────────────────────────────────────────────
💾 SALVATAGGIO TOKEN
───────────────────────────────────────────────────
⏰ Scadenza: 2025-02-11...
⏱️ Giorni rimanenti: 31
───────────────────────────────────────────────────
✅ LOGIN COMPLETATO CON SUCCESSO!
═══════════════════════════════════════════════════

───────────────────────────────────────────────────
✅ LOGIN SCREEN: Login riuscito!
───────────────────────────────────────────────────
💾 Credenziali salvate per rinnovo token automatico
```

5. Se vedi tutto questo → ✅ **FUNZIONA!**
6. L'app va alla home e carica i post

---

## ❌ Se Non Funziona

### Errore: "apiService not defined"

**Soluzione**: Aggiungi import in cima a `main.dart`:

```dart
import 'package:condominio/services/api_service.dart';
```

### Errore: "401 CREDENZIALI NON VALIDE"

**Soluzione**: Username o password sbagliati
- Accedi a WordPress da browser per verificare
- Usa le **stesse credenziali**

### Errore: "403 ACCESSO NEGATO"

**Soluzione**: API Key errata
- Verifica in `lib/services/api_service.dart` linea 19
- Deve essere: `Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe`
- Deve essere **identica** a `wp-config.php`

### Niente Log Visibile

**Soluzione**: Nel terminale dove hai fatto `flutter run`:
1. Scorri fino a trovare i log
2. Cerca `🔐 INIZIO LOGIN`
3. Leggi tutto quello dopo

---

## 🎯 Cosa Succede Adesso

1. **User inserisce credenziali** → `handleLogin()` viene chiamato
2. **handleLogin chiama** `apiService.login()` ← Una riga sola!
3. **apiService.login() mostra log** di tutto quello che fa
4. **Se successo** → Salva credenziali → Va alla home
5. **Se fallisce** → Mostra errore rosso → Rimane al login

---

## 🔄 Nella Home (initState)

Nel `MyHomePage._MyHomePageState.initState()`, aggiungi:

```dart
@override
void initState() {
  super.initState();
  _initializeApp();
}

Future<void> _initializeApp() async {
  debugPrint('🏠 Home: Inizializzazione...');
  
  // Carica token se salvato
  await apiService.loadToken();
  
  if (apiService.isAuthenticated) {
    debugPrint('✅ Home: Token trovato, carico post');
    await fetchPosts();
  } else {
    debugPrint('⚠️ Home: Token non trovato');
  }
}
```

---

## 📥 Nel fetchPosts

Semplifica il caricamento:

```dart
Future<void> fetchPosts() async {
  try {
    debugPrint('───────────────────────────────────────────────────');
    debugPrint('📥 FETCHPOSTS: Caricamento in corso');
    debugPrint('───────────────────────────────────────────────────');

    if (!apiService.isAuthenticated) {
      debugPrint('❌ Non autenticato, torno al login');
      // Vai al login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // 🔌 USA SOLO QUESTO
    final newPosts = await apiService.fetchPosts(perPage: 50);

    if (newPosts.isNotEmpty) {
      debugPrint('✅ FETCHPOSTS: ${newPosts.length} post caricati');
      
      setState(() {
        posts = newPosts;
        urgentPosts = _extractUrgentPosts(newPosts);
        translatedPosts = newPosts;
        isLoadingPosts = false;
      });
    } else {
      debugPrint('📭 FETCHPOSTS: Nessun post trovato');
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

## 🎬 Flusso Completo

```
┌────────────────┐
│ User apre app  │
└────────┬───────┘
         ↓
┌────────────────────────┐
│ _initializeApp()       │
│ apiService.loadToken() │
└────────┬───────────────┘
         ↓
    Token valido?
    /            \
  SÌ             NO
  /               \
 ↓                 ↓
fetchPosts()   Mostra LoginScreen
               (chiedi credenziali)
                     ↓
               User inserisce dati
                     ↓
               handleLogin()
                     ↓
               apiService.login()
                     ↓
                  ✅ OK?
                  /    \
                SÌ      NO
               /         \
              ↓           ↓
         fetchPosts()  Errore rosso
         (reload)      (retry)
              ↓
            home
         (success!)
```

---

## ✨ Vantaggi

✅ **Semplice** - Tutto in `ApiService`  
✅ **Leggibile** - Una riga: `apiService.login()`  
✅ **Debuggabile** - Log dettagliati  
✅ **Manutenibile** - Solo un posto per il login  
✅ **Riusabile** - `ApiService` può essere usato da altri  
✅ **Testabile** - Testa su terminale prima di compilare  

---

## 🚀 Pronto!

Sostituisci il codice, compila, e testa.

**Tempo**: 5 minuti  
**Difficoltà**: Facile (copia-incolla)  
**Risultato**: Login perfetto! ✅

---

**Prossimo**: Esegui i 3 test da [QUICK_TEST.md](./QUICK_TEST.md)
