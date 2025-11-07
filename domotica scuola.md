Perfetto 👍
Ecco il file README.md completo, già formattato in Markdown GitHub-ready (puoi copiarlo direttamente nella root del tuo repository).
Include tutta la parte tecnica su LUNA2000C, inverter, climatizzatore, n8n, IA, Modbus, ZeroTier e Cloudflare.

⸻


# ⚡ Smart Energy & Climate Control  
### n8n + Huawei LUNA2000C + SUN2000 + Climatizzatore (AI-powered)

Automazione energetica completa basata su **n8n** e **Modbus TCP**, per gestire in modo intelligente:
- sistema fotovoltaico **Huawei SUN2000**,  
- batteria **Huawei LUNA2000C**,  
- **climatizzatore / pompa di calore** collegato in rete (Modbus o MQTT),  
- e un **agente IA** (Mixtral / Ollama) che ottimizza carica, scarica e comfort termico.

Tutto gira **in rete LAN chiusa** (es. rete scolastica), senza aprire porte pubbliche, grazie a **ZeroTier** e **Cloudflare Tunnel**.

---

## 🧩 Architettura generale

                       ┌────────────────────┐
                       │      Mixtral IA    │
                       │  (docker Ollama)   │
                       └────────┬───────────┘
                                │
                                ▼

┌──────────────┐   Modbus TCP   ┌──────────────┐
│ Huawei SUN2000│◄─────────────►│ n8n (Docker) │
│ Inverter FV  │                │  + pymodbus   │
└──────────────┘                └──────┬────────┘
│
Modbus TCP                      │
┌──────────────┐                        │
│ LUNA2000C    │◄───────────────────────┘
│ Batteria ESS │
└──────────────┘

  ▲
  │ MQTT / Modbus TCP
  ▼

┌────────────────┐
│ Climatizzatore │  ← controllato da n8n in base a SOC, PV e temperatura
└────────────────┘

           ▼
 Telegram / Grafana / DB

---

## ⚙️ Componenti principali (Docker)

```yaml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    network_mode: host
    environment:
      - TZ=Europe/Rome
    volumes:
      - ./n8n:/home/node/.n8n

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    volumes:
      - ./ollama:/root/.ollama

  zerotier:
    image: zerotier/zerotier-ska:latest
    container_name: zerotier
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./zerotier-one:/var/lib/zerotier-one

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    volumes:
      - ./cloudflared:/etc/cloudflared
    command: tunnel run


⸻

📊 Registri Modbus principali

🔋 LUNA2000C (batteria)

Nome	Indirizzo	Tipo	Unità	Descrizione
Stato batteria	32000	UInt16	—	Idle / Charge / Discharge
Potenza	32002	Int16	W	Potenza attuale
SOC	32005	UInt16	%	Stato di carica
Tensione	32004	UInt16	V	Voltaggio medio
Comando carica	41000	UInt16	1/0	Forza carica
Comando scarica	41001	UInt16	1/0	Forza scarica


⸻

☀️ Huawei SUN2000 (inverter)

Nome	Indirizzo	Tipo	Unità	Descrizione
Potenza FV	30000	Int32	W	Produzione corrente
Tensione DC	30002	UInt16	V	Tensione stringa
Frequenza rete	30010	UInt16	Hz	Frequenza AC
Potenza di uscita	32016	Int32	W	Energia immessa in rete/carichi


⸻

❄️ Climatizzatore (Modbus / MQTT)

Nome	Indirizzo o Topic	Tipo	Descrizione
Temperatura interna	40001	UInt16	°C × 10
Stato	40002	UInt16	0=OFF, 1=ON
Setpoint	40003	UInt16	°C × 10
Potenza richiesta	MQTT home/clima/power	W	Lettura energia attiva
Comando ON/OFF	MQTT home/clima/cmd	testo	“on” / “off”


⸻

🔧 Esempio script Modbus (Python)

from pymodbus.client import ModbusTcpClient

client = ModbusTcpClient('192.168.10.50', port=502)
client.connect()

rr = client.read_holding_registers(32005, 1, unit=1)
soc = rr.registers[0]

if soc < 20:
    client.write_register(41000, 1, unit=1)  # forza carica
elif soc > 90:
    client.write_register(41000, 0, unit=1)  # disattiva carica
    print("Avvio climatizzatore per consumo FV")

client.close()


⸻

🧠 Prompt per l’agente IA (PROMPT_AGENT.txt)

Tu sei l’agente energetico di un edificio scolastico.
Hai accesso a dati da inverter Huawei SUN2000, batteria LUNA2000C e climatizzatore.
Il tuo obiettivo è mantenere comfort termico ed efficienza energetica, evitando sprechi.

Dati forniti ogni ciclo:
- PV_POWER (produzione solare in W)
- BATTERY_SOC (%)
- LOAD_POWER (consumi totali)
- GRID_IMPORT (W)
- TEMPERATURE_INT (°C)
- SETPOINT (°C)

Devi restituire un piano di azione JSON con:
{
  "force_charge": true/false,
  "force_discharge": true/false,
  "climate_mode": "on"|"off",
  "reason": "spiegazione sintetica"
}

Regole di base:
1. Se SOC < 20% → non scaricare, forzare carica.
2. Se SOC > 85% e PV_POWER < 200W → consenti scarica per alimentare i carichi.
3. Se PV_POWER > 1kW e SOC < 95% → forzare carica.
4. Se temperatura < SETPOINT-1 e SOC > 50% → accendi climatizzatore.
5. Se temperatura > SETPOINT+1 → spegni climatizzatore.
6. Evita cicli rapidi ON/OFF, aggiungi 5 minuti di isteresi.
7. Mantieni priorità alla sicurezza batteria (mai SOC < 15%).

Rispondi sempre con JSON valido.

Esempio output IA:

{
  "force_charge": false,
  "force_discharge": true,
  "climate_mode": "on",
  "reason": "SOC alto e nessuna produzione FV; scarico per alimentare il clima."
}


⸻

🧩 Workflow n8n (semplificato)
	1.	Trigger ogni 60s
	2.	Nodo Python (pymodbus) → legge SOC, PV Power, Temperatura
	3.	Nodo HTTP → Mixtral → invia prompt + dati
	4.	Nodo IF → in base a JSON ricevuto:
	•	force_charge=true → mbpoll -r 41000 -t 3:int -0 1
	•	force_discharge=true → mbpoll -r 41001 -t 3:int -0 1
	•	climate_mode="on" → MQTT publish home/clima/cmd=on
	5.	Nodo Telegram → invia log decisione IA

⸻

🔒 Sicurezza di rete
	•	Nessuna porta pubblica (502 o 5678) esposta.
	•	Comunicazioni interne → rete LAN o ZeroTier mesh privata.
	•	Accesso remoto alla dashboard → Cloudflare Tunnel autenticato (Keycloak / Access).
	•	Tutte le scritture Modbus vengono loggate su PostgreSQL con timestamp.

⸻

🧱 Requisiti minimi
	•	Mini-PC Linux (es. Intel NUC o simile, 8 GB RAM)
	•	Docker + docker-compose
	•	Libreria pymodbus o utility mbpoll
	•	Inverter e batteria Huawei in LAN con Modbus TCP attivo
	•	Climatizzatore con Modbus o MQTT gateway

⸻

📦 Avvio rapido

git clone https://github.com/<tuo_utente>/smart-energy-n8n.git
cd smart-energy-n8n
docker compose up -d

Poi apri http://localhost:5678 per accedere a n8n e importa il workflow in /n8n-workflows/.

⸻

✅ Obiettivi del progetto
	•	Gestione intelligente e autonoma di energia e comfort.
	•	Tutto in locale, senza dipendenza da cloud esterni.
	•	Sicurezza e controllo completo via rete privata.
	•	Log ed esportazione dati per analisi e miglioramento IA.

⸻

📂 Struttura repository suggerita

.
├── README.md
├── docker-compose.yml
├── n8n-workflows/
│   ├── read_soc_and_act.json
│   └── clima_control.json
├── scripts/
│   ├── test_mbpoll.sh
│   └── pymodbus_example.py
├── examples/
│   ├── config_modbus.md
│   └── network_notes.md
└── PROMPT_AGENT.txt


⸻

🔧 Autore

Sistema sviluppato per il Comune di Magliano in Toscana,
Ufficio Tecnico – progetto di automazione energetica locale (2025).

⸻


---

Vuoi che ti generi subito anche il file `PROMPT_AGENT.txt` separato e il `docker-compose.yml` coerente con questo README, così puoi creare direttamente il repository GitHub pronto all’uso?