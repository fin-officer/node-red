#!/bin/bash
# Skrypt do instalacji brakujących węzłów (node-types) w Node-RED

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Instalowanie brakujących węzłów Node-RED..."

# Sprawdź czy kontener Node-RED działa
if ! docker ps | grep -q "nodered-email-llm"; then
    echo -e "${RED}[BŁĄD]${NC} Kontener Node-RED nie jest uruchomiony. Uruchom go najpierw używając scripts/start.sh"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Instalowanie węzła 'node-red-node-email'..."
docker exec -it nodered-email-llm npm install --no-fund --no-audit node-red-node-email

echo -e "${BLUE}[INFO]${NC} Instalowanie węzła 'node-red-node-sqlite'..."
docker exec -it nodered-email-llm npm install --no-fund --no-audit node-red-node-sqlite

echo -e "${BLUE}[INFO]${NC} Instalowanie węzła 'node-red-contrib-cron-plus'..."
docker exec -it nodered-email-llm npm install --no-fund --no-audit node-red-contrib-cron-plus

echo -e "${BLUE}[INFO]${NC} Dodawanie funkcji pomocniczych..."

# Utwórz plik z funkcjami pomocniczymi dla emaila
cat > /tmp/emailUtils.js << 'EOF'
// Funkcje pomocnicze dla obsługi emaili
module.exports = {
    // Prosta funkcja do konwersji HTML do tekstu
    htmlToText: function(html) {
        if (!html) return "";

        // Usuń tagi HTML
        let text = html.replace(/<[^>]*>/g, " ");

        // Normalizuj białe znaki
        text = text.replace(/\s+/g, " ").trim();

        // Zastąp encje HTML
        text = text.replace(/&nbsp;/g, " ")
                   .replace(/&amp;/g, "&")
                   .replace(/&lt;/g, "<")
                   .replace(/&gt;/g, ">")
                   .replace(/&quot;/g, "\"")
                   .replace(/&#39;/g, "'");

        return text;
    }
};
EOF

# Skopiuj plik do kontenera
docker cp /tmp/emailUtils.js nodered-email-llm:/data/emailUtils.js

# Skonfiguruj plik settings.js aby ładował funkcje pomocnicze
docker exec -it nodered-email-llm bash -c "grep -q 'emailUtils' /data/settings.js || echo -e \"\n// Załaduj funkcje pomocnicze dla emaila\nfunctionGlobalContext: { emailUtils: require('./emailUtils') },\" >> /data/settings.js"

echo -e "${BLUE}[INFO]${NC} Tworzenie tabeli w bazie danych SQLite..."

# Utwórz folder dla bazy danych SQLite, jeśli nie istnieje
docker exec -it nodered-email-llm mkdir -p /data/sqlite

# Utwórz skrypt SQL dla inicjalizacji bazy danych
cat > /tmp/init-db.sql << 'EOF'
CREATE TABLE IF NOT EXISTS processed_emails (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT NOT NULL,
    subject TEXT,
    sender TEXT NOT NULL,
    recipients TEXT,
    received_date TEXT NOT NULL,
    processed_date TEXT NOT NULL,
    body_text TEXT,
    body_html TEXT,
    status TEXT,
    llm_analysis TEXT
);

CREATE INDEX IF NOT EXISTS idx_message_id ON processed_emails(message_id);
CREATE INDEX IF NOT EXISTS idx_received_date ON processed_emails(received_date);
CREATE INDEX IF NOT EXISTS idx_status ON processed_emails(status);
EOF

# Skopiuj skrypt SQL do kontenera
docker cp /tmp/init-db.sql nodered-email-llm:/data/sqlite/init-db.sql

# Utwórz bazę danych i zainicjuj ją
docker exec -it nodered-email-llm bash -c "cd /data/sqlite && sqlite3 emails.db < init-db.sql"

echo -e "${BLUE}[INFO]${NC} Restartowanie Node-RED..."
docker restart nodered-email-llm

echo -e "${GREEN}[SUKCES]${NC} Instalacja zakończona pomyślnie!"
echo ""
echo -e "${YELLOW}[INFO]${NC} Poczekaj ok. 30 sekund na restart Node-RED i załadowanie nowych węzłów."
echo -e "${YELLOW}[INFO]${NC} Następnie odśwież interfejs Node-RED w przeglądarce."
echo ""
echo -e "Dostęp do Node-RED: ${BLUE}http://localhost:1880${NC}"