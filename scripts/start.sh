#!/bin/bash
# Skrypt startowy dla Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Uruchamianie projektu Email-LLM Integration..."

# Sprawdź, czy Docker działa
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}[BŁĄD]${NC} Docker nie jest uruchomiony. Uruchom Docker i spróbuj ponownie."
    exit 1
fi

# Uruchom docker-compose
echo -e "${BLUE}[INFO]${NC} Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Ollama..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
source .env
MODEL=${OLLAMA_MODEL:-mistral}
if ! docker exec -i ollama ollama list | grep -q $MODEL; then
    echo -e "${BLUE}[INFO]${NC} Pobieranie modelu $MODEL (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull $MODEL
fi

# Poczekaj na uruchomienie Node-RED
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Node-RED..."
until curl -s http://localhost:${NODERED_PORT:-1880}/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}[SUKCES]${NC} Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "${BLUE}* Node-RED:${NC} http://localhost:${NODERED_PORT:-1880}"
echo -e "${BLUE}* Node-RED API:${NC} http://localhost:${NODERED_PORT:-1880}/api"
echo -e "${BLUE}* Panel testowej skrzynki email:${NC} http://localhost:8025"
echo -e "${BLUE}* Panel administracyjny SQLite:${NC} http://localhost:8081"
echo ""
echo -e "${YELLOW}Aby zatrzymać aplikację, użyj polecenia:${NC} ./scripts/stop.sh"