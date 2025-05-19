#!/bin/bash
# Skrypt restartujący dla Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\033[0;34m[INFO]\033[0m Restartowanie projektu Email-LLM Integration..."

# Zatrzymaj kontenery
./scripts/stop.sh

# Poczekaj chwilę
sleep 2

# Uruchom kontenery
./scripts/start.sh
