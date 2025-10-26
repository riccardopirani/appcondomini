# 🚨 PROBLEMA IDENTIFICATO: Imunify360 Blocca l'App

## ❌ Perché il Login Non Funziona

Il tuo server WordPress ha **Imunify360** (sistema di protezione) che **blocca TUTTE le richieste** della tua app Flutter.

**NON è colpa di:**
- ❌ Username/password errati (le credenziali sono corrette!)
- ❌ Codice dell'app sbagliato
- ❌ Errori di programmazione

**È colpa di:**
- ✅ **Imunify360 che blocca l'app** perché la vede come "bot automatico"

---

## 🔍 Prova Tu Stesso

Apri il terminale e digita:
```bash
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```

**Risposta che ricevi:**
```json
{
  "message": "Access denied by Imunify360 bot-protection. 
              IPs used for automation should be whitelisted"
}
```

**Questo PROVA che Imunify360 sta bloccando le richieste!**

---

## ✅ COME RISOLVERE (3 Opzioni)

### **Opzione 1: Disabilita Imunify360 per le API WordPress** ⭐ RACCOMANDATO

#### Se hai accesso a cPanel:

1. **Accedi a cPanel** del tuo hosting
2. Cerca "**Imunify360**" nella barra di ricerca
3. Vai in **Firewall** → **Whitelist**
4. Clicca "**Add IP or network to Whitelist**"
5. Invece di un IP, aggiungi una **regola basata su User-Agent**:
   - User-Agent contiene: `Mobile`
   - Oppure User-Agent contiene: `iPhone`
6. **Salva** la regola
7. **Testa l'app** → dovrebbe funzionare!

#### OPPURE - Via Ignore List:

1. **Imunify360** → **Settings** → **Malware Scanner**
2. **Ignore List** → Aggiungi questi path:
   ```
   /wp-json/*
   /wp-login.php
   /wp-admin/admin-ajax.php
   ```
3. Salva e testa

---

### **Opzione 2: Contatta il Tuo Hosting Provider** 📞

**Se NON hai accesso a cPanel**, manda questa email al supporto:

```
Oggetto: Disabilitare Imunify360 per API WordPress

Ciao,

Ho un'app mobile che deve accedere al mio sito WordPress 
(www.new.portobellodigallura.it) ma Imunify360 sta bloccando 
tutte le richieste.

Errore ricevuto:
"Access denied by Imunify360 bot-protection. IPs used for 
automation should be whitelisted"

RICHIESTA:
Potete disabilitare Imunify360 per questi endpoint?
- /wp-json/* (API REST WordPress)
- /wp-login.php (Login WordPress)
- /wp-admin/admin-ajax.php (AJAX WordPress)

OPPURE

Aggiungere una whitelist per User-Agent che contiene "Mobile" 
o "iPhone" in modo che le app mobile possano accedere.

Grazie mille!
```

**Hosting provider comuni:**
- Aruba: supporto@aruba.it
- SiteGround: supporto via chat
- Hostinger: live chat
- ServerPlan: assistenza@serverplan.com

---

### **Opzione 3: Configurazione Manuale via SSH** 💻

Se hai accesso SSH al server:

```bash
# Connettiti via SSH
ssh tuoutente@tuoserver.com

# Modifica la configurazione Imunify360
sudo nano /etc/sysconfig/imunify360/imunify360.config

# Aggiungi questa sezione:
MOD_SEC:
  ruleset: CUSTOM
  custom_rules:
    - SecRule REQUEST_URI "@beginsWith /wp-json/" "id:1000001,phase:1,pass,nolog,ctl:ruleEngine=Off"
    - SecRule REQUEST_URI "@beginsWith /wp-login.php" "id:1000002,phase:1,pass,nolog,ctl:ruleEngine=Off"

# Salva e riavvia Imunify360
sudo systemctl restart imunify360
```

---

## 🧪 Come Testare Se Ha Funzionato

Dopo aver applicato la soluzione, testa:

```bash
curl -H "User-Agent: Mozilla/5.0 (iPhone)" https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```

**Risultato atteso:** 
- ✅ Dovresti vedere JSON con i post (non più l'errore Imunify360)
- ✅ L'app dovrebbe fare login con successo
- ✅ I post dovrebbero caricarsi nell'app

---

## ⏱️ Quanto Tempo Ci Vuole?

- **Con accesso cPanel**: 5 minuti
- **Tramite hosting provider**: 1-24 ore (dipende dal supporto)
- **Via SSH**: 10 minuti (se sai usare SSH)

---

## 🆘 Hai Ancora Problemi?

Se dopo aver applicato queste soluzioni l'app ancora non funziona:

1. **Verifica** che la regola sia stata applicata correttamente
2. **Prova** a riavviare il server web
3. **Controlla** i log di Imunify360: `/var/log/imunify360/`
4. **Contattami** con i log e ti aiuto ulteriormente

---

## 📊 Provider Che Usano Imunify360

Questi provider usano tipicamente Imunify360:
- ✅ Aruba (Italia)
- ✅ Shellrent (Italia)
- ✅ Keliweb (Italia)
- ✅ ServerPlan (Italia)
- ✅ A2 Hosting
- ✅ InMotion Hosting
- ✅ GreenGeeks

Se usi uno di questi, questa è sicuramente la causa del problema!

---

## 🎯 In Sintesi

1. ❌ **Problema**: Imunify360 blocca l'app
2. ✅ **Soluzione**: Disabilita Imunify360 per `/wp-json/*`
3. 🔧 **Chi**: Tu (se hai cPanel) o il supporto hosting
4. ⏱️ **Tempo**: 5 minuti - 24 ore
5. ✅ **Risultato**: App funzionante!

**Non è un problema dell'app - è solo una configurazione del server da modificare.**

Buona fortuna! 🚀

