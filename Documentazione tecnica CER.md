# Comunità Energetica Rinnovabile - Comune di Magliano in Toscana

## Documentazione Tecnica e Normativa

-----

## 1. QUADRO NORMATIVO

### 1.1 Normativa Nazionale

**Decreto Legislativo 199/2021** (Red II)

- Recepimento Direttiva UE 2018/2001
- Definisce le Comunità Energetiche Rinnovabili (CER)
- Art. 31: configurazioni di autoconsumo

**Decreto CACER (D.M. 414/2023)**

- Attuazione incentivi per CER e autoconsumo
- Tariffa incentivante: **119 €/MWh** (0,119 €/kWh)
- Premio autoconsumo: variabile per zona (10-15 €/MWh)
- Validità: 20 anni dalla data di ammissione

**Delibera ARERA 727/2022**

- Regolazione tecnica ed economica
- Definizione energia condivisa
- Meccanismi di ripartizione incentivi

### 1.2 Requisiti CER

**Membri:**

- Persone fisiche, PMI, enti locali, autorità locali
- Partecipazione aperta e volontaria
- Sede/domicilio nell’area sottesa alla cabina primaria
- Per Comuni: popolazione < 5.000 abitanti

**Impianti:**

- Potenza singola ≤ 1 MW (fotovoltaico prevalentemente)
- Entrata in esercizio dopo 15/12/2021 o potenziati dopo tale data
- Connessi alla rete elettrica di distribuzione
- Ubicazione nell’area della cabina primaria

**Energia Condivisa:**

```
Ec(t) = MIN[Σ Produzione(t), Σ Consumo(t)]

Dove:
- Ec(t) = energia condivisa nell'ora t
- t = periodo orario
- Produzione(t) = somma energia immessa da tutti gli impianti CER
- Consumo(t) = somma energia prelevata da tutti i membri CER
```

-----

## 2. CONFIGURAZIONE SISTEMA - MAGLIANO IN TOSCANA

### 2.1 Dati CER

**Identificativi:**

- Nome: CER Comune di Magliano in Toscana
- Cabina Primaria: Grosseto CP1 (codice da verificare)
- POD Riferimento: IT001E… (da GSE)
- Codice Fiscale CER: (da registrazione GSE)

**Caratteristiche:**

- Popolazione Magliano: ~3.600 abitanti ✅ < 5.000
- Potenza installata prevista: ~150 kWp
- Numero membri iniziali: 1 (Comune) + 20-30 cittadini
- Tipologia: prevalentemente fotovoltaico

### 2.2 Impianti Comunali

|Edificio         |Potenza kWp|POD    |Indirizzo           |
|-----------------|-----------|-------|--------------------|
|Municipio        |20         |IT001E…|Piazza Garibaldi, 1 |
|Scuola Elementare|40         |IT001E…|Via della Scuola, 15|
|Palestra Comunale|30         |IT001E…|Via dello Sport, 8  |
|Biblioteca       |15         |IT001E…|Piazza del Popolo, 5|
|**TOTALE**       |**105**    |       |                    |

**Produzione Stimata Annua:**

- Irraggiamento Toscana sud: ~1.450 kWh/kWp/anno
- Produzione totale: 105 kWp × 1.450 = **152.250 kWh/anno**
- Produzione media mensile: ~12.700 kWh

### 2.3 Consumi Comunali Stimati

|Utenza                |Consumo Annuo kWh|Note                    |
|----------------------|-----------------|------------------------|
|Illuminazione pubblica|85.000           |Principale consumo      |
|Edifici comunali      |45.000           |Uffici, scuole, impianti|
|Altro                 |10.000           |Fontane, semafori, etc. |
|**TOTALE**            |**140.000**      |                        |

**Autoconsumo Potenziale:**

- Energia condivisa stimata: ~60-70% della produzione
- Circa **90.000-105.000 kWh/anno**

-----

## 3. CALCOLO INCENTIVI

### 3.1 Componenti Economiche

**Tariffa Incentivante (TIAD):**

- Base: 119 €/MWh = **0,119 €/kWh**
- Premio autoconsumo Toscana: 10 €/MWh = **0,010 €/kWh**
- **Totale: 0,129 €/kWh** di energia condivisa

**Valorizzazione Energia:**

- Corrispettivo valorizzazione: ~0,08-0,12 €/kWh (variabile PUN)
- Rimborso componenti tariffarie: ~0,01-0,02 €/kWh

**Totale Benefici:** ~0,15-0,18 €/kWh energia condivisa

### 3.2 Proiezioni Economiche Annuali

**Scenario Conservativo (60% autoconsumo):**

```
Energia condivisa: 91.350 kWh/anno

Incentivi TIAD:
91.350 kWh × 0,129 €/kWh = 11.784 €/anno

Corrispettivi energia:
91.350 kWh × 0,10 €/kWh = 9.135 €/anno

TOTALE BENEFICI: ~21.000 €/anno
```

**Scenario Ottimistico (70% autoconsumo):**

```
Energia condivisa: 106.575 kWh/anno

Incentivi TIAD:
106.575 kWh × 0,129 €/kWh = 13.748 €/anno

Corrispettivi energia:
106.575 kWh × 0,10 €/kWh = 10.658 €/anno

TOTALE BENEFICI: ~24.500 €/anno
```

### 3.3 Criteri di Ripartizione

**Proposta per Magliano:**

1. **Comune (40%)**
- Quota fissa per coperture investimenti infrastruttura
- Manutenzione impianti pubblici
- Gestione sistema di monitoraggio
1. **Membri Produttori (35%)**
- Proporzionale all’energia prodotta e immessa
- Incentivo a investire in nuovi impianti
1. **Membri Consumatori (25%)**
- Proporzionale all’energia consumata
- Incentivo a partecipare anche senza produzione

**Esempio Ripartizione Mensile (21.000 €/anno):**

- Comune: 700 €/mese
- Produttori: 612,50 €/mese (totale, poi ripartito)
- Consumatori: 437,50 €/mese (totale, poi ripartito)

-----

## 4. SETUP TECNICO INFRASTRUTTURA

### 4.1 Hardware Necessario

**Server Centrale (Comune):**

```yaml
Specifiche minime:
  CPU: 4 core
  RAM: 16 GB
  Storage: 500 GB SSD
  OS: Ubuntu Server 22.04 LTS
  
Servizi installati:
  - PostgreSQL 14 + TimescaleDB
  - InfluxDB 2.x
  - Grafana 10.x
  - n8n (self-hosted)
  - MQTT Broker (Mosquitto)
  - Nginx (reverse proxy)
  - Certbot (SSL)
```

**Backup:**

- NAS Synology o equivalente
- Backup giornaliero database
- Retention: 7 giorni incrementale, mensile completo

**Connettività:**

- Fibra ≥100 Mbps
- IP statico (per VPN accesso remoto)
- UPS per continuità servizio

### 4.2 Home Assistant - Installazione

**Per ogni edificio comunale:**

```bash
# Raspberry Pi 4 (4GB) o equivalente x86

# Installazione Home Assistant OS
# 1. Scaricare immagine da home-assistant.io
# 2. Flash su SD card con Etcher
# 3. Boot e configurazione iniziale

# Integrazioni necessarie:
- Modbus (inverter fotovoltaico)
- MQTT (comunicazione con n8n)
- REST API (esposizione dati)
- PostgreSQL Recorder
- InfluxDB
- File Editor (configurazione)
- Studio Code Server (sviluppo)
```

**File configuration.yaml:** (vedi artifact già creato)

### 4.3 Connessione Inverter

**Protocolli supportati:**

- Modbus TCP/RTU (Huawei, SMA, Fronius, SolarEdge)
- Sunspec (standard universale)
- API REST proprietarie

**Esempio configurazione Modbus Huawei:**

```yaml
modbus:
  - name: inverter_municipio
    type: tcp
    host: 192.168.1.100
    port: 502
    sensors:
      - name: "Potenza Attiva"
        address: 32080
        unit_of_measurement: "W"
        data_type: int32
        scale: 1
        
      - name: "Energia Giornaliera"
        address: 32114
        unit_of_measurement: "kWh"
        data_type: uint32
        scale: 0.01
```

### 4.4 Smart Meter

**Contatori Enel/E-Distribuzione:**

- Lettura tramite porta ottica P1
- Protocollo IEC 62056-21
- Modulo hardware: EmonCMS/Shelly EM

**Alternative:**

- Pinze amperometriche su quadro elettrico
- Shelly EM (WiFi, 2 canali, 120A)
- Integrazione diretta in Home Assistant

-----

## 5. CONFIGURAZIONE N8N

### 5.1 Installazione

```bash
# Docker Compose
version: '3.7'

services:
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=password_sicura
      - N8N_HOST=n8n.cermagliano.local
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://n8n.cermagliano.local/
      - GENERIC_TIMEZONE=Europe/Rome
    volumes:
      - ./n8n_data:/home/node/.n8n
      - ./workflows:/workflows
    depends_on:
      - postgres

  postgres:
    image: postgres:14
    restart: unless-stopped
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 5.2 Workflow da Importare

1. **Workflow Principale** (orario)
1. **Report Mensili** (primo del mese)
1. **Alert Anomalie** (continuo)
1. **Integrazione GSE** (mensile)
1. **Backup Database** (giornaliero)

-----

## 6. DATABASE - SETUP

### 6.1 Installazione PostgreSQL + TimescaleDB

```bash
# Ubuntu 22.04
sudo apt update
sudo apt install postgresql-14 postgresql-contrib

# Aggiungi TimescaleDB repository
sudo add-apt-repository ppa:timescale/timescaledb-ppa
sudo apt update
sudo apt install timescaledb-2-postgresql-14

# Configura TimescaleDB
sudo timescaledb-tune

# Restart PostgreSQL
sudo systemctl restart postgresql

# Crea database
sudo -u postgres psql
CREATE DATABASE cer_magliano;
\c cer_magliano
CREATE EXTENSION timescaledb;
```

### 6.2 Import Schema

```bash
# Esegui lo schema SQL fornito
psql -U postgres -d cer_magliano -f schema_cer_magliano.sql
```

### 6.3 Backup Automatico

```bash
# Crontab per backup giornaliero
0 2 * * * pg_dump cer_magliano | gzip > /backup/cer_$(date +\%Y\%m\%d).sql.gz

# Retention 30 giorni
find /backup -name "cer_*.sql.gz" -mtime +30 -delete
```

-----

## 7. GRAFANA - CONFIGURAZIONE

### 7.1 Installazione

```bash
# Ubuntu
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana

# Avvio
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

### 7.2 Datasource PostgreSQL

```yaml
# /etc/grafana/provisioning/datasources/postgres.yaml
apiVersion: 1

datasources:
  - name: PostgreSQL-CER
    type: postgres
    url: localhost:5432
    database: cer_magliano
    user: grafana_reader
    secureJsonData:
      password: 'password'
    jsonData:
      sslmode: 'disable'
      postgresVersion: 1400
      timescaledb: true
```

### 7.3 Import Dashboard

- Importa il JSON fornito nell’artifact
- URL: http://localhost:3000
- Login default: admin/admin

-----

## 8. PROCEDURA DI ATTIVAZIONE CER

### 8.1 Checklist Pre-Attivazione

- [ ] Statuto/atto costitutivo CER redatto
- [ ] Identificazione cabina primaria (richiesta a E-Distribuzione)
- [ ] Elenco membri fondatori completo
- [ ] POD di tutti gli impianti e utenze
- [ ] Impianti fotovoltaici entrati in esercizio dopo 15/12/2021
- [ ] Domanda di accesso al servizio (portale GSE)
- [ ] Sistema di monitoraggio operativo

### 8.2 Registrazione GSE

**Portale Area Clienti GSE:**

1. Registrazione soggetto referente (Comune)
1. Caricamento documentazione:
- Atto costitutivo CER
- Elenco membri e POD
- Visure catastali impianti
- Schemi elettrici
1. Richiesta codice CER
1. Attesa approvazione (30-60 giorni)

### 8.3 Configurazione Sistema

Una volta ottenuto codice CER:

1. Inserire codice in `configurazione_cer` table
1. Attivare tutti i workflow n8n
1. Verificare flusso dati Home Assistant → n8n → Database
1. Test calcolo energia condivisa
1. Verifica dashboard Grafana

-----

## 9. GESTIONE OPERATIVA

### 9.1 Attività Mensili

**Prima settimana del mese:**

- [ ] Generazione report automatica (n8n)
- [ ] Verifica dati GSE
- [ ] Controllo anomalie/alert
- [ ] Invio report membri via email

**Metà mese:**

- [ ] Monitoraggio performance impianti
- [ ] Verifica autoconsumo vs target
- [ ] Analisi consumi comunali

**Fine mese:**

- [ ] Preparazione dati per GSE
- [ ] Backup completo database
- [ ] Riunione referenti CER (se necessario)

### 9.2 Attività Annuali

- Revisione percentuali ripartizione
- Aggiornamento tariffe incentivi (GSE)
- Manutenzione ordinaria impianti
- Report di sostenibilità
- Assemblea membri CER

### 9.3 Monitoraggio KPI

**Indicatori chiave:**

- Autoconsumo % (target: >60%)
- Energia condivisa mensile
- Incentivi maturati
- CO2 risparmiata
- Risparmio economico membri
- Uptime sistema (target: >99%)
- Numero alert/anomalie

-----

## 10. SICUREZZA E PRIVACY

### 10.1 GDPR

**Dati personali trattati:**

- Anagrafica membri (nome, indirizzo, email)
- POD contatori
- Consumi/produzione energetica

**Misure:**

- Informativa privacy ai membri
- Consenso trattamento dati
- Data retention policy (2 anni dati orari)
- Crittografia database
- Backup cifrati
- Accesso autenticato a dashboard

### 10.2 Sicurezza IT

```yaml
Misure implementate:
  - Firewall (UFW) su server
  - SSL/TLS per tutte le comunicazioni
  - VPN per accesso remoto
  - Autenticazione forte (2FA su n8n/Grafana)
  - Audit log accessi database
  - Antivirus/antimalware
  - Aggiornamenti automatici sicurezza
```

-----

## 11. COSTI E INVESTIMENTI

### 11.1 Costi Iniziali

|Voce                     |Costo €  |
|-------------------------|---------|
|Server + UPS             |2.000    |
|Raspberry Pi (×4 edifici)|400      |
|Smart meter/sensori      |1.000    |
|Sviluppo/configurazione  |3.000    |
|Consulenza legale/GSE    |2.000    |
|**TOTALE**               |**8.400**|

### 11.2 Costi Operativi Annui

|Voce                 |Costo €/anno|
|---------------------|------------|
|Connettività/hosting |500         |
|Manutenzione software|500         |
|Assistenza tecnica   |1.000       |
|Assicurazioni        |300         |
|**TOTALE**           |**2.300**   |

### 11.3 ROI

```
Investimento iniziale: 8.400 €
Costi operativi annui: 2.300 €
Benefici annui (conservativo): 21.000 €

Beneficio netto anno 1: 21.000 - 8.400 - 2.300 = 10.300 €
Beneficio netto anni successivi: 21.000 - 2.300 = 18.700 €/anno

Payback: < 1 anno
```

-----

## 12. SUPPORTO E CONTATTI

### 12.1 Riferimenti Tecnici

**Referente Tecnico Comune:**

- Nome: [Da definire]
- Email: energia@comune.magliano.gr.it
- Telefono: 0564 XXXXXX

**Assistenza Sistema:**

- Home Assistant: https://community.home-assistant.io
- n8n: https://community.n8n.io
- PostgreSQL/Timescale: https://docs.timescale.com

### 12.2 Riferimenti Normativi

**GSE:**

- Portale: https://www.gse.it
- Area Clienti: https://applicazioni.gse.it
- Helpdesk: 800.19.99.89

**ARERA:**

- Sito: https://www.arera.it
- Delibere CER: 727/2022, 318/2020

**Ministero Ambiente:**

- DL 199/2021
- Decreto CACER (D.M. 414/2023)

-----

## APPENDICI

### A. Glossario

- **CER**: Comunità Energetica Rinnovabile
- **POD**: Point of Delivery (codice identificativo utenza)
- **GSE**: Gestore Servizi Energetici
- **TIAD**: Tariffa Incentivante Autoconsumo Diffuso
- **PUN**: Prezzo Unico Nazionale energia
- **Cabina Primaria**: Punto di connessione alla rete AT

### B. Template Documenti

- Modulo adesione membro CER
- Informativa privacy GDPR
- Regolamento interno CER
- Criteri ripartizione incentivi

### C. FAQ

**D: Quanto tempo per attivare la CER?**
R: 3-6 mesi dalla costituzione all’operatività

**D: Posso aderire se non ho un impianto?**
R: Sì, anche solo come consumatore

**D: Gli incentivi sono tassati?**
R: Da valutare con commercialista (regime fiscale CER)

**D: Posso uscire dalla CER?**
R: Sì, con preavviso di 3 mesi

-----

*Documento aggiornato al: novembre 2024*  
*Versione: 1.0*  
*Autore: Sistema CER Magliano in Toscana*
