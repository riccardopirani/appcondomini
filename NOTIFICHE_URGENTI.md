# Sistema di Notifiche Urgenti Locali

## Descrizione
Il sistema è stato implementato per mostrare notifiche locali native sia su iOS che su Android quando viene rilevata una nuova comunicazione urgente.

## Come Funziona

### 1. Rilevamento Notifiche Urgenti
- Il sistema controlla ogni **5 minuti** se ci sono nuove comunicazioni urgenti
- Una comunicazione è considerata "urgente" se ha una categoria che contiene la parola "urgent" (urgente, urgenti, urgent, urgency)
- Ogni notifica urgente viene mostrata solo una volta (il sistema tiene traccia degli ID già notificati)

### 2. Notifiche Locali
Quando viene rilevata una nuova comunicazione urgente:
- **Titolo**: "🚨 Comunicazione urgente"
- **Corpo**: Il titolo della comunicazione (senza tag HTML)
- **Notifica nativa**: Appare nella barra delle notifiche del dispositivo
- **Suono e vibrazione**: Attivati di default

### 3. Compatibilità

#### Android
- ✅ Android 13+ (richiede permesso POST_NOTIFICATIONS)
- ✅ Android 12 e precedenti
- ✅ Suono e vibrazione
- ✅ Icona personalizzata
- ✅ Priorità alta per notifiche urgenti

#### iOS
- ✅ iOS 10+
- ✅ Suono e vibrazione
- ✅ Badge e alert
- ✅ Richiesta automatica dei permessi all'avvio

## Modifiche Apportate

### 1. Dipendenze (`pubspec.yaml`)
```yaml
flutter_local_notifications: ^18.0.1
```

### 2. Codice (`lib/main.dart`)
- Aggiunto import di `flutter_local_notifications`
- Creata funzione `initializeNotifications()` per configurare le notifiche
- Creata funzione `showLocalNotification()` per mostrare notifiche
- Modificato `main()` per inizializzare le notifiche all'avvio
- Modificato `startUrgentNotificationWatcher()` per usare notifiche native invece di AlertDialog

### 3. Configurazione Android (`android/app/src/main/AndroidManifest.xml`)
Aggiunti permessi:
- `POST_NOTIFICATIONS` (Android 13+)
- `VIBRATE` (vibrazione)
- `RECEIVE_BOOT_COMPLETED` (notifiche dopo riavvio)
- `WAKE_LOCK` (risveglia il dispositivo)

Aggiunti receiver per gestire notifiche programmate e al riavvio del dispositivo.

### 4. Configurazione iOS
Le notifiche sono configurate automaticamente nel codice Dart. I permessi vengono richiesti all'avvio dell'app.

## Comportamento

### Primo Avvio
- L'app richiederà automaticamente i permessi per le notifiche
- Su iOS: popup di sistema per confermare i permessi
- Su Android 13+: richiesta di permesso per le notifiche

### Durante l'Utilizzo
- Ogni 5 minuti il sistema controlla nuove comunicazioni urgenti
- Se l'app è in background, la notifica apparirà nella barra delle notifiche
- Se l'app è in foreground, la notifica apparirà comunque (comportamento modificabile)
- Tappando sulla notifica, si aprirà l'app (funzionalità espandibile per aprire direttamente la comunicazione)

## Test

### Per testare le notifiche:
1. Avviare l'app
2. Accettare i permessi per le notifiche
3. Aspettare che venga pubblicata una comunicazione con categoria "urgente" o "urgenti"
4. Dopo massimo 5 minuti, dovrebbe apparire una notifica locale

### Debug
Le notifiche sono tracciabili nei log con:
```
🚨 Notifica urgente inviata: Post ID=XXX, Titolo=...
📱 Notifica locale mostrata: ...
```

## Note Importanti

1. **Permessi Utente**: L'utente deve accettare i permessi per le notifiche
2. **Batteria**: Su alcuni dispositivi Android, le restrizioni di risparmio energetico potrebbero ritardare le notifiche
3. **Background**: Il timer di 5 minuti funziona solo quando l'app è attiva. Per notifiche in background completo, sarebbe necessario implementare un servizio background separato
4. **Personalizzazione**: È possibile modificare l'intervallo di controllo (attualmente 5 minuti) e lo stile delle notifiche nella funzione `showLocalNotification()`

## Possibili Miglioramenti Futuri

1. **Notifiche Push**: Implementare notifiche push da server per notifiche immediate anche con app chiusa
2. **Navigazione Diretta**: Tappando la notifica, aprire direttamente la comunicazione urgente
3. **Raggruppamento**: Raggruppare più notifiche urgenti se ce ne sono molte
4. **Personalizzazione**: Permettere all'utente di configurare suono, vibrazione e frequenza di controllo
5. **Background Service**: Implementare un servizio background per controllare notifiche anche con app chiusa

