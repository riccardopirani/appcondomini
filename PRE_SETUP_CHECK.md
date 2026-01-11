# ✅ Pre-Setup Checklist

Prima di iniziare il setup, verifica di avere tutto:

## 🖥️ Infrastruttura WordPress

- [ ] Accesso SSH/SFTP al server WordPress
- [ ] PHP 7.0+ installato
- [ ] WordPress 5.0+ installato e aggiornato
- [ ] Cartella `wp-content/plugins/` scrivibile
- [ ] Accesso WordPress Admin (username/password)

**Come verificare:**
```bash
# Accedi al server
ssh user@www.portobellodigallura.it

# Verifica PHP
php --version  # Deve essere 7.0+

# Verifica permessi cartella
ls -la wp-content/ | grep plugins

# Verifica WordPress
wp --version
```

---

## 📱 Progetto Flutter

- [ ] Flutter SDK installato
- [ ] Cartella progetto disponibile: `/Users/riccardo/Desktop/Progetti/TeoJurina/condominio`
- [ ] Dipendenze installate: `flutter pub get`
- [ ] Build tools aggiornati: `flutter doctor`
- [ ] Versione minima Flutter 3.0+

**Come verificare:**
```bash
# Verifica Flutter
flutter --version  # Deve essere 3.0+

# Verifica build
cd /Users/riccardo/Desktop/Progetti/TeoJurina/condominio
flutter doctor

# Verifica dipendenze
flutter pub get
```

---

## 🔐 Sicurezza e Credenziali

- [ ] Non ho accesso a credenziali sensibili (lasciale al sysadmin)
- [ ] Ho un luogo sicuro per salvare la chiave API (password manager)
- [ ] Non commitierò chiavi nel repo Git
- [ ] Ho capito il rischio di esporre la chiave API

---

## 📚 Documentazione

- [ ] Ho tutti questi file disponibili:
  - [ ] `QUICK_START.md`
  - [ ] `SETUP_INSTRUCTIONS.md`
  - [ ] `PLUGIN_SETUP.md`
  - [ ] `DEPLOYMENT.md`

---

## 🛠️ Strumenti Necessari

- [ ] Terminal/CMD disponibile
- [ ] Text editor per modificare file
- [ ] `curl` installato (per test API)
- [ ] `jq` installato (opzionale, per formattare JSON)

**Come installare:**
```bash
# macOS
brew install curl jq

# Ubuntu/Debian
sudo apt-get install curl jq

# Windows (tramite chocolatey)
choco install curl jq
```

---

## ⏰ Tempo Disponibile

- [ ] Ho **almeno 30 minuti** per il setup
- [ ] Ho **almeno 20 minuti** per i test
- [ ] **Non sono di fretta** (meglio prendersela comoda)
- [ ] Non ho **deadline critica** nelle prossime 48 ore

---

## 📖 Prerequisiti Knowledge

- [ ] So cosa è SSH/SFTP
- [ ] So cosa è REST API
- [ ] Ho usato terminal/cmd prima
- [ ] So cos'è un file JSON
- [ ] So cos'è un token JWT (almeno vagamente)

**Se no**: Non preoccuparti, i documenti spiegano tutto. Leggi lentamente!

---

## 🚨 Rischi da Conoscere

**Leggi attentamente:**

- [ ] Capisco che modificare `wp-config.php` è critico
- [ ] So che un errore potrebbe bloccare il sito
- [ ] So che devo testare PRIMA di dire "è live"
- [ ] So che se sbagli, il plugin fallback automaticamente
- [ ] Ho un piano di rollback se qualcosa non funziona

---

## 🎯 Obiettivo Finale

Capisco che alla fine avrò:

- [ ] ✅ Plugin API installato su WordPress
- [ ] ✅ App Flutter che fa login UNA SOLA VOLTA
- [ ] ✅ Token JWT valido per 30 giorni
- [ ] ✅ Refresh post ogni 3 secondi SENZA login
- [ ] ✅ Fallback automatico ai vecchi metodi
- [ ] ✅ Rate limiting per sicurezza

---

## 📋 Lista di Controllo Hardware

- [ ] Computer con accesso a internet
- [ ] Account email (se ti serve reset password)
- [ ] Smartphone per testare l'app
- [ ] Editor di testo (VS Code, Sublime, nano, ecc.)
- [ ] Batteria carica (non vuoi che si spenga during deploy!)

---

## ✨ Ultimo Check

Prima di iniziare:

```bash
# 1. Verifica accesso progetto Flutter
ls -la /Users/riccardo/Desktop/Progetti/TeoJurina/condominio/lib/

# 2. Verifica file exist
ls -la /Users/riccardo/Desktop/Progetti/TeoJurina/condominio/QUICK_START.md

# 3. Verifica flutter
cd /Users/riccardo/Desktop/Progetti/TeoJurina/condominio
flutter doctor -v | head -20

# 4. Verifica Git (opzionale)
git status
```

Se tutto ritorna output sensato, sei ✅ PRONTO!

---

## 🚀 Pronto?

Se hai checkato tutto (specialmente il tempo disponibile 😅), puoi iniziare:

**PROSSIMO STEP**: [QUICK_START.md](./QUICK_START.md)

---

## ⚠️ Se Manca Qualcosa

| Cosa manca | Soluzione | Tempo |
|-----------|-----------|-------|
| SSH access | Contatta sysadmin | 1 day |
| Flutter | `brew install flutter` | 30 min |
| Zeit/Tempo | Riprova domani | N/A |
| Credenziali WP | Chiedi admin | 1 day |
| Courage 😅 | Leggi i doc! | 20 min |

---

## 💡 Pro Tips

1. **Fai tutto di sera/notte** - Meno carico sul server
2. **Tieni crash log aperto** - `tail -f wp-content/debug.log`
3. **Backup WordPress** - Sempre una buona idea
4. **Testa tutto PRIMA** - Non saltare i test
5. **Leggi i messaggi di errore** - Di solito dicono cosa non va

---

## 🎓 Se Hai Paura

**È normale!** Ecco cosa fare:

1. Leggi [QUICK_START.md](./QUICK_START.md) una volta (veloce)
2. Leggi [SETUP_INSTRUCTIONS.md](./SETUP_INSTRUCTIONS.md) con calma
3. Fai ogni passo UNO ALLA VOLTA
4. Se qualcosa non funziona, FERMA e controlla i log
5. È praticamente impossibile rompere WordPress (ha fallback)

---

**Sei PRONTO! 🚀 Vai a [QUICK_START.md](./QUICK_START.md)**

---

*Completato: ______ / ______ (data)*  
*Nome: ___________________*  
*Segnali di stress: basso □ medio ☑ alto □ 😅*
