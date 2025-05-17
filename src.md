email-llm-node-red/
├── docker-compose.yml        # Definicja usług
├── .env                      # Zmienne środowiskowe
├── scripts/
│   ├── install.sh            # Skrypt instalacyjny
│   ├── start.sh              # Skrypt startowy
│   └── stop.sh               # Skrypt zatrzymujący
├── data/
│   ├── node-red/             # Dane Node-RED
│   │   ├── flows.json        # Definicja przepływów
│   │   ├── settings.js       # Ustawienia Node-RED
│   │   └── package.json      # Zależności npm
│   └── sqlite/
│       └── emails.db         # Baza danych SQLite
└── documentation.md          # Dokumentacja rozwiązania
