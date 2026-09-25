-- Onafhankelijke ruimtelijke lagen voor projecttoelating, Natura 2000 en SOVON.
-- MySQL 9.7.1, EPSG:28992.

USE Meijendel;

CREATE TABLE IF NOT EXISTS meijendel_basisgebied_versie (
  basisgebiedversie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versie VARCHAR(32) NOT NULL,
  bronbestand VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  projectgeometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  crs_epsg INT UNSIGNED NOT NULL DEFAULT 28992,
  oppervlakte_ha DECIMAL(14,6) NOT NULL,
  status ENUM('concept','vastgesteld') NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (basisgebiedversie_id),
  UNIQUE KEY uq_meijendel_basisgebied_versie (versie),
  UNIQUE KEY uq_meijendel_basisgebied_bronhash (bronbestand_sha256),
  CHECK (crs_epsg=28992)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meijendel_basisgebied (
  basisgebiedversie_id BIGINT UNSIGNED NOT NULL,
  gebied_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
  naam VARCHAR(255) NOT NULL,
  gebied_geometrie MULTIPOLYGON NOT NULL SRID 28992,
  PRIMARY KEY (basisgebiedversie_id, gebied_id),
  SPATIAL KEY sx_meijendel_basisgebied (gebied_geometrie),
  CONSTRAINT fk_meijendel_basisgebied_versie FOREIGN KEY (basisgebiedversie_id)
    REFERENCES meijendel_basisgebied_versie (basisgebiedversie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meijendel_natura2000_versie (
  natura2000versie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versie VARCHAR(32) NOT NULL,
  bronbestand VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  gebiedsnummer SMALLINT UNSIGNED NOT NULL,
  crs_epsg INT UNSIGNED NOT NULL DEFAULT 28992,
  oppervlakte_ha DECIMAL(14,6) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (natura2000versie_id),
  UNIQUE KEY uq_meijendel_natura2000_versie (versie),
  UNIQUE KEY uq_meijendel_natura2000_bronhash (bronbestand_sha256),
  CHECK (crs_epsg=28992)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meijendel_natura2000 (
  natura2000versie_id BIGINT UNSIGNED NOT NULL,
  gebiedsnummer SMALLINT UNSIGNED NOT NULL,
  naam VARCHAR(255) NOT NULL,
  gebied_geometrie MULTIPOLYGON NOT NULL SRID 28992,
  PRIMARY KEY (natura2000versie_id, gebiedsnummer),
  SPATIAL KEY sx_meijendel_natura2000 (gebied_geometrie),
  CONSTRAINT fk_meijendel_natura2000_versie FOREIGN KEY (natura2000versie_id)
    REFERENCES meijendel_natura2000_versie (natura2000versie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meijendel_waarneming_ruimtelijke_status (
  ruimtelijke_status_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_tabel VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bron_record_id VARCHAR(128) CHARACTER SET ascii NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  basisgebiedversie_id BIGINT UNSIGNED NOT NULL,
  natura2000versie_id BIGINT UNSIGNED NOT NULL,
  plotversie_id BIGINT UNSIGNED NOT NULL,
  locatiemethode ENUM('exact_punt','bronpolygoon','plotvlak','benoemde_locatie','geen') NOT NULL,
  basisstatus ENUM('volledig_binnen','raakt_grens','buiten','ongeldig','geen_geometrie') NOT NULL,
  natura2000status ENUM('volledig_binnen','raakt_grens','buiten','ongeldig','geen_geometrie') NOT NULL,
  sovon_plot_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  eenduidig_plot_id INT NULL,
  toelatingsstatus ENUM(
    'toegelaten','ruimtelijk_dubbelzinnig','buiten_projectgebied',
    'geen_lokalisatie','context_alleen'
  ) NOT NULL,
  reden VARCHAR(1000) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (ruimtelijke_status_id),
  UNIQUE KEY uq_meijendel_ruimtelijke_status (bron_tabel, bron_record_id, regelversie),
  KEY ix_meijendel_ruimtelijke_selectie (regelversie, toelatingsstatus, basisstatus),
  KEY ix_meijendel_ruimtelijke_plot (plotversie_id, eenduidig_plot_id),
  CONSTRAINT fk_meijendel_ruimtelijke_basis FOREIGN KEY (basisgebiedversie_id)
    REFERENCES meijendel_basisgebied_versie (basisgebiedversie_id),
  CONSTRAINT fk_meijendel_ruimtelijke_natura FOREIGN KEY (natura2000versie_id)
    REFERENCES meijendel_natura2000_versie (natura2000versie_id),
  CONSTRAINT fk_meijendel_ruimtelijke_plot FOREIGN KEY (plotversie_id, eenduidig_plot_id)
    REFERENCES ndff_sovon_plot (plotversie_id, plot_id),
  CHECK ((sovon_plot_count=1 AND eenduidig_plot_id IS NOT NULL) OR
         (sovon_plot_count<>1 AND eenduidig_plot_id IS NULL)),
  CHECK ((basisstatus='volledig_binnen' AND toelatingsstatus IN ('toegelaten','context_alleen')) OR
         (basisstatus='raakt_grens' AND toelatingsstatus='ruimtelijk_dubbelzinnig') OR
         (basisstatus='buiten' AND toelatingsstatus='buiten_projectgebied') OR
         (basisstatus IN ('ongeldig','geen_geometrie') AND toelatingsstatus IN ('geen_lokalisatie','context_alleen')))
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_meijendel_basisgebied_actueel AS
SELECT b.*
FROM meijendel_basisgebied b
JOIN meijendel_basisgebied_versie v USING (basisgebiedversie_id)
WHERE v.status='vastgesteld'
  AND v.basisgebiedversie_id=(
    SELECT MAX(v2.basisgebiedversie_id)
    FROM meijendel_basisgebied_versie v2
    WHERE v2.status='vastgesteld'
  );

CREATE OR REPLACE VIEW v_meijendel_natura2000_actueel AS
SELECT n.*
FROM meijendel_natura2000 n
WHERE n.natura2000versie_id=(
  SELECT MAX(v.natura2000versie_id) FROM meijendel_natura2000_versie v
);

CREATE OR REPLACE VIEW v_meijendel_sovon_plot_actueel AS
SELECT p.*
FROM ndff_sovon_plot p
WHERE p.plotversie_id=(SELECT MAX(v.plotversie_id) FROM ndff_sovon_plotversie v);
