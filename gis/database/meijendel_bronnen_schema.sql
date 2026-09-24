CREATE DATABASE IF NOT EXISTS Meijendel_bronnen
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE Meijendel_bronnen;

CREATE TABLE IF NOT EXISTS bron (
  bron_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_sleutel VARCHAR(128) CHARACTER SET ascii NOT NULL,
  bron_type ENUM('dataset','literatuur','kandidaatbron') NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  omschrijving TEXT NULL,
  bronorganisatie VARCHAR(500) NULL,
  jaar_van SMALLINT UNSIGNED NULL,
  jaar_tot SMALLINT UNSIGNED NULL,
  soortgroep VARCHAR(255) NULL,
  geografische_status ENUM(
    'niet_geolokaliseerd',
    'gedeeltelijk_geolokaliseerd',
    'nvt'
  ) NOT NULL,
  geografische_toelichting TEXT NOT NULL,
  analyse_status ENUM('context_alleen','kandidaat','gepromoveerd') NOT NULL,
  rechten_status ENUM('intern','geregistreerde_onderzoekers','open_metadata') NOT NULL,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  bijgewerkt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
    ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (bron_id),
  UNIQUE KEY uq_bron_sleutel (bron_sleutel),
  KEY ix_bron_type_jaar (bron_type, jaar_van, jaar_tot),
  CHECK (jaar_tot IS NULL OR jaar_van IS NULL OR jaar_tot >= jaar_van)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bron_bestand (
  bron_bestand_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_id BIGINT UNSIGNED NOT NULL,
  bestand_naam VARCHAR(500) NOT NULL,
  bestandstype VARCHAR(128) NOT NULL,
  opslagklasse ENUM('t7','repository','publieke_url','overig') NOT NULL,
  recordaantal BIGINT UNSIGNED NULL,
  sha256 CHAR(64) CHARACTER SET ascii NULL,
  toelichting TEXT NULL,
  PRIMARY KEY (bron_bestand_id),
  UNIQUE KEY uq_bron_bestand (bron_id, bestand_naam, sha256),
  CONSTRAINT fk_bron_bestand_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE,
  CHECK (sha256 IS NULL OR sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS literatuur (
  bron_id BIGINT UNSIGNED NOT NULL,
  zotero_item_key VARCHAR(64) CHARACTER SET ascii NOT NULL,
  citation_key VARCHAR(255) CHARACTER SET ascii NULL,
  item_type VARCHAR(64) NOT NULL,
  publicatiejaar SMALLINT UNSIGNED NULL,
  container_titel VARCHAR(1000) NULL,
  uitgever VARCHAR(500) NULL,
  volume VARCHAR(64) NULL,
  nummer VARCHAR(64) NULL,
  paginas VARCHAR(128) NULL,
  doi VARCHAR(255) CHARACTER SET ascii NULL,
  url VARCHAR(2048) NULL,
  geraadpleegd_op DATE NULL,
  trefwoorden JSON NOT NULL,
  citation_chicago TEXT NOT NULL,
  citation_style VARCHAR(128) CHARACTER SET ascii NOT NULL
    DEFAULT 'chicago-fullnote-bibliography',
  zotero_status ENUM('actueel','niet_meer_in_export') NOT NULL DEFAULT 'actueel',
  gesynchroniseerd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (bron_id),
  UNIQUE KEY uq_literatuur_zotero_item_key (zotero_item_key),
  UNIQUE KEY uq_literatuur_citation_key (citation_key),
  CONSTRAINT fk_literatuur_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE,
  CHECK (json_valid(trefwoorden)),
  CHECK (url IS NULL OR url REGEXP '^https://'),
  CHECK (doi IS NULL OR doi NOT LIKE 'http%')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS literatuur_auteur (
  bron_id BIGINT UNSIGNED NOT NULL,
  volgnummer SMALLINT UNSIGNED NOT NULL,
  familienaam VARCHAR(500) NULL,
  voornamen VARCHAR(500) NULL,
  naam_letterlijk VARCHAR(1000) NULL,
  PRIMARY KEY (bron_id, volgnummer),
  CONSTRAINT fk_literatuur_auteur_bron FOREIGN KEY (bron_id)
    REFERENCES literatuur (bron_id) ON DELETE CASCADE,
  CHECK (volgnummer > 0),
  CHECK (
    familienaam IS NOT NULL OR
    voornamen IS NOT NULL OR
    naam_letterlijk IS NOT NULL
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS jachtspin_locatie (
  bron_id BIGINT UNSIGNED NOT NULL,
  locatie_nummer TINYINT UNSIGNED NOT NULL,
  bodem_droogte_getransformeerd DECIMAL(16,8) NOT NULL,
  kaal_zand_getransformeerd DECIMAL(16,8) NOT NULL,
  gevallen_blad_getransformeerd DECIMAL(16,8) NOT NULL,
  mos_getransformeerd DECIMAL(16,8) NOT NULL,
  kruidlaag_getransformeerd DECIMAL(16,8) NOT NULL,
  bodemreflectie_getransformeerd DECIMAL(16,8) NOT NULL,
  totaal_exemplaren SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (bron_id, locatie_nummer),
  CONSTRAINT fk_jachtspin_locatie_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE,
  CHECK (locatie_nummer BETWEEN 1 AND 28)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS jachtspin_soort (
  bron_id BIGINT UNSIGNED NOT NULL,
  soort_code VARCHAR(16) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  PRIMARY KEY (bron_id, soort_code),
  UNIQUE KEY uq_jachtspin_soortnaam (bron_id, wetenschappelijke_naam),
  CONSTRAINT fk_jachtspin_soort_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS jachtspin_vangst (
  bron_id BIGINT UNSIGNED NOT NULL,
  locatie_nummer TINYINT UNSIGNED NOT NULL,
  soort_code VARCHAR(16) CHARACTER SET ascii NOT NULL,
  aantal SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (bron_id, locatie_nummer, soort_code),
  CONSTRAINT fk_jachtspin_vangst_locatie FOREIGN KEY (bron_id, locatie_nummer)
    REFERENCES jachtspin_locatie (bron_id, locatie_nummer) ON DELETE CASCADE,
  CONSTRAINT fk_jachtspin_vangst_soort FOREIGN KEY (bron_id, soort_code)
    REFERENCES jachtspin_soort (bron_id, soort_code) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_bron_catalogus AS
SELECT
  b.bron_id,
  b.bron_sleutel,
  b.bron_type,
  b.titel,
  b.omschrijving,
  b.bronorganisatie,
  b.jaar_van,
  b.jaar_tot,
  b.soortgroep,
  b.geografische_status,
  b.geografische_toelichting,
  b.analyse_status,
  b.rechten_status,
  b.regelversie,
  COUNT(bb.bron_bestand_id) AS bestandsverwijzingen,
  COALESCE(SUM(bb.recordaantal), 0) AS geregistreerde_records
FROM bron b
LEFT JOIN bron_bestand bb ON bb.bron_id = b.bron_id
GROUP BY
  b.bron_id, b.bron_sleutel, b.bron_type, b.titel, b.omschrijving,
  b.bronorganisatie, b.jaar_van, b.jaar_tot, b.soortgroep,
  b.geografische_status, b.geografische_toelichting, b.analyse_status,
  b.rechten_status, b.regelversie;

CREATE OR REPLACE VIEW v_literatuur_overzicht AS
SELECT
  b.bron_id,
  b.bron_sleutel,
  b.titel,
  l.zotero_item_key,
  l.citation_key,
  l.item_type,
  l.publicatiejaar,
  l.container_titel,
  l.uitgever,
  l.volume,
  l.nummer,
  l.paginas,
  l.doi,
  l.url,
  l.geraadpleegd_op,
  l.trefwoorden,
  l.citation_chicago,
  l.citation_style,
  l.zotero_status,
  GROUP_CONCAT(
    COALESCE(NULLIF(a.naam_letterlijk, ''), TRIM(CONCAT_WS(', ', a.familienaam, a.voornamen)))
    ORDER BY a.volgnummer SEPARATOR '; '
  ) AS auteurs
FROM bron b
JOIN literatuur l ON l.bron_id = b.bron_id
LEFT JOIN literatuur_auteur a ON a.bron_id = b.bron_id
GROUP BY
  b.bron_id, b.bron_sleutel, b.titel, l.zotero_item_key, l.citation_key,
  l.item_type, l.publicatiejaar, l.container_titel, l.uitgever, l.volume,
  l.nummer, l.paginas, l.doi, l.url, l.geraadpleegd_op, l.trefwoorden,
  l.citation_chicago, l.citation_style, l.zotero_status;

CREATE OR REPLACE VIEW v_contextdataset_overzicht AS
SELECT
  b.bron_id,
  b.bron_sleutel,
  b.bron_type,
  b.titel,
  b.omschrijving,
  b.bronorganisatie,
  b.jaar_van,
  b.jaar_tot,
  b.soortgroep,
  b.geografische_status,
  b.geografische_toelichting,
  b.analyse_status,
  b.rechten_status,
  COUNT(bb.bron_bestand_id) AS bestandsverwijzingen,
  COALESCE(SUM(bb.recordaantal), 0) AS geregistreerde_records
FROM bron b
LEFT JOIN bron_bestand bb ON bb.bron_id = b.bron_id
WHERE b.bron_type IN ('dataset', 'kandidaatbron')
GROUP BY
  b.bron_id, b.bron_sleutel, b.bron_type, b.titel, b.omschrijving,
  b.bronorganisatie, b.jaar_van, b.jaar_tot, b.soortgroep,
  b.geografische_status, b.geografische_toelichting, b.analyse_status,
  b.rechten_status;
