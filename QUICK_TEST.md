# 🧪 Quick Test - Verifica Subito se Funziona

Segui questi 3 test per verificare che tutto funziona. Tempo: **10 minuti**.

---

## 🔐 Test 1: Login via API (3 minuti)

### Preparazione
Sostituisci questi valori:
- `USERNAME` → il tuo username WordPress
- `PASSWORD` → la tua password WordPress
- `API_KEY` → `Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe`

### Comando

```bash
curl -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -d '{"username":"USERNAME","password":"PASSWORD"}' \
  -v
```

### Risultato Atteso

```json
HTTP/1.1 200 OK

{
  "success": true,
  "user": {
    "id": 1,
    "username": "USERNAME",
    "display_name": "Your Name"
  },
  "token": "abc123def456ghi789jkl...",
  "expiry": 1748645123
}
```

### ✅ Cosa Significa

| Elemento | Significato |
|----------|-------------|
| `HTTP/1.1 200 OK` | ✅ Successo! |
| `success: true` | ✅ Login riuscito |
| `token: abc123...` | ✅ Token generato (64 caratteri) |
| `expiry: 1748...` | ✅ Scadenza token |

### ❌ Se Non Funziona

| Errore | Soluzione |
|--------|-----------|
| **401 Unauthorized** | Username o password sbagliati |
| **403 Forbidden** | API Key non corretta |
| **429 Too Many Requests** | Troppi tentativi falliti (aspetta 15 min) |
| **Connessione rifiutata** | Server offline o URL sbagliato |

---

## 📥 Test 2: Carica Post (3 minuti)

### Preparazione

Prendi il `TOKEN` dal Test 1 e sostituisci `TOKEN_RICEVUTO`:

```bash
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer TOKEN_RICEVUTO" \
  -v
```

### Risultato Atteso

```json
HTTP/1.1 200 OK

{
  "posts": [
    {
      "id": 42,
      "title": {"rendered": "Primo Post"},
      "content": {"rendered": "<p>Contenuto...</p>"},
      "date": "2025-01-11T10:30:00",
      "modified": "2025-01-11T11:00:00",
      "slug": "primo-post",
      "status": "publish",
      "link": "https://...",
      "featured_image_url": "https://..."
    }
  ],
  "current_page": 1,
  "note": "Total/pages are approximate..."
}
```

### ✅ Cosa Significa

| Elemento | Significato |
|----------|-------------|
| `HTTP/1.1 200 OK` | ✅ Successo! |
| `posts: [...]` | ✅ Post caricati |
| `id: 42` | ID post su WordPress |
| `title, content, date` | Dettagli post |
| `status: publish` | Post è pubblico |

### ❌ Se Non Funziona

| Errore | Soluzione |
|--------|-----------|
| **401 Unauthorized** | Token scaduto o non valido |
| **403 Forbidden** | Utente non ha permessi di lettura |
| **404 Not Found** | Endpoint non esiste |
| **0 post caricati** | Nessun post leggibile per l'utente |

---

## 📱 Test 3: Testa l'App Flutter (4 minuti)

### Compilazione

```bash
cd /Users/riccardo/Desktop/Progetti/TeoJurina/condominio
flutter clean
flutter pub get
flutter run
```

### Nel Simulatore/Dispositivo

1. **Apri l'app**
2. **Inserisci credenziali**
   - Username: `USERNAME` (stesso del Test 1)
   - Password: `PASSWORD` (stesso del Test 1)
3. **Clicca Login**
4. **Attendi caricamento** (5-10 secondi)
5. **Dovresti vedere post nella home** ✅

### 🔍 Guarda i Log (importante!)

Nel terminale dove hai lanciato `flutter run`, guarda i log:

```
═══════════════════════════════════════════════════
🔐 INIZIO LOGIN
═══════════════════════════════════════════════════
📧 Username: USERNAME
🔑 Password: ****...
...
✅ LOGIN COMPLETATO CON SUCCESSO!
═══════════════════════════════════════════════════

───────────────────────────────────────────────────
📥 CARICAMENTO POST
───────────────────────────────────────────────────
📦 Post caricati: 15
✅ SUCCESSO
───────────────────────────────────────────────────
```

### ✅ Se Tutto Va Bene

- [x] App aperta senza errori
- [x] Login accettato
- [x] Post visualizzati nella home
- [x] Refresh ogni 3 secondi funziona

### ❌ Se Ci Sono Problemi

1. **Controlla i log nel terminale** (vedi sopra)
2. **Se vedi "401 Unauthorized"** → Credenziali errate
3. **Se vedi "403 Forbidden"** → API Key sbagliata
4. **Se non vedi post** → Utente non ha permessi

---

## 📊 Checklist Finale

Quando tutti i 3 test sono passati:

- [ ] ✅ Test 1: Login API ritorna token
- [ ] ✅ Test 2: Caricamento post ritorna lista
- [ ] ✅ Test 3: App mostra post nella home
- [ ] ✅ Log in terminale Flask sono verdi (✅)
- [ ] ✅ Nessun errore 401/403
- [ ] ✅ Post sono leggibili

---

## 🎯 Prossimi Step

Se tutti i test passano:

1. **Leggi [DEBUGGING_GUIDE.md](./DEBUGGING_GUIDE.md)** per capire i log
2. **Testa il refresh ogni 3 secondi** - Apri 2 tab del browser, pubblica post nuovo, vedi se appare in app
3. **Leggi [DEPLOYMENT.md](./DEPLOYMENT.md)** per andare live

---

## 💡 Pro Tips

**Per copiare il token più facilmente:**

```bash
# Test 1 - piped version (salva il token in una variabile)
TOKEN=$(curl -s -X POST https://www.portobellodigallura.it/wp-json/pdg-app/v1/auth \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -d '{"username":"USERNAME","password":"PASSWORD"}' | jq -r '.token')

echo "Token: $TOKEN"

# Adesso usa $TOKEN nel Test 2
curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/posts?per_page=5' \
  -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🆘 Se i Test Falliscono

1. **Test 1 fallisce (401)** → Credenziali errate
   - Soluzione: Accedi a WordPress da browser per verificare

2. **Test 1 fallisce (403)** → API Key errata
   - Soluzione: Verifica `lib/services/api_service.dart` linea 19

3. **Test 2 fallisce (401)** → Token scaduto/invalido
   - Soluzione: Rifare Test 1

4. **Test 3 fallisce** → Vedi log nel terminale per dettagli
   - Controlla [DEBUGGING_GUIDE.md](./DEBUGGING_GUIDE.md)

---

**Quando tutti i 3 test passano, sei PRONTO! ✅**

**Tempo totale: ~10 minuti**

Buona fortuna! 🚀
