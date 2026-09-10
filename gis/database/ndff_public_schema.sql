-- Openbare externe natuurdata voor lokale opname in de life-database.
-- Bestaande vogel- en provinciale PQ-tabellen worden niet gewijzigd.
-- Beveiligde NDFF-locaties horen uitsluitend in Meijendel_ndff_secure.

USE Meijendel;

CREATE TABLE IF NOT EXISTS ndff_open_import_batch (
  batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bronbestand VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bouwversie VARCHAR(32) NOT NULL,
  periode_start SMALLINT UNSIGNED NOT NULL,
  periode_einde SMALLINT UNSIGNED NOT NULL,
  recordaantal BIGINT UNSIGNED NOT NULL,
  taxonaantal BIGINT UNSIGNED NOT NULL,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  bronstatus ENUM('openbaar','vervallen') NOT NULL DEFAULT 'openbaar',
  opmerkingen TEXT NULL,
  PRIMARY KEY (batch_id),
  UNIQUE KEY uq_ndff_open_batch_hash (bronbestand_sha256),
  CHECK (periode_start = 1950),
  CHECK (periode_einde = 2025)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_soorten (
  ndff_soort_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  soort_key CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  nederlandse_naam VARCHAR(500) NULL,
  wetenschappelijke_naam VARCHAR(500) NULL,
  waarneming_aantal_bron BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (ndff_soort_id),
  UNIQUE KEY uq_ndff_soort_key (soort_key),
  KEY ix_ndff_soort_wetenschappelijk (wetenschappelijke_naam),
  KEY ix_ndff_soort_groep (soortgroep_raw)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_open_waarneming (
  waarneming_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  staging_fid BIGINT NOT NULL,
  identiteit VARCHAR(1024) NOT NULL,
  identiteit_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  soort_key CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  nederlandse_naam VARCHAR(500) NULL,
  wetenschappelijke_naam VARCHAR(500) NULL,
  periode_start DATETIME NULL,
  periode_stop DATETIME NULL,
  jaar SMALLINT UNSIGNED NULL,
  vervaging_raw VARCHAR(255) NULL,
  vervaagd TINYINT(1) NOT NULL,
  vervagingsniveau_km SMALLINT UNSIGNED NULL,
  hoknummer VARCHAR(64) NULL,
  hok_grootte VARCHAR(64) NULL,
  telonderwerp VARCHAR(500) NULL,
  beleidsstatus VARCHAR(500) NULL,
  aantal_raw VARCHAR(255) NULL,
  schaal_telmethode VARCHAR(500) NULL,
  bronhouder VARCHAR(500) NULL,
  protocol VARCHAR(500) NULL,
  stadium VARCHAR(255) NULL,
  sekse VARCHAR(255) NULL,
  gedrag VARCHAR(500) NULL,
  doodsoorzaak VARCHAR(500) NULL,
  determinatiemethode VARCHAR(500) NULL,
  zoek_of_vangmethode VARCHAR(500) NULL,
  apparatuur VARCHAR(500) NULL,
  oorsprong VARCHAR(500) NULL,
  biotoop VARCHAR(500) NULL,
  substraat VARCHAR(500) NULL,
  verblijfplaats VARCHAR(500) NULL,
  ontdubbel_sleutel VARCHAR(128) NOT NULL,
  bronbestand_eerste VARCHAR(500) NOT NULL,
  bronbestand_aantal INT UNSIGNED NOT NULL,
  bronrecord_aantal INT UNSIGNED NOT NULL,
  payload_conflict TINYINT(1) NOT NULL,
  bouwversie VARCHAR(32) NOT NULL,
  openbare_geometrie GEOMETRY NOT NULL SRID 28992,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  analyse_status ENUM('bronregistratie_niet_toegelaten','verspreidingscontext_toegelaten','uitgesloten') NOT NULL DEFAULT 'bronregistratie_niet_toegelaten',
  pq_status ENUM('niet_beoordeeld','exact','waarschijnlijk_dezelfde_opname','mogelijk','onafhankelijk','niet_beoordeelbaar','niet_van_toepassing') NOT NULL DEFAULT 'niet_beoordeeld',
  raw_payload JSON NOT NULL,
  PRIMARY KEY (waarneming_id),
  UNIQUE KEY uq_ndff_open_identity_hash (identiteit_sha256),
  UNIQUE KEY uq_ndff_open_staging_fid (batch_id, staging_fid),
  KEY ix_ndff_open_soort_datum (soort_key, periode_start),
  KEY ix_ndff_open_groep_jaar (soortgroep_raw, jaar),
  KEY ix_ndff_open_analysepoort (analyse_status, pq_status),
  SPATIAL KEY sx_ndff_open_geometrie (openbare_geometrie),
  CONSTRAINT fk_ndff_open_batch FOREIGN KEY (batch_id)
    REFERENCES ndff_open_import_batch (batch_id),
  CONSTRAINT fk_ndff_open_soort FOREIGN KEY (soort_key)
    REFERENCES ndff_soorten (soort_key),
  CHECK (vervaagd IN (0,1)),
  CHECK (payload_conflict IN (0,1)),
  CHECK (periode_stop IS NULL OR periode_start IS NULL OR periode_stop >= periode_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_open_soortgroep_koppeling (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  soortgroep_code VARCHAR(64) NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  PRIMARY KEY (waarneming_id, soortgroep_code),
  KEY ix_ndff_open_groep_code (soortgroep_code),
  CONSTRAINT fk_ndff_open_groep_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_open_waarneming (waarneming_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_soortgroep_template (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (waarneming_id),
  CONSTRAINT fk_ndff_soortgroep_template FOREIGN KEY (waarneming_id)
    REFERENCES ndff_open_waarneming (waarneming_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_amfibieen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_dagvlinders LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_eencelligen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_geleedpotigen_overig LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_insecten_overig LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_kevers LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_korstmossen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_kranswieren_wieren_algen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_kreeftachtigen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_libellen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_microvlinders LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_mossen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_nachtvlinders LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_ongewervelden_overig LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_reptielen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_schimmels LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_snavelinsecten LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_spinachtigen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_sprinkhanen_en_krekels LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_vaatplanten LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_vissen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_vleermuizen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_vliegen_en_muggen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_vliesvleugeligen LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_weekdieren LIKE ndff_soortgroep_template;
CREATE TABLE IF NOT EXISTS ndff_zoogdieren_overig LIKE ndff_soortgroep_template;

DROP TABLE IF EXISTS ndff_soortgroep_template;

CREATE TABLE IF NOT EXISTS vangblik_import_batch (
  batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dataset_titel VARCHAR(500) NOT NULL,
  dataset_versie VARCHAR(64) NOT NULL,
  dataset_doi VARCHAR(128) NOT NULL,
  licentie VARCHAR(64) NOT NULL DEFAULT 'CC BY-NC 4.0',
  eventbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  occurrencebestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  eventaantal BIGINT UNSIGNED NOT NULL,
  occurrenceaantal BIGINT UNSIGNED NOT NULL,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id),
  UNIQUE KEY uq_vangblik_batch_hashes (eventbestand_sha256, occurrencebestand_sha256),
  CHECK (licentie = 'CC BY-NC 4.0')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vangblik_locatieversie (
  locatieversie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  location_id VARCHAR(64) NOT NULL,
  verbatim_x_rd INT NOT NULL,
  verbatim_y_rd INT NOT NULL,
  decimal_latitude DECIMAL(10,7) NOT NULL,
  decimal_longitude DECIMAL(10,7) NOT NULL,
  onzekerheid_meter DECIMAL(10,2) NOT NULL,
  geldig_vanaf DATE NOT NULL,
  geldig_tot_en_met DATE NOT NULL,
  locatiepunt POINT NOT NULL SRID 28992,
  is_verplaatst_blok_7_18 TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (locatieversie_id),
  UNIQUE KEY uq_vangblik_locatieversie (batch_id, location_id, verbatim_x_rd, verbatim_y_rd),
  SPATIAL KEY sx_vangblik_locatiepunt (locatiepunt),
  CONSTRAINT fk_vangblik_locatie_batch FOREIGN KEY (batch_id)
    REFERENCES vangblik_import_batch (batch_id),
  CHECK (is_verplaatst_blok_7_18 IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vangblik_event (
  event_id VARCHAR(255) NOT NULL,
  batch_id BIGINT UNSIGNED NOT NULL,
  locatieversie_id BIGINT UNSIGNED NOT NULL,
  eventdatum DATE NOT NULL,
  start_day_of_year SMALLINT UNSIGNED NULL,
  sampling_protocol VARCHAR(128) NOT NULL,
  sample_size_value DECIMAL(10,2) NOT NULL,
  sample_size_unit VARCHAR(64) NOT NULL,
  sampling_effort VARCHAR(255) NULL,
  event_remarks TEXT NULL,
  owner_institution_code VARCHAR(500) NULL,
  country VARCHAR(128) NULL,
  country_code CHAR(2) NULL,
  locality VARCHAR(255) NULL,
  geodetic_datum VARCHAR(64) NULL,
  is_vergelijkingsblik_1959 TINYINT(1) NOT NULL DEFAULT 0,
  heeft_predatie_of_zoogdierrisico TINYINT(1) NOT NULL DEFAULT 0,
  geen_harde_nul TINYINT(1) NOT NULL DEFAULT 1,
  occurrenceaantal INT UNSIGNED NOT NULL DEFAULT 0,
  raw_payload JSON NOT NULL,
  PRIMARY KEY (event_id),
  KEY ix_vangblik_event_datum (eventdatum),
  KEY ix_vangblik_event_locatie (locatieversie_id, eventdatum),
  CONSTRAINT fk_vangblik_event_batch FOREIGN KEY (batch_id)
    REFERENCES vangblik_import_batch (batch_id),
  CONSTRAINT fk_vangblik_event_locatie FOREIGN KEY (locatieversie_id)
    REFERENCES vangblik_locatieversie (locatieversie_id),
  CHECK (is_vergelijkingsblik_1959 IN (0,1)),
  CHECK (heeft_predatie_of_zoogdierrisico IN (0,1)),
  CHECK (geen_harde_nul = 1)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vangblik_soorten (
  vangblik_soort_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  taxon_key CHAR(64) CHARACTER SET ascii NOT NULL,
  scientific_name VARCHAR(500) NOT NULL,
  kingdom VARCHAR(128) NULL,
  phylum VARCHAR(128) NULL,
  class_name VARCHAR(128) NULL,
  order_name VARCHAR(128) NULL,
  family VARCHAR(255) NULL,
  taxon_rank VARCHAR(64) NULL,
  PRIMARY KEY (vangblik_soort_id),
  UNIQUE KEY uq_vangblik_taxon_key (taxon_key),
  KEY ix_vangblik_scientific_name (scientific_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_sovon_plotversie (
  plotversie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versie VARCHAR(32) NOT NULL,
  bronbestand VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  crs_epsg INT UNSIGNED NOT NULL DEFAULT 28992,
  objectaantal SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (plotversie_id),
  UNIQUE KEY uq_ndff_public_plotversie_hash (bronbestand_sha256),
  CHECK (crs_epsg = 28992)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_sovon_plot (
  plotversie_id BIGINT UNSIGNED NOT NULL,
  plot_id INT NOT NULL,
  sovon_projectid BIGINT NULL,
  plotnummer INT NULL,
  plotnaam VARCHAR(500) NULL,
  bron_oppervlakte_ha DECIMAL(14,6) NULL,
  plot_geometrie GEOMETRY NOT NULL SRID 28992,
  plot_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (plotversie_id, plot_id),
  SPATIAL KEY sx_ndff_public_plot (plot_geometrie),
  CONSTRAINT fk_ndff_public_plotversie FOREIGN KEY (plotversie_id)
    REFERENCES ndff_sovon_plotversie (plotversie_id),
  CONSTRAINT fk_ndff_public_plot_id FOREIGN KEY (plot_id) REFERENCES plots (plot_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vangblik_vangst (
  occurrence_id VARCHAR(500) NOT NULL,
  batch_id BIGINT UNSIGNED NOT NULL,
  event_id VARCHAR(255) NULL,
  bron_event_id VARCHAR(255) NOT NULL,
  vangblik_soort_id BIGINT UNSIGNED NOT NULL,
  owner_institution_code VARCHAR(500) NULL,
  basis_of_record VARCHAR(128) NULL,
  recorded_by VARCHAR(500) NULL,
  individual_count INT UNSIGNED NOT NULL,
  life_stage VARCHAR(128) NULL,
  occurrence_status VARCHAR(64) NULL,
  occurrence_remarks TEXT NULL,
  is_verweesd TINYINT(1) NOT NULL DEFAULT 0,
  referentieel_geldig TINYINT(1) NOT NULL DEFAULT 1,
  minimumvangst_mogelijk TINYINT(1) NOT NULL DEFAULT 1,
  analyse_status ENUM('bronregistratie_niet_toegelaten','historische_verspreidingscontext','uitgesloten') NOT NULL DEFAULT 'bronregistratie_niet_toegelaten',
  raw_payload JSON NOT NULL,
  PRIMARY KEY (occurrence_id),
  KEY ix_vangblik_vangst_event (event_id),
  KEY ix_vangblik_vangst_soort (vangblik_soort_id),
  CONSTRAINT fk_vangblik_vangst_batch FOREIGN KEY (batch_id)
    REFERENCES vangblik_import_batch (batch_id),
  CONSTRAINT fk_vangblik_vangst_event FOREIGN KEY (event_id)
    REFERENCES vangblik_event (event_id),
  CONSTRAINT fk_vangblik_vangst_soort FOREIGN KEY (vangblik_soort_id)
    REFERENCES vangblik_soorten (vangblik_soort_id),
  CHECK (is_verweesd IN (0,1)),
  CHECK (referentieel_geldig IN (0,1)),
  CHECK (minimumvangst_mogelijk = 1),
  CHECK ((is_verweesd = 1 AND event_id IS NULL AND referentieel_geldig = 0) OR
         (is_verweesd = 0 AND event_id IS NOT NULL AND referentieel_geldig = 1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vangblik_event_plot (
  event_id VARCHAR(255) NOT NULL,
  plot_id INT NOT NULL,
  koppelregel_versie VARCHAR(64) NOT NULL,
  is_eenduidig TINYINT(1) NOT NULL,
  PRIMARY KEY (event_id, plot_id),
  CONSTRAINT fk_vangblik_plot_event FOREIGN KEY (event_id)
    REFERENCES vangblik_event (event_id),
  CONSTRAINT fk_vangblik_plot FOREIGN KEY (plot_id) REFERENCES plots (plot_id),
  CHECK (is_eenduidig IN (0,1))
) ENGINE=InnoDB;
