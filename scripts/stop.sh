#!/bin/bash
# Skrypt zatrzymujący dla Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Zatrzymywanie projektu Email-LLM Integration..."

# Zatrzymaj kontenery
docker-compose down

echo -e "${GREEN}[SUKCES]${NC} Projekt zatrzymany pomyślnie!"