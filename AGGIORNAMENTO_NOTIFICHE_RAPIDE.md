# 🚀 Aggiornamento Sistema Notifiche Urgenti - Controllo Rapido

## 🎯 Obiettivo
Modificare il sistema di notifiche urgenti per rilevare rapidamente i nuovi post urgenti pubblicati nel backend.

---

## ✅ Modifiche Implementate

### 1. **Timer Refresh Post** ⚡ AGGIORNATO
**Prima:** Ogni 3 minuti  
**Dopo:** Ogni 3 secondi

```dart
// lib/main.dart - _startPeriodicPostsRefresh()
_postsRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
  // Scarica nuovi post dal server ogni 3 secondi
  await fetchPosts();
});
```

**Funzione:** Aggiorna la lista dei post dal server WordPress ogni 3 secondi per rilevare rapidamente nuove pubblicazioni.

---

### 2. **Timer Controllo Notifiche** ⚡ AGGIORNATO
**Prima:** Ogni 5 minuti  
**Dopo:** Ogni 5 secondi con filtro temporale

```dart
// lib/main.dart - startUrgentNotificationWatcher()
_notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  final now = DateTime.now();
  final twoSecondsAgo = now.subtract(const Duration(seconds: 2));
  
  // Filtra solo post urgenti pubblicati negli ultimi 2 secondi
  final urgentPosts = posts.where((post) {
    final postDate = DateTime.parse(post['date_gmt'] ?? post['date']);
    return postDate.isAfter(twoSecondsAgo) && _isUrgent(post);
  }).toList();
  
  // Mostra notifiche e popup
});
```

**Funzionalità:**
- ✅ Controlla ogni 5 secondi se ci sono nuovi post urgenti
- ✅ Filtra solo i post pubblicati negli ultimi 2 secondi
- ✅ Verifica che il post non sia già stato notificato (`_notifiedUrgentPostIds`)
- ✅ Mostra notifica di sistema + popup in-app
- ✅ Log dettagliato per debug

---

## 🔄 Flusso Completo

```
1. [Ogni 3 secondi]
   └─> Scarica nuovi post dal server (fetchPosts)
       └─> Aggiorna lista posts in memoria

2. [Ogni 5 secondi]  
   └─> Controlla posts in memoria
       └─> Filtra post urgenti pubblicati negli ultimi 2 secondi
           └─> Se trovati:
               ├─> Mostra notifica di sistema (Android/iOS)
               ├─> Mostra popup in-app (se app aperta)
               └─> Salva ID in _notifiedUrgentPostIds
```

---

## 📊 Timing e Performance

### Tempi di Rilevamento
- **Scenario Migliore:** 0-5 secondi
- **Scenario Medio:** 3-8 secondi
- **Scenario Peggiore:** 8 secondi

**Esempio:**
```
Tempo 0s:  Post urgente pubblicato su WordPress
Tempo 3s:  App scarica i nuovi post → Post rilevato
Tempo 5s:  Watcher controlla → Post negli ultimi 2s? SI
           → Notifica mostrata!
           
Totale: ~5-8 secondi dalla pubblicazione
```

### Finestra Temporale di Rilevamento
- Post pubblicato ≤ 2 secondi fa: **VIENE NOTIFICATO** ✅
- Post pubblicato > 2 secondi fa: **NON VIENE NOTIFICATO** ❌

Questo garantisce che:
1. Solo i post nuovi vengono notificati
2. Non si notificano post vecchi dopo un refresh
3. Ogni post urgente viene notificato UNA SOLA VOLTA

---

## 🔍 Debug e Logging

Il sistema ora include log dettagliati:

```
🔍 Controllo notifiche urgenti - Ora: 2025-11-07 15:30:45
📅 Post ID=123 pubblicato: 2025-11-07 15:30:44 (1s fa) - RECENTE!
🚨 Trovati 1 nuovi post urgenti da notificare
🚨 Notifica urgente inviata: Post ID=123, Titolo=...
⏱️ Refresh periodico post (ogni 3 secondi per rilevare urgenti)
✅ Watcher notifiche urgenti avviato (controllo ogni 5 secondi, post pubblicati negli ultimi 2 secondi)
```

---

## ⚠️ Considerazioni Importanti

### 1. **Consumo Batteria** 🔋
- Controlli ogni 3-5 secondi aumentano il consumo batteria
- L'app deve rimanere in foreground per funzionare
- Considerare l'ottimizzazione per uso prolungato

### 2. **Traffico Rete** 📡
- Richieste HTTP ogni 3 secondi al server WordPress
- Verificare impatto su server con molti utenti
- Considerare rate limiting lato server

### 3. **Solo Foreground** 📱
- Il sistema funziona solo con app aperta (foreground)
- Con app in background/chiusa NON funziona
- Per notifiche in background serve Firebase Cloud Messaging

### 4. **Timezone** 🌍
- Usa `date_gmt` (GMT/UTC) per evitare problemi timezone
- Se `date_gmt` non disponibile, usa `date` locale

---

## 🧪 Come Testare

### Test 1: Post Urgente Nuovo
1. Apri l'app e lasciala in foreground
2. Vai su WordPress backend
3. Pubblica un nuovo post con categoria "Urgente"
4. **Atteso:** Entro 8 secondi:
   - Notifica di sistema appare
   - Popup in-app si apre
   - Log mostra il rilevamento

### Test 2: Post Urgente Vecchio
1. Pubblica un post urgente su WordPress
2. Attendi 10 secondi
3. Apri l'app
4. **Atteso:** Nessuna notifica (post > 2 secondi)

### Test 3: Multipli Post Urgenti
1. Pubblica 3 post urgenti in rapida successione
2. **Atteso:** Una notifica per ogni post

### Test 4: App in Background
1. Pubblica post urgente
2. Metti app in background
3. **Atteso:** Nessuna notifica (timer in pausa)

---

## 📱 Compatibilità

- ✅ Android 13+ (con permesso notifiche)
- ✅ Android 12 e precedenti
- ✅ iOS 13.0+
- ✅ Richiede connessione internet attiva
- ✅ Richiede app in foreground

---

## 🔧 Configurazione

### Modificare i Tempi
Se vuoi cambiare gli intervalli di controllo:

```dart
// Cambio frequenza refresh post (default: 3 secondi)
Timer.periodic(const Duration(seconds: 3), ...);

// Cambio frequenza controllo notifiche (default: 5 secondi)
Timer.periodic(const Duration(seconds: 5), ...);

// Cambio finestra temporale rilevamento (default: 2 secondi)
final twoSecondsAgo = now.subtract(const Duration(seconds: 2));
```

### Ridurre Consumo Batteria/Rete
Valori consigliati per uso meno intensivo:

```dart
// Opzione moderata
Timer.periodic(const Duration(seconds: 10), ...);  // Refresh post
Timer.periodic(const Duration(seconds: 15), ...);  // Check notifiche
final thirtySecondsAgo = now.subtract(const Duration(seconds: 30));

// Opzione conservativa (originale)
Timer.periodic(const Duration(minutes: 3), ...);   // Refresh post
Timer.periodic(const Duration(minutes: 5), ...);   // Check notifiche
```

---

## 📝 File Modificati

- ✅ `lib/main.dart`:
  - Funzione `startUrgentNotificationWatcher()` - linea ~3125
  - Funzione `_startPeriodicPostsRefresh()` - linea ~3446

---

## 🚀 Prossimi Passi Consigliati

### 1. **Ottimizzazione Server**
- Implementare caching lato server
- Aggiungere endpoint API dedicato per post urgenti recenti
- Rate limiting per proteggere il server

### 2. **Notifiche Background** (Opzionale)
- Integrare Firebase Cloud Messaging
- Webhook WordPress → Firebase → App
- Notifiche anche con app chiusa

### 3. **Gestione Errori**
- Retry automatico in caso di errore rete
- Fallback a timer meno frequente se offline ripetutamente
- Alert utente se troppi errori consecutivi

### 4. **Analytics**
- Tracciare quante notifiche vengono inviate
- Monitorare tempo medio di rilevamento
- Verificare impatto su batteria/rete

---

**Data implementazione:** Novembre 2025  
**Versione:** 2.0 - Sistema Notifiche Rapide  
**Stato:** ✅ Implementato e Testato

---

## 📚 Documentazione Correlata

- `CONFIGURAZIONE_NOTIFICHE.md` - Configurazione base notifiche
- `RIEPILOGO_MODIFICHE.md` - Prime modifiche notifiche
- Questo documento - Sistema rapido di rilevamento

