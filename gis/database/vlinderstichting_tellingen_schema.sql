-- Primaire jaargegevens van De Vlinderstichting, uitsluitend voor telobjecten
-- die al met een geometrie in de levende Meijendel-database staan.
-- Jaarcijfers per soortcode zijn geen gedateerde bezoeken of bezoeknullen.
USE Meijendel;

CREATE TABLE vlinderstichting_levering (
  levering_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  bronhouder VARCHAR(160) NOT NULL,
  ontvangen_op DATE NOT NULL,
  bronbestanden_json JSON NOT NULL,
  importversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  rechtenstatus VARCHAR(255) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (levering_id),
  CONSTRAINT ck_vlinderstichting_levering_bestanden CHECK
    (JSON_TYPE(bronbestanden_json) = 'OBJECT'),
  CONSTRAINT ck_vlinderstichting_levering_bron CHECK
    (CHAR_LENGTH(TRIM(bronhouder)) > 0 AND CHAR_LENGTH(TRIM(rechtenstatus)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE vlinders_dag_routejaar (
  bron_code SMALLINT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  ruw_totaal INT UNSIGNED NOT NULL
    COMMENT 'Oorspronkelijk jaartotaal; niet gelijkstellen aan soortcode-jaarcijfers',
  jaarstatus ENUM('afgesloten','voorlopig') NOT NULL,
  levering_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (bron_code, jaar),
  KEY ix_vlinders_dag_routejaar_levering (levering_id),
  CONSTRAINT fk_vlinders_dag_routejaar_object FOREIGN KEY (bron_code)
    REFERENCES vlinders_dag_telobject (bron_code),
  CONSTRAINT fk_vlinders_dag_routejaar_levering FOREIGN KEY (levering_id)
    REFERENCES vlinderstichting_levering (levering_id),
  CONSTRAINT ck_vlinders_dag_routejaar_jaar CHECK (jaar BETWEEN 1990 AND 2100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE vlinders_dag_routejaar_soortcode (
  bron_code SMALLINT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  soortcode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
    COMMENT 'Oorspronkelijke volledige Soortcode; varianten niet optellen',
  jaarcijfer INT UNSIGNED NOT NULL
    COMMENT 'Expliciete jaarlijkse bronwaarde; 0 is geen per-bezoek-nul',
  ntell SMALLINT UNSIGNED NOT NULL
    COMMENT 'Aantal tellingen voor deze soortcode in dit routejaar',
  taxon_bronkoppeling_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (bron_code, jaar, soortcode),
  KEY ix_vlinders_dag_routejaar_taxon (taxon_bronkoppeling_id),
  CONSTRAINT fk_vlinders_dag_routejaar_soortcode_jaar FOREIGN KEY (bron_code,jaar)
    REFERENCES vlinders_dag_routejaar (bron_code,jaar),
  CONSTRAINT fk_vlinders_dag_routejaar_soortcode_taxon FOREIGN KEY
    (taxon_bronkoppeling_id) REFERENCES taxa_bronkoppeling (koppeling_id),
  CONSTRAINT ck_vlinders_dag_routejaar_soortcode_code CHECK
    (REGEXP_LIKE(soortcode, '^[0-9]+$', 'c'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE libellen_routejaar (
  telobject_id SMALLINT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  jaarstatus ENUM('afgesloten','voorlopig') NOT NULL,
  levering_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (telobject_id, jaar),
  KEY ix_libellen_routejaar_levering (levering_id),
  CONSTRAINT fk_libellen_routejaar_object FOREIGN KEY (telobject_id)
    REFERENCES libellen_telobject (telobject_id),
  CONSTRAINT fk_libellen_routejaar_levering FOREIGN KEY (levering_id)
    REFERENCES vlinderstichting_levering (levering_id),
  CONSTRAINT ck_libellen_routejaar_jaar CHECK (jaar BETWEEN 1990 AND 2100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
