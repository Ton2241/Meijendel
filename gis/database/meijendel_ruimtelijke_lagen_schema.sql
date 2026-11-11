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

-- Bronvaste lijninfrastructuur. Een OSM-snapshot is een waarnemingsmoment en
-- staat los van de historische statusvlakken voor toegankelijkheid.
CREATE TABLE IF NOT EXISTS infrastructuurbron_snapshot (
  snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  snapshot_code VARCHAR(80) CHARACTER SET ascii NOT NULL,
  snapshottype ENUM('lijnen','voorzieningen') NOT NULL DEFAULT 'lijnen',
  bron_code VARCHAR(32) CHARACTER SET ascii NOT NULL DEFAULT 'OSM',
  bron_url VARCHAR(500) NOT NULL,
  licentie VARCHAR(255) NOT NULL,
  querytekst MEDIUMTEXT NOT NULL,
  query_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bron_timestamp DATETIME(6) NOT NULL,
  gedownload_op DATETIME(6) NOT NULL,
  bronbestand VARCHAR(500) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bron_objecten INT UNSIGNED NOT NULL,
  geselecteerde_objecten INT UNSIGNED NOT NULL,
  geimporteerde_segmenten INT UNSIGNED NOT NULL,
  basisgebiedversie_id BIGINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (snapshot_id),
  UNIQUE KEY uq_infrastructuur_snapshot_code (snapshot_code),
  UNIQUE KEY uq_infrastructuur_snapshot_bronhash (bronbestand_sha256),
  CONSTRAINT fk_infrastructuur_snapshot_basis FOREIGN KEY (basisgebiedversie_id)
    REFERENCES meijendel_basisgebied_versie (basisgebiedversie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS infrastructuursegment (
  segment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  bron_objecttype VARCHAR(16) CHARACTER SET ascii NOT NULL,
  bron_object_id BIGINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (segment_id),
  UNIQUE KEY uq_infrastructuursegment_bronobject
    (bron_code,bron_objecttype,bron_object_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS infrastructuursegment_versie (
  segment_versie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  segment_id BIGINT UNSIGNED NOT NULL,
  snapshot_id BIGINT UNSIGNED NOT NULL,
  bron_versie INT UNSIGNED NULL,
  bron_gewijzigd_op DATETIME(6) NULL,
  bron_changeset BIGINT UNSIGNED NULL,
  infrastructuurtype ENUM('fietspad','voetpad','weg') NOT NULL,
  toegankelijkheidsstatus ENUM('openbaar','beperkt_toegankelijk','afgesloten') NOT NULL,
  beoordelingsstatus ENUM('bron_afgeleid','veld_bevestigd','conflict','nog_te_beoordelen')
    NOT NULL DEFAULT 'bron_afgeleid',
  classificatieregel VARCHAR(80) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NULL,
  oppervlak VARCHAR(100) NULL,
  bron_tags JSON NOT NULL,
  geldig_vanaf DATETIME(6) NOT NULL,
  geldig_vanaf_grondslag ENUM('inschatting','bron') NOT NULL DEFAULT 'bron',
  geldig_tot DATETIME(6) NULL,
  geometrie MULTILINESTRING NOT NULL SRID 28992,
  geometrie_wkt MEDIUMTEXT NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  lengte_m DECIMAL(14,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (segment_versie_id),
  UNIQUE KEY uq_infrastructuursegment_versie_snapshot (segment_id,snapshot_id),
  KEY ix_infrastructuursegment_status
    (infrastructuurtype,toegankelijkheidsstatus,beoordelingsstatus),
  SPATIAL KEY sx_infrastructuursegment_geometrie (geometrie),
  CONSTRAINT fk_infrastructuursegment_versie_segment FOREIGN KEY (segment_id)
    REFERENCES infrastructuursegment (segment_id),
  CONSTRAINT fk_infrastructuursegment_versie_snapshot FOREIGN KEY (snapshot_id)
    REFERENCES infrastructuurbron_snapshot (snapshot_id) ON DELETE CASCADE,
  CHECK (lengte_m>0),
  CHECK (geldig_tot IS NULL OR geldig_tot>geldig_vanaf)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS infrastructuursegment_plot_afleiding (
  segment_versie_id BIGINT UNSIGNED NOT NULL,
  plot_id INT NOT NULL,
  infrastructuurtype ENUM('fietspad','voetpad','weg') NOT NULL,
  toegankelijkheidsstatus ENUM('openbaar','beperkt_toegankelijk','afgesloten') NOT NULL,
  doorsnijding_m DECIMAL(14,3) NOT NULL,
  segmentlengte_m DECIMAL(14,3) NOT NULL,
  aandeel_pct DECIMAL(10,6) NOT NULL,
  segment_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  plot_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  afgeleid_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (segment_versie_id,plot_id),
  KEY ix_infrastructuursegment_plot (plot_id,toegankelijkheidsstatus),
  CONSTRAINT fk_infrastructuursegment_plot_versie FOREIGN KEY (segment_versie_id)
    REFERENCES infrastructuursegment_versie (segment_versie_id) ON DELETE CASCADE,
  CONSTRAINT fk_infrastructuursegment_plot_plot FOREIGN KEY (plot_id)
    REFERENCES plots (plot_id),
  CHECK (doorsnijding_m>0),
  CHECK (segmentlengte_m>0),
  CHECK (aandeel_pct>0 AND aandeel_pct<=100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS infrastructuurvoorziening (
  voorziening_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  bron_objecttype VARCHAR(16) CHARACTER SET ascii NOT NULL,
  bron_object_id BIGINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (voorziening_id),
  UNIQUE KEY uq_infrastructuurvoorziening_bronobject
    (bron_code,bron_objecttype,bron_object_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS infrastructuurvoorziening_versie (
  voorziening_versie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  voorziening_id BIGINT UNSIGNED NOT NULL,
  snapshot_id BIGINT UNSIGNED NOT NULL,
  bron_versie INT UNSIGNED NULL,
  bron_gewijzigd_op DATETIME(6) NULL,
  bron_changeset BIGINT UNSIGNED NULL,
  voorzieningstype ENUM('parkeerplaats') NOT NULL,
  naam VARCHAR(255) NULL,
  bron_tags JSON NOT NULL,
  geldig_vanaf DATETIME(6) NOT NULL,
  geldig_vanaf_grondslag ENUM('inschatting','bron') NOT NULL DEFAULT 'bron',
  geldig_tot DATETIME(6) NULL,
  binnen_basisgebied TINYINT(1) NOT NULL,
  afstand_basisgebied_m DECIMAL(14,3) NOT NULL,
  geometrie GEOMETRY NOT NULL SRID 28992,
  geometrie_wkt MEDIUMTEXT NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (voorziening_versie_id),
  UNIQUE KEY uq_infrastructuurvoorziening_versie_snapshot (voorziening_id,snapshot_id),
  KEY ix_infrastructuurvoorziening_type (voorzieningstype,binnen_basisgebied),
  SPATIAL KEY sx_infrastructuurvoorziening_geometrie (geometrie),
  CONSTRAINT fk_infrastructuurvoorziening_versie_object FOREIGN KEY (voorziening_id)
    REFERENCES infrastructuurvoorziening (voorziening_id),
  CONSTRAINT fk_infrastructuurvoorziening_versie_snapshot FOREIGN KEY (snapshot_id)
    REFERENCES infrastructuurbron_snapshot (snapshot_id) ON DELETE CASCADE,
  CHECK (afstand_basisgebied_m>=0),
  CHECK (geldig_tot IS NULL OR geldig_tot>geldig_vanaf)
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_infrastructuursegment_actueel AS
SELECT v.*,s.bron_code,s.bron_objecttype,s.bron_object_id
FROM infrastructuursegment_versie v
JOIN infrastructuursegment s USING(segment_id)
JOIN infrastructuurbron_snapshot b USING(snapshot_id)
WHERE v.geldig_tot IS NULL
  AND b.snapshottype='lijnen'
  AND b.snapshot_id=(
    SELECT snapshot_id FROM infrastructuurbron_snapshot
    WHERE snapshottype='lijnen'
    ORDER BY bron_timestamp DESC,snapshot_id DESC LIMIT 1
  );

CREATE OR REPLACE VIEW v_infrastructuursegment_historie AS
SELECT v.*,s.bron_code,s.bron_objecttype,s.bron_object_id,
       b.snapshot_code,b.snapshottype,b.bron_timestamp,b.bronbestand_sha256
FROM infrastructuursegment_versie v
JOIN infrastructuursegment s USING(segment_id)
JOIN infrastructuurbron_snapshot b USING(snapshot_id);

CREATE OR REPLACE VIEW v_infrastructuurvoorziening_actueel AS
SELECT v.*,o.bron_code,o.bron_objecttype,o.bron_object_id
FROM infrastructuurvoorziening_versie v
JOIN infrastructuurvoorziening o USING(voorziening_id)
JOIN infrastructuurbron_snapshot b USING(snapshot_id)
WHERE v.geldig_tot IS NULL
  AND b.snapshottype='voorzieningen'
  AND b.snapshot_id=(
    SELECT snapshot_id FROM infrastructuurbron_snapshot
    WHERE snapshottype='voorzieningen'
    ORDER BY bron_timestamp DESC,snapshot_id DESC LIMIT 1
  );

CREATE OR REPLACE VIEW v_infrastructuurvoorziening_historie AS
SELECT v.*,o.bron_code,o.bron_objecttype,o.bron_object_id,
       b.snapshot_code,b.snapshottype,b.bron_timestamp,b.bronbestand_sha256
FROM infrastructuurvoorziening_versie v
JOIN infrastructuurvoorziening o USING(voorziening_id)
JOIN infrastructuurbron_snapshot b USING(snapshot_id);
