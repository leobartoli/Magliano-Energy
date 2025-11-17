# Sistema Riscaldamento con Agente IA + PostgreSQL

## Architettura Completa

```
┌─────────────────────────────────────────────────────┐
│                   PostgreSQL                         │
│  ┌──────────────────────────────────────────────┐  │
│  │ Tabella: heating_config                      │  │
│  │ - id, config_json, created_at, modified_by   │  │
│  │                                              │  │
│  │ Tabella: heating_history                     │  │
│  │ - id, timestamp, action, zone, values        │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
           ↑                           ↑
           │                           │
    ┌──────┴──────┐           ┌───────┴────────┐
    │   Bot       │           │   Esecutore    │
    │ Configuratore│          │   Automatico   │
    │  (Telegram) │           │  (Schedule)    │
    └─────────────┘           └────────────────┘
```

-----

## 1. Setup PostgreSQL

### Schema Database

```sql
-- Tabella configurazione (mantiene sempre 1 sola riga)
CREATE TABLE heating_config (
    id SERIAL PRIMARY KEY,
    config_json JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    modified_by VARCHAR(100),
    notes TEXT
);

-- Inserisci configurazione iniziale
INSERT INTO heating_config (config_json, modified_by, notes) VALUES (
    '{
        "fasce_orarie": [
            {
                "nome": "Riscaldamento mattina",
                "ora_inizio": 6,
                "ora_fine": 7,
                "temperatura": 37,
                "usa_fotovoltaico": false,
                "attiva": true
            },
            {
                "nome": "Riscaldamento giorno",
                "ora_inizio": 10,
                "ora_fine": 20,
                "temperatura": 37,
                "usa_fotovoltaico": true,
                "attiva": true
            }
        ],
        "soglie_fv": {
            "accensione_kw": 1.0,
            "spegnimento_kw": 0.75
        },
        "zone": [
            {"nome": "cameretta", "entity_id": "climate.cameretta", "attiva": true},
            {"nome": "soggiorno", "entity_id": "climate.pannello_soggiorno", "attiva": true},
            {"nome": "bagno_seminterrato", "entity_id": "climate.bagno_piano_seminterrato", "attiva": true},
            {"nome": "bagno_primo", "entity_id": "climate.bagno_piano_primo", "attiva": true}
        ]
    }'::jsonb,
    'system',
    'Configurazione iniziale'
);

-- Tabella storico azioni
CREATE TABLE heating_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    zona VARCHAR(50),
    azione VARCHAR(20),
    temperatura NUMERIC(4,1),
    fv_produzione NUMERIC(5,2),
    motivazione TEXT
);

-- Tabella storico modifiche configurazione
CREATE TABLE config_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    config_json JSONB,
    modified_by VARCHAR(100),
    change_description TEXT
);

-- Indici per performance
CREATE INDEX idx_history_timestamp ON heating_history(timestamp);
CREATE INDEX idx_config_json ON heating_config USING GIN(config_json);
```

-----

## 2. Workflow n8n Completo

### WORKFLOW A: Bot Configuratore Telegram

```json
{
  "name": "Heating Config Bot",
  "nodes": [
    {
      "name": "Telegram Trigger",
      "type": "n8n-nodes-base.telegramTrigger",
      "parameters": {
        "updates": ["message"]
      },
      "position": [240, 300]
    },
    {
      "name": "Leggi Config Attuale",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT config_json FROM heating_config ORDER BY id DESC LIMIT 1"
      },
      "position": [440, 300]
    },
    {
      "name": "Agente Configuratore",
      "type": "@n8n/n8n-nodes-langchain.agent",
      "parameters": {
        "promptType": "define",
        "text": "=Sei l'assistente per la configurazione del riscaldamento delle scuole di via Gramsci.\n\n**CONFIGURAZIONE ATTUALE:**\n```json\n{{ JSON.stringify($('Leggi Config Attuale').item.json.config_json, null, 2) }}\n```\n\n**MESSAGGIO UTENTE:**\n{{ $('Telegram Trigger').item.json.message.text }}\n\n**IL TUO COMPITO:**\n1. Interpreta la richiesta dell'utente in linguaggio naturale\n2. Modifica SOLO i parametri richiesti nella configurazione\n3. Mantieni tutti gli altri valori invariati\n4. Valida i parametri:\n   - Temperature: 21-37°C\n   - Orari: 0-23\n   - Soglie FV: > 0 kW\n5. Restituisci JSON completo aggiornato + spiegazione umana\n\n**ESEMPI DI RICHIESTE:**\n- \"Accendi alle 7 invece che alle 6\"\n- \"Abbassa temperatura a 35 gradi\"\n- \"Spegni il bagno piano primo\"\n- \"Aumenta soglia fotovoltaico a 1.5 kW\"\n- \"Mostrami la configurazione attuale\"\n- \"Aggiungi una fascia oraria 14-16 a 30 gradi\"\n\n**OUTPUT OBBLIGATORIO (JSON):**\n```json\n{\n  \"risposta_utente\": \"Spiegazione chiara e amichevole del cambiamento effettuato\",\n  \"config_aggiornata\": { ...intera configurazione aggiornata... },\n  \"cambiamenti\": [\"lista delle modifiche fatte\"],\n  \"richiede_conferma\": true/false\n}\n```\n\n**REGOLE:**\n- Se la richiesta è ambigua, chiedi chiarimenti\n- Se i valori sono fuori range, proponi alternative\n- Conferma sempre cosa hai modificato\n- Se chiede solo di vedere la config, NON modificarla"
      },
      "position": [640, 300]
    },
    {
      "name": "Estrai Risposta",
      "type": "@n8n/n8n-nodes-langchain.informationExtractor",
      "parameters": {
        "text": "={{ $json.output }}",
        "attributes": {
          "attributes": [
            {
              "name": "risposta_utente",
              "type": "string",
              "description": "Messaggio da mandare all'utente"
            },
            {
              "name": "config_aggiornata",
              "type": "object",
              "description": "Configurazione JSON completa"
            },
            {
              "name": "cambiamenti",
              "type": "array",
              "description": "Lista delle modifiche"
            },
            {
              "name": "richiede_conferma",
              "type": "boolean",
              "description": "Se serve conferma utente"
            }
          ]
        }
      },
      "position": [840, 300]
    },
    {
      "name": "Verifica Conferma",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "boolean": [
            {
              "value1": "={{ $json.output.richiede_conferma }}",
              "value2": false
            }
          ]
        }
      },
      "position": [1040, 300]
    },
    {
      "name": "Salva Config",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "=UPDATE heating_config \nSET config_json = '{{ JSON.stringify($json.output.config_aggiornata) }}'::jsonb,\n    modified_by = 'telegram_{{ $('Telegram Trigger').item.json.message.from.username }}',\n    created_at = NOW()\nWHERE id = (SELECT MAX(id) FROM heating_config);\n\n-- Salva storico\nINSERT INTO config_history (config_json, modified_by, change_description)\nVALUES (\n  '{{ JSON.stringify($json.output.config_aggiornata) }}'::jsonb,\n  'telegram_{{ $('Telegram Trigger').item.json.message.from.username }}',\n  '{{ $json.output.cambiamenti.join(\", \") }}'\n);"
      },
      "position": [1240, 240]
    },
    {
      "name": "Invia Conferma",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "=✅ {{ $json.output.risposta_utente }}\n\n📝 Modifiche:\n{{ $json.output.cambiamenti.map(c => '• ' + c).join('\\n') }}"
      },
      "position": [1440, 240]
    },
    {
      "name": "Richiedi Conferma",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "=⚠️ {{ $json.output.risposta_utente }}\n\nRispondi 'SI' per confermare o 'NO' per annullare."
      },
      "position": [1240, 360]
    },
    {
      "name": "Anthropic Chat Model",
      "type": "@n8n/n8n-nodes-langchain.lmChatAnthropic",
      "parameters": {
        "model": "claude-sonnet-4-20250514"
      },
      "position": [640, 500]
    }
  ],
  "connections": {
    "Telegram Trigger": {
      "main": [[{"node": "Leggi Config Attuale"}]]
    },
    "Leggi Config Attuale": {
      "main": [[{"node": "Agente Configuratore"}]]
    },
    "Agente Configuratore": {
      "main": [[{"node": "Estrai Risposta"}]]
    },
    "Estrai Risposta": {
      "main": [[{"node": "Verifica Conferma"}]]
    },
    "Verifica Conferma": {
      "main": [
        [{"node": "Salva Config"}],
        [{"node": "Richiedi Conferma"}]
      ]
    },
    "Salva Config": {
      "main": [[{"node": "Invia Conferma"}]]
    },
    "Anthropic Chat Model": {
      "ai_languageModel": [[
        {"node": "Agente Configuratore"},
        {"node": "Estrai Risposta"}
      ]]
    }
  }
}
```

-----

### WORKFLOW B: Esecutore Automatico

```json
{
  "name": "Heating Executor",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "*/30 6-20 * * *"
            }
          ]
        }
      },
      "position": [240, 300]
    },
    {
      "name": "Leggi Config",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT config_json FROM heating_config ORDER BY id DESC LIMIT 1"
      },
      "position": [440, 300]
    },
    {
      "name": "Leggi Stati Sensori",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://10.241.185.242:8123/api/states",
        "authentication": "genericCredentialType",
        "options": {}
      },
      "position": [640, 300]
    },
    {
      "name": "Prepara Dati",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "jsCode": "const config = $input.item.json.config_json;\nconst states = $('Leggi Stati Sensori').first().json;\n\n// Trova sensori rilevanti\nconst fv = states.find(s => s.entity_id === 'sensor.solaredge_potenza_attuale');\nconst climates = states.filter(s => s.entity_id.startsWith('climate.'));\n\n// Mappa stati zone\nconst statiZone = config.zone.map(z => {\n  const climate = climates.find(c => c.entity_id === z.entity_id);\n  return {\n    nome: z.nome,\n    entity_id: z.entity_id,\n    attiva: z.attiva,\n    stato_corrente: climate?.state || 'unknown',\n    temperatura_corrente: parseFloat(climate?.attributes?.temperature || 0),\n    temperatura_ambiente: parseFloat(climate?.attributes?.current_temperature || 0)\n  };\n});\n\nreturn {\n  json: {\n    timestamp: new Date().toISOString(),\n    ora_corrente: new Date().getHours(),\n    minuto_corrente: new Date().getMinutes(),\n    produzione_fv_kw: parseFloat(fv?.state || 0),\n    config: config,\n    stati_zone: statiZone\n  }\n};"
      },
      "position": [840, 300]
    },
    {
      "name": "Agente Esecutore",
      "type": "@n8n/n8n-nodes-langchain.agent",
      "parameters": {
        "promptType": "define",
        "text": "=Sei il controllore automatico del riscaldamento. Analizza i dati e decidi le azioni.\n\n**DATI CORRENTI:**\n```json\n{{ JSON.stringify($json, null, 2) }}\n```\n\n**LOGICA DI CONTROLLO:**\n\n1. **Trova la fascia oraria attiva:**\n   - Controlla quale fascia copre l'ora corrente\n   - Se nessuna fascia è attiva → SPEGNI tutto\n\n2. **Se fascia attiva NON usa fotovoltaico:**\n   - Target: ACCESO alla temperatura della fascia\n   - Applica a tutte le zone attive\n\n3. **Se fascia attiva USA fotovoltaico:**\n   - Produzione > soglia_accensione → ACCENDI\n   - Produzione < soglia_spegnimento → SPEGNI\n   - Tra le due soglie → MANTIENI stato attuale\n\n4. **Confronta stato attuale vs desiderato:**\n   - Per ogni zona attiva:\n     * Se stato diverso → genera azione\n     * Se temperatura diversa (e acceso) → genera azione\n     * Se già corretto → NESSUNA azione\n\n5. **Genera output SOLO per zone che richiedono cambiamenti**\n\n**OUTPUT OBBLIGATORIO (JSON):**\n```json\n{\n  \"fascia_attiva\": \"nome fascia o null\",\n  \"decisione_fv\": \"accendi/spegni/mantieni o N/A\",\n  \"azioni\": [\n    {\n      \"zona\": \"nome\",\n      \"entity_id\": \"climate.xxx\",\n      \"stato_corrente\": \"heat/off\",\n      \"stato_target\": \"heat/off\",\n      \"temp_corrente\": 30,\n      \"temp_target\": 37,\n      \"azione\": \"accendi/spegni/imposta_temperatura/nessuna\"\n    }\n  ],\n  \"motivazione\": \"Spiegazione sintetica della logica applicata\",\n  \"azioni_da_eseguire\": true/false\n}\n```\n\n**REGOLA CRITICA:**\nSe `stato_corrente == stato_target` E `temp_corrente == temp_target` → `azione: \"nessuna\"`"
      },
      "position": [1040, 300]
    },
    {
      "name": "Estrai Decisioni",
      "type": "@n8n/n8n-nodes-langchain.informationExtractor",
      "parameters": {
        "text": "={{ $json.output }}",
        "attributes": {
          "attributes": [
            {
              "name": "fascia_attiva",
              "type": "string"
            },
            {
              "name": "decisione_fv",
              "type": "string"
            },
            {
              "name": "azioni",
              "type": "array"
            },
            {
              "name": "motivazione",
              "type": "string"
            },
            {
              "name": "azioni_da_eseguire",
              "type": "boolean"
            }
          ]
        }
      },
      "position": [1240, 300]
    },
    {
      "name": "Ci Sono Azioni?",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "boolean": [
            {
              "value1": "={{ $json.output.azioni_da_eseguire }}",
              "value2": true
            }
          ]
        }
      },
      "position": [1440, 300]
    },
    {
      "name": "Split Azioni",
      "type": "n8n-nodes-base.splitInBatches",
      "parameters": {
        "batchSize": 1,
        "options": {}
      },
      "position": [1640, 240]
    },
    {
      "name": "Esegui Azione",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "jsCode": "const azione = $input.item.json;\nconst tutte_azioni = $('Estrai Decisioni').first().json.output.azioni;\nconst azione_corrente = tutte_azioni[$input.item.index];\n\nif (azione_corrente.azione === 'nessuna') {\n  return { json: { skipped: true } };\n}\n\nlet url, body;\n\nif (azione_corrente.azione === 'spegni') {\n  url = 'http://10.241.185.242:8123/api/services/climate/set_hvac_mode';\n  body = {\n    entity_id: azione_corrente.entity_id,\n    hvac_mode: 'off'\n  };\n} else if (azione_corrente.azione === 'accendi') {\n  url = 'http://10.241.185.242:8123/api/services/climate/set_hvac_mode';\n  body = {\n    entity_id: azione_corrente.entity_id,\n    hvac_mode: 'heat'\n  };\n} else if (azione_corrente.azione === 'imposta_temperatura') {\n  url = 'http://10.241.185.242:8123/api/services/climate/set_temperature';\n  body = {\n    entity_id: azione_corrente.entity_id,\n    temperature: azione_corrente.temp_target\n  };\n}\n\nreturn {\n  json: {\n    url: url,\n    body: body,\n    azione: azione_corrente\n  }\n};"
      },
      "position": [1840, 240]
    },
    {
      "name": "Chiama Home Assistant",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "POST",
        "url": "={{ $json.url }}",
        "authentication": "genericCredentialType",
        "sendBody": true,
        "bodyParameters": {
          "parameters": []
        },
        "jsonBody": "={{ JSON.stringify($json.body) }}",
        "options": {}
      },
      "position": [2040, 240]
    },
    {
      "name": "Salva Storico",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "=INSERT INTO heating_history (zona, azione, temperatura, fv_produzione, motivazione)\nVALUES (\n  '{{ $json.azione.zona }}',\n  '{{ $json.azione.azione }}',\n  {{ $json.azione.temp_target || 0 }},\n  {{ $('Prepara Dati').first().json.produzione_fv_kw }},\n  '{{ $('Estrai Decisioni').first().json.output.motivazione }}'\n);"
      },
      "position": [2240, 240]
    },
    {
      "name": "Notifica Telegram",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "chatId": "1819276368",
        "text": "=🏠 Riscaldamento aggiornato\n\n⏰ {{ $('Prepara Dati').first().json.timestamp.slice(11,16) }}\n☀️ FV: {{ $('Prepara Dati').first().json.produzione_fv_kw }} kW\n\n{{ $('Estrai Decisioni').first().json.output.motivazione }}\n\n📋 Azioni:\n{{ $('Estrai Decisioni').first().json.output.azioni.filter(a => a.azione !== 'nessuna').map(a => '• ' + a.zona + ': ' + a.azione + (a.temp_target ? ' (' + a.temp_target + '°C)' : '')).join('\\n') }}"
      },
      "position": [1640, 360]
    },
    {
      "name": "Anthropic Chat Model",
      "type": "@n8n/n8n-nodes-langchain.lmChatAnthropic",
      "parameters": {
        "model": "claude-sonnet-4-20250514"
      },
      "position": [1040, 500]
    }
  ],
  "connections": {
    "Schedule Trigger": {
      "main": [[{"node": "Leggi Config"}]]
    },
    "Leggi Config": {
      "main": [[{"node": "Leggi Stati Sensori"}]]
    },
    "Leggi Stati Sensori": {
      "main": [[{"node": "Prepara Dati"}]]
    },
    "Prepara Dati": {
      "main": [[{"node": "Agente Esecutore"}]]
    },
    "Agente Esecutore": {
      "main": [[{"node": "Estrai Decisioni"}]]
    },
    "Estrai Decisioni": {
      "main": [[{"node": "Ci Sono Azioni?"}]]
    },
    "Ci Sono Azioni?": {
      "main": [
        [{"node": "Split Azioni"}, {"node": "Notifica Telegram"}],
        []
      ]
    },
    "Split Azioni": {
      "main": [[{"node": "Esegui Azione"}]]
    },
    "Esegui Azione": {
      "main": [[{"node": "Chiama Home Assistant"}]]
    },
    "Chiama Home Assistant": {
      "main": [[{"node": "Salva Storico"}]]
    },
    "Anthropic Chat Model": {
      "ai_languageModel": [[
        {"node": "Agente Esecutore"},
        {"node": "Estrai Decisioni"}
      ]]
    }
  }
}
```

-----

## 3. Query Utili PostgreSQL

```sql
-- Vedi configurazione attuale
SELECT 
    config_json,
    modified_by,
    created_at,
    notes
FROM heating_config
ORDER BY id DESC
LIMIT 1;

-- Storico ultime 24h
SELECT 
    timestamp,
    zona,
    azione,
    temperatura,
    fv_produzione,
    motivazione
FROM heating_history
WHERE timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Statistiche per zona
SELECT 
    zona,
    COUNT(*) as num_azioni,
    AVG(temperatura) as temp_media,
    MAX(timestamp) as ultima_azione
FROM heating_history
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY zona;

-- Storico modifiche config
SELECT 
    timestamp,
    modified_by,
    change_description,
    config_json->'soglie_fv' as soglie_fv
FROM config_history
ORDER BY timestamp DESC
LIMIT 10;

-- Efficienza fotovoltaico
SELECT 
    DATE(timestamp) as giorno,
    COUNT(*) FILTER (WHERE azione = 'accendi' AND fv_produzione > 0.75) as accensioni_fv,
    COUNT(*) FILTER (WHERE azione = 'spegni' AND fv_produzione < 0.75) as spegnimenti_fv,
    AVG(fv_produzione) as produzione_media
FROM heating_history
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY giorno DESC;
```

-----

## 4. Connessione PostgreSQL in n8n

### Configurazione Credentials

1. In n8n: **Credentials → Add Credential → Postgres**
1. Compila:
   
   ```
   Host: localhost (o IP del server)
   Database: heating_db
   User: heating_user
   Password: [tua password sicura]
   Port: 5432
   SSL: Preferibile (se supportato)
   ```

-----

## 5. Esempi Conversazione Completi

### Cambio Orario

```
👤: "Accendi alle 7 invece che alle 6"

🤖: ✅ Ho spostato l'orario di accensione mattutina!

Prima: 06:00-07:00 a 37°C
Ora: 07:00-08:00 a 37°C

📝 Modifiche:
• Fascia "Riscaldamento mattina": ora_inizio 6→7, ora_fine 7→8

La modifica sarà applicata da domani mattina.
```

### Modifica Soglie FV

```
👤: "Aumenta la soglia del fotovoltaico a 1.2"

🤖: ✅ Soglie fotovoltaico aggiornate!

Prima: Accensione 1.0 kW / Spegnimento 0.75 kW
Ora: Accensione 1.2 kW / Spegnimento 0.75 kW

📝 Modifiche:
• Soglia accensione: 1.0 → 1.2 kW

Servirà più produzione solare per attivare il riscaldamento durante la fascia 10:00-20:00.
```

### Nuova Fascia Oraria

```
👤: "Aggiungi riscaldamento dalle 14 alle 16 a 32 gradi senza fotovoltaico"

🤖: ✅ Nuova fascia oraria aggiunta!

Fascia: "Riscaldamento pomeriggio"
Orario: 14:00-16:00
Temperatura: 32°C
Fotovoltaico: No
Stato: Attiva

📝 Modifiche:
• Aggiunta fascia oraria 14:00-16:00

Tutte le zone attive scalderanno a 32°C in questo intervallo.
```

### Disabilita Zona

```
👤: "Spegni il bagno primo piano"

🤖: ✅ Zona "Bagno Piano Primo" disabilitata!

📝 Modifiche:
• Zona "bagno_primo": attiva → disattivata

Questa zona non riceverà più comandi di riscaldamento. Vuoi che la spenga immediatamente?
```

-----

## 6. Vantaggi PostgreSQL vs File JSON

|Feature        |PostgreSQL        |File JSON              |
|---------------|------------------|-----------------------|
|**Persistenza**|✅ Garantita       |⚠️ Dipende da filesystem|
|**Concorrenza**|✅ Transazioni ACID|❌ Race conditions      |
|**Storico**    |✅ Tabelle dedicate|⚠️ Gestione manuale     |
|**Query**      |✅ SQL potente     |❌ Parsing limitato     |
|**Backup**     |✅ Automatico      |⚠️ Manuale              |
|**Rollback**   |✅ Facile          |❌ Difficile            |
|**Analytics**  |✅ Native          |❌ Complesse            |
|**Performance**|✅ Indicizzata     |⚠️ Scan completo        |

-----

## 7. Prossimi Passi

1. **Setup PostgreSQL**: Crea database e tabelle con SQL sopra
1. **Configura n8n**: Aggiungi credential PostgreSQL
1. **Importa Workflow A**: Bot configuratore
1. **Importa Workflow B**: Esecutore automatico
1. **Test**: Invia comandi via Telegram
1. **Monitor**: Query per vedere storico e performance

Tutto pronto! 🚀