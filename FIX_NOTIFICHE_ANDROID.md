# 🔧 Fix Notifiche Android - Guida Completa

## ✅ Modifiche Implementate

### 1. **Creazione Canale Notifiche Android** ⚡ NUOVO
Android 8.0+ (Oreo) richiede la creazione esplicita dei canali di notifica:

```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'urgent_channel',
  'Comunicazioni Urgenti',
  description: 'Notifiche per comunicazioni urgenti del condominio',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```

### 2. **Richiesta Permessi Runtime Android 13+** ⚡ NUOVO
Android 13+ (Tiramisu) richiede permessi runtime per le notifiche:

```dart
final androidImplementation = flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

if (androidImplementation != null) {
  final bool? granted = await androidImplementation.requestNotificationsPermission();
  debugPrint('🔔 Permesso notifiche Android: ${granted == true ? "✅ CONCESSO" : "❌ NEGATO"}');
}
```

### 3. **Log Dettagliati** 📝
Aggiunti log per verificare lo stato delle notifiche:
- `✅ Sistema notifiche inizializzato correttamente`
- `🔔 Permesso notifiche Android: ✅ CONCESSO` o `❌ NEGATO`
- `📱 Notifica locale mostrata: [titolo] - [corpo]`

---

## 🔍 Checklist Verifica Configurazione

### ✅ AndroidManifest.xml
Verificato che contenga:
- ✅ `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` (Android 13+)
- ✅ `<uses-permission android:name="android.permission.VIBRATE" />`
- ✅ `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />`
- ✅ `<uses-permission android:name="android.permission.WAKE_LOCK" />`
- ✅ Receivers per notifiche schedulte

### ✅ Codice Dart
- ✅ Creazione canale notifiche nell'inizializzazione
- ✅ Richiesta permessi runtime Android 13+
- ✅ ID canale corrispondente (`'urgent_channel'`)
- ✅ Configurazione notifiche con `Importance.max` e `Priority.high`

---

## 🧪 Come Testare

### Test 1: Verifica Inizializzazione
1. Avvia l'app su Android (preferibilmente dispositivo reale con Android 13+)
2. Guarda i log nella console/logcat
3. Dovresti vedere:
   ```
   🔔 Permesso notifiche Android: ✅ CONCESSO
   ✅ Sistema notifiche inizializzato correttamente
   ```

**Se vedi `❌ NEGATO`:** L'utente ha negato il permesso → Vai nelle Impostazioni app e abilita le notifiche manualmente.

### Test 2: Verifica Notifica Manuale
Aggiungi temporaneamente questo codice dopo l'inizializzazione per testare:

```dart
// In main(), dopo initializeNotifications()
Future.delayed(Duration(seconds: 3), () {
  showLocalNotification(
    id: 999,
    title: '🧪 Test Notifica',
    body: 'Questa è una notifica di test',
    payload: 'test',
  );
});
```

**Atteso:** Dopo 3 secondi dall'apertura dell'app, dovrebbe apparire una notifica.

### Test 3: Verifica Post Urgente
1. Apri l'app e lasciala in foreground
2. Pubblica un post urgente su WordPress
3. Attendi max 8 secondi
4. Dovresti vedere:
   - Log: `🚨 Trovati 1 nuovi post urgenti da notificare`
   - Log: `📱 Notifica locale mostrata: 🚨 Comunicazione urgente - [titolo]`
   - **Notifica nella barra di sistema Android**
   - **Popup in-app**

---

## 🐛 Troubleshooting

### Problema 1: Nessuna Notifica Appare

#### Causa A: Permessi Negati
**Sintomo:** Log mostra `❌ NEGATO`

**Soluzione:**
1. Vai in Impostazioni Android → App → Condominio
2. Vai in "Notifiche"
3. Abilita "Mostra notifiche"
4. Abilita il canale "Comunicazioni Urgenti"
5. Imposta importanza su "Urgente" o "Alta"

#### Causa B: Canale Non Creato
**Sintomo:** Nessun log di inizializzazione

**Soluzione:**
```bash
# Disinstalla completamente l'app
flutter clean
flutter pub get
flutter run

# Il canale viene creato al primo avvio
```

#### Causa C: Versione Android Troppo Vecchia
**Sintomo:** App crash o nessuna notifica

**Soluzione:**
Verifica versione Android:
```bash
adb shell getprop ro.build.version.sdk
```
- Android 13+ (API 33+): Tutto dovrebbe funzionare
- Android 8-12 (API 26-32): Notifiche senza richiesta permessi
- Android <8 (API <26): Notifiche senza canali

### Problema 2: Notifica Appare ma Non Ha Suono/Vibrazione

**Soluzione:**
1. Apri Impostazioni Android → App → Condominio → Notifiche
2. Tocca "Comunicazioni Urgenti"
3. Verifica:
   - ✅ Suono notifica abilitato
   - ✅ Vibrazione abilitata
   - ✅ Importanza impostata su "Urgente" (la più alta)
   - ✅ "Mostra nella schermata di blocco" abilitato

### Problema 3: Notifica Appare ma Popup No

**Causa:** L'app potrebbe essere in background

**Soluzione:**
Il popup in-app funziona solo con app in foreground. Verifica:
```dart
if (context.mounted) {
  _showUrgentNotificationDialog(context, cleanTitle, id);
}
```

Se l'app è in background, vedrai solo la notifica di sistema (comportamento corretto).

### Problema 4: Troppe Notifiche Duplicate

**Causa:** Post vecchi vengono notificati al riavvio app

**Soluzione:** Il sistema ora filtra solo post pubblicati negli ultimi 2 secondi.
Verifica log:
```
📅 Post ID=123 pubblicato: 2025-11-07 15:30:44 (1s fa) - RECENTE!
```

Se vedi post vecchi, verifica che il server restituisca `date_gmt` correttamente.

---

## 📱 Test su Diverse Versioni Android

### Android 13+ (API 33+)
- ✅ Richiesta permessi runtime all'avvio
- ✅ Dialog sistema per concedere/negare permessi
- ✅ Canale notifiche creato automaticamente

**Test:**
```bash
adb shell dumpsys notification_listener
```
Verifica che il canale `urgent_channel` esista.

### Android 8-12 (API 26-32)
- ✅ Nessuna richiesta permessi (concessi automaticamente)
- ✅ Canale notifiche creato automaticamente

### Android <8 (API <26)
- ⚠️ Nessun supporto canali (fallback automatico)
- ✅ Notifiche funzionano comunque

---

## 🔧 Debug Avanzato con ADB

### Verifica Permessi
```bash
# Lista permessi dell'app
adb shell dumpsys package com.example.condominio | grep permission

# Controlla specificamente permesso notifiche
adb shell dumpsys package com.example.condominio | grep POST_NOTIFICATIONS
```

### Verifica Canali Notifiche
```bash
# Lista canali notifiche
adb shell dumpsys notification | grep -A 5 "com.example.condominio"

# Output atteso:
# Channel: urgent_channel
# Name: Comunicazioni Urgenti
# Importance: MAX
```

### Mostra Notifica di Test da ADB
```bash
adb shell "cmd notification post -t 'Test' 'Tag' 'Questo è un test'"
```

### Verifica Log in Tempo Reale
```bash
# Filtra solo log dell'app
adb logcat | grep -i "flutter"

# Filtra solo log notifiche
adb logcat | grep -E "(notifica|notification|🔔|📱|🚨)"
```

---

## 🎨 Personalizzazione Notifiche

### Cambiare Suono Notifica
Aggiungi un file audio in `android/app/src/main/res/raw/notification_sound.mp3`

```dart
const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'urgent_channel',
  'Comunicazioni Urgenti',
  sound: RawResourceAndroidNotificationSound('notification_sound'),
  // ... resto configurazione
);
```

### Cambiare Icona Notifica
1. Crea icone in `android/app/src/main/res/drawable-*/ic_notification.png`
2. Usa icone monocromatiche (bianco su trasparente)

```dart
const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'urgent_channel',
  'Comunicazioni Urgenti',
  icon: 'ic_notification', // Senza @drawable/
  // ... resto configurazione
);
```

### Aggiungere Azioni alla Notifica
```dart
const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'urgent_channel',
  'Comunicazioni Urgenti',
  actions: <AndroidNotificationAction>[
    AndroidNotificationAction(
      'view',
      'Visualizza',
      showsUserInterface: true,
    ),
    AndroidNotificationAction(
      'dismiss',
      'Ignora',
    ),
  ],
  // ... resto configurazione
);
```

---

## 📊 Statistiche e Monitoraggio

### Verifica Delivery Rate
Aggiungi contatori per monitorare:

```dart
int notificheInviate = 0;
int notificheRicevute = 0;

// Quando invii notifica
notificheInviate++;

// Nel callback onDidReceiveNotificationResponse
notificheRicevute++;

// Log periodico
debugPrint('📊 Notifiche: $notificheRicevute/$notificheInviate ricevute');
```

---

## 🔒 Privacy e Best Practices

### Rispetta la Scelta dell'Utente
```dart
// Salva preferenza utente
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('notifications_enabled', granted == true);

// Prima di inviare notifica, controlla
final enabled = prefs.getBool('notifications_enabled') ?? false;
if (!enabled) {
  debugPrint('⏭️ Notifiche disabilitate dall\'utente');
  return;
}
```

### Non Abusare delle Notifiche
- ✅ Solo per comunicazioni veramente urgenti
- ✅ Max 1 notifica ogni 5 secondi (attuale)
- ❌ Non inviare notifiche di notte (23:00 - 07:00)

```dart
final now = DateTime.now();
if (now.hour >= 23 || now.hour < 7) {
  debugPrint('🌙 Orario notturno, notifica posticipata');
  return;
}
```

---

## 📚 Risorse Utili

- [Flutter Local Notifications - Documentazione Ufficiale](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Channels](https://developer.android.com/develop/ui/views/notifications/channels)
- [Android 13 Notification Permission](https://developer.android.com/develop/ui/views/notifications/notification-permission)

---

## ✅ Checklist Finale

Prima di rilasciare in produzione:

- [ ] Testato su Android 13+ (permessi runtime)
- [ ] Testato su Android 8-12 (canali)
- [ ] Testato notifiche con app in foreground
- [ ] Testato notifiche con app in background
- [ ] Verificato suono e vibrazione
- [ ] Verificato icona notifica
- [ ] Verificato popup in-app
- [ ] Log di debug pronti per produzione
- [ ] Documentazione utente creata
- [ ] Privacy policy aggiornata con uso notifiche

---

**Data implementazione:** Novembre 2025  
**Versione:** 3.0 - Fix Notifiche Android  
**Stato:** ✅ Implementato - Pronto per Test

