#!/bin/bash
# Skrypt instalacyjny dla Email-LLM Integration z Node-RED (poprawiona wersja)

# Kolory do komunikatów
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funkcja wyświetlająca informacje
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Funkcja wyświetlająca sukcesy
success() {
    echo -e "${GREEN}[SUKCES]${NC} $1"
}

# Funkcja wyświetlająca ostrzeżenia
warning() {
    echo -e "${YELLOW}[UWAGA]${NC} $1"
}

# Funkcja wyświetlająca błędy
error() {
    echo -e "${RED}[BŁĄD]${NC} $1"
    exit 1
}

# Funkcja sprawdzająca wymagania
check_requirements() {
    info "Sprawdzanie wymagań systemowych..."

    # Sprawdź Docker
    if ! command -v docker &> /dev/null; then
        error "Docker nie jest zainstalowany. Zainstaluj Docker przed kontynuowaniem."
    fi

    # Sprawdź Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose nie jest zainstalowany. Zainstaluj Docker Compose przed kontynuowaniem."
    fi

    # Sprawdź SQLite
    if ! command -v sqlite3 &> /dev/null; then
        warning "SQLite3 nie jest zainstalowany. Instalacja może być niepełna. Zalecane jest zainstalowanie sqlite3."
        read -p "Czy chcesz kontynuować bez sqlite3? (t/n): " choice
        if [[ "$choice" != "t" && "$choice" != "T" ]]; then
            error "Instalacja przerwana. Zainstaluj sqlite3 przed kontynuowaniem."
        fi
    fi

    # Sprawdź curl
    if ! command -v curl &> /dev/null; then
        error "curl nie jest zainstalowany. Zainstaluj curl przed kontynuowaniem."
    fi

    success "Wszystkie wymagania systemowe są spełnione."
}

# Funkcja tworząca strukturę katalogów
create_directory_structure() {
    info "Tworzenie struktury katalogów..."

    mkdir -p data/node-red
    mkdir -p data/sqlite
    mkdir -p scripts

    # Ustaw odpowiednie uprawnienia
    chmod -R 755 data

    success "Struktura katalogów została utworzona."
}

# Funkcja inicjalizująca bazę danych SQLite
initialize_sqlite_database() {
    info "Inicjalizacja bazy danych SQLite..."

    # Utwórz katalog dla bazy danych, jeśli nie istnieje
    mkdir -p data/sqlite

    # Sprawdź, czy baza danych już istnieje i usuń ją, jeśli tak
    if [ -f "data/sqlite/emails.db" ]; then
        warning "Baza danych już istnieje. Usuwanie istniejącej bazy danych..."
        rm -f data/sqlite/emails.db
    fi

    # Inicjalizuj bazę danych używając tymczasowego pliku SQL
    cat > /tmp/init_db.sql <<EOF
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA cache_size=-102400;
PRAGMA temp_store=MEMORY;
PRAGMA mmap_size=1073741824;

-- Tabela dla przetworzonych emaili
CREATE TABLE IF NOT EXISTS processed_emails (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT UNIQUE,
    subject TEXT,
    sender TEXT,
    recipients TEXT,
    received_date TEXT,
    processed_date TEXT,
    body_text TEXT,
    body_html TEXT,
    status TEXT,
    llm_analysis TEXT,
    metadata TEXT
);

-- Indeksy
CREATE INDEX IF NOT EXISTS idx_processed_emails_message_id ON processed_emails(message_id);
CREATE INDEX IF NOT EXISTS idx_processed_emails_status ON processed_emails(status);
CREATE INDEX IF NOT EXISTS idx_processed_emails_received_date ON processed_emails(received_date);

-- Tabela dla załączników
CREATE TABLE IF NOT EXISTS email_attachments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email_id INTEGER,
    filename TEXT,
    content_type TEXT,
    size INTEGER,
    content BLOB,
    FOREIGN KEY (email_id) REFERENCES processed_emails(id) ON DELETE CASCADE
);

VACUUM;
EOF

    # Uruchom sqlite3 z plikiem SQL
    if ! sqlite3 data/sqlite/emails.db < /tmp/init_db.sql; then
        error "Nie udało się zainicjalizować bazy danych SQLite. Sprawdź, czy sqlite3 jest zainstalowany poprawnie."
    fi

    # Usuń tymczasowy plik
    rm -f /tmp/init_db.sql

    # Ustaw odpowiednie uprawnienia do bazy danych
    chmod 666 data/sqlite/emails.db

    success "Baza danych SQLite została zainicjalizowana."
}

# Funkcja tworząca pliki konfiguracyjne Node-RED
create_node_red_files() {
    info "Tworzenie plików konfiguracyjnych Node-RED..."

    # Utwórz package.json
    cat > data/node-red/package.json <<EOF
{
    "name": "email-llm-integration",
    "version": "0.1.0",
    "description": "Integracja email z modelami LLM za pomocą Node-RED",
    "dependencies": {
        "node-red-node-sqlite": "latest",
        "node-red-node-email": "latest",
        "node-red-contrib-cron-plus": "latest"
    }
}
EOF

    # Utwórz settings.js (konfiguracja Node-RED)
    cat > data/node-red/settings.js <<EOF
module.exports = {
    flowFile: 'flows.json',
    flowFilePretty: true,

    adminAuth: {
        type: "credentials",
        users: [{
            username: process.env.NODERED_USERNAME || "admin",
            password: process.env.NODERED_PASSWORD ? require('bcryptjs').hashSync(process.env.NODERED_PASSWORD) : "\$2a\$08\$zZAdYdNMdqdvIXM4oCQQEuUfGK7tgbWh31h.npVFn4MBgBuLsNowy",
            permissions: "*"
        }]
    },

    httpNodeAuth: {
        user: process.env.NODERED_USERNAME || "admin",
        pass: process.env.NODERED_PASSWORD || "password"
    },

    functionGlobalContext: {
        os: require('os'),
        process: process,
        // Dodatkowe moduły można dodać tutaj
        emailUtils: {
            extractAddresses: function(recipients) {
                if (!recipients) return [];
                return recipients.split(',').map(r => r.trim());
            },
            cleanSubject: function(subject) {
                if (!subject) return '';
                return subject.replace(/^(RE:|FWD:)/i, '').trim();
            },
            htmlToText: function(html) {
                if (!html) return '';
                // Prosta implementacja
                return html.replace(/<[^>]*>/g, ' ')
                          .replace(/\\s+/g, ' ')
                          .trim();
            }
        }
    },

    contextStorage: {
        default: "memoryOnly",
        memoryOnly: { module: 'memory' },
        file: { module: 'localfilesystem' }
    },

    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },

    exportGlobalContextKeys: false,
    externalModules: {},

    // Dodaj endpoint zdrowia dla healthcheck
    httpNodeMiddleware: function(req, res, next) {
        if (req.url === '/health') {
            res.setHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            res.end(JSON.stringify({status: "UP", time: new Date().toISOString()}));
        } else {
            next();
        }
    }
};
EOF

    # Utwórz katalog lib i plik emailUtils.js
    mkdir -p data/node-red/lib
    cat > data/node-red/lib/email-utils.js <<EOF
module.exports = {
    // Ekstrakcja adresów email
    extractAddresses: function(recipients) {
        if (!recipients) return [];
        return recipients.split(',').map(r => r.trim());
    },

    // Czyszczenie tematu email
    cleanSubject: function(subject) {
        if (!subject) return '';
        return subject.replace(/^(RE:|FWD:)/i, '').trim();
    },

    // Konwersja HTML do tekstu
    htmlToText: function(html) {
        if (!html) return '';
        // Prosta implementacja
        return html.replace(/<[^>]*>/g, ' ')
                  .replace(/\s+/g, ' ')
                  .trim();
    },

    // Formatowanie daty
    formatDate: function(date) {
        if (!date) return '';
        return new Date(date).toISOString();
    }
};
EOF

    # Ustaw odpowiednie uprawnienia dla plików Node-RED
    chmod -R 777 data/node-red

    success "Pliki konfiguracyjne Node-RED zostały utworzone."
}

# Funkcja kopiująca flows.json z repozytorium lub generująca domyślny
copy_or_generate_flows() {
    info "Przygotowanie pliku przepływów Node-RED..."

    # Kopiuj wzorcowy plik flows.json, jeśli istnieje w repozytorium
    if [ -f "flows.json" ]; then
        cp flows.json data/node-red/flows.json
        success "Skopiowano gotowy plik przepływów."
    else
        # Wygeneruj przykładowy plik flows.json
        cat > data/node-red/flows.json <<EOF
[
    {
        "id": "email-llm-flow",
        "type": "tab",
        "label": "Email-LLM Integration",
        "disabled": false,
        "info": "Integracja między email a LLM"
    },
    {
        "id": "setup-placeholder",
        "type": "comment",
        "z": "email-llm-flow",
        "name": "Przepływy do skonfigurowania",
        "info": "1. Skonfiguruj połączenie email w zakładce 'Configuration Nodes'\\n2. Dodaj węzły do monitorowania skrzynki email\\n3. Dodaj węzły do analizy wiadomości przez LLM\\n4. Dodaj węzły do zapisywania w bazie danych\\n\\nPełna dokumentacja znajduje się w pliku documentation.md",
        "x": 160,
        "y": 80,
        "wires": []
    },
    {
        "id": "health-endpoint",
        "type": "http in",
        "z": "email-llm-flow",
        "name": "Health Endpoint",
        "url": "/api/health",
        "method": "get",
        "upload": false,
        "swaggerDoc": "",
        "x": 170,
        "y": 160,
        "wires": [["health-response"]]
    },
    {
        "id": "health-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Status",
        "func": "msg.payload = {\\n    status: 'UP',\\n    time: new Date().toISOString()\\n};\\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 370,
        "y": 160,
        "wires": [["health-http-response"]]
    },
    {
        "id": "health-http-response",
        "type": "http response",
        "z": "email-llm-flow",
        "name": "",
        "statusCode": "200",
        "headers": {
            "content-type": "application/json"
        },
        "x": 570,
        "y": 160,
        "wires": []
    }
]
EOF
        success "Wygenerowano podstawowy plik przepływów."
    fi

    # Ustaw uprawnienia dla pliku flows.json
    chmod 666 data/node-red/flows.json
}

# Funkcja tworząca skrypty do zarządzania
create_management_scripts() {
    info "Tworzenie skryptów do zarządzania..."

    # Skrypt start.sh
    cat > scripts/start.sh <<EOF
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

# Uruchom docker-compose
echo -e "${BLUE}[INFO]${NC} Uruchamianie kontenerów..."
docker-compose up -d

# Poczekaj na uruchomienie Ollama
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Ollama..."
until docker exec -i ollama curl -s http://localhost:11434/api/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

# Pobierz model, jeśli nie istnieje
source .env
MODEL=\${OLLAMA_MODEL:-mistral}
if ! docker exec -i ollama ollama list | grep -q \$MODEL; then
    echo -e "${BLUE}[INFO]${NC} Pobieranie modelu \$MODEL (może to potrwać kilka minut)..."
    docker exec -i ollama ollama pull \$MODEL
fi

# Poczekaj na uruchomienie Node-RED
echo -e "${BLUE}[INFO]${NC} Czekam na uruchomienie Node-RED..."
until curl -s http://localhost:\${NODERED_PORT:-1880}/health &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}[SUKCES]${NC} Projekt uruchomiony pomyślnie!"
echo ""
echo "Dostępne usługi:"
echo -e "${BLUE}* Node-RED:${NC} http://localhost:\${NODERED_PORT:-1880}"
echo -e "${BLUE}* Node-RED API:${NC} http://localhost:\${NODERED_PORT:-1880}/api"
echo -e "${BLUE}* Panel testowej skrzynki email:${NC} http://localhost:8025"
echo -e "${BLUE}* Panel administracyjny SQLite:${NC} http://localhost:8081"
echo ""
echo -e "${YELLOW}Aby zatrzymać aplikację, użyj polecenia:${NC} ./scripts/stop.sh"
EOF
    chmod +x scripts/start.sh

    # Skrypt stop.sh
    cat > scripts/stop.sh <<EOF
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
EOF
    chmod +x scripts/stop.sh

    # Skrypt restart.sh
    cat > scripts/restart.sh <<EOF
#!/bin/bash
# Skrypt restartujący dla Email-LLM Integration

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Restartowanie projektu Email-LLM Integration..."

# Zatrzymaj kontenery
./scripts/stop.sh

# Poczekaj chwilę
sleep 2

# Uruchom kontenery
./scripts/start.sh
EOF
    chmod +x scripts/restart.sh

    success "Skrypty do zarządzania zostały utworzone."
}

# Funkcja kopiująca plik .env
copy_env_file() {
    info "Przygotowanie pliku .env..."

    # Sprawdź, czy plik .env już istnieje
    if [ -f ".env" ]; then
        warning "Plik .env już istnieje. Tworzenie kopii zapasowej..."
        cp .env .env.backup-$(date +%Y%m%d-%H%M%S)
    fi

    # Kopiuj wzorcowy plik .env, jeśli istnieje
    if [ -f ".env.example" ]; then
        cp .env.example .env
        success "Skopiowano plik .env z szablonu."
    else
        # Wygeneruj przykładowy plik .env
        cat > .env <<EOF
# Konfiguracja środowiska
# Email
EMAIL_HOST=test-smtp.example.com
EMAIL_PORT=587
EMAIL_USER=test@example.com
EMAIL_PASSWORD=test_password
EMAIL_USE_TLS=true
EMAIL_IMAP_HOST=test-imap.example.com
EMAIL_IMAP_PORT=993
EMAIL_IMAP_FOLDER=INBOX

# Ollama
OLLAMA_HOST=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_API_KEY=

# SQLite
SQLITE_DB_PATH=/data/sqlite/emails.db

# Node-RED
NODERED_PORT=1880
NODERED_USERNAME=admin
NODERED_PASSWORD=password
EOF
        success "Wygenerowano przykładowy plik .env."
    fi
}

# Główna funkcja instalacyjna
install() {
    info "Rozpoczynam instalację Email-LLM Integration z Node-RED..."

    # Sprawdź wymagania systemowe
    check_requirements

    # Utwórz strukturę katalogów
    create_directory_structure

    # Przygotuj plik .env
    copy_env_file

    # Zainicjalizuj bazę danych SQLite
    initialize_sqlite_database

    # Utwórz pliki konfiguracyjne Node-RED
    create_node_red_files

    # Przygotuj plik przepływów
    copy_or_generate_flows

    # Utwórz skrypty do zarządzania
    create_management_scripts

    success "Instalacja zakończona pomyślnie!"
    echo ""
    echo -e "${YELLOW}NASTĘPNE KROKI:${NC}"
    echo "1. Dostosuj plik .env do swoich potrzeb"
    echo "2. Uruchom aplikację za pomocą polecenia:"
    echo -e "   ${BLUE}./scripts/start.sh${NC}"
    echo "3. Dostęp do interfejsów:"
    echo "   - Node-RED: http://localhost:1880"
    echo "   - Panel testowej skrzynki email: http://localhost:8025"
    echo "   - Panel administracyjny SQLite: http://localhost:8081"
    echo ""
    echo -e "${GREEN}Powodzenia z implementacją projektu!${NC}"
}

# Uruchomienie instalacji
install