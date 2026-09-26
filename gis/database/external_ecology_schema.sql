USE Meijendel;

CREATE TABLE IF NOT EXISTS externe_ecologie_dataset (
  dataset_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dataset_sleutel VARCHAR(128) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  bronorganisatie VARCHAR(500) NOT NULL,
  doi VARCHAR(255) CHARACTER SET ascii NULL,
  licentie VARCHAR(255) NULL,
  bronbestand_naam VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bronversie VARCHAR(128) NULL,
  selectie_omschrijving TEXT NOT NULL,
  importversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (dataset_id),
  UNIQUE KEY uq_externe_ecologie_dataset_sleutel (dataset_sleutel),
  UNIQUE KEY uq_externe_ecologie_bronhash (dataset_sleutel, bronbestand_sha256),
  CHECK (bronbestand_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (doi IS NULL OR doi NOT LIKE 'http%')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS externe_ecologie_event (
  event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dataset_id BIGINT UNSIGNED NOT NULL,
  bron_event_id VARCHAR(512) NOT NULL,
  event_datum DATE NULL,
  event_datum_tot DATE NULL,
  datum_precisie ENUM('exact','interval','maand','jaar','onbekend') NOT NULL,
  jaar SMALLINT UNSIGNED NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  coordinate_uncertainty_m DECIMAL(12,2) NULL,
  bron_locatie VARCHAR(1000) NULL,
  ruimtelijke_klasse ENUM(
    'exact_punt',
    'punt_binnen_50m',
    'meijendel_gebiedslabel',
    'volledig_binnen_basisgebied'
  ) NOT NULL,
  sampling_protocol VARCHAR(1000) NULL,
  inspanning_waarde DECIMAL(18,6) NULL,
  inspanning_eenheid VARCHAR(128) NULL,
  analyse_status ENUM(
    'volledig_bezoek',
    'positieve_resultaten_alleen',
    'collectiecontext',
    'geen_resultaatmatrix'
  ) NOT NULL,
  bronmetadata JSON NOT NULL,
  PRIMARY KEY (event_id),
  UNIQUE KEY uq_externe_ecologie_event (dataset_id, bron_event_id),
  KEY ix_externe_ecologie_event_datum (event_datum),
  KEY ix_externe_ecologie_event_ruimtelijk (ruimtelijke_klasse, analyse_status),
  CONSTRAINT fk_externe_ecologie_event_dataset FOREIGN KEY (dataset_id)
    REFERENCES externe_ecologie_dataset (dataset_id) ON DELETE CASCADE,
  CHECK (json_valid(bronmetadata)),
  CHECK (jaar IS NULL OR jaar BETWEEN 1800 AND 2100),
  CHECK (event_datum_tot IS NULL OR event_datum IS NULL OR event_datum_tot >= event_datum),
  CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS externe_ecologie_resultaat (
  resultaat_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id BIGINT UNSIGNED NOT NULL,
  bron_occurrence_id VARCHAR(512) NOT NULL,
  wetenschappelijke_naam VARCHAR(500) NOT NULL,
  wetenschappelijke_naam_bron VARCHAR(500) NOT NULL,
  nederlandse_naam VARCHAR(500) NULL,
  taxonrang VARCHAR(128) NULL,
  occurrence_status ENUM('present','absent') NOT NULL,
  hoeveelheid DECIMAL(24,8) NULL,
  hoeveelheid_oorspronkelijk VARCHAR(255) NULL,
  hoeveelheid_eenheid VARCHAR(128) NULL,
  basis_of_record VARCHAR(128) NULL,
  catalogusnummer VARCHAR(255) NULL,
  bronmetadata JSON NOT NULL,
  PRIMARY KEY (resultaat_id),
  UNIQUE KEY uq_externe_ecologie_resultaat (event_id, bron_occurrence_id),
  KEY ix_externe_ecologie_resultaat_taxon (wetenschappelijke_naam),
  KEY ix_externe_ecologie_resultaat_status (occurrence_status),
  CONSTRAINT fk_externe_ecologie_resultaat_event FOREIGN KEY (event_id)
    REFERENCES externe_ecologie_event (event_id) ON DELETE CASCADE,
  CHECK (json_valid(bronmetadata))
) ENGINE=InnoDB;

SET @external_name_migration = IF(
  EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema=DATABASE()
      AND table_name='externe_ecologie_resultaat'
      AND column_name='wetenschappelijke_naam_bron'
  ),
  'SELECT 1',
  'ALTER TABLE externe_ecologie_resultaat ADD COLUMN wetenschappelijke_naam_bron VARCHAR(500) NOT NULL DEFAULT '''' AFTER wetenschappelijke_naam'
);
PREPARE external_name_stmt FROM @external_name_migration;
EXECUTE external_name_stmt;
DEALLOCATE PREPARE external_name_stmt;

CREATE TABLE IF NOT EXISTS externe_ecologie_overlap (
  overlap_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  resultaat_id BIGINT UNSIGNED NOT NULL,
  doelsysteem ENUM('ndff','provinciale_pq','duinvallei','andere_externe_bron') NOT NULL,
  doelrecord_sleutel VARCHAR(384) NOT NULL,
  koppelmethode VARCHAR(128) NOT NULL,
  zekerheid ENUM('exact','waarschijnlijk','mogelijk') NOT NULL,
  toelichting TEXT NULL,
  PRIMARY KEY (overlap_id),
  UNIQUE KEY uq_externe_ecologie_overlap (
    resultaat_id, doelsysteem, doelrecord_sleutel, koppelmethode
  ),
  KEY ix_externe_ecologie_overlap_doel (doelsysteem, zekerheid),
  CONSTRAINT fk_externe_ecologie_overlap_resultaat FOREIGN KEY (resultaat_id)
    REFERENCES externe_ecologie_resultaat (resultaat_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_externe_ecologie_analyse AS
SELECT
  d.dataset_sleutel,
  d.titel AS dataset_titel,
  e.event_id,
  e.bron_event_id,
  e.event_datum,
  e.event_datum_tot,
  e.datum_precisie,
  e.jaar,
  e.latitude,
  e.longitude,
  e.coordinate_uncertainty_m,
  e.bron_locatie,
  e.ruimtelijke_klasse,
  e.sampling_protocol,
  e.inspanning_waarde,
  e.inspanning_eenheid,
  e.analyse_status,
  r.resultaat_id,
  r.bron_occurrence_id,
  r.wetenschappelijke_naam,
  r.wetenschappelijke_naam_bron,
  r.nederlandse_naam,
  r.taxonrang,
  r.occurrence_status,
  r.hoeveelheid,
  r.hoeveelheid_oorspronkelijk,
  r.hoeveelheid_eenheid,
  EXISTS (
    SELECT 1
    FROM externe_ecologie_overlap o
    WHERE o.resultaat_id = r.resultaat_id
      AND o.zekerheid IN ('exact','waarschijnlijk')
  ) AS heeft_bekende_overlap
FROM externe_ecologie_dataset d
JOIN externe_ecologie_event e ON e.dataset_id = d.dataset_id
JOIN externe_ecologie_resultaat r ON r.event_id = e.event_id;
