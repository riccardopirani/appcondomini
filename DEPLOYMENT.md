# 🚀 Deployment - Come Mettere in Produzione

## 📊 Fase di Deployment

```
┌─────────────────┐
│  Development    │ ← Qui siamo adesso (tutto configurato)
└────────┬────────┘
         ↓ (Testing completato)
┌─────────────────┐
│  Staging        │ ← Testa su istanza non-produzione
└────────┬────────┘
         ↓ (Tutto ok)
┌─────────────────┐
│  Production     │ ← Deploy finale
└─────────────────┘
```

---

## 🎯 Pre-Deployment Checklist

### Codice
- [ ] `flutter analyze` - Zero errori di linting
- [ ] `flutter test` - Tutti i test passano
- [ ] Nessun print/debug nel codice produzione
- [ ] API Key configurate per production

### Plugin WordPress
- [ ] Plugin attivato e testato
- [ ] Rate limiting attivo
- [ ] Token expiry = 30 giorni
- [ ] Debug logging abilitato temporaneamente

### App
- [ ] Build APK/IPA senza errori
- [ ] Versione incrementata (pubspec.yaml)
- [ ] Firma digitale verificata
- [ ] Icone/splash screen aggiornati

### Documentazione
- [ ] SETUP_INSTRUCTIONS.md letto e capito
- [ ] QUICK_START.md stampato per riferimento
- [ ] Numeri supporto a portata di mano

---

## 🔑 Passo 1: Genera Chiave API di Produzione

```bash
cd wordpress-plugin
php generate-api-key.php
```

**Output:**
```
🔑 Chiave API generata:

   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

✅ **Salva questa chiave in un posto SICURO**

---

## 🌍 Passo 2: Deploy Plugin WordPress

### 2.1 Accedi al Server WordPress

```bash
ssh user@www.portobellodigallura.it
cd /path/to/wordpress
```

### 2.2 Copia il Plugin

```bash
cp /local/path/wordpress-plugin/pdg-app-api.php \
   wp-content/plugins/pdg-app-api.php
```

### 2.3 Configura wp-config.php

```bash
nano wp-config.php
```

Aggiungi (prima di `/* That's all */`):
```php
define('PDG_APP_API_KEY', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...');
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
```

Salva: `CTRL+O`, `INVIO`, `CTRL+X`

### 2.4 Attiva Plugin da WordPress Admin

1. Accedi a `https://www.portobellodigallura.it/wp-admin/`
2. Vai a **Plugin**
3. Cerca "PdG App API"
4. Clicca **Attiva**
5. Dovresti vedere: ✅ **Plugin activated**

### 2.5 Verifica Plugin Attivo

```bash
curl -s https://www.portobellodigallura.it/wp-json/pdg-app/v1/categories \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6..." \
  -H "Authorization: Bearer DUMMY" \
  -w "\nHTTP Status: %{http_code}\n"
```

**Output atteso:**
```
HTTP Status: 401
```

✅ Plugin è online!

---

## 📱 Passo 3: Build App Flutter

### 3.1 Aggiorna Versione

Apri `pubspec.yaml`:
```yaml
version: 1.0.1+3  # Cambia a 1.0.2+4 per esempio
```

### 3.2 Aggiorna ApiService

Apri `lib/services/api_service.dart`:
```dart
static const String apiKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...';
```

### 3.3 Pulisci e Build

```bash
flutter clean
flutter pub get

# Per Android
flutter build apk --release

# Per iOS
flutter build ios --release
```

⏳ Aspetta 5-10 minuti per il build...

---

## ✅ Passo 4: Test Completo

### Test 1: Login Manuale

```bash
# Sostituisci USERNAME e PASSWORD con credenziali reali
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6..." \
  -d '{"username":"USERNAME","password":"PASSWORD"}' | jq
```

**Output atteso:**
```json
{
  "success": true,
  "user": {
    "id": 1,
    "username": "USERNAME",
    "display_name": "Display Name"
  },
  "token": "abc123...",
  "expiry": 1705123456
}
```

### Test 2: Carica Post

Prendi il TOKEN dal Test 1 e sostituisci:

```bash
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6..." \
  -H "Authorization: Bearer TOKEN" | jq '.posts | length'
```

**Output atteso:**
```
5
```

### Test 3: App Installata

1. Installa APK/IPA sul dispositivo di test
2. Apri l'app
3. Accedi con credenziali WordPress
4. Dovresti vedere post nella home
5. Attendi 3 secondi, refresh automatic
6. Controlla che i post siano ancora visibili

✅ **Se tutto funziona = sei pronto per il deploy!**

---

## 🚨 Passo 5: Monitoring Post-Deploy

### Monitora i Log WordPress

```bash
# Accedi al server
ssh user@www.portobellodigallura.it

# Guarda i log in tempo reale
tail -f wp-content/debug.log
```

Dovresti vedere richieste come:
```
[...] REST API auth attempt...
[...] Token validated successfully...
[...] Posts returned: 20
```

### Monitora gli Utenti Attivi

Da WordPress Admin:
1. **Users** → Vedi lista utenti
2. Verifica che non ci siano strani accessi
3. Controlla **user meta** per token scaduti

### Abilita Notifiche di Errore

Opzionale: Configura Slack/Email per errori WordPress

---

## 🔄 Passo 6: Rollback Plan

Se qualcosa non funziona:

### Opzione 1: Disattiva Plugin (veloce)

Da WordPress Admin:
1. **Plugin** → "PdG App API"
2. Clicca **Disattiva**
3. L'app fallback automaticamente al metodo legacy

### Opzione 2: Ripristina Versione Precedente

```bash
# Se il plugin è rotto
cd /path/to/wordpress/wp-content/plugins/
rm pdg-app-api.php
# L'app continua a funzionare senza plugin

# Se l'app è rotta
# Reinstalla versione precedente da app store
```

### Opzione 3: Reset Token

Se gli utenti sono bloccati:

```bash
# Da WordPress (WP-CLI)
wp post meta delete --meta-key='pdg_app_token_hash'
wp post meta delete --meta-key='pdg_app_token_expiry'

# Gli utenti dovranno rifare login
```

---

## 📊 Statistiche da Monitorare

Dopo il deploy, osserva:

| Metrica | Baseline | Target | Strumento |
|---------|----------|--------|-----------|
| API Response Time | <1000ms | <500ms | curl timing |
| Failed Logins | <5/day | <1/day | wp-content/debug.log |
| Active Users | ? | ? | WordPress Users page |
| App Crashes | ? | <1% | Crash logging (opzionale) |
| User Feedback | ? | Positivo | App store reviews |

---

## 🎓 Comunicazione agli Utenti

### Email Template

Invia questa email ai beta tester:

---

**Oggetto**: App aggiornata - Nuovo metodo di autenticazione

Caro Utente,

Siamo felici di annunciare che l'app Condominio è stata aggiornata con:

✅ **Login più veloce** - Una sola autenticazione al startup
✅ **Sessione stabile** - Valida per 30 giorni
✅ **Refresh istantanei** - Post aggiornati senza nuovo login
✅ **Maggiore sicurezza** - Token JWT protetto

**Come usarla:**
1. Aggiorna l'app da App Store
2. Accedi normalmente (username/password)
3. Goditi l'app più veloce e stabile!

Per problemi, contattaci a: support@portobellodigallura.it

---

## 🎯 Success Criteria

Il deployment è completato con successo quando:

✅ Plugin attivato su WordPress  
✅ API Key configurata in wp-config.php  
✅ App compilata con nuova API Key  
✅ Test 1, 2, 3 passati  
✅ App installt te su dispositivo di test funziona  
✅ Login via API plugin funziona  
✅ Post caricati in <500ms  
✅ Log WordPress senza errori  
✅ Nessun crash dell'app  
✅ Utenti positivi  

---

## 📞 Contatti di Supporto

Se hai problemi durante il deploy:

**Team Tecnico**: tech@portobellodigallura.it  
**Hours**: Lunedì-Venerdì 9-18  
**Emergency**: +39-XXX-XXX-XXXX  

Fornisci:
- Screenshot dell'errore
- Output di `curl` tests
- Content di `wp-content/debug.log`

---

## 🎉 Congratulazioni!

Se sei arrivato qui, hai completato il deployment. L'app è ora live con il nuovo sistema di autenticazione!

**Prossimi passi:**
1. Monitora i log per 24h
2. Raccogli feedback dagli utenti
3. Fai aggiustamenti minori se necessario
4. Considera implementazione di 2FA (opzionale)

---

**Data Deployment**: __________  
**Responsabile**: __________  
**Note**: __________

---

*Per documentazione tecnica completa, vedi README_IMPLEMENTATION.md*
