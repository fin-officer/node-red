#!/bin/bash
# Skrypt do bezpośredniej instalacji i naprawy modułu cron-plus

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Próba bezpośredniej instalacji modułu cron-plus w kontenerze..."

# Wykonaj polecenia bezpośrednio w kontenerze jako użytkownik root
docker exec -u root -it nodered-email-llm bash -c "
echo \"Zmieniam uprawnienia katalogu .npm\"
chown -R node-red:node-red /data/.npm 2>/dev/null || true
chmod -R 775 /data/.npm 2>/dev/null || true

echo \"Tworzę katalog dla modułów node\"
mkdir -p /data/node_modules
chown -R node-red:node-red /data/node_modules
chmod -R 775 /data/node_modules

echo \"Instaluję cron-plus z uprawnieniami root\"
cd /data && npm install --unsafe-perm node-red-contrib-cron-plus
"

# Sprawdź, czy instalacja się powiodła
echo -e "${BLUE}[INFO]${NC} Sprawdzanie, czy moduł został zainstalowany..."
if docker exec -it nodered-email-llm bash -c "cd /data && npm list node-red-contrib-cron-plus" | grep -q "node-red-contrib-cron-plus"; then
    echo -e "${GREEN}[SUKCES]${NC} Moduł cron-plus został zainstalowany!"
else
    echo -e "${YELLOW}[UWAGA]${NC} Moduł cron-plus nadal nie jest zainstalowany. Próba alternatywnej instalacji..."

    # Spróbuj alternatywnej metody - instalacja z repozytorium GitHub
    docker exec -u root -it nodered-email-llm bash -c "
    echo \"Instaluję cron-plus z repozytorium GitHub\"
    cd /data && npm install --unsafe-perm https://github.com/totallyinformation/node-red-contrib-cron-plus.git
    "

    if docker exec -it nodered-email-llm bash -c "cd /data && npm list node-red-contrib-cron-plus" | grep -q "node-red-contrib-cron-plus"; then
        echo -e "${GREEN}[SUKCES]${NC} Moduł cron-plus został zainstalowany z repozytorium GitHub!"
    else
        echo -e "${RED}[BŁĄD]${NC} Nie udało się zainstalować modułu cron-plus."
        echo -e "${YELLOW}[INFO]${NC} Użyj alternatywnego flow bez cron-plus."
    fi
fi

echo -e "${BLUE}[INFO]${NC} Restartowanie Node-RED..."
docker restart nodered-email-llm

echo -e "${YELLOW}[INFO]${NC} Poczekaj ok. 30 sekund na restart Node-RED i sprawdź, czy moduł cron-plus jest dostępny."