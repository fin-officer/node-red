#!/bin/bash
# Skrypt do instalacji modułu cron-plus z dodatkowymi opcjami

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Instalowanie modułu node-red-contrib-cron-plus..."

# Sprawdź czy kontener Node-RED działa
if ! docker ps | grep -q "nodered-email-llm"; then
    echo -e "${RED}[BŁĄD]${NC} Kontener Node-RED nie jest uruchomiony. Uruchom go najpierw używając scripts/start.sh"
    exit 1
fi

# Wyczyść npm cache
echo -e "${BLUE}[INFO]${NC} Czyszczenie cache npm..."
docker exec -it nodered-email-llm npm cache clean --force

# Instalacja z force i verbose dla lepszego debugowania
echo -e "${BLUE}[INFO]${NC} Instalowanie modułu cron-plus (próba 1)..."
docker exec -it nodered-email-llm npm install --unsafe-perm --verbose node-red-contrib-cron-plus

# Sprawdź, czy instalacja się powiodła
if ! docker exec -it nodered-email-llm npm list | grep -q "node-red-contrib-cron-plus"; then
    echo -e "${YELLOW}[UWAGA]${NC} Pierwsza próba instalacji nie powiodła się. Próba alternatywnej instalacji..."
    
    # Instalacja globalna, a następnie lokalna
    echo -e "${BLUE}[INFO]${NC} Instalowanie modułu cron-plus globalnie (próba 2)..."
    docker exec -it nodered-email-llm npm install -g node-red-contrib-cron-plus
    
    echo -e "${BLUE}[INFO]${NC} Linkowanie modułu cron-plus do lokalnego projektu..."
    docker exec -it nodered-email-llm bash -c "cd /data && npm link node-red-contrib-cron-plus"
fi

# Sprawdź ponownie, czy instalacja się powiodła
if ! docker exec -it nodered-email-llm npm list | grep -q "node-red-contrib-cron-plus"; then
    echo -e "${YELLOW}[UWAGA]${NC} Druga próba instalacji nie powiodła się. Próbuję alternatywną metodę..."
    
    # Instalacja przez npm bezpośrednio z repozytorium
    echo -e "${BLUE}[INFO]${NC} Instalowanie modułu cron-plus z repozytorium GitHub (próba 3)..."
    docker exec -it nodered-email-llm npm install --unsafe-perm https://github.com/totallyinformation/node-red-contrib-cron-plus.git
fi

echo -e "${BLUE}[INFO]${NC} Sprawdzanie, czy moduł został zainstalowany..."
if docker exec -it nodered-email-llm npm list | grep -q "node-red-contrib-cron-plus"; then
    echo -e "${GREEN}[SUKCES]${NC} Moduł node-red-contrib-cron-plus został pomyślnie zainstalowany."
else
    echo -e "${RED}[BŁĄD]${NC} Nie udało się zainstalować modułu node-red-contrib-cron-plus."
    echo -e "${YELLOW}[WSKAZÓWKA]${NC} Spróbuj zainstalować ręcznie lub użyj alternatywnego węzła do zaplanowanych zadań."
fi

echo -e "${BLUE}[INFO]${NC} Restartowanie Node-RED..."
docker restart nodered-email-llm

echo -e "${BLUE}[INFO]${NC} Sprawdzanie logów Node-RED dla ewentualnych błędów..."
sleep 5
docker logs --tail 50 nodered-email-llm

echo -e "${YELLOW}[INFO]${NC} Poczekaj ok. 30 sekund na restart Node-RED i załadowanie nowych węzłów."
echo -e "${YELLOW}[INFO]${NC} Następnie odśwież interfejs Node-RED w przeglądarce."