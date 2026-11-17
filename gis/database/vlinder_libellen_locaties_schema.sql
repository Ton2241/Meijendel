-- Primaire kaartlocaties uit de levering van De Vlinderstichting van 16 november 2026.
-- De kaartcomponenten zijn geen bewezen historische secties of bezoekgeometrieën.
-- Biologische jaarcijfers en NDFF-waarnemingen staan niet in deze vier tabellen.
USE Meijendel;

CREATE TABLE IF NOT EXISTS vlinders_dag_telobject (
  bron_code SMALLINT UNSIGNED NOT NULL,
  bronnaam VARCHAR(160) NOT NULL,
  weergavenaam_override VARCHAR(160) DEFAULT NULL,
  projectnaam VARCHAR(80) NOT NULL,
  bron_eerste_jaar SMALLINT UNSIGNED NOT NULL,
  bron_laatste_jaar SMALLINT UNSIGNED NOT NULL,
  bronkaart_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  basisgebiedversie VARCHAR(32) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (bron_code),
  UNIQUE KEY uq_vlinders_dag_bronnaam (bronnaam),
  CHECK (bron_laatste_jaar >= bron_eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vlinders_dag_geometrie (
  bron_code SMALLINT UNSIGNED NOT NULL,
  kaartcomponent_nr SMALLINT UNSIGNED NOT NULL,
  geometrie GEOMETRY NOT NULL SRID 28992,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (bron_code, kaartcomponent_nr),
  SPATIAL KEY sx_vlinders_dag_geometrie (geometrie),
  CONSTRAINT fk_vlinders_dag_geometrie_telobject FOREIGN KEY (bron_code)
    REFERENCES vlinders_dag_telobject (bron_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS libellen_telobject (
  telobject_id SMALLINT UNSIGNED NOT NULL,
  bronnaam VARCHAR(160) NOT NULL,
  projectnaam VARCHAR(80) NOT NULL,
  bron_eerste_jaar SMALLINT UNSIGNED NOT NULL,
  bron_laatste_jaar SMALLINT UNSIGNED NOT NULL,
  bronkaart_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  basisgebiedversie VARCHAR(32) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (telobject_id),
  UNIQUE KEY uq_libellen_bronnaam (bronnaam),
  CHECK (bron_laatste_jaar >= bron_eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS libellen_geometrie (
  telobject_id SMALLINT UNSIGNED NOT NULL,
  kaartcomponent_nr SMALLINT UNSIGNED NOT NULL,
  geometrie GEOMETRY NOT NULL SRID 28992,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (telobject_id, kaartcomponent_nr),
  SPATIAL KEY sx_libellen_geometrie (geometrie),
  CONSTRAINT fk_libellen_geometrie_telobject FOREIGN KEY (telobject_id)
    REFERENCES libellen_telobject (telobject_id)
) ENGINE=InnoDB;
