FROM ollama/ollama:latest

# Ustaw zmienne środowiskowe dla szybszego uruchamiania
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_KEEP_ALIVE=1

# Tworzymy entrypoint, który będzie pobierał model przy pierwszym uruchomieniu
RUN echo '#!/bin/sh\n\
# Sprawdź, czy model istnieje\n\
MODEL=${MODEL:-mistral}\n\
if ! ollama list | grep -q $MODEL; then\n\
  echo "Pobieranie modelu $MODEL..."\n\
  ollama pull $MODEL\n\
fi\n\
# Uruchom serwer Ollama\n\
ollama serve "$@"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Ustaw health check
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:11434/api/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]