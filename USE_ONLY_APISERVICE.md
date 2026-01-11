# 🎯 Usa SOLO ApiService - Guida Veloce

**Se vuoi usare SOLO `api_service.dart` per il login**, segui questo.

---

## 🔑 Tre Cose da Sapere

### 1️⃣ Nel LoginScreen
```dart
// Sostituisci handleLogin() con:
final loginSuccess = await apiService.login(username, password);

if (loginSuccess) {
  // Vai alla home
} else {
  // Mostra errore
}
```

### 2️⃣ Nella Home (initState)
```dart
// Carica token salvato
await apiService.loadToken();

// Se valido, carica post
if (apiService.isAuthenticated) {
  await fetchPosts();
}
```

### 3️⃣ Nel fetchPosts
```dart
// Carica post con token autenticato
final posts = await apiService.fetchPosts(perPage: 50);

if (posts.isNotEmpty) {
  // Mostra post
} else {
  // Nessun post
}
```

---

## 📋 Step-by-Step

### Passo 1: Aggiungi Import
In `main.dart` all'inizio:
```dart
import 'package:condominio/services/api_service.dart';
```

### Passo 2: Modifica LoginScreen.handleLogin()
Vedi: **[REPLACE_LOGIN_SCREEN.md](./REPLACE_LOGIN_SCREEN.md)**
- Copia il codice da quel file
- Incolla in handleLogin()
- Fatto!

### Passo 3: Modifica MyHomePage.initState()
Aggiungi:
```dart
Future<void> _initializeApp() async {
  await apiService.loadToken();
  if (apiService.isAuthenticated) {
    await fetchPosts();
  }
}

@override
void initState() {
  super.initState();
  _initializeApp();
}
```

### Passo 4: Modifica fetchPosts()
Sostituisci tutto con:
```dart
if (!apiService.isAuthenticated) return;
final posts = await apiService.fetchPosts(perPage: 50);
// setState con i post
```

### Passo 5: Compila e Testa
```bash
flutter run
```

---

## 🔍 Dove Trovare le Istruzioni Dettagliate

| Cosa Fare | Dove Leggere |
|-----------|--------------|
| **Sostituire LoginScreen** | [REPLACE_LOGIN_SCREEN.md](./REPLACE_LOGIN_SCREEN.md) |
| **Capire ApiService** | [LOGIN_SIMPLE.md](./LOGIN_SIMPLE.md) |
| **Testare da terminale** | [QUICK_TEST.md](./QUICK_TEST.md) |
| **Capire i log** | [DEBUGGING_GUIDE.md](./DEBUGGING_GUIDE.md) |
| **Leggere il codice** | `lib/services/api_service.dart` linea 53-157 |

---

## 📊 Metodi Disponibili in ApiService

```dart
// Login
await apiService.login(username, password)  // → bool

// Caricamento dati
await apiService.fetchPosts(perPage: 20)    // → List<Map>
await apiService.fetchPost(id)              // → Map?
await apiService.fetchCategories()          // → List<Map>

// Token management
await apiService.loadToken()                // carica da SharedPreferences
await apiService.logout()                   // rimuove token

// Status
apiService.isAuthenticated                  // → bool (token valido?)
```

---

## ✅ Checklist

- [ ] Importato `api_service.dart` in main.dart
- [ ] Sostituito `handleLogin()` nel LoginScreen
- [ ] Aggiunto `_initializeApp()` nella Home
- [ ] Semplificato `fetchPosts()`
- [ ] Compilato: `flutter run`
- [ ] Testato login da app
- [ ] Visti i log di login riuscito
- [ ] Visti i post caricati
- [ ] Pronto per deployment!

---

## 🎯 Fine!

**3 modifiche, 5 minuti, perfetto.**

```
handleLogin() → apiService.login()
initState() → apiService.loadToken()
fetchPosts() → apiService.fetchPosts()
```

**Fatto!** ✨

---

Per dettagli specifici, vedi: **[REPLACE_LOGIN_SCREEN.md](./REPLACE_LOGIN_SCREEN.md)**
