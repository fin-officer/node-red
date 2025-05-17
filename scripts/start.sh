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

# Ustaw domyślne wartości, jeśli nie zostały zdefiniowane
OLLAMA_MODEL=${OLLAMA_MODEL:-mistral}
OLLAMA_PORT=${OLLAMA_PORT:-11435}
NODERED_PORT=${NODERED_PORT:-1880}
MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT:-1026}
MAILHOG_UI_PORT=${MAILHOG_UI_PORT:-8026}
ADMINER_PORT=${ADMINER_PORT:-8081}

# Funkcja do sprawdzania, czy port jest zajęty
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
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

# Sprawdź, czy chcemy zbudować niestandardowy obraz Ollama
build_custom_ollama=false
if [ -f ./docker/ollama/Dockerfile ]; then
    echo -e "${BLUE}[INFO]${NC} Znaleziono niestandardowy Dockerfile dla Ollama."
    echo -e "${YELLOW}[PYTANIE]${NC} Czy chcesz zbudować niestandardowy obraz Ollama? (t/n)"
    read -r response
    if [[ "$response" =~ ^[tT]$ ]]; then
        build_custom_ollama=true
    fi
fi

# Zbuduj niestandardowy obraz Ollama, jeśli użytkownik wybrał tę opcję
if [ "$build_custom_ollama" = true ]; then
    echo -e "${BLUE}[INFO]${NC} Budowanie niestandardowego obrazu Ollama..."
    (cd ./docker/ollama && ./build.sh $OLLAMA_MODEL)

    # Zaktualizuj docker-compose.yml, aby używać niestandardowego obrazu
    if grep -q "image: ollama/ollama" docker-compose.yml; then
        sed -i 's|image: ollama/ollama:latest|image: custom-ollama:latest|g' docker-compose.yml
        echo -e "${BLUE}[INFO]${NC} Zaktualizowano docker-compose.yml, aby używać niestandardowego obrazu."
    fi
fi

# Uruchom docker-compose
echo -e "${BLUE}[INFO]${NC} Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama z timeoutem
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Ollama (timeout: 2 minuty)..."
start_time=$(date +%s)
timeout=120 # 2 minuty
ollama_ready=false

while [ $(($(date +%s) - $start_time)) -lt $timeout ]; do
    if docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; then
        ollama_ready=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$ollama_ready" = false ]; then
    echo -e "${YELLOW}[UWAGA]${NC} Przekroczono czas oczekiwania na uruchomienie Ollama."
    echo -e "Kontenery zostały uruchomione, ale Ollama może potrzebować więcej czasu."
    echo -e "Możesz sprawdzić logi Ollama: docker logs -f ollama"
else
    echo -e "${GREEN}[SUKCES]${NC} Ollama uruchomiony pomyślnie!"

    # Pobierz model, jeśli nie istnieje (tylko jeśli nie używamy niestandardowego obrazu)
    if [ "$build_custom_ollama" = false ]; then
        if ! docker exec -i ollama ollama list | grep -q $OLLAMA_MODEL; then
            echo -e "${BLUE}[INFO]${NC} Pobieranie modelu $OLLAMA_MODEL (może to potrwać kilka minut)..."
            docker exec -i ollama ollama pull $OLLAMA_MODEL
        fi
    fi
fi

# Poczekaj na uruchomienie Node-RED z timeoutem
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Node-RED (timeout: 1 minuta)..."
start_time=$(date +%s)
timeout=60 # 1 minuta
nodered_ready=false

while [ $(($(date +%s) - $start_time)) -lt $timeout ]; do
    if curl -s http://localhost:$NODERED_PORT/health &> /dev/null; then
        nodered_ready=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$nodered_ready" = false ]; then
    echo -e "${YELLOW}[UWAGA]${NC} Przekroczono czas oczekiwania na uruchomienie Node-RED."
    echo -e "Możesz sprawdzić logi Node-RED: docker logs -f nodered-email-llm"
else
    echo -e "${GREEN}[SUKCES]${NC} Node-RED uruchomiony pomyślnie!"
fi

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