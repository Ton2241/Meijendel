-- Bronvast register van actuele en historische namen en brongeometrieën.
-- MySQL 9.7.1; geometrieën in EPSG:28992.

USE Meijendel;

CREATE TABLE IF NOT EXISTS nameninventaris_import (
  import_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  versiesleutel VARCHAR(80) CHARACTER SET ascii NOT NULL,
  leveringsdatum DATE NOT NULL,
  bronreferentie VARCHAR(255) NOT NULL,
  archief_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  verwacht_bronnen SMALLINT UNSIGNED NOT NULL,
  verwacht_objecten SMALLINT UNSIGNED NOT NULL,
  verwacht_vermeldingen SMALLINT UNSIGNED NOT NULL,
  verwacht_geometrieen SMALLINT UNSIGNED NOT NULL,
  verwacht_lacunes SMALLINT UNSIGNED NOT NULL,
  geimporteerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (import_id),
  UNIQUE KEY uq_nameninventaris_import_versie (versiesleutel),
  UNIQUE KEY uq_nameninventaris_import_hash (archief_sha256),
  CHECK (archief_sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_bron (
  import_id BIGINT UNSIGNED NOT NULL,
  source_id VARCHAR(64) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  auteur_beheerder VARCHAR(500) NULL,
  bronjaar SMALLINT UNSIGNED NULL,
  brontype VARCHAR(100) NOT NULL,
  bronverwijzing VARCHAR(1000) NOT NULL,
  zotero_item_key CHAR(8) CHARACTER SET ascii NULL,
  raadpleegdatum DATE NOT NULL,
  ruimtelijke_grondslag TEXT NOT NULL,
  rechten VARCHAR(500) NOT NULL,
  kwaliteitsbeoordeling VARCHAR(1000) NOT NULL,
  PRIMARY KEY (import_id, source_id),
  CONSTRAINT fk_nameninventaris_bron_import FOREIGN KEY (import_id)
    REFERENCES nameninventaris_import (import_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_object (
  object_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
  import_id BIGINT UNSIGNED NOT NULL,
  voorkeursnaam VARCHAR(500) NOT NULL,
  aangeleverde_naam VARCHAR(500) NOT NULL,
  objectklasse ENUM('gebied','functioneel_gebied','pad_of_weg','wandelroute') NOT NULL,
  bronobjecttype VARCHAR(255) NULL,
  bewijsstatus ENUM(
    'actueel_bronbewijs',
    'historisch_bronbewijs',
    'actueel_en_historisch_bronbewijs'
  ) NOT NULL,
  nauwkeurigheid_m DECIMAL(14,6) NULL,
  nauwkeurigheidsstatus ENUM('opgegeven','niet_opgegeven') NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (object_id),
  UNIQUE KEY uq_nameninventaris_object_import (import_id, object_id),
  KEY ix_nameninventaris_object_naam (voorkeursnaam),
  CONSTRAINT fk_nameninventaris_object_import FOREIGN KEY (import_id)
    REFERENCES nameninventaris_import (import_id),
  CHECK ((nauwkeurigheidsstatus='opgegeven' AND nauwkeurigheid_m IS NOT NULL) OR
         (nauwkeurigheidsstatus='niet_opgegeven' AND nauwkeurigheid_m IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_vermelding (
  mention_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
  import_id BIGINT UNSIGNED NOT NULL,
  object_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
  source_id VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bronnaam VARCHAR(500) NOT NULL,
  periode_letterlijk VARCHAR(32) NOT NULL,
  periode_einde_letterlijk VARCHAR(32) NULL,
  jaar_van SMALLINT UNSIGNED NOT NULL,
  jaar_tot SMALLINT UNSIGNED NOT NULL,
  datumprecisie ENUM('dag','jaar','jaarbereik','decennium') NOT NULL,
  pagina_kaart_bronobject VARCHAR(1000) NULL,
  deelgebied VARCHAR(500) NULL,
  bewijsnotitie TEXT NOT NULL,
  PRIMARY KEY (mention_id),
  UNIQUE KEY uq_nameninventaris_vermelding_import (import_id, mention_id),
  KEY ix_nameninventaris_vermelding_object (import_id, object_id),
  KEY ix_nameninventaris_vermelding_bron (import_id, source_id),
  CONSTRAINT fk_nameninventaris_vermelding_object FOREIGN KEY (import_id, object_id)
    REFERENCES nameninventaris_object (import_id, object_id),
  CONSTRAINT fk_nameninventaris_vermelding_bron FOREIGN KEY (import_id, source_id)
    REFERENCES nameninventaris_bron (import_id, source_id),
  CHECK (jaar_tot >= jaar_van)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_geometrie (
  geometrie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  import_id BIGINT UNSIGNED NOT NULL,
  object_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
  source_id VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  peildatum DATE NOT NULL,
  bronobjecttype VARCHAR(255) NULL,
  wkt_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  nauwkeurigheid_m DECIMAL(14,6) NULL,
  nauwkeurigheidsstatus ENUM('opgegeven','niet_opgegeven') NOT NULL,
  ruimtelijke_selectiegrondslag TEXT NOT NULL,
  geometrieopmerking TEXT NULL,
  geometry GEOMETRY NOT NULL SRID 28992,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (geometrie_id),
  UNIQUE KEY uq_nameninventaris_geometrie (import_id, object_id, source_id, geometrieversie),
  KEY ix_nameninventaris_geometrie_object (import_id, object_id),
  KEY ix_nameninventaris_geometrie_bron (import_id, source_id),
  SPATIAL KEY sx_nameninventaris_geometry (geometry),
  CONSTRAINT fk_nameninventaris_geometrie_object FOREIGN KEY (import_id, object_id)
    REFERENCES nameninventaris_object (import_id, object_id),
  CONSTRAINT fk_nameninventaris_geometrie_bron FOREIGN KEY (import_id, source_id)
    REFERENCES nameninventaris_bron (import_id, source_id),
  CHECK (wkt_sha256 REGEXP '^[0-9a-f]{64}$'),
  CHECK ((nauwkeurigheidsstatus='opgegeven' AND nauwkeurigheid_m IS NOT NULL) OR
         (nauwkeurigheidsstatus='niet_opgegeven' AND nauwkeurigheid_m IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_geometrie_bronobject (
  geometrie_id BIGINT UNSIGNED NOT NULL,
  bronobject_systeem ENUM('TOP10NL','OSM') NOT NULL,
  bronobject_id VARCHAR(128) CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (geometrie_id, bronobject_systeem, bronobject_id),
  UNIQUE KEY uq_nameninventaris_bronobject (bronobject_systeem, bronobject_id),
  CONSTRAINT fk_nameninventaris_bronobject_geometrie FOREIGN KEY (geometrie_id)
    REFERENCES nameninventaris_geometrie (geometrie_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS nameninventaris_beoordeling (
  beoordeling_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  import_id BIGINT UNSIGNED NOT NULL,
  object_id VARCHAR(32) CHARACTER SET ascii NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  beoordelingsstatus ENUM('bronlacune_geometrie') NOT NULL,
  ontbreekt VARCHAR(500) NOT NULL,
  gevolg TEXT NOT NULL,
  kleinste_volgende_bron TEXT NOT NULL,
  actueel TINYINT(1) NOT NULL DEFAULT 1,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (beoordeling_id),
  UNIQUE KEY uq_nameninventaris_beoordeling (object_id, regelversie),
  KEY ix_nameninventaris_beoordeling_object (import_id, object_id),
  CONSTRAINT fk_nameninventaris_beoordeling_object FOREIGN KEY (import_id, object_id)
    REFERENCES nameninventaris_object (import_id, object_id),
  CHECK (actueel IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
