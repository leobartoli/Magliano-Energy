# Sistema Riscaldamento Semplificato (SENZA Fotovoltaico)

## Filosofia: Orari Fissi e Basta

**PRIMA (Complicato):**

- Leggi produzione FV
- Confronta con soglie (>1kW, <0.75kW, zona intermedia)
- Decidi in base a FV + orario
- Aggiorna soglie quando cambiano

**DOPO (Semplice):**

- Guarda che ora è
- Accendi/spegni secondo tabella orari
- Fine.

-----

## 1. Schema Database Semplificato

```sql
-- Una sola tabella config (molto più semplice)
CREATE TABLE heating_config (
    id SERIAL PRIMARY KEY,
    config_json JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    modified_by VARCHAR(100)
);

-- Config iniziale SEMPLICE
INSERT INTO heating_config (config_json, modified_by) VALUES (
    '{
        "fasce_orarie": [
            {
                "nome": "Riscaldamento mattina",
                "ora_inizio": 6,
                "ora_fine": 7,
                "temperatura": 37,
                "attiva": true
            },
            {
                "nome": "Riscaldamento giorno",
                "ora_inizio": 10,
                "ora_fine": 20,
                "temperatura": 37,
                "attiva": true
            }
        ],
        "zone": [
            {"nome": "cameretta", "entity_id": "climate.cameretta", "attiva": true},
            {"nome": "soggiorno", "entity_id": "climate.pannello_soggiorno", "attiva": true},
            {"nome": "bagno_seminterrato", "entity_id": "climate.bagno_piano_seminterrato", "attiva": true},
            {"nome": "bagno_primo", "entity_id": "climate.bagno_piano_primo", "attiva": true}
        ],
        "modalita_vacanza": false
    }'::jsonb,
    'system'
);

-- Storico (opzionale, per debug)
CREATE TABLE heating_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    zona VARCHAR(50),
    azione VARCHAR(20),
    temperatura NUMERIC(4,1),
    motivo TEXT
);
```

-----

## 2. Workflow Bot Configuratore (Semplificato)

```json
{
  "name": "Heating Config Bot SIMPLE",
  "nodes": [
    {
      "name": "Telegram Trigger",
      "type": "n8n-nodes-base.telegramTrigger",
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
      "name": "Agente Configuratore",
      "type": "@n8n/n8n-nodes-langchain.agent",
      "parameters": {
        "promptType": "define",
        "text": "=Sei l'assistente per configurare il riscaldamento delle scuole.\n\n**CONFIGURAZIONE ATTUALE:**\n```json\n{{ JSON.stringify($('Leggi Config').item.json.config_json, null, 2) }}\n```\n\n**MESSAGGIO UTENTE:**\n{{ $('Telegram Trigger').item.json.message.text }}\n\n**COSA PUOI MODIFICARE:**\n\n1. **Orari di accensione/spegnimento**\n   - \"Accendi alle 7 invece che alle 6\"\n   - \"Spegni alle 19 invece che alle 20\"\n\n2. **Temperature**\n   - \"Metti 35 gradi al mattino\"\n   - \"Temperatura pomeriggio a 30\"\n\n3. **Zone attive/disattive**\n   - \"Spegni il bagno primo piano\"\n   - \"Riaccendi la cameretta\"\n\n4. **Fasce orarie** (aggiungi/rimuovi)\n   - \"Aggiungi riscaldamento 14-16 a 30 gradi\"\n   - \"Elimina la fascia mattutina\"\n\n5. **Modalità vacanza**\n   - \"Modalità vacanza\" → Spegne tutto\n   - \"Modalità normale\" → Riattiva\n\n6. **Visualizzare config**\n   - \"Status\" / \"Stato\" / \"Configurazione attuale\"\n\n**VALIDAZIONI:**\n- Temperature: 21-37°C\n- Orari: 0-23\n- Se richiesta non chiara, chiedi dettagli\n\n**OUTPUT (JSON):**\n```json\n{\n  \"risposta_utente\": \"Spiegazione chiara e amichevole\",\n  \"config_aggiornata\": { ...intera configurazione aggiornata... },\n  \"cambiamenti\": [\"lista modifiche\"],\n  \"tipo_operazione\": \"modifica/visualizza/vacanza\"\n}\n```"
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
            {"name": "risposta_utente", "type": "string"},
            {"name": "config_aggiornata", "type": "object"},
            {"name": "cambiamenti", "type": "array"},
            {"name": "tipo_operazione", "type": "string"}
          ]
        }
      },
      "position": [840, 300]
    },
    {
      "name": "Solo Se Modifica",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.output.tipo_operazione }}",
              "operation": "notEquals",
              "value2": "visualizza"
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
        "query": "=UPDATE heating_config \nSET config_json = '{{ JSON.stringify($json.output.config_aggiornata) }}'::jsonb,\n    modified_by = 'telegram_{{ $('Telegram Trigger').item.json.message.from.username }}',\n    created_at = NOW()\nWHERE id = (SELECT MAX(id) FROM heating_config);"
      },
      "position": [1240, 240]
    },
    {
      "name": "Invia Risposta",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "chatId": "={{ $('Telegram Trigger').item.json.message.chat.id }}",
        "text": "={{ $json.output.risposta_utente }}"
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
    "Telegram Trigger": {"main": [[{"node": "Leggi Config"}]]},
    "Leggi Config": {"main": [[{"node": "Agente Configuratore"}]]},
    "Agente Configuratore": {"main": [[{"node": "Estrai Risposta"}]]},
    "Estrai Risposta": {"main": [[{"node": "Solo Se Modifica"}, {"node": "Invia Risposta"}]]},
    "Solo Se Modifica": {"main": [[{"node": "Salva Config"}], []]},
    "Anthropic Chat Model": {"ai_languageModel": [[{"node": "Agente Configuratore"}, {"node": "Estrai Risposta"}]]}
  }
}
```

-----

## 3. Workflow Esecutore (SUPER Semplificato)

```json
{
  "name": "Heating Executor SIMPLE",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [{"field": "cronExpression", "expression": "*/30 6-20 * * *"}]
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
      "name": "Leggi Stati Zone",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://10.241.185.242:8123/api/states",
        "authentication": "genericCredentialType"
      },
      "position": [640, 300]
    },
    {
      "name": "Calcola Azioni SEMPLICE",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "jsCode": "const config = $('Leggi Config').first().json.config_json;\nconst states = $input.first().json;\n\nconst now = new Date();\nconst oraCorrente = now.getHours();\n\n// Se modalità vacanza → SPEGNI tutto\nif (config.modalita_vacanza) {\n  return [{\n    json: {\n      decisione: 'MODALITA VACANZA - Spegni tutto',\n      azioni: config.zone.map(z => ({\n        zona: z.nome,\n        entity_id: z.entity_id,\n        azione: 'spegni',\n        temperatura: 0\n      }))\n    }\n  }];\n}\n\n// Trova fascia oraria attiva\nconst fasciaAttiva = config.fasce_orarie.find(f => \n  f.attiva && \n  oraCorrente >= f.ora_inizio && \n  oraCorrente < f.ora_fine\n);\n\n// Stati attuali delle zone\nconst climates = states.filter(s => s.entity_id.startsWith('climate.'));\n\nconst azioni = config.zone\n  .filter(z => z.attiva)\n  .map(zona => {\n    const climate = climates.find(c => c.entity_id === zona.entity_id);\n    const statoCorrente = climate?.state || 'unknown';\n    const tempCorrente = parseFloat(climate?.attributes?.temperature || 0);\n    \n    // Decisione SEMPLICE\n    if (!fasciaAttiva) {\n      // Fuori orario → Spegni\n      return {\n        zona: zona.nome,\n        entity_id: zona.entity_id,\n        azione: statoCorrente === 'off' ? 'nessuna' : 'spegni',\n        temperatura: 0\n      };\n    } else {\n      // Dentro fascia → Accendi a temperatura\n      const targetTemp = fasciaAttiva.temperatura;\n      \n      if (statoCorrente === 'off') {\n        return {\n          zona: zona.nome,\n          entity_id: zona.entity_id,\n          azione: 'accendi_e_imposta',\n          temperatura: targetTemp\n        };\n      } else if (tempCorrente !== targetTemp) {\n        return {\n          zona: zona.nome,\n          entity_id: zona.entity_id,\n          azione: 'imposta_temperatura',\n          temperatura: targetTemp\n        };\n      } else {\n        return {\n          zona: zona.nome,\n          entity_id: zona.entity_id,\n          azione: 'nessuna',\n          temperatura: targetTemp\n        };\n      }\n    }\n  });\n\nreturn [{\n  json: {\n    decisione: fasciaAttiva ? `Fascia: ${fasciaAttiva.nome}` : 'Fuori orario',\n    azioni: azioni\n  }\n}];"
      },
      "position": [840, 300]
    },
    {
      "name": "Filtra Azioni Necessarie",
      "type": "n8n-nodes-base.filter",
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.azione }}",
              "operation": "notEquals",
              "value2": "nessuna"
            }
          ]
        }
      },
      "position": [1040, 300]
    },
    {
      "name": "Esegui Azione",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "jsCode": "const azione = $input.first().json;\n\nlet calls = [];\n\nif (azione.azione === 'spegni') {\n  calls.push({\n    url: 'http://10.241.185.242:8123/api/services/climate/set_hvac_mode',\n    body: { entity_id: azione.entity_id, hvac_mode: 'off' }\n  });\n} \nelse if (azione.azione === 'accendi_e_imposta') {\n  calls.push(\n    {\n      url: 'http://10.241.185.242:8123/api/services/climate/set_hvac_mode',\n      body: { entity_id: azione.entity_id, hvac_mode: 'heat' }\n    },\n    {\n      url: 'http://10.241.185.242:8123/api/services/climate/set_temperature',\n      body: { entity_id: azione.entity_id, temperature: azione.temperatura }\n    }\n  );\n} \nelse if (azione.azione === 'imposta_temperatura') {\n  calls.push({\n    url: 'http://10.241.185.242:8123/api/services/climate/set_temperature',\n    body: { entity_id: azione.entity_id, temperature: azione.temperatura }\n  });\n}\n\nreturn calls.map(call => ({ json: { ...call, azione: azione } }));"
      },
      "position": [1240, 300]
    },
    {
      "name": "Chiama Home Assistant",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "POST",
        "url": "={{ $json.url }}",
        "authentication": "genericCredentialType",
        "sendBody": true,
        "bodyParameters": {},
        "jsonBody": "={{ JSON.stringify($json.body) }}"
      },
      "position": [1440, 300]
    },
    {
      "name": "Salva Storico",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "=INSERT INTO heating_history (zona, azione, temperatura, motivo)\nVALUES (\n  '{{ $json.azione.zona }}',\n  '{{ $json.azione.azione }}',\n  {{ $json.azione.temperatura }},\n  '{{ $('Calcola Azioni SEMPLICE').first().json.decisione }}'\n);"
      },
      "position": [1640, 300]
    }
  ],
  "connections": {
    "Schedule Trigger": {"main": [[{"node": "Leggi Config"}]]},
    "Leggi Config": {"main": [[{"node": "Leggi Stati Zone"}]]},
    "Leggi Stati Zone": {"main": [[{"node": "Calcola Azioni SEMPLICE"}]]},
    "Calcola Azioni SEMPLICE": {"main": [[{"node": "Filtra Azioni Necessarie"}]]},
    "Filtra Azioni Necessarie": {"main": [[{"node": "Esegui Azione"}]]},
    "Esegui Azione": {"main": [[{"node": "Chiama Home Assistant"}]]},
    "Chiama Home Assistant": {"main": [[{"node": "Salva Storico"}]]}
  }
}
```

-----

## 4. Cosa È Cambiato

### ❌ RIMOSSO (Complessità)

- ~Lettura produzione fotovoltaico~
- ~Soglie accensione/spegnimento FV~
- ~Logica intermedia 0.75-1 kW~
- ~Tool “produzione_fv_kw”~
- ~Tool “Energia prodotta oggi”~
- ~Campo `usa_fotovoltaico` nelle fasce~
- ~Decisioni basate su sensori solari~

### ✅ MANTENUTO (Semplicità)

- Fasce orarie con temperatura fissa
- Attiva/disattiva zone
- Modalità vacanza
- Storico azioni
- Bot Telegram per modifiche
- Validazione temperature 21-37°C

-----

## 5. Vantaggi Reali

|Prima                          |Dopo                              |
|-------------------------------|----------------------------------|
|35+ nodi                       |**~15 nodi**                      |
|16 tool per l’agente           |**0 tool** (solo logic)           |
|Logica FV complicata           |**IF orario → ON/OFF**            |
|Errori possibili su soglie     |**Nessuna soglia**                |
|Debug difficile                |**Debug semplicissimo**           |
|Configurazione con 10 parametri|**Configurazione con 4 parametri**|

-----

## 6. Esempi Conversazione (Invariati)

```
👤: "Accendi alle 7 invece che alle 6"
🤖: ✅ Fascia "Riscaldamento mattina" spostata a 07:00-08:00

👤: "Temperatura giorno a 35 gradi"
🤖: ✅ Fascia "Riscaldamento giorno" impostata a 35°C

👤: "Modalità vacanza"
🤖: ✅ Modalità vacanza attivata. Tutto il riscaldamento è ora spento.

👤: "Status"
🤖: 🏠 Ora: 14:30
    📋 Fascia attiva: "Riscaldamento giorno" (37°C)
    ✅ Cameretta: ON 37°C
    ✅ Soggiorno: ON 37°C
```

-----

## 7. Se In Futuro Vuoi Ri-aggiungere FV

Basta aggiungere 1 campo alla config:

```json
{
  "usa_fotovoltaico_globale": false  // Un solo flag ON/OFF
}
```

E nel codice:

```javascript
if (config.usa_fotovoltaico_globale && fv_kw < 0.5) {
  return spegni_tutto;
}
```

**Molto più semplice della logica precedente!**

-----

## Conclusione

- **50% nodi in meno**
- **Zero complessità fotovoltaico**
- **Stesso risultato pratico** per 95% dei casi
- **Manutenzione 10x più facile**
- **Debug immediato**

Il fotovoltaico era un’ottimizzazione prematura che complicava tutto. Ora il sistema è **robusto, comprensibile, modificabile**. 🎯