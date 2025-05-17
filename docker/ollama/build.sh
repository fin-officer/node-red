#!/bin/bash
# Skrypt do budowania obrazu Ollama

MODEL=${1:-mistral}
TAG=${2:-latest}

echo "Budowanie obrazu Ollama z modelem $MODEL..."
docker build --build-arg MODEL=$MODEL -t custom-ollama:$TAG .

echo "Obraz custom-ollama:$TAG został zbudowany pomyślnie!"
