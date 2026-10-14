-- Bronvaste koppeling van de nameninventaris aan actuele vogelkavelgeometrieën.
-- De actuele polygonen staan rechtstreeks in plots.geom.

USE Meijendel;

CREATE TABLE IF NOT EXISTS plot_geometrie_import (
  plot_geometrie_import_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versiesleutel VARCHAR(96) CHARACTER SET ascii NOT NULL,
  bronbestand VARCHAR(1000) NOT NULL,
  bron_datum DATE NOT NULL,
  shp_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  shx_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  dbf_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  prj_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bundel_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bron_objecten SMALLINT UNSIGNED NOT NULL,
  geimporteerde_plots SMALLINT UNSIGNED NOT NULL,
  uitgesloten_plot_id INT NOT NULL,
  uitgesloten_naam VARCHAR(255) NOT NULL,
  selectieregel VARCHAR(1000) NOT NULL,
  actueel TINYINT(1) NOT NULL DEFAULT 1,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (plot_geometrie_import_id),
  UNIQUE KEY uq_plot_geometrie_import_versie (versiesleutel),
  UNIQUE KEY uq_plot_geometrie_import_bundel (bundel_sha256),
  CHECK (bron_objecten=56),
  CHECK (geimporteerde_plots=55),
  CHECK (uitgesloten_plot_id=29945),
  CHECK (actueel IN (0,1)),
  CHECK (shp_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (shx_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (dbf_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (prj_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (bundel_sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET @kolom_geom_bron_bestaat = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='plots'
    AND COLUMN_NAME='geom_bron_import_id'
);
SET @kolom_geom_bron_sql = IF(
  @kolom_geom_bron_bestaat=0,
  'ALTER TABLE plots ADD COLUMN geom_bron_import_id BIGINT UNSIGNED NULL',
  'DO 0'
);
PREPARE kolom_geom_bron_stmt FROM @kolom_geom_bron_sql;
EXECUTE kolom_geom_bron_stmt;
DEALLOCATE PREPARE kolom_geom_bron_stmt;

SET @kolom_geom_hash_bestaat = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='plots'
    AND COLUMN_NAME='geom_sha256'
);
SET @kolom_geom_hash_sql = IF(
  @kolom_geom_hash_bestaat=0,
  'ALTER TABLE plots ADD COLUMN geom_sha256 CHAR(64) CHARACTER SET ascii NULL',
  'DO 0'
);
PREPARE kolom_geom_hash_stmt FROM @kolom_geom_hash_sql;
EXECUTE kolom_geom_hash_stmt;
DEALLOCATE PREPARE kolom_geom_hash_stmt;

SET @fk_plot_geom_bron_bestaat = (
  SELECT COUNT(*)
  FROM information_schema.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA=DATABASE()
    AND CONSTRAINT_NAME='fk_plots_geom_bron_import'
);
SET @fk_plot_geom_bron_sql = IF(
  @fk_plot_geom_bron_bestaat=0,
  'ALTER TABLE plots ADD CONSTRAINT fk_plots_geom_bron_import FOREIGN KEY (geom_bron_import_id) REFERENCES plot_geometrie_import (plot_geometrie_import_id)',
  'DO 0'
);
PREPARE fk_plot_geom_bron_stmt FROM @fk_plot_geom_bron_sql;
EXECUTE fk_plot_geom_bron_stmt;
DEALLOCATE PREPARE fk_plot_geom_bron_stmt;

CREATE TABLE IF NOT EXISTS nameninventaris_plot_koppeling (
  geometrie_id BIGINT UNSIGNED NOT NULL,
  plot_id INT NOT NULL,
  plot_geometrie_import_id BIGINT UNSIGNED NOT NULL,
  relatietype ENUM('oppervlakte_overlap','lijn_overlap') NOT NULL,
  intersectiedimensie TINYINT UNSIGNED NOT NULL,
  naamgeometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  plotgeometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  rekenregelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  berekend_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (geometrie_id, plot_id, plot_geometrie_import_id),
  KEY ix_nameninventaris_plot_plot (plot_id, plot_geometrie_import_id),
  CONSTRAINT fk_nameninventaris_plot_geometrie FOREIGN KEY (geometrie_id)
    REFERENCES nameninventaris_geometrie (geometrie_id),
  CONSTRAINT fk_nameninventaris_plot_plot FOREIGN KEY (plot_id)
    REFERENCES plots (plot_id),
  CONSTRAINT fk_nameninventaris_plot_bron FOREIGN KEY (plot_geometrie_import_id)
    REFERENCES plot_geometrie_import (plot_geometrie_import_id),
  CHECK ((relatietype='oppervlakte_overlap' AND intersectiedimensie=2) OR
         (relatietype='lijn_overlap' AND intersectiedimensie=1)),
  CHECK (naamgeometrie_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK (plotgeometrie_sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_nameninventaris_plot_actueel AS
SELECT
  k.geometrie_id,
  g.object_id,
  o.voorkeursnaam,
  o.objectklasse,
  k.plot_id,
  p.plot_naam,
  p.kavel_nummer,
  k.relatietype,
  k.intersectiedimensie,
  k.plot_geometrie_import_id,
  i.versiesleutel AS plotgeometrieversie,
  s.scope_code,
  s.in_scope,
  k.berekend_op
FROM nameninventaris_plot_koppeling k
JOIN nameninventaris_geometrie g ON g.geometrie_id=k.geometrie_id
JOIN nameninventaris_object o ON o.object_id=g.object_id
JOIN plots p ON p.plot_id=k.plot_id
JOIN plot_geometrie_import i
  ON i.plot_geometrie_import_id=k.plot_geometrie_import_id
JOIN plot_analyse_scope s
  ON s.plot_id=k.plot_id AND s.scope_code='meijendel_natura2000'
WHERE i.actueel=1
  AND p.geom_bron_import_id=i.plot_geometrie_import_id
  AND s.in_scope=1;
