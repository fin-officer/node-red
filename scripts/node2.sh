#!/bin/bash
# Skrypt do utworzenia alternatywnego flow bez węzła cron-plus

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Tworzenie alternatywnego flow bez węzła cron-plus..."

# Sprawdź czy kontener Node-RED działa
if ! docker ps | grep -q "nodered-email-llm"; then
    echo -e "${RED}[BŁĄD]${NC} Kontener Node-RED nie jest uruchomiony. Uruchom go najpierw używając scripts/start.sh"
    exit 1
fi

# Zapisz flow do pliku tymczasowego
cat > /tmp/email-llm-flow-alt.json << 'EOF'
[
    {
        "id": "email-llm-flow",
        "type": "tab",
        "label": "Email-LLM Integration",
        "disabled": false,
        "info": "Integracja między email a LLM"
    },
    {
        "id": "email-in",
        "type": "e-mail in",
        "z": "email-llm-flow",
        "name": "Monitor skrzynki odbiorczej",
        "server": "${EMAIL_IMAP_HOST}",
        "port": "${EMAIL_IMAP_PORT}",
        "protocol": "IMAP",
        "useSSL": true,
        "credentials": {
            "userid": "${EMAIL_USER}",
            "password": "${EMAIL_PASSWORD}"
        },
        "box": "${EMAIL_IMAP_FOLDER}",
        "disposition": "Read",
        "criteria": "UNSEEN",
        "repeat": "60",
        "fetch": "auto",
        "inputs": 0,
        "x": 120,
        "y": 120,
        "wires": [
            [
                "extract-email-data"
            ]
        ]
    },
    {
        "id": "extract-email-data",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Ekstrahuj dane z emaila",
        "func": "// Dostęp do funkcji pomocniczych\nconst utils = global.get('emailUtils');\n\n// Ekstrakcja podstawowych danych z wiadomości\nconst email = {\n    messageId: msg.payload.messageId || `no-id-${Date.now()}`,\n    subject: msg.payload.topic || \"\",\n    sender: msg.payload.from || \"\",\n    recipients: msg.payload.to || \"\",\n    receivedDate: new Date().toISOString(),\n    bodyText: \"\",\n    bodyHtml: \"\",\n    status: \"pending\"\n};\n\n// Ekstrakcja zawartości\nif (msg.payload.text) {\n    email.bodyText = msg.payload.text;\n} else if (msg.payload.html) {\n    // Konwersja HTML do tekstu\n    email.bodyText = utils.htmlToText(msg.payload.html);\n    email.bodyHtml = msg.payload.html;\n} else if (msg.payload.attachments && msg.payload.attachments.length > 0) {\n    // Próba znalezienia treści w załącznikach\n    const textAttachment = msg.payload.attachments.find(att => \n        att.contentType.includes('text/plain'));\n    \n    if (textAttachment) {\n        email.bodyText = textAttachment.content.toString('utf8');\n    } else {\n        email.bodyText = \"Brak treści tekstowej\";\n    }\n}\n\n// Zapisz pełny email do kontekstu flow (dla późniejszego użycia)\nflow.set(\"currentEmail\", email);\n\n// Przygotowanie zapytania dla LLM\nmsg.emailData = email;\nmsg.payload = {\n    model: \"${OLLAMA_MODEL}\",\n    prompt: `Przeanalizuj poniższą wiadomość email:\\n\\nOd: ${email.sender}\\nDo: ${email.recipients}\\nTemat: ${email.subject}\\nTreść:\\n${email.bodyText}\\n\\nOdpowiedz w formacie JSON z następującymi polami:\\n{\\n  \"keyTopics\": [\"temat1\", \"temat2\"],\\n  \"priority\": \"high/medium/low\",\\n  \"requiresResponse\": true/false,\\n  \"actionRequired\": true/false,\\n  \"summary\": \"krótkie podsumowanie\"\\n}`,\n    stream: false\n};\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 320,
        "y": 120,
        "wires": [
            [
                "analyze-with-llm"
            ]
        ]
    },
    {
        "id": "analyze-with-llm",
        "type": "http request",
        "z": "email-llm-flow",
        "name": "Analiza przez Ollama LLM",
        "method": "POST",
        "ret": "obj",
        "paytoqs": "ignore",
        "url": "${OLLAMA_HOST}/api/generate",
        "tls": "",
        "persist": false,
        "proxy": "",
        "insecureHTTPParser": false,
        "authType": "",
        "senderr": false,
        "headers": [
            {
                "name": "Content-Type",
                "value": "application/json"
            }
        ],
        "x": 540,
        "y": 120,
        "wires": [
            [
                "process-llm-response"
            ]
        ]
    },
    {
        "id": "process-llm-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Przetwórz odpowiedź LLM",
        "func": "// Pobierz dane emaila z poprzedniego kroku\nconst email = msg.emailData;\n\n// Parsowanie odpowiedzi LLM\nlet analysis;\ntry {\n    // Próba parsowania JSON z odpowiedzi LLM\n    // Najpierw próbujemy znaleźć poprawny JSON w odpowiedzi\n    const jsonMatch = /\\{[\\s\\S]*\\}/g.exec(msg.payload.response);\n    if (jsonMatch) {\n        analysis = JSON.parse(jsonMatch[0]);\n    } else {\n        throw new Error(\"Nie znaleziono prawidłowego JSON w odpowiedzi\");\n    }\n} catch (e) {\n    // Jeśli odpowiedź nie jest poprawnym JSON, użyj heurystyki\n    node.warn(\"Nie można sparsować odpowiedzi jako JSON: \" + e.message);\n    \n    analysis = {\n        keyTopics: [],\n        priority: \"medium\",\n        requiresResponse: false,\n        actionRequired: false,\n        summary: msg.payload.response.substring(0, 200)\n    };\n    \n    // Prosta heurystyka dla priorytetów i odpowiedzi\n    const responseText = msg.payload.response.toLowerCase();\n    \n    if (responseText.includes(\"wysoki priorytet\") || responseText.includes(\"high priority\")) {\n        analysis.priority = \"high\";\n    } else if (responseText.includes(\"niski priorytet\") || responseText.includes(\"low priority\")) {\n        analysis.priority = \"low\";\n    }\n    \n    if (responseText.includes(\"wymaga odpowiedzi\") || responseText.includes(\"requires response\")) {\n        analysis.requiresResponse = true;\n    }\n    \n    if (responseText.includes(\"wymaga działania\") || responseText.includes(\"action required\")) {\n        analysis.actionRequired = true;\n    }\n}\n\n// Połącz dane emaila z analizą LLM\nemail.llmAnalysis = JSON.stringify(analysis);\nemail.status = \"processed\";\nemail.processedDate = new Date().toISOString();\n\n// Zbuduj SQL dla zapisu do bazy danych\nmsg.topic = \"INSERT INTO processed_emails (message_id, subject, sender, recipients, received_date, processed_date, body_text, body_html, status, llm_analysis) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)\";\n\nmsg.payload = [\n    email.messageId, \n    email.subject, \n    email.sender, \n    email.recipients, \n    email.receivedDate, \n    email.processedDate, \n    email.bodyText, \n    email.bodyHtml || \"\", \n    email.status, \n    email.llmAnalysis\n];\n\n// Zachowaj dane email i analizę dla dalszych kroków\nmsg.email = email;\nmsg.analysis = analysis;\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 760,
        "y": 120,
        "wires": [
            [
                "save-to-sqlite"
            ]
        ]
    },
    {
        "id": "save-to-sqlite",
        "type": "sqlite",
        "z": "email-llm-flow",
        "name": "Zapisz do bazy danych",
        "database": "${SQLITE_DB_PATH}",
        "sql": "",
        "sqlParams": true,
        "multipleStatements": false,
        "x": 970,
        "y": 120,
        "wires": [
            [
                "check-response-needed"
            ]
        ]
    },
    {
        "id": "check-response-needed",
        "type": "switch",
        "z": "email-llm-flow",
        "name": "Czy wymagana odpowiedź?",
        "property": "analysis.requiresResponse",
        "propertyType": "msg",
        "rules": [
            {
                "t": "true"
            }
        ],
        "checkall": "true",
        "repair": false,
        "outputs": 1,
        "x": 220,
        "y": 220,
        "wires": [
            [
                "prepare-response"
            ]
        ]
    },
    {
        "id": "prepare-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Przygotuj odpowiedź",
        "func": "// Pobierz dane emaila i analizę\nconst email = msg.email;\nconst analysis = msg.analysis;\n\n// Przygotuj treść odpowiedzi\nlet responseBody = `Dziękuję za wiadomość.\\n\\n`;\n\nif (analysis.summary) {\n    responseBody += `${analysis.summary}\\n\\n`;\n}\n\nif (analysis.actionRequired) {\n    responseBody += `Ta wiadomość wymaga naszego działania i zajmiemy się nią wkrótce.\\n\\n`;\n}\n\nresponseBody += `Pozdrawiam,\\nSystem Email-LLM`;\n\n// Przygotuj obiekt wiadomości\nmsg.topic = `Re: ${email.subject}`;\nmsg.to = email.sender;\nmsg.payload = responseBody;\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 430,
        "y": 220,
        "wires": [
            [
                "send-email"
            ]
        ]
    },
    {
        "id": "send-email",
        "type": "e-mail",
        "z": "email-llm-flow",
        "server": "${EMAIL_HOST}",
        "port": "${EMAIL_PORT}",
        "secure": true,
        "tls": true,
        "name": "Wyślij odpowiedź",
        "dname": "Wyślij odpowiedź",
        "credentials": {
            "userid": "${EMAIL_USER}",
            "password": "${EMAIL_PASSWORD}"
        },
        "x": 630,
        "y": 220,
        "wires": [
            [
                "log-email-sent"
            ]
        ]
    },
    {
        "id": "log-email-sent",
        "type": "debug",
        "z": "email-llm-flow",
        "name": "Email wysłany",
        "active": true,
        "tosidebar": true,
        "console": true,
        "tostatus": false,
        "complete": "true",
        "targetType": "full",
        "statusVal": "",
        "statusType": "auto",
        "x": 830,
        "y": 220,
        "wires": []
    },
    {
        "id": "sqlite-maintenance",
        "type": "inject",
        "z": "email-llm-flow",
        "name": "Codzienne zadanie konserwacji",
        "props": [
            {
                "p": "payload"
            }
        ],
        "repeat": "86400",
        "crontab": "",
        "once": false,
        "onceDelay": "0",
        "topic": "",
        "payload": "",
        "payloadType": "date",
        "x": 150,
        "y": 320,
        "wires": [
            [
                "cleanup-old-emails"
            ]
        ]
    },
    {
        "id": "cleanup-old-emails",
        "type": "sqlite",
        "z": "email-llm-flow",
        "name": "Usuń stare emaile",
        "database": "${SQLITE_DB_PATH}",
        "sql": "DELETE FROM processed_emails WHERE received_date < datetime('now', '-30 days') AND status IN ('processed', 'failed')",
        "sqlParams": [],
        "multipleStatements": false,
        "x": 420,
        "y": 320,
        "wires": [
            [
                "optimize-db"
            ]
        ]
    },
    {
        "id": "optimize-db",
        "type": "sqlite",
        "z": "email-llm-flow",
        "name": "Optymalizuj bazę danych",
        "database": "${SQLITE_DB_PATH}",
        "sql": "VACUUM; PRAGMA optimize;",
        "sqlParams": [],
        "multipleStatements": true,
        "x": 660,
        "y": 320,
        "wires": [
            [
                "log-maintenance"
            ]
        ]
    },
    {
        "id": "log-maintenance",
        "type": "debug",
        "z": "email-llm-flow",
        "name": "Konserwacja zakończona",
        "active": true,
        "tosidebar": true,
        "console": true,
        "tostatus": false,
        "complete": "payload",
        "targetType": "msg",
        "statusVal": "",
        "statusType": "auto",
        "x": 890,
        "y": 320,
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
        "x": 120,
        "y": 420,
        "wires": [
            [
                "prepare-health-response"
            ]
        ]
    },
    {
        "id": "prepare-health-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Przygotuj odpowiedź",
        "func": "msg.payload = {\n    status: \"UP\",\n    time: new Date().toISOString(),\n    components: {\n        sqlite: \"UP\",\n        ollama: \"UP\"\n    }\n};\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 370,
        "y": 420,
        "wires": [
            [
                "health-response"
            ]
        ]
    },
    {
        "id": "health-response",
        "type": "http response",
        "z": "email-llm-flow",
        "name": "Zwróć status",
        "statusCode": "200",
        "headers": {
            "content-type": "application/json"
        },
        "x": 610,
        "y": 420,
        "wires": []
    },
    {
        "id": "manual-email-test",
        "type": "inject",
        "z": "email-llm-flow",
        "name": "Test manualny",
        "props": [
            {
                "p": "payload"
            }
        ],
        "repeat": "",
        "crontab": "",
        "once": false,
        "onceDelay": 0.1,
        "topic": "",
        "payload": "{\"messageId\":\"test-1234\",\"topic\":\"Test Email\",\"from\":\"test@example.com\",\"to\":\"system@example.com\",\"text\":\"To jest testowa wiadomość email. Proszę o szybką odpowiedź w sprawie zamówienia #54321.\"}",
        "payloadType": "json",
        "x": 120,
        "y": 480,
        "wires": [
            [
                "extract-email-data"
            ]
        ]
    },
    {
        "id": "api-get-emails",
        "type": "http in",
        "z": "email-llm-flow",
        "name": "API: Pobierz emaile",
        "url": "/api/emails",
        "method": "get",
        "upload": false,
        "swaggerDoc": "",
        "x": 130,
        "y": 540,
        "wires": [
            [
                "query-emails"
            ]
        ]
    },
    {
        "id": "query-emails",
        "type": "sqlite",
        "z": "email-llm-flow",
        "name": "Pobierz z bazy danych",
        "database": "${SQLITE_DB_PATH}",
        "sql": "SELECT id, message_id, subject, sender, recipients, received_date, processed_date, status FROM processed_emails ORDER BY received_date DESC LIMIT 100",
        "sqlParams": [],
        "multipleStatements": false,
        "x": 340,
        "y": 540,
        "wires": [
            [
                "format-emails-response"
            ]
        ]
    },
    {
        "id": "format-emails-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Formatuj odpowiedź",
        "func": "msg.payload = {\n    emails: msg.payload,\n    total: msg.payload.length,\n    page: 1,\n    status: \"success\"\n};\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 570,
        "y": 540,
        "wires": [
            [
                "api-emails-response"
            ]
        ]
    },
    {
        "id": "api-emails-response",
        "type": "http response",
        "z": "email-llm-flow",
        "name": "Zwróć listę",
        "statusCode": "200",
        "headers": {
            "content-type": "application/json"
        },
        "x": 780,
        "y": 540,
        "wires": []
    },
    {
        "id": "api-get-email",
        "type": "http in",
        "z": "email-llm-flow",
        "name": "API: Pobierz email",
        "url": "/api/emails/:id",
        "method": "get",
        "upload": false,
        "swaggerDoc": "",
        "x": 130,
        "y": 600,
        "wires": [
            [
                "query-single-email"
            ]
        ]
    },
    {
        "id": "query-single-email",
        "type": "sqlite",
        "z": "email-llm-flow",
        "name": "Pobierz szczegóły",
        "database": "${SQLITE_DB_PATH}",
        "sql": "SELECT * FROM processed_emails WHERE id = ?",
        "sqlParams": [
            {
                "p": "req.params.id",
                "t": "msg"
            }
        ],
        "multipleStatements": false,
        "x": 330,
        "y": 600,
        "wires": [
            [
                "format-email-response"
            ]
        ]
    },
    {
        "id": "format-email-response",
        "type": "function",
        "z": "email-llm-flow",
        "name": "Formatuj odpowiedź",
        "func": "if (msg.payload && msg.payload.length > 0) {\n    msg.payload = {\n        email: msg.payload[0],\n        status: \"success\"\n    };\n    msg.statusCode = 200;\n} else {\n    msg.payload = {\n        error: \"Email nie znaleziony\",\n        status: \"error\"\n    };\n    msg.statusCode = 404;\n}\n\nreturn msg;",
        "outputs": 1,
        "noerr": 0,
        "initialize": "",
        "finalize": "",
        "libs": [],
        "x": 570,
        "y": 600,
        "wires": [
            [
                "api-email-response"
            ]
        ]
    },
    {
        "id": "api-email-response",
        "type": "http response",
        "z": "email-llm-flow",
        "name": "Zwróć szczegóły",
        "statusCode": "",
        "headers": {
            "content-type": "application/json"
        },
        "x": 790,
        "y": 600,
        "wires": []
    }
]
EOF

# Kopiuj alternatywny plik flow do kontenera
docker cp /tmp/email-llm-flow-alt.json nodered-email-llm:/data/email-llm-flow-alt.json

echo -e "${BLUE}[INFO]${NC} Alternatywny flow został skopiowany do kontenera Node-RED."
echo -e "${YELLOW}[INFO]${NC} Ten flow zastępuje węzeł 'cron-plus' standardowym węzłem 'inject'."
echo ""
echo -e "${YELLOW}[INFO]${NC} Aby zaimportować flow w interfejsie Node-RED:"
echo -e "1. Otwórz interfejs Node-RED: ${BLUE}http://localhost:1880${NC}"
echo -e "2. Kliknij menu hamburgera (trzy linie) w prawym górnym rogu"
echo -e "3. Wybierz Import -> Clipboard"
echo -e "4. Kliknij 'wybierz plik do zaimportowania' i wybierz plik /data/email-llm-flow-alt.json"
echo -e "5. Kliknij 'Import'"
echo ""
echo -e "${BLUE}[INFO]${NC} Po zaimportowaniu flow, kliknij przycisk Deploy, aby go zapisać i uruchomić."