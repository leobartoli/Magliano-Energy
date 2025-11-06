– Schema Database per CER Magliano in Toscana
– PostgreSQL 14+

– Estensioni utili
CREATE EXTENSION IF NOT EXISTS “uuid-ossp”;
CREATE EXTENSION IF NOT EXISTS “timescaledb”;

– =====================================================
– TABELLE ANAGRAFICHE
– =====================================================

– Membri della CER
CREATE TABLE membri (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
codice_membro VARCHAR(20) UNIQUE NOT NULL,
tipo_membro VARCHAR(20) NOT NULL CHECK (tipo_membro IN (‘comune’, ‘cittadino’, ‘impresa’, ‘associazione’)),
nome VARCHAR(100) NOT NULL,
cognome VARCHAR(100),
ragione_sociale VARCHAR(200),
codice_fiscale VARCHAR(16),
partita_iva VARCHAR(11),
indirizzo TEXT,
cap VARCHAR(5),
comune VARCHAR(100) DEFAULT ‘Magliano in Toscana’,
telefono VARCHAR(20),
email VARCHAR(100),
pec VARCHAR(100),
data_adesione DATE NOT NULL DEFAULT CURRENT_DATE,
data_uscita DATE,
attivo BOOLEAN DEFAULT true,
pod VARCHAR(14), – Codice POD del contatore
percentuale_ripartizione DECIMAL(5,2) DEFAULT 0, – % degli incentivi
note TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

– Impianti di produzione
CREATE TABLE impianti (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
codice_impianto VARCHAR(20) UNIQUE NOT NULL,
membro_id UUID REFERENCES membri(id),
nome_impianto VARCHAR(100) NOT NULL,
tipo_impianto VARCHAR(50) DEFAULT ‘fotovoltaico’,
potenza_nominale_kw DECIMAL(10,3) NOT NULL,
data_installazione DATE,
data_attivazione DATE,
indirizzo_installazione TEXT,
latitudine DECIMAL(10,7),
longitudine DECIMAL(10,7),
marca_inverter VARCHAR(50),
modello_inverter VARCHAR(50),
numero_pannelli INTEGER,
orientamento VARCHAR(20), – sud, est, ovest
inclinazione_gradi INTEGER,
codice_gse VARCHAR(50), – Codice impianto GSE
attivo BOOLEAN DEFAULT true,
note TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

– Edifici comunali
CREATE TABLE edifici_comunali (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
nome_edificio VARCHAR(100) NOT NULL,
tipologia VARCHAR(50), – scuola, municipio, palestra, biblioteca
indirizzo TEXT,
superficie_mq INTEGER,
pod VARCHAR(14),
impianto_id UUID REFERENCES impianti(id),
consumo_medio_annuo_kwh INTEGER,
note TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

– =====================================================
– TABELLE DATI ENERGETICI
– =====================================================

– Dati orari produzione (TimescaleDB hypertable)
CREATE TABLE produzione_oraria (
timestamp TIMESTAMPTZ NOT NULL,
impianto_id UUID NOT NULL REFERENCES impianti(id),
energia_prodotta_kwh DECIMAL(10,3) NOT NULL,
energia_immessa_kwh DECIMAL(10,3),
energia_autoconsumata_kwh DECIMAL(10,3),
potenza_media_kw DECIMAL(10,3),
irraggiamento_wm2 DECIMAL(6,2),
temperatura_moduli_c DECIMAL(5,2),
efficienza_percentuale DECIMAL(5,2),
ore_funzionamento DECIMAL(4,2),
PRIMARY KEY (timestamp, impianto_id)
);

– Converti in hypertable per performance
SELECT create_hypertable(‘produzione_oraria’, ‘timestamp’);

– Dati orari consumo
CREATE TABLE consumo_orario (
timestamp TIMESTAMPTZ NOT NULL,
membro_id UUID NOT NULL REFERENCES membri(id),
pod VARCHAR(14),
energia_prelevata_kwh DECIMAL(10,3) NOT NULL,
energia_consumata_kwh DECIMAL(10,3) NOT NULL,
potenza_media_kw DECIMAL(10,3),
fascia_oraria VARCHAR(2), – F1, F2, F3
PRIMARY KEY (timestamp, membro_id)
);

SELECT create_hypertable(‘consumo_orario’, ‘timestamp’);

– =====================================================
– CALCOLI ENERGIA CONDIVISA
– =====================================================

– Energia condivisa oraria (cuore del sistema CER)
CREATE TABLE energia_condivisa_oraria (
timestamp TIMESTAMPTZ NOT NULL PRIMARY KEY,
produzione_totale_kwh DECIMAL(10,3) NOT NULL,
consumo_totale_kwh DECIMAL(10,3) NOT NULL,
energia_condivisa_kwh DECIMAL(10,3) NOT NULL,
energia_immessa_rete_kwh DECIMAL(10,3),
energia_prelevata_rete_kwh DECIMAL(10,3),
percentuale_autoconsumo DECIMAL(5,2),
numero_membri_attivi INTEGER,
prezzo_pun_euro_kwh DECIMAL(8,5),
tariffa_incentivo_euro_kwh DECIMAL(8,5) DEFAULT 0.119,
valore_incentivo_euro DECIMAL(10,2),
calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT create_hypertable(‘energia_condivisa_oraria’, ‘timestamp’);

– Dettaglio ripartizione energia condivisa per membro
CREATE TABLE ripartizione_oraria (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
timestamp TIMESTAMPTZ NOT NULL,
membro_id UUID NOT NULL REFERENCES membri(id),
energia_condivisa_membro_kwh DECIMAL(10,3),
produzione_membro_kwh DECIMAL(10,3),
consumo_membro_kwh DECIMAL(10,3),
percentuale_contributo DECIMAL(5,2),
incentivo_spettante_euro DECIMAL(10,2),
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
UNIQUE(timestamp, membro_id)
);

CREATE INDEX idx_ripartizione_timestamp ON ripartizione_oraria(timestamp);
CREATE INDEX idx_ripartizione_membro ON ripartizione_oraria(membro_id);

– =====================================================
– TABELLE INCENTIVI E CONTABILITÀ
– =====================================================

– Report mensili incentivi
CREATE TABLE report_mensili (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
anno INTEGER NOT NULL,
mese INTEGER NOT NULL CHECK (mese BETWEEN 1 AND 12),
membro_id UUID NOT NULL REFERENCES membri(id),
energia_prodotta_kwh DECIMAL(10,3),
energia_consumata_kwh DECIMAL(10,3),
energia_condivisa_kwh DECIMAL(10,3),
percentuale_autoconsumo DECIMAL(5,2),
incentivo_totale_euro DECIMAL(10,2),
incentivo_produzione_euro DECIMAL(10,2),
incentivo_consumo_euro DECIMAL(10,2),
risparmio_bolletta_stimato_euro DECIMAL(10,2),
co2_risparmiata_kg DECIMAL(10,2),
stato_pagamento VARCHAR(20) DEFAULT ‘da_pagare’,
data_pagamento DATE,
note TEXT,
generato_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
UNIQUE(anno, mese, membro_id)
);

– Pagamenti incentivi
CREATE TABLE pagamenti_incentivi (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
report_mensile_id UUID REFERENCES report_mensili(id),
membro_id UUID REFERENCES membri(id),
importo_euro DECIMAL(10,2) NOT NULL,
data_pagamento DATE NOT NULL,
modalita_pagamento VARCHAR(50), – bonifico, accredito_bolletta
riferimento_bancario VARCHAR(100),
note TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

– =====================================================
– TABELLE CONFIGURAZIONE E GESTIONE
– =====================================================

– Configurazione sistema CER
CREATE TABLE configurazione_cer (
chiave VARCHAR(50) PRIMARY KEY,
valore TEXT NOT NULL,
tipo_dato VARCHAR(20), – string, number, boolean, json
descrizione TEXT,
modificabile BOOLEAN DEFAULT true,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

– Inserimento configurazioni iniziali
INSERT INTO configurazione_cer (chiave, valore, tipo_dato, descrizione) VALUES
(‘tariffa_incentivo_base’, ‘0.119’, ‘number’, ‘Tariffa incentivo CER €/kWh’),
(‘tariffa_premio_autoconsumo’, ‘0.010’, ‘number’, ‘Premio autoconsumo €/kWh’),
(‘cabina_primaria’, ‘Grosseto_CP1’, ‘string’, ‘Cabina primaria di riferimento’),
(‘potenza_massima_cer_kw’, ‘200’, ‘number’, ‘Potenza massima CER secondo normativa’),
(‘percentuale_comune’, ‘40’, ‘number’, ‘Percentuale incentivi spettanti al Comune’),
(‘fattore_emissione_co2’, ‘0.300’, ‘number’, ‘kg CO2 per kWh (fattore conversione)’),
(‘email_referente_cer’, ‘energia@comune.magliano.gr.it’, ‘string’, ‘Email referente CER’);

– Log eventi sistema
CREATE TABLE log_eventi (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
tipo_evento VARCHAR(50) NOT NULL,
entita VARCHAR(50), – membro, impianto, sistema
entita_id UUID,
descrizione TEXT,
dati_json JSONB,
severita VARCHAR(20) DEFAULT ‘info’ – info, warning, error, critical
);

CREATE INDEX idx_log_timestamp ON log_eventi(timestamp DESC);
CREATE INDEX idx_log_tipo ON log_eventi(tipo_evento);

– Alert e notifiche
CREATE TABLE alert (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
tipo_alert VARCHAR(50) NOT NULL,
priorita VARCHAR(20) DEFAULT ‘media’, – bassa, media, alta, critica
titolo VARCHAR(200) NOT NULL,
messaggio TEXT,
impianto_id UUID REFERENCES impianti(id),
membro_id UUID REFERENCES membri(id),
letto BOOLEAN DEFAULT false,
risolto BOOLEAN DEFAULT false,
risolto_at TIMESTAMPTZ,
note_risoluzione TEXT
);

– =====================================================
– VISTE UTILI
– =====================================================

– Vista produzione giornaliera per impianto
CREATE VIEW v_produzione_giornaliera AS
SELECT
DATE(timestamp) as data,
impianto_id,
i.nome_impianto,
i.potenza_nominale_kw,
SUM(energia_prodotta_kwh) as produzione_kwh,
SUM(energia_immessa_kwh) as immessa_kwh,
SUM(energia_autoconsumata_kwh) as autoconsumata_kwh,
ROUND(AVG(efficienza_percentuale), 2) as efficienza_media,
COUNT(*) as ore_dati
FROM produzione_oraria p
JOIN impianti i ON p.impianto_id = i.id
GROUP BY DATE(timestamp), impianto_id, i.nome_impianto, i.potenza_nominale_kw;

– Vista consumo giornaliero per membro
CREATE VIEW v_consumo_giornaliero AS
SELECT
DATE(timestamp) as data,
membro_id,
m.codice_membro,
m.nome,
m.tipo_membro,
SUM(energia_consumata_kwh) as consumo_kwh,
SUM(energia_prelevata_kwh) as prelevata_kwh,
COUNT(*) as ore_dati
FROM consumo_orario c
JOIN membri m ON c.membro_id = m.id
GROUP BY DATE(timestamp), membro_id, m.codice_membro, m.nome, m.tipo_membro;

– Vista dashboard CER (dati aggregati)
CREATE VIEW v_dashboard_cer AS
SELECT
DATE(ec.timestamp) as data,
SUM(ec.produzione_totale_kwh) as produzione_giornaliera_kwh,
SUM(ec.consumo_totale_kwh) as consumo_giornaliero_kwh,
SUM(ec.energia_condivisa_kwh) as energia_condivisa_kwh,
ROUND(AVG(ec.percentuale_autoconsumo), 2) as autoconsumo_medio_perc,
SUM(ec.valore_incentivo_euro) as incentivi_giornalieri_euro,
AVG(ec.numero_membri_attivi) as membri_attivi_medio
FROM energia_condivisa_oraria ec
GROUP BY DATE(ec.timestamp);

– Vista classifica membri più virtuosi
CREATE VIEW v_classifica_membri AS
SELECT
m.codice_membro,
m.nome,
m.tipo_membro,
COUNT(DISTINCT DATE(r.timestamp)) as giorni_attivi,
SUM(r.energia_condivisa_membro_kwh) as energia_condivisa_totale_kwh,
SUM(r.incentivo_spettante_euro) as incentivi_totali_euro,
ROUND(AVG(r.percentuale_contributo), 2) as contributo_medio_perc
FROM membri m
LEFT JOIN ripartizione_oraria r ON m.id = r.membro_id
WHERE m.attivo = true
GROUP BY m.id, m.codice_membro, m.nome, m.tipo_membro
ORDER BY energia_condivisa_totale_kwh DESC;

– =====================================================
– FUNZIONI STORED PROCEDURES
– =====================================================

– Funzione calcolo energia condivisa (algoritmo GSE)
CREATE OR REPLACE FUNCTION calcola_energia_condivisa(
p_timestamp TIMESTAMPTZ
) RETURNS DECIMAL AS $$
DECLARE
v_produzione DECIMAL;
v_consumo DECIMAL;
v_condivisa DECIMAL;
BEGIN
– Somma produzione totale nell’ora
SELECT COALESCE(SUM(energia_prodotta_kwh), 0) INTO v_produzione
FROM produzione_oraria
WHERE timestamp = p_timestamp;

```
-- Somma consumo totale nell'ora
SELECT COALESCE(SUM(energia_consumata_kwh), 0) INTO v_consumo
FROM consumo_orario
WHERE timestamp = p_timestamp;

-- Energia condivisa = minimo tra produzione e consumo
v_condivisa := LEAST(v_produzione, v_consumo);

RETURN v_condivisa;
```

END;
$$ LANGUAGE plpgsql;

– Funzione ripartizione incentivi
CREATE OR REPLACE FUNCTION ripartisci_incentivi_orari(
p_timestamp TIMESTAMPTZ
) RETURNS VOID AS $$
DECLARE
v_energia_condivisa DECIMAL;
v_tariffa DECIMAL;
v_incentivo_totale DECIMAL;
r_membro RECORD;
BEGIN
– Recupera energia condivisa e tariffa
SELECT energia_condivisa_kwh, tariffa_incentivo_euro_kwh
INTO v_energia_condivisa, v_tariffa
FROM energia_condivisa_oraria
WHERE timestamp = p_timestamp;

```
v_incentivo_totale := v_energia_condivisa * v_tariffa;

-- Ripartizione proporzionale per produttori e consumatori
FOR r_membro IN 
    SELECT DISTINCT m.id, m.percentuale_ripartizione
    FROM membri m
    WHERE m.attivo = true
LOOP
    INSERT INTO ripartizione_oraria (
        timestamp,
        membro_id,
        energia_condivisa_membro_kwh,
        incentivo_spettante_euro
    ) VALUES (
        p_timestamp,
        r_membro.id,
        v_energia_condivisa * (r_membro.percentuale_ripartizione / 100),
        v_incentivo_totale * (r_membro.percentuale_ripartizione / 100)
    ) ON CONFLICT (timestamp, membro_id) DO UPDATE
    SET energia_condivisa_membro_kwh = EXCLUDED.energia_condivisa_membro_kwh,
        incentivo_spettante_euro = EXCLUDED.incentivo_spettante_euro;
END LOOP;
```

END;
$$ LANGUAGE plpgsql;

– =====================================================
– INDICI PER PERFORMANCE
– =====================================================

CREATE INDEX idx_produzione_impianto ON produzione_oraria(impianto_id, timestamp DESC);
CREATE INDEX idx_consumo_membro ON consumo_orario(membro_id, timestamp DESC);
CREATE INDEX idx_membri_attivi ON membri(attivo) WHERE attivo = true;
CREATE INDEX idx_impianti_attivi ON impianti(attivo) WHERE attivo = true;

– =====================================================
– POLITICHE DI RETENTION (TimescaleDB)
– =====================================================

– Mantieni dati orari per 2 anni, poi aggrega
SELECT add_retention_policy(‘produzione_oraria’, INTERVAL ‘2 years’);
SELECT add_retention_policy(‘consumo_orario’, INTERVAL ‘2 years’);

– Continuous aggregates per performance query
CREATE MATERIALIZED VIEW produzione_giornaliera_agg
WITH (timescaledb.continuous) AS
SELECT
time_bucket(‘1 day’, timestamp) AS giorno,
impianto_id,
SUM(energia_prodotta_kwh) as produzione_kwh,
AVG(efficienza_percentuale) as efficienza_media
FROM produzione_oraria
GROUP BY giorno, impianto_id;

SELECT add_continuous_aggregate_policy(‘produzione_giornaliera_agg’,
start_offset => INTERVAL ‘3 days’,
end_offset => INTERVAL ‘1 hour’,
schedule_interval => INTERVAL ‘1 hour’);
