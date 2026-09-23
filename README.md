# PDG — App Portobello di Gallura

App mobile ufficiale per i residenti e gli utenti di **Portobello di Gallura**: comunicazioni dal sito WordPress, servizi verso la segreteria, webcam/meteo e avvisi urgenti.

| | |
|---|---|
| **Prodotto** | App Flutter `pdg` (package `condominio`) |
| **Versione** | `1.1.11+31` (vedi `pubspec.yaml`) |
| **Piattaforme** | iOS, Android (target primari); web/desktop secondari |
| **Sito collegato** | [portobellodigallura.it](https://www.portobellodigallura.it) |
| **Repo** | Monorepo: app + backend email/cache + plugin WordPress |

> Documentazione funzionale completa (flussi, auth, cache, limiti): **[DOCUMENTAZIONE.md](./DOCUMENTAZIONE.md)**

---

## Cosa fa l’app

- **Login** con account WordPress, oppure accesso **ospite** / **demo** (review store)
- **Home / News / Articoli**: post e categorie dal CMS, filtrati per permessi (PublishPress)
- **Avvisi urgenti**: popup + notifica **locale** se la categoria del post contiene `urgent` (es. *Urgente*)
- **Servizi**: moduli per bombole gas, ritiro rifiuti, guasto, ormeggio, pulizia fosse → email alla segreteria
- **WebCam** e **stazione meteo**
- **Lingue UI**: italiano, inglese, francese, cinese (traduzione dinamica dei contenuti via MyMemory)

### Cosa non fa (ancora)

| Funzione | Stato |
|---|---|
| Push remote (FCM/APNs) da WordPress | Non implementata — le notifiche urgenti sono solo locali |
| Invio automatico link su gruppo WhatsApp | Non implementato |
| Piattaforma ticket con stati/storico | Non implementata — i servizi sono form → email one-shot |

---

## Architettura

```
App Flutter
    │
    ├──► Backend (Render) ──► TurboSMTP ──► segreteria@…
    │         │
    │         └── cache /posts + /categories
    │                    ▲
    └──► WordPress ◄─────┘
         plugin pdg-app/v1
         (+ PublishPress Permissions)
```

| Componente | Dove | Ruolo |
|---|---|---|
| App Flutter | `lib/` | UI e logica client (gran parte in `lib/main.dart`) |
| API client | `lib/services/api_service.dart` | Auth, post, categorie, delete account |
| Config URL/email | `lib/setttings.dart` | Sito, webcam, meteo, destinatario email |
| Backend Node | `backend-email/` | `POST /send-email`, proxy cache post |
| Plugin WP | `wordpress-plugin/` | REST `pdg-app/v1` (auth + contenuti sicuri) |
| CI release | `.github/workflows/` | Play Console + App Store Connect |

Dettagli endpoint backend: [`backend-email/README.md`](./backend-email/README.md)  
Dettagli plugin WP: [`wordpress-plugin/README.md`](./wordpress-plugin/README.md)

---

## Requisiti di sviluppo

- [Flutter](https://docs.flutter.dev/get-started/install) SDK compatibile con `environment.sdk: ^3.5.4`
- Xcode (iOS) / Android Studio o SDK Android
- Node.js 18+ (solo se lavori sul backend)
- Accesso al sito WordPress con plugin **PdG App API** attivo e API key allineata all’app

---

## Avvio rapido (app)

```bash
# Dalla root del repository
flutter pub get
flutter run
```

Build locali utili:

```bash
# APK debug/release (script di progetto)
./scripts/build_apk.sh

# Device USB
./scripts/run_usb_device.sh
```

Versione store: aggiornare `version:` in `pubspec.yaml` (`x.y.z+buildNumber`) prima di un rilascio.

---

## Backend email + cache

Cartella: `backend-email/`  
Deploy tipico: **Render** (`https://appcondomini.onrender.com`).

```bash
cd backend-email
npm install
npm run dev    # oppure: npm start
```

Endpoint principali:

| Metodo | Path | Uso |
|---|---|---|
| `GET` | `/health` | Healthcheck / warm-up cold start |
| `POST` | `/send-email` | Invio email (usato dai moduli Servizi) |
| `GET` | `/posts` | Proxy cache verso WordPress |
| `GET` | `/categories` | Proxy cache categorie |
| `POST` | `/cache/clear` | Svuota cache (opzionale, protetto da secret) |

L’app prova prima il backend per i post; se non risponde, fa **fallback diretto** al plugin WordPress.

Variabili d’ambiente utili: vedi `backend-email/README.md` e `backend-email/.env.example`.

---

## Plugin WordPress

Cartella: `wordpress-plugin/`

1. Genera una API key: `php wordpress-plugin/generate-api-key.php`
2. Imposta in `wp-config.php`: `define('PDG_APP_API_KEY', '…');`
3. Installa/attiva il plugin (`pdg-app-api.php` o pacchetto in `dist/`)
4. Allinea la stessa chiave in `lib/services/api_service.dart` (e nel backend se necessario)

Namespace REST: `/wp-json/pdg-app/v1/`  
Auth: header `x-pdg-api-key` +, dopo login, `Authorization: Bearer <token>` (o `x-pdg-token`).

---

## Configurazione app (punti chiave)

| File | Cosa configura |
|---|---|
| `lib/services/api_service.dart` | Base URL plugin WP, API key, URL backend cache |
| `lib/setttings.dart` | URL sito, email segreteria, webcam, meteo |
| `lib/main.dart` | UI, tab, notifiche locali, form email (`EmailService`) |
| `pubspec.yaml` | Nome package, versione, asset, font |

### Tab principali

1. **Home** — comunicazioni urgenti + scorciatoie  
2. **News** — feed articoli  
3. **Servizi** — moduli verso segreteria  
4. **Articoli** — browse per categoria  
5. **WebCam** — live + meteo  

### Sessioni

- **Mantieni accesso ~30 giorni** oppure **logout alla chiusura** (`SessionPrefs` in `main.dart`)
- Token API salvato in `SharedPreferences`; scadenza tipica allineata al plugin (~30 giorni)

### Categoria “urgente”

Un post è trattato come urgente se il nome categoria contiene `urgent` (copre *urgente*, *urgenti*, *urgent*, …).  
Le notifiche associate sono **locali** (canale Android `urgent_channel`), non push da server.

---

## Release store

| Piattaforma | Come |
|---|---|
| **Android → Play** | Workflow [release-android-play.yml](./.github/workflows/release-android-play.yml) (manuale o tag `v*`) |
| **iOS → App Store / TestFlight** | Workflow [release-ios-appstore.yml](./.github/workflows/release-ios-appstore.yml) + Fastlane in `ios/fastlane/` |

Segreti GitHub necessari: elencati in testa ai rispettivi file workflow (keystore, Play service account, certificati Apple, API key App Store Connect, …).

Script locali correlati: `build_ios_release.sh`, `scripts/release_ios_appstore.sh`.

---

## Struttura repository

```
condominio/
├── lib/                    # Codice Flutter
│   ├── main.dart           # UI e logica principale (monolite)
│   ├── services/           # ApiService, debug
│   ├── setttings.dart      # Config URL / email / media
│   ├── app_theme.dart
│   └── l10n/               # Stringhe UI multilingua
├── backend-email/          # Node: SMTP + cache post
├── wordpress-plugin/       # Plugin REST pdg-app
├── android/ · ios/         # Progetti nativi
├── assets/ · fonts/
├── scripts/                # Build APK, USB, release helper
├── .github/workflows/      # CI release store
├── DOCUMENTAZIONE.md       # Funzionamento dettagliato
└── README.md               # Questo file
```

Le cartelle `lib/screens/`, `lib/widgets/` e `lib/config/` esistono ma oggi sono vuote: le schermate sono ancora in `main.dart`.

---

## Sicurezza

- **Non** committare nuove password, API key o secret SMTP in chiaro.
- Chiavi e secret oggi presenti in alcuni file di codice vanno trattati come sensibili; idealmente migrarli a variabili d’ambiente / secret store.
- In documentazione e issue **non** incollare token o chiavi.
- Rate limit login sul plugin WP: troppi tentativi falliti → HTTP 429 (attendi ~15 minuti).

---

## Documentazione correlata

| Documento | Contenuto |
|---|---|
| [DOCUMENTAZIONE.md](./DOCUMENTAZIONE.md) | Funzionamento completo dell’app (auth, cache, urgenti, servizi, limiti) |
| [backend-email/README.md](./backend-email/README.md) | Setup e API del backend |
| [wordpress-plugin/README.md](./wordpress-plugin/README.md) | Installazione plugin, endpoint, troubleshooting |

---

## Supporto

Progetto per **Portobello di Gallura**. Per problemi di runtime controllare:

1. Plugin WP attivo e API key coerente tra app / `wp-config` / backend  
2. Health del backend Render (`GET /health`)  
3. Log Flutter e, lato WP, `wp-content/debug.log` se abilitato  

---

*README allineato al codice del repository. Per il dettaglio dei flussi interni vedi DOCUMENTAZIONE.md.*
