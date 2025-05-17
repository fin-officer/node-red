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

# Załaduj zmienne środowiskowe
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}[UWAGA]${NC} Plik .env nie został znaleziony, używam domyślnych wartości."
fi

# Funkcja do sprawdzania, czy port jest zajęty
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${YELLOW}[UWAGA]${NC} Port $port używany przez $service jest już zajęty."
        echo -e "Możesz zmienić port w pliku .env lub zatrzymać usługę używającą tego portu."
        return 1
    fi
    return 0
}

# Sprawdź dostępność portów
ports_ok=true
check_port $NODERED_PORT "Node-RED" || ports_ok=false
check_port $MAILHOG_SMTP_PORT "MailHog SMTP" || ports_ok=false
check_port $MAILHOG_UI_PORT "MailHog UI" || ports_ok=false
check_port $OLLAMA_PORT "Ollama" || ports_ok=false
check_port $ADMINER_PORT "Adminer" || ports_ok=false

if [ "$ports_ok" = false ]; then
    echo -e "${YELLOW}[UWAGA]${NC} Wykryto zajęte porty. Czy chcesz kontynuować? (t/n)"
    read -r response
    if [[ ! "$response" =~ ^[tT]$ ]]; then
        echo -e "${YELLOW}[INFO]${NC} Zatrzymanie uruchamiania."
        exit 1
    fi
fi

# Uruchom docker-compose
echo -e "${BLUE}[INFO]${NC} Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Ollama..."
# Wewnętrzny port Ollama to nadal 11434
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
if ! docker exec -i ollama ollama list | grep -q $OLLAMA_MODEL; then
    echo -e "${BLUE}[INFO]${NC} Pobieranie modelu $OLLAMA_MODEL (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull $OLLAMA_MODEL
fi

# Poczekaj na uruchomienie Node-RED
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Node-RED..."
until curl -s http://localhost:$NODERED_PORT/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}[SUKCES]${NC} Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "${BLUE}* Node-RED:${NC} http://localhost:$NODERED_PORT"
echo -e "${BLUE}* Node-RED API:${NC} http://localhost:$NODERED_PORT/api"
echo -e "${BLUE}* Ollama API:${NC} http://localhost:$OLLAMA_PORT"
echo -e "${BLUE}* Panel testowej skrzynki email:${NC} http://localhost:$MAILHOG_UI_PORT"
echo -e "${BLUE}* Panel administracyjny SQLite:${NC} http://localhost:$ADMINER_PORT"
echo ""
echo -e "${YELLOW}Aby zatrzymać aplikację, użyj polecenia:${NC} ./scripts/stop.sh"