# 📱 Configurazione Notifiche - Riepilogo

## ✅ Stato Configurazione

### 📦 Dipendenze (pubspec.yaml)
✅ **flutter_local_notifications: ^18.0.1** - Installata e aggiornata

---

## 🤖 ANDROID - Configurazione Completa

### ✅ AndroidManifest.xml
Tutti i permessi necessari sono già configurati:
- ✅ `POST_NOTIFICATIONS` - Per Android 13+ (Tiramisu)
- ✅ `VIBRATE` - Vibrazione per le notifiche
- ✅ `RECEIVE_BOOT_COMPLETED` - Notifiche dopo riavvio
- ✅ `WAKE_LOCK` - Per svegliare il dispositivo
- ✅ Receivers configurati per le notifiche locali schedulate

### ✅ build.gradle
- ✅ Android Gradle Plugin: 8.3.0
- ✅ Kotlin: 1.9.10
- ✅ Desugaring abilitato per compatibilità API recenti
- ✅ minSdk, targetSdk, compileSdk gestiti da Flutter

### 📝 Note Android
- **Android 13+ (API 33+)**: L'app richiederà automaticamente il permesso per le notifiche al primo avvio
- **Android 12 e precedenti**: Le notifiche funzioneranno automaticamente senza richiedere permessi

---

## 🍎 iOS - Configurazione Aggiornata

### ✅ Info.plist
**AGGIUNTO:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```
Questo permette all'app di ricevere notifiche anche in background.

### ✅ AppDelegate.swift
**AGGIORNATO COMPLETAMENTE** con:
1. Import di `UserNotifications` framework
2. Richiesta esplicita dei permessi notifiche all'avvio
3. Registrazione per le notifiche remote
4. Gestione notifiche in foreground (app aperta)
5. Gestione tap sulle notifiche

**Funzionalità aggiunte:**
- Le notifiche vengono mostrate anche quando l'app è aperta
- Log dei permessi concessi/negati
- Supporto iOS 14+ con banner e iOS 10+ con alert

### ✅ Podfile
- ✅ Deployment target: iOS 13.0
- ✅ Swift 5.0 configurato
- ✅ use_frameworks! abilitato

---

## 💻 Codice Dart (main.dart)

### ✅ Inizializzazione Notifiche
```dart
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
```

### ✅ Funzione Notifica Urgente
```dart
Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {
  // Configurazione Android con canale urgente
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'urgent_channel',
    'Comunicazioni Urgenti',
    channelDescription: 'Notifiche per comunicazioni urgenti del condominio',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
  );

  // Configurazione iOS con alert, badge e suono
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await flutterLocalNotificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
}
```

### ✅ Popup In-App
```dart
void _showUrgentNotificationDialog(BuildContext context, String title, int postId) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            const Text('🚨', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(child: Text('Comunicazione Urgente', style: TextStyle(color: Color(0xFFE74C3C)))),
          ],
        ),
        content: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Chiudi')),
          ElevatedButton(onPressed: () { /* Naviga al post */ }, child: const Text('Visualizza')),
        ],
      );
    },
  );
}
```

### ✅ Timer Controllo Notifiche Urgenti
Il sistema controlla ogni 5 minuti se ci sono nuove comunicazioni urgenti:
```dart
Timer.periodic(const Duration(minutes: 5), (timer) {
  // Controlla post urgenti non ancora notificati
  // Mostra notifica nativa + popup in-app
});
```

---

## 🚀 Test e Verifica

### Per testare su Android:
1. Compila ed esegui l'app: `flutter run`
2. Al primo avvio su Android 13+, concedi il permesso notifiche
3. Crea un post urgente nel backend
4. Attendi max 5 minuti per vedere:
   - Notifica nella barra di sistema
   - Popup in-app (se l'app è aperta)

### Per testare su iOS:
1. Compila ed esegui l'app: `flutter run`
2. Al primo avvio, concedi il permesso notifiche quando richiesto
3. Crea un post urgente nel backend
4. Attendi max 5 minuti per vedere:
   - Notifica banner (anche con app aperta)
   - Popup in-app (se l'app è aperta)

---

## 🔧 Comandi Utili

```bash
# Pulire e ricompilare iOS dopo le modifiche
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter run

# Pulire e ricompilare Android
flutter clean
flutter pub get
flutter run
```

---

## 📋 Checklist Finale

- ✅ Dipendenza flutter_local_notifications installata
- ✅ Android: Permessi configurati in AndroidManifest.xml
- ✅ Android: Receivers per notifiche configurati
- ✅ iOS: Info.plist aggiornato con UIBackgroundModes
- ✅ iOS: AppDelegate.swift configurato per notifiche
- ✅ iOS: Deployment target iOS 13.0+
- ✅ Dart: Inizializzazione notifiche nel main()
- ✅ Dart: Canale notifiche urgenti configurato
- ✅ Dart: Popup in-app implementato
- ✅ Dart: Timer controllo notifiche attivo

---

## ⚠️ Note Importanti

1. **Permessi utente richiesti:**
   - Su Android 13+, l'utente deve concedere il permesso notifiche
   - Su iOS, l'utente deve concedere il permesso notifiche

2. **Icona Android:**
   - L'icona `@mipmap/ic_launcher` viene usata per le notifiche
   - Assicurati che l'icona esista in tutte le risoluzioni

3. **Background execution:**
   - Il timer funziona solo quando l'app è in foreground
   - Per notifiche con app in background serve configurazione aggiuntiva (Firebase Cloud Messaging)

4. **Testing:**
   - Testa su dispositivi reali, non solo emulatori
   - Verifica con diverse versioni di Android (13+) e iOS (13+)

---

**Ultima verifica:** Novembre 2025
**Versione Flutter local notifications:** 18.0.1

