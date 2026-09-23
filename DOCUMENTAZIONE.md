# Documentazione — App mobile PDG (Portobello di Gallura)

Documentazione del **funzionamento attuale** dell’app Flutter del condominio / porto.  
Versione app di riferimento: `1.1.11+31` (`pubspec.yaml`).  
Data documento: settembre 2026.

> **Nota sicurezza:** in questo documento **non** sono riportate API key, password o secret SMTP.  
> Le chiavi vive stanno in codice (`lib/services/api_service.dart`, `lib/setttings.dart`, `backend-email/server.js`, `wp-config.php`) e vanno trattate come sensibili.

---

## 1. Cos’è l’app

App mobile **Flutter** (iOS / Android, anche web/desktop come target secondari) per i residenti / utenti di **Portobello di Gallura**.

Permette di:

1. **Autenticarsi** con le credenziali WordPress (o entrare come ospite / demo).
2. Leggere **comunicazioni e articoli** pubblicati sul sito, filtrati per **permessi** (PublishPress).
3. Ricevere **avvisi locali** e popup quando esce un post nella categoria **urgente**.
4. Inviare **richieste di servizio** (gas, rifiuti, guasto, ormeggio, pulizia fosse) via email alla segreteria.
5. Consultare **webcam** e **stazione meteo**, link del sito, documenti, numeri utili.
6. Usare l’interfaccia in **IT / EN / FR / ZH** (UI localizzata + traduzione dinamica dei post).

Non è ancora una piattaforma ticket strutturata: le richieste servizi sono **form → email SMTP**, non ticket con stati.

---

## 2. Architettura generale

```
┌─────────────────────┐
│  App Flutter (lib/) │
│  UI + cache locale  │
└──────────┬──────────┘
           │
     ┌─────┴──────────────────────────────┐
     │                                    │
     ▼                                    ▼
┌────────────────────────┐    ┌───────────────────────────────┐
│ Backend Render         │    │ WordPress                     │
│ appcondomini.onrender  │    │ portobellodigallura.it        │
│ • POST /send-email     │    │ Plugin: pdg-app/v1            │
│ • GET  /posts (cache)  │◄───│ Auth + post + categorie       │
│ • GET  /categories     │    │ PublishPress Permissions      │
└────────────────────────┘    └───────────────────────────────┘
     │
     ▼
┌────────────────────────┐
│ TurboSMTP              │
│ email → segreteria     │
└────────────────────────┘
```

### Componenti del repository

| Cartella / file | Ruolo |
|---|---|
| `lib/` | Codice app Flutter (UI quasi tutta in `main.dart`) |
| `lib/services/api_service.dart` | Login, post, categorie, account, proxy backend |
| `lib/setttings.dart` | URL sito, email, webcam, meteo, parametri |
| `lib/app_theme.dart` | Colori e tema |
| `lib/l10n/` + `language_provider.dart` | Lingue UI |
| `backend-email/` | Node.js: email SMTP + cache post/categorie |
| `wordpress-plugin/` | Plugin REST `pdg-app/v1` |
| `android/`, `ios/` | Progetti nativi + Fastlane / store |
| `.github/workflows/` | Release Android Play / iOS App Store |

---

## 3. Stack tecnico

| Layer | Tecnologia |
|---|---|
| UI | Flutter 3.x, Material, font **Karla** |
| HTTP | `http` |
| Persistenza locale | `shared_preferences` |
| Notifiche | `flutter_local_notifications` (**locali**, non push remote FCM/APNs) |
| Web content | `webview_flutter` |
| Link esterni / tel | `url_launcher` |
| Rete | `connectivity_plus` |
| Backend | Node.js + Express su **Render** |
| CMS | WordPress + plugin custom + PublishPress Permissions |
| Traduzione post | MyMemory Translation API |

---

## 4. Avvio app e navigazione

### 4.1 Bootstrap (`main()`)

1. Inizializza Flutter.
2. Inizializza il sistema **notifiche locali** (canale Android `urgent_channel`).
3. Avvia `MyApp` con localizzazioni e `LanguageProvider`.

### 4.2 Flusso tipico

```
SplashScreen
    │
    ├─ Sessione valida (keep 30 giorni) → MyHomePage (loggato)
    ├─ Sessione “logout on close” / scaduta → ospite / Login
    └─ Prima apertura → Onboarding (se previsto) → Login / Guest
```

**Splash** (`SplashScreen`): legge `SharedPreferences` e `SessionPrefs`:

- `keep30` → resta loggato fino a scadenza (~30 giorni).
- `logout_on_close` → alla ripartenza app tratta la sessione come chiusa.

**Login** (`LoginScreen`):

- Username / password WordPress → `ApiService.login()` → token salvato.
- Opzione **“Ricordami / tieni sessione 30 giorni”** vs scollega a fine uso.
- Accesso **ospite** (contenuti pubblici, no moduli account).
- **Modalità demo** (review store): come ospite ma **blocca invio email**.

### 4.3 Home e tab (`MyHomePage`)

Barra inferiore a **5 tab**:

| Index | Tab | Contenuto |
|---|---|---|
| 0 | **Home** | Comunicazioni urgenti in evidenza + scorciatoie servizi |
| 1 | **News** | Elenco articoli / feed |
| 2 | **Servizi** | Contatti / moduli richieste |
| 3 | **Articoli** | Categorie WordPress navigabili |
| 4 | **WebCam** | Webcam porto/parco + stazione meteo |

Drawer / menu laterale: documenti, contatti sito, account, info app, lingua, logout, eliminazione account (solo autenticati).

---

## 5. Autenticazione e permessi

### 5.1 Login API

- **Endpoint:** `POST /wp-json/pdg-app/v1/auth`
- **Header:** `x-pdg-api-key`
- **Body:** `{ "username", "password" }`
- **Risposta:** token + `expiry` (circa **30 giorni**)

Il token è salvato in SharedPreferences (`pdg_app_token`, `pdg_app_token_expiry`) e inviato come:

- `Authorization: Bearer <token>`
- `x-pdg-token: <token>` (fallback se l’hosting strippa `Authorization`)

### 5.2 Modalità utente

| Modalità | Flag tipici | Cosa può fare |
|---|---|---|
| Loggato | `isLoggedIn=true`, guest/demo=false | Post privati consentiti, moduli email, delete account |
| Ospite | `isGuest=true` | Contenuti pubblici; moduli account bloccati |
| Demo | `demoMode=true` | Come ospite; **email disabilitate** |

### 5.3 Ruoli e categorie riservate

I ruoli WordPress (es. `um_proprietari`) arrivano da `/debug/permissions` e restano in cache (`user_roles`).

In app, alcune categorie sono **visibili solo ai proprietari** (confronto case-insensitive sul nome):

- `avvisi`
- `documenti`
- `documenti condominio`
- `documentazione ridosso`

Le altre categorie restano visibili a tutti gli utenti che le ricevono dall’API (già filtrate da PublishPress lato server).

### 5.4 Eliminazione account

Utente autenticato → `DELETE /wp-json/pdg-app/v1/account` → logout locale e ritorno in modalità ospite.

---

## 6. Contenuti: post e categorie

### 6.1 Percorso di download (preferito)

1. App chiama il **backend Render** `GET /posts` e `GET /categories` (con API key + token se presente).
2. Il backend fa da **proxy + cache** verso il plugin WP `pdg-app/v1`, arricchisce i post con `_embedded.wp:term` (categorie).
3. Strategia cache: **stale-while-revalidate** (risposta immediata da cache, refresh WP in background).
4. Se Render non risponde → **fallback diretto** a WordPress.

Config flag in `ApiService`: `useBackendCache = true`.

### 6.2 Cache locale sull’app

- Chiavi: `cached_posts`, `cache_timestamp`, `notified_urgent_posts`.
- Validità locale tipica: **6 ore**, poi riscarico completo.
- Refresh periodico in background (es. timer ~30 minuti) con guardia anti-overlap.
- Al cambio utente in login: pulizia cache post/notifiche; **stesso utente** → cache mantenuta per login più veloce.

### 6.3 Schermate contenuti

| Widget | Funzione |
|---|---|
| `ModernArticlesScreen` | Lista / filtri / ricerca; griglia categorie; paginazione “altri 5” |
| `CategoryPostsScreen` / `CategoryPostViewer` | Vista per singola categoria |
| `PostDetailScreen` | Dettaglio articolo (HTML / contenuto) |
| Home | Solo subset **urgenti** (max ~5) in evidenza |

### 6.4 Cosa significa “urgente”

Un post è urgente se in `_embedded.wp:term` esiste una categoria il cui **nome** contiene `urgent` (copre: urgente, urgenti, urgent, urgency).

All’avvio `fetchUrgentPosts()` prova a scaricare solo quella categoria; se assente/vuota fa fallback agli ultimi post.

---

## 7. Notifiche urgenti (stato attuale)

### Importante

Oggi le notifiche sono **locali** (`flutter_local_notifications`), generate **dal dispositivo mentre l’app è in esecuzione / in foreground (o comunque con processo attivo)**.

**Non** c’è ancora push remota da WordPress (FCM / APNs) quando l’app è chiusa.

### Come funziona

1. Durante il download/processamento post, se trova un urgente **non ancora notificato** →:
   - notifica locale sul canale `urgent_channel`;
   - **popup rosso** in-app.
2. Watcher di **backup** ogni **30 secondi**: controlla post urgenti **nuovi** (pubblicati dopo l’avvio del watcher) non ancora in `notified_urgent_posts`.
3. ID già notificati salvati in SharedPreferences per evitare duplicati.
4. Tap sulla notifica → naviga al dettaglio del post (`payload` = id post).

### Permessi

Su Android/iOS richiede consenso notifiche; se negato, l’app avvisa che non può mostrare gli avvisi urgenti.

---

## 8. Servizi e email

Schermata **Servizi** / scorciatoie Home aprono moduli verso la segreteria:

| Servizio | UI | Destinatario |
|---|---|---|
| Bombole Gas | `EmailFormTab` | `segreteria@portobellodigallura.it` |
| Ritiro rifiuti | `WastePickupScreen` (+ fascia oraria) | stessa |
| Segnalazione guasto | `EmailFormTab` | stessa |
| Ormeggio | `EmailFormTab` | stessa |
| Pulizia fosse | `PuliziaFosseScreen` | stessa |

### Flusso invio

```
Form compilato (solo se loggato, non demo)
    → EmailService.sendAppEmail(...)
    → warm-up GET /health sul backend Render
    → POST /send-email
    → TurboSMTP → casella segreteria
```

Il body email include: servizio, data/ora, nome, email, dettagli extra, messaggio, orari ufficio.

**Ospite / demo:** invio bloccato con messaggio esplicito.

Esistono anche dialoghi informativi (non email) per:

- Numeri di emergenza (112, 118, …)
- Assistenza medica / farmacie / ASL

Apriibili da scorciatoie dove previste.

---

## 9. Webcam, meteo e link sito

URL centralizzati in `AppSettings` (`lib/setttings.dart`):

- Webcam porto e panoramica (player Castr)
- Stazione meteo SoluzioniMeteo
- Pagine sito: home, dove siamo, numeri utili, documenti

Apertura tipica: `WebcamScreen`, `CustomWebViewScreen`, oppure browser in-app / esterno (`url_launcher`).

---

## 10. Multilingua

### UI

`AppLocalizations` + `LanguageProvider`: **it, en, fr, zh**.

### Contenuti WordPress

Se la lingua ≠ `it`, titolo / excerpt / content dei post passano da **MyMemory** (`api.mymemory.translated.net`), con cache in memoria `_translationCache`.  
Italiano = testo originale WordPress.

---

## 11. Backend email + cache (`backend-email/`)

Servizio Node deployato tipicamente su **Render** (`https://appcondomini.onrender.com`).

| Endpoint | Descrizione |
|---|---|
| `GET /health` | Healthcheck (+ warm-up cold start Render) |
| `POST /send-email` | Invio SMTP (TurboSMTP) |
| `GET /posts` | Proxy cache WP + categorie embedded |
| `GET /categories` | Proxy cache categorie |
| `POST /cache/clear` | Svuota cache (opz. protetto da secret) |

Dettagli operativi: `backend-email/README.md`.

Cold start Render free: l’app usa timeout lunghi (~90s) e warm-up su `/health` prima dell’invio email.

---

## 12. Plugin WordPress (`wordpress-plugin/`)

Plugin **PdG App API** (v3.x): namespace REST `pdg-app/v1`.

Funzioni principali:

- Auth con API key + token
- Rate limit login (es. 10 fail / 15 min per IP)
- Post/categorie filtrati con **PublishPress Permissions**
- Hardening endpoint WP sensibili per non-admin
- Cache transient lato WP
- Delete account

Documentazione endpoint: `wordpress-plugin/README.md`.

---

## 13. Struttura codice Flutter (nota importante)

Quasi tutta la UI e la business logic mobile vivono in un unico file:

- `lib/main.dart` (~11.000+ righe)

Le cartelle `lib/screens/`, `lib/widgets/`, `lib/config/` esistono ma sono **vuote**: non c’è ancora uno split per schermata.

Classi principali in `main.dart`:

- `EmailService`
- `SplashScreen`, `OnboardingScreen`, `LoginScreen`
- `MyApp`, `MyHomePage`
- `ModernArticlesScreen`, `PostDetailScreen`, `CategoryPostsScreen`
- `ContactOptionsScreen`, `EmailFormTab`, `WastePickupScreen`, `PuliziaFosseScreen`
- `WebcamScreen`, `CustomWebViewScreen`
- `AppInfoScreen`, `NoAccessMessage`, `SessionPrefs`

Servizi esterni al monolite:

- `lib/services/api_service.dart`
- `lib/services/debug_api_service.dart`
- `lib/utils/auth_utils.dart`, `token_redaction.dart`

---

## 14. Persistenza locale (chiavi rilevanti)

| Chiave | Uso |
|---|---|
| `pdg_app_token` / `pdg_app_token_expiry` | Sessione API |
| `session_mode` / `session_expiry` | keep30 vs logout on close |
| `isLoggedIn`, `isGuest`, `demoMode` | Modalità accesso |
| `user_roles` | Ruoli WP in cache |
| `cached_posts`, `cache_timestamp` | Cache articoli |
| `notified_urgent_posts` | Anti-duplicato notifiche urgenti |
| `pdg_last_login_user` | Evita wipe cache se stesso utente |

---

## 15. Release e versioning

- Versione: `pubspec.yaml` → `version: x.y.z+build`
- Android: workflow `.github/workflows/release-android-play.yml`
- iOS: `.github/workflows/release-ios-appstore.yml` + script `build_ios_release.sh` / Fastlane
- Script utilità in `scripts/`

---

## 16. Limiti attuali (utile per evoluzioni)

| Area | Stato oggi | Implicazione |
|---|---|---|
| Push remote | Assenti | Urgente solo se app “viva” / processo attivo |
| WhatsApp | Assente | Nessun post automatico su gruppo |
| Ticket | Assente | Solo email one-shot, senza stati/storico |
| Codice UI | Monolite `main.dart` | Manutenzione / test più difficili |
| Hosting email/cache | Render | Cold start possibili |
| Secret in repo | Presenti in chiaro in alcuni file | Da migrare a env / secret store |

---

## 17. Mappa funzionale sintetica

```
Login WP ──► Token 30gg ──► Post/categorie (Render cache → WP)
                │
                ├── Home: urgenti + scorciatoie
                ├── News / Articoli: browse + dettaglio
                ├── Servizi: form → SMTP → segreteria
                ├── WebCam / meteo / link sito
                ├── Notifiche LOCALI su categoria "urgent*"
                └── Account: logout / delete
```

---

## 18. Dove leggere altro

- Backend: `backend-email/README.md`
- Plugin WP: `wordpress-plugin/README.md`
- Config URL/email/webcam: `lib/setttings.dart`
- API client: `lib/services/api_service.dart`

---

*Documento generato dall’analisi del codice nel repository `condominio`. Se cambiano flussi (push remote, WhatsApp, ticket), aggiornare le sezioni 7, 8 e 16.*
