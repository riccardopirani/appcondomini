# 🔔 Popup Urgente Sempre Attivo - Documentazione

> ⚠️ **NOTA:** Questa versione è stata SOSTITUITA dalla versione 5.0
> 
> **Vedi:** `SOLO_POPUP_URGENTI.md` per la versione attuale (solo popup, niente notifiche di sistema)
> 
> Questo documento è mantenuto solo per riferimento storico.

---

## 🎯 Obiettivo (VERSIONE OBSOLETA)
Il popup urgente deve apparire SEMPRE per tutti i post urgenti non ancora notificati, mentre le notifiche di sistema vengono inviate solo per i post pubblicati di recente (ultimi 2 secondi).

---

## ✅ Nuovo Comportamento

### 📱 **Notifiche di Sistema** (Android/iOS)
**Condizione:** Solo post urgenti pubblicati negli ultimi 2 secondi

**Motivo:** Evitare spam di notifiche di sistema quando l'app viene aperta dopo un periodo di inattività

```dart
// Esempio:
Post pubblicato 1 secondo fa  → ✅ Notifica sistema
Post pubblicato 5 secondi fa  → ❌ NO notifica sistema
Post pubblicato 1 ora fa      → ❌ NO notifica sistema
```

### 🔔 **Popup In-App**
**Condizione:** TUTTI i post urgenti non ancora notificati (indipendentemente dalla data)

**Motivo:** L'utente deve vedere TUTTI i messaggi urgenti quando apre l'app

```dart
// Esempio (app appena aperta):
Post urgente pubblicato 1 secondo fa  → ✅ Popup + Notifica sistema
Post urgente pubblicato 5 secondi fa  → ✅ Popup (no notifica sistema)
Post urgente pubblicato 1 ora fa      → ✅ Popup (no notifica sistema)
Post urgente pubblicato 1 giorno fa   → ✅ Popup (no notifica sistema)
```

---

## 🔄 Flusso Completo

### Scenario 1: Utente Ha App Aperta
```
T=0s   → Post urgente pubblicato su WordPress
T=3s   → App scarica il post (refresh automatico)
T=5s   → Watcher controlla:
         ├─ Post non ancora notificato? SÌ
         ├─ Post urgente? SÌ
         ├─ Post < 2 secondi? SÌ
         └─ RISULTATO:
            ├─ ✅ Notifica sistema mostrata
            └─ ✅ Popup in-app mostrato
```

### Scenario 2: Utente Apre App Dopo 10 Minuti
```
T=-10min → Post urgente pubblicato su WordPress
T=0s     → Utente apre l'app
T=3s     → App scarica i post
T=5s     → Watcher controlla:
           ├─ Post non ancora notificato? SÌ
           ├─ Post urgente? SÌ
           ├─ Post < 2 secondi? NO (pubblicato 10 min fa)
           └─ RISULTATO:
              ├─ ❌ NO notifica sistema (troppo vecchio)
              └─ ✅ Popup in-app mostrato (importante comunque)
```

### Scenario 3: Multipli Post Urgenti Vecchi
```
T=-1ora  → Post urgente A pubblicato
T=-30min → Post urgente B pubblicato
T=-10min → Post urgente C pubblicato
T=0s     → Utente apre l'app
T=5s     → Watcher controlla:
           └─ RISULTATO:
              ├─ ❌ NO notifiche sistema (tutti vecchi)
              └─ ✅ 3 Popup in-app mostrati uno dopo l'altro
                   (uno per ogni post urgente)
```

---

## 💡 Vantaggi del Nuovo Sistema

### ✅ **Niente Spam di Notifiche**
L'utente non riceverà 10 notifiche di sistema quando apre l'app dopo ore di inattività.

### ✅ **Nessuna Informazione Persa**
L'utente vedrà comunque TUTTI i post urgenti tramite popup in-app.

### ✅ **Migliore UX**
- Notifiche di sistema: solo per eventi "freschi" e rilevanti
- Popup in-app: per informazioni complete quando l'utente è attivo

### ✅ **Context Sempre Valido**
Usa `navigatorKey.currentContext` per garantire che il popup possa sempre essere mostrato quando l'app è in foreground.

---

## 🔍 Log di Debug

Il sistema ora fornisce log dettagliati per capire cosa sta succedendo:

```
✅ Watcher notifiche urgenti avviato (controllo ogni 5 secondi)
   📱 Notifiche sistema: solo post pubblicati negli ultimi 2 secondi
   🔔 Popup in-app: TUTTI i post urgenti non ancora notificati

🔍 Controllo notifiche urgenti - Ora: 2025-11-07 15:30:45

📅 Post ID=123 pubblicato: 2025-11-07 15:30:44 (1s fa) - RECENTE!

🚨 Trovati 3 post urgenti non notificati (1 recenti)
   ↳ Post ID=120 (vecchio, solo popup)
   ↳ Post ID=121 (vecchio, solo popup)
   ↳ Post ID=123 (recente, notifica + popup)

📱 Notifica sistema inviata per post recente ID=123
🔔 Popup mostrato per post urgente ID=120
🔔 Popup mostrato per post urgente ID=121
🔔 Popup mostrato per post urgente ID=123
🚨 Notifica completata: Post ID=120, Titolo=...
🚨 Notifica completata: Post ID=121, Titolo=...
🚨 Notifica completata: Post ID=123, Titolo=...
```

---

## 🧪 Test Cases

### Test 1: Post Urgente Fresco
**Setup:**
1. Apri l'app
2. Pubblica un post urgente su WordPress
3. Attendi 8 secondi

**Atteso:**
- ✅ Notifica di sistema appare
- ✅ Popup in-app appare
- Log: `📱 Notifica sistema inviata` + `🔔 Popup mostrato`

### Test 2: Post Urgente Vecchio (10 minuti fa)
**Setup:**
1. Pubblica un post urgente su WordPress
2. Attendi 10 minuti
3. Apri l'app

**Atteso:**
- ❌ Nessuna notifica di sistema
- ✅ Popup in-app appare
- Log: `🔔 Popup mostrato` (senza `📱 Notifica sistema`)

### Test 3: Multipli Post Urgenti (mix vecchi/nuovi)
**Setup:**
1. Pubblica 3 post urgenti: uno ora fa, uno 5 minuti fa, uno adesso
2. Apri l'app o lasciala aperta

**Atteso:**
- ✅ 1 notifica di sistema (solo per il post recente)
- ✅ 3 popup in-app (uno per ogni post)
- Log mostra: `3 post urgenti non notificati (1 recenti)`

### Test 4: App in Background
**Setup:**
1. Apri l'app
2. Metti l'app in background
3. Pubblica post urgente
4. Riapri l'app

**Atteso:**
- ✅ Popup appare quando riapri l'app
- Log: `⚠️ Context non disponibile` durante background, poi `🔔 Popup mostrato` quando riapri

### Test 5: Tutti Post Già Notificati
**Setup:**
1. Apri l'app con post urgenti
2. Vedi tutti i popup
3. Chiudi i popup
4. Attendi il prossimo check (5 secondi)

**Atteso:**
- ❌ Nessun nuovo popup (già tutti notificati)
- Log: Nessun `🚨 Trovati N post urgenti`

---

## 🛠️ Configurazione Avanzata

### Modificare la Finestra Temporale per Notifiche Sistema

Se vuoi cambiare quanto tempo un post è considerato "recente" per le notifiche di sistema:

```dart
// Default: 2 secondi
final twoSecondsAgo = now.subtract(const Duration(seconds: 2));

// Esempi alternativi:
final thirtySecondsAgo = now.subtract(const Duration(seconds: 30));  // 30 secondi
final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));     // 5 minuti
final oneHourAgo = now.subtract(const Duration(hours: 1));           // 1 ora
```

**Raccomandazione:**
- **2-10 secondi:** Per notifiche molto fresche, minimo spam
- **30-60 secondi:** Bilanciamento tra tempestività e spam
- **5+ minuti:** Massima tempestività, possibile spam

### Disabilitare Popup per Post Vecchi

Se vuoi mostrare popup solo per post recenti (come le notifiche di sistema):

```dart
// Cambia questa linea:
// POPUP: Mostra SEMPRE per tutti i post urgenti (recenti e non)
final isRecent = recentUrgentPosts.any((p) => p['id'] == id);

// Cambia in:
if (isRecent) {  // Mostra popup solo se recente
  final currentContext = navigatorKey.currentContext;
  if (currentContext != null && mounted) {
    _showUrgentNotificationDialog(currentContext, cleanTitle, id);
  }
}
```

### Limitare Numero di Popup Consecutivi

Se ci sono troppi post urgenti vecchi, potresti voler limitare i popup:

```dart
// Aggiungi dopo il for loop:
const maxPopupsPerCycle = 3;  // Max 3 popup alla volta
int popupsShown = 0;

for (var post in urgentPosts) {
  // ... codice esistente ...
  
  // POPUP: con limite
  if (popupsShown < maxPopupsPerCycle) {
    final currentContext = navigatorKey.currentContext;
    if (currentContext != null && mounted) {
      _showUrgentNotificationDialog(currentContext, cleanTitle, id);
      popupsShown++;
    }
  }
}

if (urgentPosts.length > maxPopupsPerCycle) {
  debugPrint('⚠️ ${urgentPosts.length - maxPopupsPerCycle} popup non mostrati (limite raggiunto)');
}
```

---

## ⚡ Performance e Best Practices

### Gestione Memoria
Il Set `_notifiedUrgentPostIds` cresce indefinitamente. Per app che girano a lungo:

```dart
// Pulisci vecchi ID dopo un certo periodo (esempio: 24 ore)
void _cleanOldNotifications() {
  if (_notifiedUrgentPostIds.length > 100) {  // Soglia
    final oldestIds = _notifiedUrgentPostIds.take(50).toList();
    _notifiedUrgentPostIds.removeAll(oldestIds);
    debugPrint('🧹 Puliti ${oldestIds.length} vecchi ID notifiche');
  }
}
```

### Popup Multipli
I popup vengono mostrati uno dopo l'altro. Per migliorare l'UX:

```dart
// Opzione 1: Aggiungi delay tra popup
await Future.delayed(Duration(milliseconds: 500));

// Opzione 2: Mostra un solo popup con lista di tutti i post urgenti
if (urgentPosts.length > 1) {
  _showMultipleUrgentPostsDialog(context, urgentPosts);
} else {
  _showUrgentNotificationDialog(context, cleanTitle, id);
}
```

---

## 🔒 Privacy e Sicurezza

### Contenuto dei Popup
I popup mostrano il titolo del post. Assicurati che:
- ✅ I titoli non contengano informazioni sensibili
- ✅ Gli utenti siano autenticati per vedere i contenuti

### Log di Debug in Produzione
Prima del rilascio, considera di ridurre i log:

```dart
// Aggiungi un flag per ambiente
const bool isDebug = false;  // false in produzione

if (isDebug) {
  debugPrint('🔍 Controllo notifiche urgenti - Ora: $now');
}
```

---

## 📊 Metriche da Monitorare

Per ottimizzare il sistema, monitora:

1. **Popup mostrati vs Post urgenti totali**
   - Target: 100% (tutti i post urgenti generano popup)

2. **Tempo medio tra pubblicazione e visualizzazione popup**
   - Target: < 10 secondi per post freschi

3. **Numero medio di popup per sessione utente**
   - Alto numero potrebbe indicare troppi post urgenti

4. **Tasso di dismissal popup senza azione**
   - Alto tasso potrebbe indicare popup fastidiosi

---

## 📝 Changelog

### Versione 4.0 - Popup Sempre Attivo
- ✅ Popup mostrato per TUTTI i post urgenti non notificati
- ✅ Notifiche sistema solo per post recenti (< 2 secondi)
- ✅ Uso di `navigatorKey` per context sempre valido
- ✅ Log dettagliati per debug
- ✅ Separazione logica notifiche sistema vs popup

### Versione 3.0 - Fix Notifiche Android
- ✅ Creazione canale notifiche Android 8+
- ✅ Richiesta permessi runtime Android 13+

### Versione 2.0 - Notifiche Rapide
- ✅ Refresh post ogni 3 secondi
- ✅ Check notifiche ogni 5 secondi
- ✅ Filtro temporale 2 secondi

### Versione 1.0 - Sistema Base
- ✅ Notifiche locali iOS/Android
- ✅ Popup in-app
- ✅ Check periodico post urgenti

---

**Data implementazione:** Novembre 2025  
**Versione:** 4.0 - Popup Sempre Attivo  
**Stato:** ✅ Implementato e Pronto per Test

**File modificati:**
- `lib/main.dart` - Funzione `startUrgentNotificationWatcher()` (linea ~3153)

