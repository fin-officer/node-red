#!/bin/bash
# Skrypt startowy dla Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\033[0;34m[INFO]\033[0m Uruchamianie projektu Email-LLM Integration..."

# Sprawdź, czy Docker działa
if ! docker info > /dev/null 2>&1; then
    echo -e "\033[0;31m[BŁĄD]\033[0m Docker nie jest uruchomiony. Uruchom Docker i spróbuj ponownie."
    exit 1
fi

# Uruchom docker-compose
echo -e "\033[0;34m[INFO]\033[0m Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "\033[0;34m[INFO]\033[0m Czekam na uruchomienie Ollama..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
source .env
MODEL=${OLLAMA_MODEL:-mistral}
if ! docker exec -i ollama ollama list | grep -q $MODEL; then
    echo -e "\033[0;34m[INFO]\033[0m Pobieranie modelu $MODEL (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull $MODEL
fi

# Poczekaj na uruchomienie Node-RED
echo -e "\033[0;34m[INFO]\033[0m Czekam na uruchomienie Node-RED..."
until curl -s http://localhost:${NODERED_PORT:-1880}/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "\033[0;32m[SUKCES]\033[0m Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "\033[0;34m* Node-RED:\033[0m http://localhost:${NODERED_PORT:-1880}"
echo -e "\033[0;34m* Node-RED API:\033[0m http://localhost:${NODERED_PORT:-1880}/api"
echo -e "\033[0;34m* Panel testowej skrzynki email:\033[0m http://localhost:8025"
echo -e "\033[0;34m* Panel administracyjny SQLite:\033[0m http://localhost:8081"
echo ""
echo -e "\033[1;33mAby zatrzymać aplikację, użyj polecenia:\033[0m ./scripts/stop.sh"
