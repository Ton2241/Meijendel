-- Bronoverstijgende beoordeling van ecologische gegevensreeksen.
-- Deze laag bevat uitsluitend verwijzingen en beslisregels; waarnemingen
-- blijven in hun oorspronkelijke brontabellen staan.

USE Meijendel;

CREATE TABLE IF NOT EXISTS analyse_type (
  analyse_type_code ENUM('V','I','TV','TA','TK') NOT NULL,
  naam VARCHAR(128) NOT NULL,
  omschrijving VARCHAR(1000) NOT NULL,
  PRIMARY KEY (analyse_type_code),
  UNIQUE KEY uq_analyse_type_naam (naam)
) ENGINE=InnoDB;

INSERT INTO analyse_type (analyse_type_code, naam, omschrijving) VALUES
  ('V', 'Voorkomen en verspreiding',
   'Waar en wanneer een taxon is geregistreerd; een ontbrekende melding is geen afwezigheid.'),
  ('I', 'Inventarisatie',
   'Samenstelling binnen een aantoonbaar volledig onderzocht bezoek, monster of gebied.'),
  ('TV', 'Trend in verspreiding',
   'Verandering in bezetting of geregistreerde verspreiding binnen herhaald en vergelijkbaar onderzochte eenheden.'),
  ('TA', 'Trend in aantallen',
   'Verandering in aantallen, dichtheid of een aantalsindex bij bekende en vergelijkbare telinspanning.'),
  ('TK', 'Trend in kwaliteit',
   'Verandering in een vastgelegde ecologische kwaliteitsmaat, zoals bedekking, soortensamenstelling of habitatkwaliteit.')
ON DUPLICATE KEY UPDATE
  naam=VALUES(naam),
  omschrijving=VALUES(omschrijving);

CREATE TABLE IF NOT EXISTS analyse_datareeks (
  datareeks_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  datareeks_sleutel VARCHAR(128) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(500) NOT NULL,
  bronorganisatie VARCHAR(500) NOT NULL,
  bronstatus ENUM('primaire_bron','secundaire_bron','contextbron') NOT NULL,
  bron_schema VARCHAR(64) CHARACTER SET ascii NOT NULL DEFAULT 'Meijendel',
  bron_object VARCHAR(128) CHARACTER SET ascii NOT NULL,
  bronselectie_omschrijving TEXT NOT NULL,
  korrel VARCHAR(500) NOT NULL,
  soortgroep VARCHAR(255) NULL,
  jaar_van SMALLINT UNSIGNED NULL,
  jaar_tot SMALLINT UNSIGNED NULL,
  recordaantal_bij_beoordeling BIGINT UNSIGNED NULL,
  classificatiebron ENUM('generiek','ndff_v4') NOT NULL DEFAULT 'generiek',
  ruimtelijke_status ENUM(
    'exact_of_eenduidig','bruikbaar_met_beperking','onzekerheidspolygoon',
    'gedeeltelijk_geolokaliseerd','niet_geolokaliseerd'
  ) NOT NULL,
  bezoekstructuur_status ENUM(
    'volledig','gedeeltelijk','gereconstrueerd','ontbreekt','niet_van_toepassing'
  ) NOT NULL,
  nulwaarneming_status ENUM(
    'expliciet','betrouwbaar_afleidbaar','gedeeltelijk_afleidbaar','ontbreekt',
    'niet_van_toepassing'
  ) NOT NULL,
  methode_status ENUM(
    'volledig','gedeeltelijk','alleen_protocol_bekend','onbekend','niet_van_toepassing'
  ) NOT NULL,
  validatie_status ENUM(
    'gevalideerd','gedeeltelijk_gevalideerd','bronvalidatie_overgenomen','niet_gevalideerd'
  ) NOT NULL,
  beveiligingsniveau ENUM('openbaar','intern','beveiligd') NOT NULL,
  kwaliteitsmelding TEXT NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  beoordeeld_op DATE NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  bijgewerkt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (datareeks_id),
  UNIQUE KEY uq_analyse_datareeks_sleutel (datareeks_sleutel),
  KEY ix_analyse_datareeks_bron (bron_schema, bron_object),
  KEY ix_analyse_datareeks_classificatie (classificatiebron, bronstatus),
  CHECK (jaar_tot IS NULL OR jaar_van IS NULL OR jaar_tot >= jaar_van)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analyse_datareeks_geschiktheid (
  datareeks_geschiktheid_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  datareeks_id BIGINT UNSIGNED NOT NULL,
  analyse_type_code ENUM('V','I','TV','TA','TK') NOT NULL,
  protocolgeschiktheid ENUM('primair','voorwaardelijk','niet_onderbouwd') NOT NULL,
  gegevensgeschiktheid ENUM('geschikt','voorwaardelijk','onvoldoende','niet_beoordeeld') NOT NULL,
  eindbesluit ENUM(
    'toegelaten','voorlopig_toegelaten','alleen_context','niet_toegelaten'
  ) NOT NULL,
  voorwaarden TEXT NULL,
  kwaliteitsmelding TEXT NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  beoordeeld_op DATE NOT NULL,
  PRIMARY KEY (datareeks_geschiktheid_id),
  UNIQUE KEY uq_analyse_datareeks_geschiktheid
    (datareeks_id, analyse_type_code, regelversie),
  KEY ix_analyse_geschiktheid_selectie
    (analyse_type_code, eindbesluit, regelversie),
  CONSTRAINT fk_analyse_geschiktheid_datareeks FOREIGN KEY (datareeks_id)
    REFERENCES analyse_datareeks (datareeks_id) ON DELETE CASCADE,
  CONSTRAINT fk_analyse_geschiktheid_type FOREIGN KEY (analyse_type_code)
    REFERENCES analyse_type (analyse_type_code)
) ENGINE=InnoDB;

-- Uitsluitend voor records die afwijken van het besluit voor hun gegevensreeks.
-- De bronrecord_sleutel verwijst naar het oorspronkelijke record; er worden
-- geen soortnamen, aantallen, datums of geometrieën gekopieerd.
CREATE TABLE IF NOT EXISTS analyse_recorduitzondering (
  recorduitzondering_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  datareeks_id BIGINT UNSIGNED NOT NULL,
  bronrecord_sleutel VARCHAR(512) NOT NULL,
  analyse_type_code ENUM('V','I','TV','TA','TK') NOT NULL,
  gegevensgeschiktheid ENUM('geschikt','voorwaardelijk','onvoldoende','niet_beoordeeld') NOT NULL,
  eindbesluit ENUM(
    'toegelaten','voorlopig_toegelaten','alleen_context','niet_toegelaten'
  ) NOT NULL,
  reden VARCHAR(1000) NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  beoordeeld_op DATE NOT NULL,
  PRIMARY KEY (recorduitzondering_id),
  UNIQUE KEY uq_analyse_recorduitzondering
    (datareeks_id, bronrecord_sleutel, analyse_type_code, regelversie),
  KEY ix_analyse_recorduitzondering_selectie
    (datareeks_id, analyse_type_code, eindbesluit),
  CONSTRAINT fk_analyse_recorduitzondering_datareeks FOREIGN KEY (datareeks_id)
    REFERENCES analyse_datareeks (datareeks_id) ON DELETE CASCADE,
  CONSTRAINT fk_analyse_recorduitzondering_type FOREIGN KEY (analyse_type_code)
    REFERENCES analyse_type (analyse_type_code)
) ENGINE=InnoDB;

-- Eén menselijk leesbare ingang. Voor NDFF worden de bestaande actuele
-- protocolbesluiten rechtstreeks geprojecteerd; zij worden niet gekopieerd.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_analyse_catalogus AS
SELECT
  d.datareeks_sleutel,
  CAST(NULL AS CHAR(512)) AS deelreeks_sleutel,
  d.naam AS datareeks_naam,
  CAST(NULL AS CHAR(1000)) AS deelreeks_naam,
  d.bronorganisatie,
  d.bronstatus,
  d.bron_schema,
  d.bron_object,
  d.bronselectie_omschrijving,
  d.korrel,
  d.soortgroep,
  d.jaar_van,
  d.jaar_tot,
  d.recordaantal_bij_beoordeling,
  g.analyse_type_code,
  t.naam AS analyse_type_naam,
  g.protocolgeschiktheid,
  g.gegevensgeschiktheid,
  g.eindbesluit,
  g.voorwaarden,
  d.ruimtelijke_status,
  d.bezoekstructuur_status,
  d.nulwaarneming_status,
  d.methode_status,
  d.validatie_status,
  d.beveiligingsniveau,
  CONCAT_WS(' ', d.kwaliteitsmelding, g.kwaliteitsmelding) AS kwaliteitsmelding,
  g.regelversie,
  g.beoordeeld_op
FROM analyse_datareeks d
JOIN analyse_datareeks_geschiktheid g ON g.datareeks_id=d.datareeks_id
JOIN analyse_type t ON t.analyse_type_code=g.analyse_type_code
WHERE d.classificatiebron='generiek'

UNION ALL

SELECT
  d.datareeks_sleutel,
  CONCAT(n.bron_scope, ':', n.soortgroep_raw, ':', p.protocol_sleutel) AS deelreeks_sleutel,
  d.naam AS datareeks_naam,
  CONCAT(n.soortgroep_raw, ' — ', p.protocol_naam) AS deelreeks_naam,
  d.bronorganisatie,
  d.bronstatus,
  d.bron_schema,
  d.bron_object,
  d.bronselectie_omschrijving,
  'protocol × soortgroep × leveringsscope' AS korrel,
  n.soortgroep_raw AS soortgroep,
  d.jaar_van,
  d.jaar_tot,
  n.recordaantal_bij_besluit AS recordaantal_bij_beoordeling,
  n.analysetype AS analyse_type_code,
  t.naam AS analyse_type_naam,
  n.protocolgeschiktheid,
  n.gegevensgeschiktheid,
  CASE n.eindbesluit
    WHEN 'toegelaten' THEN 'toegelaten'
    WHEN 'voorlopig_toegelaten' THEN 'voorlopig_toegelaten'
    WHEN 'alleen_verspreidingscontext' THEN 'alleen_context'
    WHEN 'alleen_na_doelsoortselectie' THEN 'voorlopig_toegelaten'
    ELSE 'niet_toegelaten'
  END AS eindbesluit,
  n.reden AS voorwaarden,
  d.ruimtelijke_status,
  d.bezoekstructuur_status,
  d.nulwaarneming_status,
  d.methode_status,
  d.validatie_status,
  d.beveiligingsniveau,
  CONCAT_WS(' ', d.kwaliteitsmelding, n.reden) AS kwaliteitsmelding,
  n.regelversie,
  n.besloten_op AS beoordeeld_op
FROM analyse_datareeks d
JOIN v_ndff_analysebesluit_actueel n ON d.classificatiebron='ndff_v4'
JOIN ndff_protocol p ON p.protocol_id=n.protocol_id
JOIN analyse_type t ON t.analyse_type_code=n.analysetype;

-- Compact overzicht: per reeks en analysetype één strengste samenvatting.
-- Detailselecties blijven via v_analyse_catalogus beschikbaar.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_analyse_selectieadvies AS
SELECT
  datareeks_sleutel,
  datareeks_naam,
  bronorganisatie,
  analyse_type_code,
  CASE
    WHEN SUM(eindbesluit='toegelaten') > 0 THEN 'toegelaten'
    WHEN SUM(eindbesluit='voorlopig_toegelaten') > 0 THEN 'voorlopig_toegelaten'
    WHEN SUM(eindbesluit='alleen_context') > 0 THEN 'alleen_context'
    ELSE 'niet_toegelaten'
  END AS beste_beschikbare_status,
  COUNT(*) AS onderliggende_besluiten,
  MAX(beoordeeld_op) AS laatst_beoordeeld_op
FROM v_analyse_catalogus
GROUP BY
  datareeks_sleutel, datareeks_naam, bronorganisatie, analyse_type_code;
