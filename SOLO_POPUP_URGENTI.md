# 🔔 Sistema Popup Urgenti - Solo In-App

## 🎯 Obiettivo
Sistema semplificato che mostra **SOLO popup in-app** per comunicazioni urgenti, senza notifiche di sistema (Android/iOS).

---

## ✅ Caratteristiche

### 🔔 **Solo Popup In-App**
- ✅ Nessuna notifica di sistema (barra notifiche Android/iOS)
- ✅ Popup visibile solo quando l'app è aperta in foreground
- ✅ Tutti i post urgenti non ancora mostrati vengono visualizzati
- ✅ Controllo automatico ogni 5 secondi
- ✅ Refresh post dal server ogni 3 secondi

### 🎨 **Design Popup**
- 🚨 Icona di allerta ben visibile
- ❤️ Titolo rosso "Comunicazione Urgente"
- 📝 Contenuto del messaggio
- 🔘 Due pulsanti:
  - **"Chiudi"** - Dismissi il popup
  - **"Visualizza"** - Vai alla home per vedere il post

---

## 🔄 Come Funziona

### Flusso Completo

```
1. [Ogni 3 secondi]
   └─> App scarica nuovi post dal server WordPress
       └─> Aggiorna lista posts in memoria

2. [Ogni 5 secondi]
   └─> Watcher controlla posts in memoria
       └─> Cerca post con categoria "Urgente"
           └─> Filtra solo quelli mai mostrati prima
               └─> Se trovati:
                   └─> Mostra popup in-app per ognuno
```

### Timeline Esempio

```
T=0s   → Post urgente pubblicato su WordPress
T=3s   → App scarica i nuovi post
T=5s   → Watcher rileva il post urgente
        └─> 🔔 Popup appare a schermo
T=5s   → Utente chiude il popup
T=10s  → Watcher controlla di nuovo
        └─> Post già mostrato, nessun nuovo popup
```

---

## 📊 Scenari d'Uso

### Scenario 1: App Aperta, Nuovo Post
```
Situazione:
- Utente ha l'app aperta
- Viene pubblicato un post urgente

Risultato:
- Entro 8 secondi appare il popup
- L'utente lo vede immediatamente
```

### Scenario 2: App Aperta Dopo Ore
```
Situazione:
- 5 post urgenti pubblicati nelle ultime 2 ore
- Utente apre l'app

Risultato:
- Entro 8 secondi appaiono 5 popup (uno dopo l'altro)
- L'utente vede tutti i messaggi urgenti persi
```

### Scenario 3: App in Background
```
Situazione:
- App in background
- Viene pubblicato un post urgente

Risultato:
- Nessun popup (app non in foreground)
- Quando l'utente riapre l'app → popup appare
```

### Scenario 4: App Completamente Chiusa
```
Situazione:
- App chiusa completamente
- Viene pubblicato un post urgente

Risultato:
- Nessun popup (app non attiva)
- Quando l'utente apre l'app → popup appare
```

---

## 🆚 Vantaggi vs Svantaggi

### ✅ Vantaggi

1. **Nessuno Spam**
   - Niente notifiche fastidiose nella barra di sistema
   - L'utente non viene disturbato continuamente

2. **Controllo Utente**
   - Popup visibile solo quando l'utente è attivo nell'app
   - L'utente decide quando aprire l'app

3. **Esperienza Pulita**
   - Nessuna configurazione permessi notifiche
   - Funziona su tutte le versioni Android/iOS

4. **Semplicità**
   - Codice più semplice e manutenibile
   - Meno configurazioni da gestire

### ⚠️ Svantaggi

1. **Solo con App Aperta**
   - Se l'app è chiusa, l'utente non sa che c'è un messaggio urgente
   - Nessun avviso in tempo reale

2. **Richiede Azione Utente**
   - L'utente deve aprire l'app per vedere i messaggi
   - Non è proattivo come le notifiche di sistema

3. **Possibile Ritardo**
   - Se l'utente non apre l'app per giorni, non vede i messaggi
   - Dipende dall'abitudine dell'utente

---

## 🔍 Log di Debug

Il sistema fornisce log chiari per il debugging:

```
✅ Watcher popup urgenti avviato (controllo ogni 5 secondi)
   🔔 Solo popup in-app per tutti i post urgenti non ancora mostrati

🔍 Controllo post urgenti non notificati...

🚨 Trovati 2 post urgenti da mostrare
🔔 Popup urgente mostrato: ID=123, Titolo="Manutenzione ascensore"
🔔 Popup urgente mostrato: ID=124, Titolo="Chiusura acqua domani"

⚠️ Context non disponibile per popup ID=125
```

---

## 🧪 Test

### Test 1: Post Urgente con App Aperta
**Setup:**
1. Apri l'app e lasciala in foreground
2. Pubblica un post urgente su WordPress
3. Osserva

**Atteso:**
- Entro 8 secondi appare il popup
- Il popup mostra il titolo del post
- Log: `🔔 Popup urgente mostrato: ID=...`

**Comando test:**
```bash
flutter run
# Poi pubblica post urgente su WordPress
```

### Test 2: Multipli Post Urgenti Vecchi
**Setup:**
1. Pubblica 3 post urgenti su WordPress
2. Attendi 10 minuti
3. Apri l'app

**Atteso:**
- Entro 8 secondi appaiono 3 popup (uno per volta)
- Log: `🚨 Trovati 3 post urgenti da mostrare`

### Test 3: App in Background
**Setup:**
1. Apri l'app
2. Pubblica un post urgente
3. Metti subito l'app in background (tasto Home)
4. Attendi 10 secondi
5. Riapri l'app

**Atteso:**
- Durante background: nessun popup
- Quando riapri: popup appare entro 5 secondi
- Log: Può mostrare `⚠️ Context non disponibile` durante background

### Test 4: Stesso Post Non Si Ripete
**Setup:**
1. Apri l'app
2. Vedi un popup urgente
3. Chiudi il popup
4. Attendi 10 secondi

**Atteso:**
- Il popup non riappare
- Log non mostra più quel post negli urgenti da mostrare

---

## 🛠️ Configurazione

### Modificare Frequenza Controlli

**Controllo popup urgenti** (default: 5 secondi)
```dart
// In startUrgentNotificationWatcher()
Timer.periodic(const Duration(seconds: 5), ...);

// Per cambiare:
Timer.periodic(const Duration(seconds: 10), ...);  // 10 secondi
Timer.periodic(const Duration(minutes: 1), ...);   // 1 minuto
```

**Refresh post dal server** (default: 3 secondi)
```dart
// In _startPeriodicPostsRefresh()
Timer.periodic(const Duration(seconds: 3), ...);

// Per cambiare:
Timer.periodic(const Duration(seconds: 10), ...);  // 10 secondi
Timer.periodic(const Duration(minutes: 1), ...);   // 1 minuto
```

**Raccomandazioni:**
- **Molto Reattivo:** Controllo 3-5s, Refresh 3-5s (attuale)
- **Bilanciato:** Controllo 10s, Refresh 10s
- **Conservativo:** Controllo 30s, Refresh 30s

### Personalizzare il Popup

**Cambiare colori:**
```dart
// In _showUrgentNotificationDialog()
Text(
  'Comunicazione Urgente',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFFE74C3C), // Rosso - cambia qui
    fontSize: 18,
  ),
),
```

**Cambiare testo pulsanti:**
```dart
TextButton(
  onPressed: () => Navigator.of(dialogContext).pop(),
  child: const Text('Chiudi'), // Cambia qui
),

ElevatedButton(
  onPressed: () { ... },
  child: const Text('Visualizza'), // Cambia qui
),
```

**Disabilitare chiusura toccando fuori:**
```dart
showDialog(
  context: context,
  barrierDismissible: false, // Cambia da true a false
  builder: ...
```

### Limitare Numero di Popup

Se ci sono troppi post urgenti, puoi limitare:

```dart
// Dopo: if (urgentPosts.isNotEmpty) {
const int maxPopupsPerCycle = 3; // Max 3 popup alla volta
int popupsShown = 0;

for (var post in urgentPosts) {
  if (popupsShown >= maxPopupsPerCycle) {
    debugPrint('⏭️ Popup rimandato per ID=${post['id']} (limite raggiunto)');
    _notifiedUrgentPostIds.remove(post['id']); // Rimuovi per rimostrare dopo
    continue;
  }
  
  // ... resto del codice ...
  popupsShown++;
}
```

---

## 💡 Best Practices

### 1. Evitare Troppi Popup Contemporanei

Se ci sono molti post urgenti, considera di mostrarli in un unico popup con lista:

```dart
if (urgentPosts.length > 3) {
  _showMultipleUrgentPostsDialog(context, urgentPosts);
} else {
  // Mostra popup singoli
}
```

### 2. Aggiungere Suono/Vibrazione

Per attirare l'attenzione quando appare il popup:

```dart
// Aggiungi al progetto: audioplayers o vibration
import 'package:vibration/vibration.dart';

// Prima di mostrare popup:
if (await Vibration.hasVibrator() ?? false) {
  Vibration.vibrate(duration: 500);
}
```

### 3. Badge su Tab Bar

Mostra un badge per indicare quanti post urgenti ci sono:

```dart
// Nella NavigationBar
Badge(
  label: Text('$urgentPostsCount'),
  isLabelVisible: urgentPostsCount > 0,
  child: Icon(Icons.home),
)
```

### 4. Orario Silenzioso

Non mostrare popup durante la notte:

```dart
final now = DateTime.now();
if (now.hour >= 22 || now.hour < 7) {
  debugPrint('🌙 Orario silenzioso, popup rimandato');
  _notifiedUrgentPostIds.remove(id); // Rimuovi per mostrare dopo
  continue;
}
```

---

## 🔒 Privacy

### Dati Mostrati
Il popup mostra:
- ✅ Titolo del post (visibile nel popup)
- ✅ Categoria "Urgente" (implicito)
- ❌ Contenuto completo (non mostrato)

### Log
I log includono:
- ID del post
- Titolo del post
- Timestamp

**In produzione**, considera di ridurre i log per la privacy.

---

## 📈 Metriche da Monitorare

1. **Popup Aperti vs Chiusi Immediatamente**
   - Misura se gli utenti leggono o ignorano

2. **Tempo Medio Popup Visibile**
   - Quanto tempo gli utenti lasciano aperto il popup

3. **Click su "Visualizza" vs "Chiudi"**
   - Misura interesse nei contenuti

4. **Numero Medio Popup per Sessione**
   - Alto numero → troppi post urgenti o utente apre app raramente

---

## 🐛 Troubleshooting

### Problema: Popup Non Appare

**Causa 1:** App non in foreground
```
Soluzione: Verifica che l'app sia attiva e visibile
```

**Causa 2:** Context non disponibile
```
Log mostra: ⚠️ Context non disponibile per popup ID=...
Soluzione: Il popup apparirà al prossimo check quando context è disponibile
```

**Causa 3:** Post già notificato
```
Soluzione: Normale, ogni post viene mostrato una sola volta
Per testare: Pubblica un nuovo post urgente
```

### Problema: Troppi Popup

**Causa:** Molti post urgenti vecchi non visti
```
Soluzione temporanea: Apri e chiudi i popup
Soluzione permanente: Implementa limite popup (vedi sezione Configurazione)
```

### Problema: Popup Appare Troppo Tardi

**Causa:** Timer di controllo troppo lento
```
Soluzione: Riduci intervallo del timer (vedi sezione Configurazione)
Attuale: 5 secondi controllo + 3 secondi refresh = max 8 secondi
```

---

## 📚 Documentazione Correlata

- **FIX_NOTIFICHE_ANDROID.md** - Configurazione notifiche Android (ora non necessario)
- **AGGIORNAMENTO_NOTIFICHE_RAPIDE.md** - Sistema refresh rapido
- **POPUP_SEMPRE_ATTIVO.md** - Versione precedente con notifiche sistema

---

## 🔄 Changelog

### Versione 5.0 - Solo Popup (Attuale)
- ✅ Rimossa completamente logica notifiche di sistema
- ✅ Semplificato codice watcher
- ✅ Solo popup in-app per tutti i post urgenti
- ✅ Nessun filtro temporale
- ✅ Log più chiari e diretti

### Versione 4.0 - Popup Sempre + Notifiche Selettive
- ✅ Popup per tutti i post urgenti
- ✅ Notifiche sistema solo per post recenti

### Versione 3.0 - Fix Android
- ✅ Permessi runtime Android 13+
- ✅ Creazione canali notifiche

---

## ✅ Checklist Finale

Prima del rilascio:

- [ ] Testato popup con app aperta
- [ ] Testato popup con app riaperta dopo ore
- [ ] Testato multipli popup consecutivi
- [ ] Verificato che popup non si ripeta
- [ ] Testato comportamento app in background
- [ ] Log puliti e informativi
- [ ] UI/UX popup soddisfacente
- [ ] Performance accettabile (timer ogni 3-5s)
- [ ] Documentazione utente creata

---

**Data implementazione:** Novembre 2025  
**Versione:** 5.0 - Solo Popup In-App  
**Stato:** ✅ Implementato - Sistema Semplificato

**Vantaggi principali:**
- 🎯 Semplicità
- 🚫 Nessuno spam notifiche
- ✅ Funziona su tutte le piattaforme senza permessi
- 🔔 Utente vede tutti i messaggi urgenti quando usa l'app

