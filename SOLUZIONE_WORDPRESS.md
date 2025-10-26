# 🔧 Soluzioni WordPress per Imunify360

## 🎯 Problema Confermato

```bash
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
Risposta: "Access denied by Imunify360 bot-protection"
```

**Imunify360 blocca TUTTE le richieste API dell'app.**

---

## ✅ SOLUZIONE 1: Whitelist via cPanel (5 minuti) ⭐ RACCOMANDATO

### Passo 1: Accedi a cPanel
1. Vai su: `https://www.new.portobellodigallura.it:2083` (o URL del tuo cPanel)
2. Login con le tue credenziali

### Passo 2: Trova Imunify360
1. Cerca "**Imunify360**" nella barra di ricerca
2. Clicca sull'icona Imunify360

### Passo 3: Whitelist REST API
1. Vai in **Firewall** → **Whitelist**
2. Clicca "**Add to Whitelist**"
3. Seleziona "**URLs**"
4. Aggiungi questi path:
   ```
   /wp-json/*
   /wp-login.php
   /wp-admin/admin-ajax.php
   ```
5. **Salva**

### Passo 4: Test
```bash
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```
Dovresti vedere JSON con i post, non l'errore Imunify360.

---

## ✅ SOLUZIONE 2: File .htaccess WordPress (2 minuti)

### Opzione A: Via cPanel File Manager

1. **cPanel** → **File Manager**
2. Naviga nella cartella del sito: `public_html/` (o dove è installato WordPress)
3. Trova il file `.htaccess`
4. Clicca **Edit**
5. **Aggiungi all'inizio del file** (prima di `# BEGIN WordPress`):

```apache
# Whitelist WordPress REST API da Imunify360
<IfModule mod_security.c>
    <Location /wp-json/>
        SecRuleEngine Off
    </Location>
</IfModule>

# Permetti accesso API senza bot check
<FilesMatch "wp-login\.php">
    SetEnvIf User-Agent ".*" allowed
</FilesMatch>
```

6. **Salva**
7. **Testa l'app**

### Opzione B: Via FTP/SFTP

1. Connettiti via **FileZilla** (o altro client FTP)
2. Naviga in `public_html/`
3. Scarica `.htaccess`
4. Modifica con le regole sopra
5. Ri-carica il file
6. Testa

---

## ✅ SOLUZIONE 3: Plugin WordPress (10 minuti)

### Installa Plugin "Disable REST API and Require JWT"

**NO ASPETTA - vogliamo il contrario!** Usa invece:

### Plugin: "Application Passwords" (già incluso in WP 5.6+)

1. **WordPress Admin** → **Utenti** → **Il Tuo Profilo**
2. Scorri fino a "**Application Passwords**"
3. Nome: `App Mobile Condominio`
4. Clicca "**Add New Application Password**"
5. **COPIA** la password generata (es: `xxxx xxxx xxxx xxxx xxxx xxxx`)

Questa password bypassa Imunify360 perché usa Basic Auth nativo di WordPress!

### Aggiorna l'app con la nuova password:

Nel file `lib/main.dart`, linea 14:
```dart
String appPassword = 'LA-TUA-NUOVA-PASSWORD-GENERATA';
```

---

## ✅ SOLUZIONE 4: Disabilita Imunify360 per il Dominio (se hai accesso root/WHM)

### Via WHM (Web Host Manager):

1. Login in **WHM** (porta 2087)
2. Cerca "**Imunify360**"
3. **Settings** → **Malware Scanner**
4. **Disabled for domains** → Aggiungi: `new.portobellodigallura.it`
5. Salva

### Via SSH (se hai accesso root):

```bash
# Connetti via SSH
ssh root@tuoserver.com

# Disabilita Imunify360 per API WordPress
imunify360-agent whitelist add /wp-json/* --comment "WordPress REST API"
imunify360-agent whitelist add /wp-login.php --comment "WordPress Login"

# Verifica whitelist
imunify360-agent whitelist list
```

---

## ✅ SOLUZIONE 5: Contatta il Supporto Hosting

Se non hai accesso a cPanel o WHM, **contatta il supporto** con questo messaggio:

```
Oggetto: Whitelist API WordPress da Imunify360

Salve,

Il mio sito new.portobellodigallura.it ha un'app mobile che deve 
accedere alle API WordPress ma Imunify360 sta bloccando tutte 
le richieste.

Test di conferma:
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
Errore: "Access denied by Imunify360 bot-protection"

RICHIESTA:
Potete aggiungere questi path alla whitelist di Imunify360?
- /wp-json/* (tutte le API REST WordPress)
- /wp-login.php (login WordPress)
- /wp-admin/admin-ajax.php (AJAX WordPress)

OPPURE

Configurare Imunify360 per permettere richieste con User-Agent 
che contiene "iPhone" o "Mobile" verso questi endpoint.

Grazie!
```

**Provider comuni:**
- **Aruba**: Supporto tecnico via ticket
- **SiteGround**: Live chat (molto veloce!)
- **Hostinger**: Live chat
- **ServerPlan**: assistenza@serverplan.com

---

## ✅ SOLUZIONE 6: Test Temporaneo - Disabilita Imunify360 (NON per produzione!)

**SOLO PER TEST - 5 minuti:**

### Via cPanel:
1. **Imunify360** → **Settings**
2. **Firewall** → **Mode**
3. Cambia da "**Active**" a "**Disabled**"
4. Testa l'app
5. **RIATTIVA** subito dopo il test!

⚠️ **ATTENZIONE**: Il sito sarà vulnerabile durante il test!

---

## 🧪 Come Verificare Se Ha Funzionato

### Test 1: cURL Base
```bash
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```
✅ **Successo**: Vedi JSON con array di post  
❌ **Fallito**: Vedi "Access denied by Imunify360"

### Test 2: cURL con User-Agent Mobile
```bash
curl -H "User-Agent: Mozilla/5.0 (iPhone)" \
  https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```
✅ **Successo**: Vedi JSON con post

### Test 3: App Flutter
1. Lancia l'app
2. Prova a fare login
3. Controlla se i post vengono scaricati

---

## 📊 Quale Soluzione Scegliere?

| Soluzione | Difficoltà | Tempo | Efficacia |
|-----------|------------|-------|-----------|
| 1. Whitelist cPanel | ⭐ Facile | 5 min | ✅✅✅ Alta |
| 2. .htaccess | ⭐⭐ Media | 2 min | ✅✅ Media |
| 3. Application Password | ⭐ Facile | 10 min | ✅✅✅ Alta |
| 4. WHM/SSH | ⭐⭐⭐ Difficile | 5 min | ✅✅✅ Alta |
| 5. Supporto | ⭐ Facile | 1-24h | ✅✅✅ Alta |
| 6. Disabilita (test) | ⭐ Facile | 2 min | ⚠️ Solo test |

**RACCOMANDAZIONE**: 
1. **Prima prova Soluzione 3** (Application Password) - è la più sicura
2. Se non funziona, **prova Soluzione 1** (Whitelist cPanel)
3. Se non hai accesso, **Soluzione 5** (Contatta supporto)

---

## 🆘 Non Funziona Ancora?

### Verifica anche:

1. **Cloudflare** (se attivo):
   - Login su cloudflare.com
   - **Security** → **WAF** → **Custom Rules**
   - Aggiungi regola: URI Path contains `/wp-json/` → Action: **Allow**

2. **Plugin di sicurezza WordPress**:
   - Wordfence
   - Sucuri
   - iThemes Security
   
   **Disabilitali temporaneamente per test**

3. **Firewall a livello server**:
   - Chiedi al supporto se ci sono altri firewall attivi
   - ConfigServer Security & Firewall (CSF)
   - ModSecurity

---

## 📝 Log Utili per Debug

Se contatti il supporto, fornisci questi log:

```bash
# Test base
curl -v https://www.new.portobellodigallura.it/wp-json/wp/v2/posts 2>&1 | grep -E "(HTTP|Server|imunify|cloudflare)"

# Test con headers
curl -v -H "User-Agent: Mozilla/5.0 (iPhone)" \
  -H "Accept: application/json" \
  https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```

---

## ✅ Conclusione

Il problema è **solo configurazione server**, non c'è nulla di sbagliato:
- ✅ WordPress funziona
- ✅ Le API esistono
- ✅ L'app è corretta
- ❌ **Imunify360 blocca le richieste** ← DA RISOLVERE

**Tempo stimato soluzione**: 5-30 minuti (a seconda del metodo scelto)

Buona fortuna! 🚀

