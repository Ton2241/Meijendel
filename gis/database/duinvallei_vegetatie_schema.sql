USE Meijendel;

CREATE TABLE IF NOT EXISTS duinvallei_import_batch (
  batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dataset_titel VARCHAR(500) NOT NULL,
  dataset_doi VARCHAR(128) NOT NULL,
  dataset_publicatiedatum DATE NOT NULL,
  metadata_bestand VARCHAR(255) NOT NULL,
  metadata_bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  matrix_bestand VARCHAR(255) NOT NULL,
  matrix_bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  analysescript_bestand VARCHAR(255) NOT NULL,
  analysescript_bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bronopname_aantal INT UNSIGNED NOT NULL,
  taxon_aantal SMALLINT UNSIGNED NOT NULL,
  importversie VARCHAR(64) NOT NULL,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id),
  UNIQUE KEY uq_duinvallei_batch_bron (
    metadata_bronbestand_sha256,
    matrix_bronbestand_sha256,
    analysescript_bronbestand_sha256
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS duinvallei_plot (
  plot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  site_code VARCHAR(32) NOT NULL,
  locatietype ENUM('KV','PP','LV') NOT NULL,
  omschrijving VARCHAR(255) NOT NULL,
  PRIMARY KEY (plot_id),
  UNIQUE KEY uq_duinvallei_plot (batch_id, site_code),
  CONSTRAINT fk_duinvallei_plot_batch FOREIGN KEY (batch_id)
    REFERENCES duinvallei_import_batch (batch_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS duinvallei_opname (
  opname_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  plot_id BIGINT UNSIGNED NOT NULL,
  bron_opname_id VARCHAR(32) NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  blok_raw VARCHAR(16) NOT NULL,
  plotnummer_raw SMALLINT UNSIGNED NOT NULL,
  grouping_code_raw VARCHAR(64) NOT NULL,
  locatie_raw VARCHAR(64) NOT NULL,
  locatie_genormaliseerd VARCHAR(64) NOT NULL,
  analyse_status ENUM('toegelaten','uitgesloten_bronanomalie') NOT NULL,
  uitsluitingsreden VARCHAR(500) NULL,
  bronmetadata JSON NOT NULL,
  PRIMARY KEY (opname_id),
  UNIQUE KEY uq_duinvallei_opname (batch_id, bron_opname_id),
  KEY ix_duinvallei_opname_plot_jaar (plot_id, jaar),
  CONSTRAINT fk_duinvallei_opname_batch FOREIGN KEY (batch_id)
    REFERENCES duinvallei_import_batch (batch_id),
  CONSTRAINT fk_duinvallei_opname_plot FOREIGN KEY (plot_id)
    REFERENCES duinvallei_plot (plot_id),
  CHECK (
    (analyse_status = 'toegelaten' AND uitsluitingsreden IS NULL) OR
    (analyse_status = 'uitgesloten_bronanomalie' AND uitsluitingsreden IS NOT NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS duinvallei_taxon (
  taxon_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id BIGINT UNSIGNED NOT NULL,
  wetenschappelijke_naam_raw VARCHAR(500) NOT NULL,
  PRIMARY KEY (taxon_id),
  UNIQUE KEY uq_duinvallei_taxon (batch_id, wetenschappelijke_naam_raw),
  CONSTRAINT fk_duinvallei_taxon_batch FOREIGN KEY (batch_id)
    REFERENCES duinvallei_import_batch (batch_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS duinvallei_bedekkingscode (
  bedekkingscode SMALLINT UNSIGNED NOT NULL,
  bronlabel VARCHAR(32) NOT NULL,
  aanwezig TINYINT(1) NOT NULL,
  toelichting VARCHAR(255) NOT NULL,
  PRIMARY KEY (bedekkingscode),
  CHECK (aanwezig IN (0,1))
) ENGINE=InnoDB;

INSERT INTO duinvallei_bedekkingscode
  (bedekkingscode, bronlabel, aanwezig, toelichting)
VALUES
  (0, '0', 0, 'Niet aangetroffen in de volledige soortenmatrix'),
  (1, 'r', 1, 'Gemodificeerde Braun-Blanquetschaal: r'),
  (2, '+', 1, 'Gemodificeerde Braun-Blanquetschaal: +'),
  (3, '1', 1, 'Gemodificeerde Braun-Blanquetschaal: 1'),
  (4, '2m', 1, 'Gemodificeerde Braun-Blanquetschaal: 2m'),
  (6, '2a', 1, 'Gemodificeerde Braun-Blanquetschaal: 2a'),
  (8, '2b', 1, 'Gemodificeerde Braun-Blanquetschaal: 2b'),
  (9, '3', 1, 'Gemodificeerde Braun-Blanquetschaal: 3'),
  (18, '2b/3', 1, 'Tussencode, door bron beschreven als ongeveer 2b/3'),
  (38, '3', 1, 'Tussencode, door bron beschreven als ongeveer 3'),
  (68, '4', 1, 'Tussencode, door bron beschreven als ongeveer 4'),
  (88, '5', 1, 'Tussencode, door bron beschreven als ongeveer 5')
ON DUPLICATE KEY UPDATE
  bronlabel = VALUES(bronlabel),
  aanwezig = VALUES(aanwezig),
  toelichting = VALUES(toelichting);

CREATE TABLE IF NOT EXISTS duinvallei_bedekking (
  opname_id BIGINT UNSIGNED NOT NULL,
  taxon_id BIGINT UNSIGNED NOT NULL,
  bedekkingscode SMALLINT UNSIGNED NOT NULL,
  aanwezig TINYINT(1) NOT NULL,
  PRIMARY KEY (opname_id, taxon_id),
  KEY ix_duinvallei_bedekking_taxon (taxon_id, opname_id),
  CONSTRAINT fk_duinvallei_bedekking_opname FOREIGN KEY (opname_id)
    REFERENCES duinvallei_opname (opname_id),
  CONSTRAINT fk_duinvallei_bedekking_taxon FOREIGN KEY (taxon_id)
    REFERENCES duinvallei_taxon (taxon_id),
  CONSTRAINT fk_duinvallei_bedekking_code FOREIGN KEY (bedekkingscode)
    REFERENCES duinvallei_bedekkingscode (bedekkingscode),
  CHECK (aanwezig IN (0,1)),
  CHECK ((bedekkingscode = 0 AND aanwezig = 0) OR (bedekkingscode > 0 AND aanwezig = 1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS duinvallei_bodemparameter (
  parameter_sleutel VARCHAR(16) NOT NULL,
  parameter_naam VARCHAR(128) NOT NULL,
  eenheid VARCHAR(64) NULL,
  eenheid_bevestigd TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (parameter_sleutel),
  CHECK (eenheid_bevestigd IN (0,1))
) ENGINE=InnoDB;

INSERT INTO duinvallei_bodemparameter
  (parameter_sleutel, parameter_naam, eenheid, eenheid_bevestigd)
VALUES
  ('OM', 'Organische stof', '%', 1),
  ('Moist', 'Bodemvocht', NULL, 0),
  ('pH', 'Zuurgraad', 'pH', 1),
  ('NO3', 'Nitraat', NULL, 0),
  ('NH4', 'Ammonium', NULL, 0),
  ('PO4', 'Fosfaat', NULL, 0),
  ('K', 'Kalium', NULL, 0),
  ('Na', 'Natrium', NULL, 0),
  ('Ntot', 'Totaal stikstof', NULL, 0),
  ('Ptot', 'Totaal fosfor', NULL, 0)
ON DUPLICATE KEY UPDATE
  parameter_naam = VALUES(parameter_naam),
  eenheid = VALUES(eenheid),
  eenheid_bevestigd = VALUES(eenheid_bevestigd);

CREATE TABLE IF NOT EXISTS duinvallei_bodemmeting (
  opname_id BIGINT UNSIGNED NOT NULL,
  parameter_sleutel VARCHAR(16) NOT NULL,
  waarde DECIMAL(20,9) NOT NULL,
  PRIMARY KEY (opname_id, parameter_sleutel),
  CONSTRAINT fk_duinvallei_bodemmeting_opname FOREIGN KEY (opname_id)
    REFERENCES duinvallei_opname (opname_id),
  CONSTRAINT fk_duinvallei_bodemmeting_parameter FOREIGN KEY (parameter_sleutel)
    REFERENCES duinvallei_bodemparameter (parameter_sleutel)
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_duinvallei_analyse_opname AS
SELECT
  o.opname_id,
  o.bron_opname_id,
  p.site_code,
  p.locatietype,
  o.jaar,
  o.blok_raw,
  o.plotnummer_raw,
  o.locatie_genormaliseerd
FROM duinvallei_opname o
JOIN duinvallei_plot p ON p.plot_id = o.plot_id
WHERE o.analyse_status = 'toegelaten';

CREATE OR REPLACE VIEW v_duinvallei_analyse_bedekking AS
SELECT
  o.opname_id,
  o.bron_opname_id,
  p.site_code,
  p.locatietype,
  o.jaar,
  t.taxon_id,
  t.wetenschappelijke_naam_raw,
  b.bedekkingscode,
  b.aanwezig
FROM duinvallei_opname o
JOIN duinvallei_plot p ON p.plot_id = o.plot_id
JOIN duinvallei_bedekking b ON b.opname_id = o.opname_id
JOIN duinvallei_taxon t ON t.taxon_id = b.taxon_id
WHERE o.analyse_status = 'toegelaten';
