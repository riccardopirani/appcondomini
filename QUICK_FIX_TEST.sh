#!/bin/bash

# 🚀 QUICK TEST PLUGIN API - Per risolvere velocemente il problema dei post vuoti
# 
# Questo script testa se il plugin PdG App API funziona correttamente
# 
# Uso: bash QUICK_FIX_TEST.sh <username> <password>
# Esempio: bash QUICK_FIX_TEST.sh pdgadmin MyPassword123

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurazione
API_URL="https://www.portobellodigallura.it/wp-json/pdg-app/v1"
API_KEY="Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe"
USERNAME="${1:-pdgadmin}"
PASSWORD="${2:-}"

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}❌ Errore: Password richiesta${NC}"
    echo "Uso: bash QUICK_FIX_TEST.sh <username> <password>"
    echo "Esempio: bash QUICK_FIX_TEST.sh pdgadmin MyPassword123"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 TEST PLUGIN API PdG${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# Step 1: Verifica API disponibilità
echo -e "\n${YELLOW}Step 1: Verifica API disponibilità...${NC}"
if ! curl -s "$API_URL/auth" > /dev/null 2>&1; then
    echo -e "${RED}❌ API non raggiungibile${NC}"
    echo "URL: $API_URL"
    exit 1
fi
echo -e "${GREEN}✅ API disponibile${NC}"

# Step 2: Esegui login e estrai token
echo -e "\n${YELLOW}Step 2: Autenticazione con $USERNAME...${NC}"
AUTH_RESPONSE=$(curl -s -X POST "$API_URL/auth" \
  -H "Content-Type: application/json" \
  -H "x-pdg-api-key: $API_KEY" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Login fallito${NC}"
    echo "Risposta: $AUTH_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Login riuscito${NC}"
echo "Token: ${TOKEN:0:20}...${TOKEN: -10}"

# Step 3: Test endpoint debug
echo -e "\n${YELLOW}Step 3: Test endpoint debug...${NC}"
DEBUG_RESPONSE=$(curl -s -X GET "$API_URL/debug" \
  -H "x-pdg-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Parse JSON
POSTS_FOUND=$(echo "$DEBUG_RESPONSE" | grep -o '"posts_found":[0-9]*' | cut -d':' -f2)
READABLE_COUNT=$(echo "$DEBUG_RESPONSE" | grep -o '"readable_posts_count":[0-9]*' | cut -d':' -f2)
USER_LOGIN=$(echo "$DEBUG_RESPONSE" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)

if [ -z "$POSTS_FOUND" ]; then
    echo -e "${RED}❌ Debug endpoint fallito${NC}"
    echo "Risposta: $DEBUG_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Debug endpoint funzionante${NC}"

# Step 4: Analisi risultati
echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 RISULTATI${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

echo -e "\n👤 Utente:"
echo "   Login: $USER_LOGIN"

echo -e "\n📰 Post:"
echo "   Totali nel database: $POSTS_FOUND"
echo "   Leggibili dall'utente: $READABLE_COUNT"

if [ "$POSTS_FOUND" -eq 0 ]; then
    echo -e "\n${RED}⚠️  PROBLEMA: Nessun post nel database${NC}"
    echo -e "${YELLOW}🔧 Soluzione:${NC}"
    echo "   1. Accedi a WordPress Admin"
    echo "   2. Crea almeno un post di test"
    echo "   3. Pubblica il post"
    echo "   4. Riprova il test"
    exit 1
fi

if [ "$READABLE_COUNT" -eq 0 ]; then
    echo -e "\n${RED}⚠️  PROBLEMA: L'utente non può leggere alcun post${NC}"
    echo -e "${YELLOW}🔧 Soluzione:${NC}"
    echo "   1. Accedi a WordPress Admin"
    echo "   2. Vai a Utenti → $USER_LOGIN"
    echo "   3. Configura i permessi PublishPress"
    echo "   4. Assicurati che l'utente abbia accesso alle categorie"
    echo "   5. Riprova il test"
    exit 1
fi

PERCENTAGE=$((READABLE_COUNT * 100 / POSTS_FOUND))

if [ "$READABLE_COUNT" -eq "$POSTS_FOUND" ]; then
    echo -e "\n${GREEN}✅ TUTTO OK! L'utente può leggere tutti i post ($PERCENTAGE%)${NC}"
    echo -e "${GREEN}✅ Il plugin API funziona correttamente${NC}"
    echo -e "\n${YELLOW}Prossimo step:${NC}"
    echo "   Se l'app non carica comunque i post:"
    echo "   1. Controlla i log di Flutter"
    echo "   2. Verifica che _tryFetchPostsViaPluginApi() sia richiamato"
    echo "   3. Controlla il parsing della risposta JSON"
else
    echo -e "\n${YELLOW}⚠️  ATTENZIONE: L'utente può leggere solo il $PERCENTAGE% dei post${NC}"
    echo -e "${YELLOW}🔧 Soluzione parziale:${NC}"
    echo "   1. Accedi a WordPress Admin"
    echo "   2. Verifica i permessi PublishPress per questa categoria"
    echo "   3. Estendi i permessi dell'utente se necessario"
fi

echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ TEST COMPLETATO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
