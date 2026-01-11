# 🔧 Plugin API - Riepilogo Problema e Soluzione

## 📌 Problema Identificato

Nonostante il **login sia valido**, l'app **non carica i post** dal server.

**Sintomi:**
- ✅ `apiService.login()` → Success
- ✅ Token ricevuto e salvato
- ❌ `apiService.fetchPosts()` → Array vuoto `[]`

**Root cause**: L'utente PdGadmin potrebbe **non avere i permessi di lettura** sui post installati nel database, oppure il plugin non è correttamente attivato.

---

## ✅ Cosa È Stato Fatto

### 1. **Aggiornamento Plugin** (`wordpress-plugin/pdg-app-api.php`)
- ✨ Aggiunto endpoint `/debug` (linee 393-460)
- Permette di testare lo stato del plugin senza errori
- Mostra quanti post sono leggibili vs totali

### 2. **Nuovo Servizio Debug** (`lib/services/debug_api_service.dart`)
- 🔍 `DebugApiService.testPluginAPI()` - Testa il plugin
- 📊 `analyzeTestResults()` - Analizza i risultati
- Fornisce consigli automatici basati sul risultato

### 3. **Documentazione Dettagliata**
- `DEBUG_PLUGIN_INSTALLATION.md` - Guida all'installazione con debug
- `RISOLVI_POST_VUOTI.md` - Guida completa alla risoluzione

---

## 🚀 Come Usare la Soluzione

### Fase 1: Carica il Plugin Aggiornato

**SSH sul server:**
```bash
scp wordpress-plugin/pdg-app-api.php user@portobellodigallura.it:/var/www/wordpress/wp-content/plugins/
```

**Oppure via FTP:**
1. Scarica `wordpress-plugin/pdg-app-api.php`
2. Carica in `/wp-content/plugins/pdg-app-api.php`

### Fase 2: Testa da Flutter

Nel `main.dart` (già importato `DebugApiService`), aggiungi temporaneamente un pulsante test:

```dart
ElevatedButton.icon(
  onPressed: () async {
    debugPrint('🔍 Avvio test plugin API...');
    final results = await DebugApiService.testPluginAPI();
    if (mounted) {
      DebugApiService.analyzeTestResults(results);
    }
  },
  icon: const Icon(Icons.bug_report),
  label: const Text('🔍 Testa Plugin API'),
)
```

### Fase 3: Analizza i Risultati

#### ✅ Se `readable_posts_count > 0`:
- Il plugin funziona ✓
- Il problema è nell'app
- Continua con il debug della logica di caricamento

#### ❌ Se `readable_posts_count == 0` e `posts_found > 0`:
- **Problema**: Utente senza permessi
- **Soluzione**: 
  1. Accedi a WordPress Admin
  2. Vai a Utenti → PdGadmin
  3. Configura i permessi PublishPress

#### ❌ Se `posts_found == 0`:
- **Problema**: Nessun post nel database
- **Soluzione**: Crea un post di test e pubblicalo

---

## 📊 Risultato Atteso

Se tutto funziona, vedrai nei log Flutter:

```
═══════════════════════════════════════════════════
🔍 INIZIO TEST PLUGIN API
═══════════════════════════════════════════════════
📋 Informazioni:
  Endpoint: https://www.portobellodigallura.it/wp-json/pdg-app/v1/debug
  Token disponibile: true
  Token valido: true
───────────────────────────────────────────────────
📡 RISPOSTA RICEVUTA
───────────────────────────────────────────────────
Status Code: 200
───────────────────────────────────────────────────
✅ PARSING RISPOSTA
───────────────────────────────────────────────────
👤 Utente:
  ID: 2
  Login: pdgadmin
  Nome: PdG Admin
  Ruoli: [administrator]
📰 Post:
  Totali trovati: 5
  Leggibili: 5
  Percentuale leggibilità: 100.0%
───────────────────────────────────────────────────
📋 CAMPIONE POST (primi 5):
───────────────────────────────────────────────────
1. "Breaking News" (ID: 1, Status: publish)
   Leggibile: ✅ SÌ
2. "Avviso Importante" (ID: 2, Status: publish)
   Leggibile: ✅ SÌ
───────────────────────────────────────────────────
✅ TEST COMPLETATO CON SUCCESSO
═══════════════════════════════════════════════════
```

---

## 🧹 Pulizia Finale

Una volta risolto il problema:

1. **Rimuovi l'endpoint debug dal plugin** (linee 393-460 in `pdg-app-api.php`)
2. **Rimuovi il servizio debug** (`lib/services/debug_api_service.dart`)
3. **Rimuovi il pulsante di test** dall'app
4. **Ricaricare il plugin** sul server

---

## 📌 Checklist di Controllo

- [ ] Plugin caricato sul server
- [ ] Plugin attivato da WordPress Admin
- [ ] API Key è corretta in `wp-config.php`
- [ ] Almeno 1 post pubblicato
- [ ] Utente PdGadmin ha permessi PublishPress
- [ ] Test API debug ritorna `readable_posts_count > 0`
- [ ] App carica i post con successo

---

## 🆘 Se Ancora Non Funziona

1. **Controlla i log di WordPress**:
   ```bash
   tail -f /var/www/wordpress/wp-content/debug.log
   ```

2. **Verifica la configurazione wp-config.php**:
   ```bash
   grep PDG_APP /var/www/wordpress/wp-config.php
   ```

3. **Test manuale con curl**:
   ```bash
   curl -X GET 'https://www.portobellodigallura.it/wp-json/pdg-app/v1/debug' \
     -H "x-pdg-api-key: Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe" \
     -H "Authorization: Bearer TOKEN_HERE" \
     -v
   ```

---

**Nota**: Tutti gli strumenti sono stati creati per facilitare il debug. Una volta risolto, usa la documentazione `RISOLVI_POST_VUOTI.md` per la configurazione finale.
