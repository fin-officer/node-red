#!/bin/bash
# Skrypt do zatrzymania wszystkich kontenerów i usunięcia sieci

echo "Zatrzymywanie wszystkich kontenerów..."
docker-compose down

echo "Sprawdzanie czy sieci Docker zostały usunięte..."
networks=$(docker network ls --filter "name=node-red" -q)
if [ -n "$networks" ]; then
    echo "Usuwanie sieci Docker związanych z projektem..."
    for network in $networks; do
        docker network rm $network 2>/dev/null || true
    done
fi

echo "Sprawdzanie czy kontenery projektu nadal istnieją..."
containers=$(docker ps -a --filter "name=ollama|mailserver|nodered-email-llm|adminer" -q)
if [ -n "$containers" ]; then
    echo "Usuwanie pozostałych kontenerów projektu..."
    docker rm -f $containers 2>/dev/null || true
fi

echo "Wszystkie kontenery i sieci zostały zatrzymane i usunięte."

# Sprawdź, czy porty są teraz wolne
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo "UWAGA: Port $port jest nadal zajęty!"
        return 1
    fi
    echo "OK: Port $port jest wolny."
    return 0
}

if [ -f .env ]; then
    source .env
    echo "Sprawdzanie kluczowych portów..."
    check_port ${MAILHOG_SMTP_PORT:-1026}
    check_port ${MAILHOG_UI_PORT:-8026}
    check_port ${OLLAMA_PORT:-11435}
    check_port ${NODERED_PORT:-1880}
    check_port ${ADMINER_PORT:-8081}
else
    echo "Plik .env nie został znaleziony, nie można sprawdzić portów."
fi