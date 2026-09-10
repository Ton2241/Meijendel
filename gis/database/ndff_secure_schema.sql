-- Voorbereidend schema voor beveiligde NDFF-data, ticket 58679.
-- Het ontvangen GeoPackage is groen gevalideerd; NIET uitvoeren voordat de
-- inhoudelijke toelating per soortgroep en analysetype expliciet is beoordeeld.
-- Dit schema blijft buiten de gewone Meijendel.sql en krijgt geen rechten voor
-- meijendel_read.

CREATE DATABASE IF NOT EXISTS Meijendel_ndff_secure
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE Meijendel_ndff_secure;

CREATE TABLE IF NOT EXISTS ndff_import_batch (
  batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ticketnummer VARCHAR(32) NOT NULL,
  ontvangen_op DATETIME(6) NOT NULL,
  periode_start SMALLINT UNSIGNED NOT NULL,
  periode_einde SMALLINT UNSIGNED NOT NULL,
  origineel_bestand VARCHAR(255) NOT NULL,
  origineel_formaat ENUM('gpkg','zip_shapefile','xlsx','overig') NOT NULL,
  origineel_bestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  manifest_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  standaardcitatie TEXT NOT NULL,
  gebruiksstatus ENUM('ontvangen','gevalideerd','toegelaten','afgesloten','vernietigd') NOT NULL DEFAULT 'ontvangen',
  gevalideerd_op DATETIME(6) NULL,
  vernietigen_uiterlijk DATE NULL,
  vernietigd_op DATETIME(6) NULL,
  opmerkingen TEXT NULL,
  PRIMARY KEY (batch_id),
  UNIQUE KEY uq_ndff_batch_bestand_hash (origineel_bestand_sha256),
  CHECK (periode_start = 1950),
  CHECK (periode_einde = 2025),
  CHECK (vernietigd_op IS NULL OR gebruiksstatus = 'vernietigd')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_soorten (
  ndff_soort_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ndff_taxon_identity VARCHAR(512) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  nederlandse_naam VARCHAR(255) NULL,
  oorspronkelijke_ffv_soortgroep VARCHAR(128) NOT NULL,
  taxon_status VARCHAR(64) NULL,
  kwetsbare_data_status VARCHAR(64) NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (ndff_soort_id),
  UNIQUE KEY uq_ndff_taxon_identity (ndff_taxon_identity),
  KEY ix_ndff_soorten_wetenschappelijk (wetenschappelijke_naam),
  KEY ix_ndff_soorten_groep (oorspronkelijke_ffv_soortgroep)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_waarneming_register (
  waarneming_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  ndff_soort_id BIGINT UNSIGNED NOT NULL,
  ndff_identity VARCHAR(512) NOT NULL,
  open_identity_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bron_record_id BIGINT NULL,
  periode_start DATE NOT NULL,
  periode_stop DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bronhouder VARCHAR(255) NULL,
  validatiestatus VARCHAR(128) NULL,
  protocol VARCHAR(255) NULL,
  bron_locatietype VARCHAR(32) NULL,
  bron_centrum_x_rd INT NULL,
  bron_centrum_y_rd INT NULL,
  bron_oppervlakte_m2 DECIMAL(18,6) NULL,
  publieke_vervaging_raw VARCHAR(128) NULL,
  publieke_vervagingsniveau_km DECIMAL(6,2) NULL,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NULL,
  exacte_geometrie GEOMETRY NOT NULL SRID 28992,
  exacte_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  ruimtelijke_klasse ENUM('nog_niet_bepaald','single','multiple','outside','ongeldig') NOT NULL DEFAULT 'nog_niet_bepaald',
  toewijzingskwaliteit ENUM('nog_niet_bepaald','single_volledig_binnen','single_deels','multiple','outside','ongeldig') NOT NULL DEFAULT 'nog_niet_bepaald',
  plot_match_count SMALLINT UNSIGNED NULL,
  protocol_auditklasse VARCHAR(128) NOT NULL,
  verspreidingscontext_status ENUM('niet_beoordeeld','kandidaat_verspreidingscontext','uitgesloten_ruimtelijk','uitgesloten_pq') NOT NULL DEFAULT 'niet_beoordeeld',
  trend_status ENUM('niet_beoordeeld','trendkandidaat_wacht_op_brondata','niet_trendklaar') NOT NULL DEFAULT 'niet_beoordeeld',
  analyse_poort_versie VARCHAR(64) NOT NULL,
  is_pq_bronrecord TINYINT(1) NOT NULL DEFAULT 0,
  inname_status ENUM('staging','toegelaten','uitgesloten','vernietigd') NOT NULL DEFAULT 'staging',
  inname_reden VARCHAR(255) NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id),
  UNIQUE KEY uq_ndff_identity (ndff_identity),
  UNIQUE KEY uq_ndff_open_identity (open_identity_sha256),
  KEY ix_ndff_register_batch (batch_id),
  KEY ix_ndff_register_soort_datum (ndff_soort_id, periode_start),
  KEY ix_ndff_register_ruimte (ruimtelijke_klasse, inname_status),
  KEY ix_ndff_register_analyse (verspreidingscontext_status, trend_status, jaar),
  SPATIAL KEY sx_ndff_exacte_geometrie (exacte_geometrie),
  CONSTRAINT fk_ndff_register_batch FOREIGN KEY (batch_id)
    REFERENCES ndff_import_batch (batch_id),
  CONSTRAINT fk_ndff_register_soort FOREIGN KEY (ndff_soort_id)
    REFERENCES ndff_soorten (ndff_soort_id),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(periode_start)),
  CHECK (is_pq_bronrecord IN (0,1)),
  CHECK (plot_match_count IS NULL OR
    (ruimtelijke_klasse = 'single' AND plot_match_count = 1) OR
    (ruimtelijke_klasse = 'multiple' AND plot_match_count > 1) OR
    (ruimtelijke_klasse = 'outside' AND plot_match_count = 0) OR
    ruimtelijke_klasse IN ('nog_niet_bepaald','ongeldig'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_waarneming_bron (
  bronrecord_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  batch_id BIGINT UNSIGNED NOT NULL,
  bronbestand VARCHAR(255) NOT NULL,
  bronlaag VARCHAR(255) NULL,
  bron_fid BIGINT NULL,
  bronrecord_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  raw_payload JSON NOT NULL,
  PRIMARY KEY (bronrecord_id),
  UNIQUE KEY uq_ndff_bronrecord (batch_id, bronbestand, bronlaag, bron_fid),
  KEY ix_ndff_bron_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_bron_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id),
  CONSTRAINT fk_ndff_bron_batch FOREIGN KEY (batch_id)
    REFERENCES ndff_import_batch (batch_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_sovon_plotversie (
  plotversie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versie VARCHAR(32) NOT NULL,
  bronbestand VARCHAR(255) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  crs_epsg INT UNSIGNED NOT NULL DEFAULT 28992,
  objectaantal SMALLINT UNSIGNED NOT NULL,
  overlap_plotparen SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATE NOT NULL,
  PRIMARY KEY (plotversie_id),
  UNIQUE KEY uq_ndff_plotversie_hash (bronbestand_sha256),
  CHECK (crs_epsg = 28992)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_sovon_plot (
  plotversie_id BIGINT UNSIGNED NOT NULL,
  plot_id VARCHAR(64) NOT NULL,
  plot_geometrie GEOMETRY NOT NULL SRID 28992,
  plot_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (plotversie_id, plot_id),
  SPATIAL KEY sx_ndff_plot_geometrie (plot_geometrie),
  CONSTRAINT fk_ndff_plot_versie FOREIGN KEY (plotversie_id)
    REFERENCES ndff_sovon_plotversie (plotversie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_waarneming_plot (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  plotversie_id BIGINT UNSIGNED NOT NULL,
  plot_id VARCHAR(64) NOT NULL,
  match_volgnummer SMALLINT UNSIGNED NOT NULL,
  overlap_oppervlak_m2 DECIMAL(16,3) NULL,
  overlap_aandeel DECIMAL(9,8) NULL,
  centroid_binnen TINYINT(1) NULL,
  is_aanwezigheid_per_plot TINYINT(1) NOT NULL DEFAULT 0,
  koppelregel_versie VARCHAR(64) NOT NULL,
  PRIMARY KEY (waarneming_id, plotversie_id, plot_id),
  UNIQUE KEY uq_ndff_plot_match_order (waarneming_id, match_volgnummer),
  CONSTRAINT fk_ndff_wp_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id),
  CONSTRAINT fk_ndff_wp_plot FOREIGN KEY (plotversie_id, plot_id)
    REFERENCES ndff_sovon_plot (plotversie_id, plot_id),
  CHECK (overlap_aandeel IS NULL OR overlap_aandeel BETWEEN 0 AND 1),
  CHECK (is_aanwezigheid_per_plot IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_waarneming_uitsluiting (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  analysetype VARCHAR(64) NOT NULL,
  uitgesloten TINYINT(1) NOT NULL,
  reden_code VARCHAR(64) NOT NULL,
  toelichting VARCHAR(500) NULL,
  beslisregel_versie VARCHAR(64) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL,
  beoordeeld_door VARCHAR(128) NOT NULL,
  PRIMARY KEY (waarneming_id, analysetype, beslisregel_versie),
  CONSTRAINT fk_ndff_uitsluiting_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id),
  CHECK (uitgesloten IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_pq_koppeling (
  ndff_waarneming_id BIGINT UNSIGNED NOT NULL,
  pq_opname_id BIGINT UNSIGNED NULL,
  classificatie ENUM('exact','waarschijnlijk_dezelfde_opname','mogelijk','onafhankelijk','niet_beoordeelbaar','niet_van_toepassing') NOT NULL,
  datum_match TINYINT(1) NULL,
  taxon_match TINYINT(1) NULL,
  afstand_meter DECIMAL(12,3) NULL,
  soortenlijst_overlap DECIMAL(9,8) NULL,
  abundantie_compatibel TINYINT(1) NULL,
  bronhouder_match TINYINT(1) NULL,
  ndff_bronrol ENUM('secundaire_controlebron','niet_van_toepassing') NOT NULL,
  primaire_pq_bron ENUM('provincie_zuid_holland','niet_van_toepassing') NOT NULL,
  beslisregel_versie VARCHAR(64) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL,
  toelichting VARCHAR(500) NULL,
  PRIMARY KEY (ndff_waarneming_id, beslisregel_versie),
  CONSTRAINT fk_ndff_pq_waarneming FOREIGN KEY (ndff_waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id),
  CHECK (soortenlijst_overlap IS NULL OR soortenlijst_overlap BETWEEN 0 AND 1)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_retentie_log (
  retentie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  objecttype ENUM('origineel','afgeleid_bestand','database','tijdelijk','backup') NOT NULL,
  object_locator VARCHAR(500) NOT NULL,
  bevat_beveiligde_data TINYINT(1) NOT NULL,
  geregistreerd_op DATETIME(6) NOT NULL,
  vernietigen_uiterlijk DATE NULL,
  vernietigd_op DATETIME(6) NULL,
  vernietigingsbewijs_sha256 CHAR(64) CHARACTER SET ascii NULL,
  PRIMARY KEY (retentie_id),
  UNIQUE KEY uq_ndff_retentie_object (batch_id, objecttype, object_locator),
  CONSTRAINT fk_ndff_retentie_batch FOREIGN KEY (batch_id)
    REFERENCES ndff_import_batch (batch_id),
  CHECK (bevat_beveiligde_data IN (0,1))
) ENGINE=InnoDB;

-- De koppeling met de openbare bron staat alleen in dit beveiligde schema.
-- open_waarneming_id is bewust geen cross-schema foreign key: het openbare
-- schema blijft zelfstandig herstelbaar en bevat geen verwijzing terug.
CREATE TABLE IF NOT EXISTS ndff_open_secure_koppeling (
  secure_waarneming_id BIGINT UNSIGNED NOT NULL,
  open_identity_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  open_waarneming_id BIGINT UNSIGNED NOT NULL,
  koppelmethode VARCHAR(64) NOT NULL,
  gekoppeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (secure_waarneming_id),
  UNIQUE KEY uq_ndff_secure_open_hash (open_identity_sha256),
  UNIQUE KEY uq_ndff_secure_open_id (open_waarneming_id),
  CONSTRAINT fk_ndff_secure_open_waarneming FOREIGN KEY (secure_waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id)
) ENGINE=InnoDB;

-- Iedere soortgroep krijgt een fysieke tabel met dezelfde controleerbare basis.
-- raw_payload bewaart alleen de groepsspecifieke bronvelden; identiteit,
-- geometrie, taxon, datum en provenance staan in de genormaliseerde kerntabellen.
CREATE TABLE ndff_soortgroep_template (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  aantal_raw VARCHAR(128) NULL,
  telonderwerp VARCHAR(255) NULL,
  schaal_telmethode VARCHAR(255) NULL,
  protocol VARCHAR(255) NULL,
  stadium VARCHAR(128) NULL,
  sekse VARCHAR(64) NULL,
  gedrag VARCHAR(255) NULL,
  determinatiemethode VARCHAR(255) NULL,
  zoek_of_vangmethode VARCHAR(255) NULL,
  apparatuur VARCHAR(255) NULL,
  biotoop VARCHAR(255) NULL,
  substraat VARCHAR(255) NULL,
  verblijfplaats VARCHAR(255) NULL,
  analyse_toelating ENUM('niet_beoordeeld','verspreidingscontext','periodieke_toestand','trendkandidaat','uitgesloten') NOT NULL DEFAULT 'niet_beoordeeld',
  toelatingsregel_versie VARCHAR(64) NULL,
  raw_payload JSON NOT NULL,
  PRIMARY KEY (waarneming_id),
  KEY ix_ndff_groep_protocol (protocol),
  KEY ix_ndff_groep_toelating (analyse_toelating)
) ENGINE=InnoDB;

CREATE TABLE ndff_amfibieen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_dagvlinders LIKE ndff_soortgroep_template;
CREATE TABLE ndff_eencelligen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_geleedpotigen_overig LIKE ndff_soortgroep_template;
CREATE TABLE ndff_insecten_overig LIKE ndff_soortgroep_template;
CREATE TABLE ndff_kevers LIKE ndff_soortgroep_template;
CREATE TABLE ndff_korstmossen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_kranswieren_wieren_algen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_kreeftachtigen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_libellen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_microvlinders LIKE ndff_soortgroep_template;
CREATE TABLE ndff_mossen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_nachtvlinders LIKE ndff_soortgroep_template;
CREATE TABLE ndff_ongewervelden_overig LIKE ndff_soortgroep_template;
CREATE TABLE ndff_reptielen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_schimmels LIKE ndff_soortgroep_template;
CREATE TABLE ndff_snavelinsecten LIKE ndff_soortgroep_template;
CREATE TABLE ndff_spinachtigen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_sprinkhanen_en_krekels LIKE ndff_soortgroep_template;
CREATE TABLE ndff_vaatplanten LIKE ndff_soortgroep_template;
CREATE TABLE ndff_vissen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_vleermuizen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_vliegen_en_muggen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_vliesvleugeligen LIKE ndff_soortgroep_template;
CREATE TABLE ndff_weekdieren LIKE ndff_soortgroep_template;
CREATE TABLE ndff_zoogdieren_overig LIKE ndff_soortgroep_template;

ALTER TABLE ndff_amfibieen ADD CONSTRAINT fk_ndff_amfibieen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_dagvlinders ADD CONSTRAINT fk_ndff_dagvlinders FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_eencelligen ADD CONSTRAINT fk_ndff_eencelligen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_geleedpotigen_overig ADD CONSTRAINT fk_ndff_geleedpotigen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_insecten_overig ADD CONSTRAINT fk_ndff_insecten FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_kevers ADD CONSTRAINT fk_ndff_kevers FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_korstmossen ADD CONSTRAINT fk_ndff_korstmossen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_kranswieren_wieren_algen ADD CONSTRAINT fk_ndff_kranswieren FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_kreeftachtigen ADD CONSTRAINT fk_ndff_kreeftachtigen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_libellen ADD CONSTRAINT fk_ndff_libellen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_microvlinders ADD CONSTRAINT fk_ndff_microvlinders FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_mossen ADD CONSTRAINT fk_ndff_mossen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_nachtvlinders ADD CONSTRAINT fk_ndff_nachtvlinders FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_ongewervelden_overig ADD CONSTRAINT fk_ndff_ongewervelden FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_reptielen ADD CONSTRAINT fk_ndff_reptielen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_schimmels ADD CONSTRAINT fk_ndff_schimmels FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_snavelinsecten ADD CONSTRAINT fk_ndff_snavelinsecten FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_spinachtigen ADD CONSTRAINT fk_ndff_spinachtigen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_sprinkhanen_en_krekels ADD CONSTRAINT fk_ndff_sprinkhanen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_vaatplanten ADD CONSTRAINT fk_ndff_vaatplanten FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_vissen ADD CONSTRAINT fk_ndff_vissen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_vleermuizen ADD CONSTRAINT fk_ndff_vleermuizen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_vliegen_en_muggen ADD CONSTRAINT fk_ndff_vliegen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_vliesvleugeligen ADD CONSTRAINT fk_ndff_vliesvleugeligen FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_weekdieren ADD CONSTRAINT fk_ndff_weekdieren FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);
ALTER TABLE ndff_zoogdieren_overig ADD CONSTRAINT fk_ndff_zoogdieren FOREIGN KEY (waarneming_id) REFERENCES ndff_waarneming_register (waarneming_id);

DROP TABLE ndff_soortgroep_template;

-- Uitsluitend lokaal analyseoverzicht. De view bevat geen dagdatum,
-- geometrie, coördinaten, bronpayload of herleidbare NDFF-identiteit.
CREATE OR REPLACE VIEW v_ndff_lokale_overzicht AS
SELECT
  s.oorspronkelijke_ffv_soortgroep AS soortgroep,
  w.verspreidingscontext_status,
  w.trend_status,
  p.classificatie AS pq_status,
  COUNT(DISTINCT w.waarneming_id) AS positieve_waarnemingen
FROM ndff_waarneming_register AS w
JOIN ndff_soorten AS s
  ON s.ndff_soort_id = w.ndff_soort_id
JOIN ndff_pq_koppeling AS p
  ON p.ndff_waarneming_id = w.waarneming_id
GROUP BY
  s.oorspronkelijke_ffv_soortgroep,
  w.verspreidingscontext_status,
  w.trend_status,
  p.classificatie;

-- Positieve aanwezigheid per plot, jaar en taxon. Dit is nadrukkelijk geen
-- nul-, dichtheids- of trendtabel.
CREATE OR REPLACE VIEW v_ndff_lokale_plot_jaar_taxon AS
SELECT
  wp.plotversie_id,
  wp.plot_id,
  w.jaar,
  w.ndff_soort_id,
  s.oorspronkelijke_ffv_soortgroep AS soortgroep,
  s.wetenschappelijke_naam,
  s.nederlandse_naam,
  w.protocol_auditklasse,
  w.trend_status,
  COUNT(DISTINCT w.waarneming_id) AS positieve_waarnemingen
FROM ndff_waarneming_register AS w
JOIN ndff_waarneming_plot AS wp
  ON wp.waarneming_id = w.waarneming_id
JOIN ndff_soorten AS s
  ON s.ndff_soort_id = w.ndff_soort_id
JOIN ndff_pq_koppeling AS p
  ON p.ndff_waarneming_id = w.waarneming_id
WHERE w.toewijzingskwaliteit = 'single_volledig_binnen'
  AND w.verspreidingscontext_status = 'kandidaat_verspreidingscontext'
  AND p.classificatie IN ('onafhankelijk','niet_van_toepassing')
  AND w.is_pq_bronrecord = 0
  AND wp.is_aanwezigheid_per_plot = 1
GROUP BY
  wp.plotversie_id,
  wp.plot_id,
  w.jaar,
  w.ndff_soort_id,
  s.oorspronkelijke_ffv_soortgroep,
  s.wetenschappelijke_naam,
  s.nederlandse_naam,
  w.protocol_auditklasse,
  w.trend_status;

CREATE OR REPLACE VIEW v_ndff_lokale_protocolstatus AS
SELECT
  s.oorspronkelijke_ffv_soortgroep AS soortgroep,
  w.protocol,
  w.protocol_auditklasse,
  w.verspreidingscontext_status,
  w.trend_status,
  COUNT(DISTINCT w.waarneming_id) AS positieve_waarnemingen
FROM ndff_waarneming_register AS w
JOIN ndff_soorten AS s
  ON s.ndff_soort_id = w.ndff_soort_id
GROUP BY
  s.oorspronkelijke_ffv_soortgroep,
  w.protocol,
  w.protocol_auditklasse,
  w.verspreidingscontext_status,
  w.trend_status;

-- Interne onderzoeksvw: geen exacte geometrie, dagdatum, NDFF-identiteit of
-- bronpayload. Dit is nog geen toestemming voor VPS- of algemene Shiny-toegang.
CREATE OR REPLACE VIEW v_ndff_plot_jaar_taxon_research AS
SELECT
  wp.plotversie_id,
  wp.plot_id,
  YEAR(w.periode_start) AS jaar,
  w.ndff_soort_id,
  s.oorspronkelijke_ffv_soortgroep AS soortgroep,
  s.wetenschappelijke_naam,
  s.nederlandse_naam,
  COUNT(DISTINCT w.waarneming_id) AS positieve_waarnemingen
FROM ndff_waarneming_register AS w
JOIN ndff_waarneming_plot AS wp
  ON wp.waarneming_id = w.waarneming_id
JOIN ndff_soorten AS s
  ON s.ndff_soort_id = w.ndff_soort_id
WHERE w.ruimtelijke_klasse = 'single'
  AND w.inname_status = 'toegelaten'
  AND w.is_pq_bronrecord = 0
  AND wp.is_aanwezigheid_per_plot = 1
GROUP BY
  wp.plotversie_id,
  wp.plot_id,
  YEAR(w.periode_start),
  w.ndff_soort_id,
  s.oorspronkelijke_ffv_soortgroep,
  s.wetenschappelijke_naam,
  s.nederlandse_naam;

-- Rechten worden pas na lokale accountcontrole toegekend. Voorbeeld, niet
-- automatisch uitvoeren:
-- GRANT SELECT, INSERT, UPDATE, DELETE ON Meijendel_ndff_secure.* TO 'ndff_loader';
-- GRANT SELECT ON Meijendel_ndff_secure.v_ndff_plot_jaar_taxon_research TO 'ndff_shiny_read';
-- Geef meijendel_read geen enkel recht op Meijendel_ndff_secure.
