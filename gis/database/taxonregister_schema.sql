-- Meijendel taxonregister v2, 29 september 2026; weergavenaam verplicht.
-- Eenmalige ADDITIEVE migratie: uitsluitend drie lege nieuwe tabellen.
-- Geen IF NOT EXISTS: een bestaande naam moet blokkeren, niet stilzwijgend
-- een mogelijk afwijkende structuur accepteren. MySQL DDL commit per statement.
-- Voer uitsluitend uit na back-up en controle van alle drie vrije tabelnamen.
-- Wetenschappelijke onderbouwing en vervolggates: docs/database/TAXONREGISTER.md.
USE Meijendel;
SET NAMES utf8mb4;
SET SESSION lock_wait_timeout = 10;

CREATE TABLE taxon_groepen (
  groep_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  groep_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
    COMMENT 'Stabiele praktische groepscode, niet een taxonomische rang',
  groep_naam VARCHAR(255) NOT NULL,
  bovenliggende_groep_id BIGINT UNSIGNED NULL,
  omschrijving TEXT NULL,
  indeling_bron TEXT NULL,
  indeling_versie VARCHAR(128) NULL,
  sorteervolgorde SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  actief BOOLEAN NOT NULL DEFAULT TRUE,
  groepmetadata JSON NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  gewijzigd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (groep_id),
  UNIQUE KEY uq_taxon_groep_code (groep_code),
  KEY ix_taxon_groep_parent (bovenliggende_groep_id),
  CONSTRAINT fk_taxon_groep_parent FOREIGN KEY (bovenliggende_groep_id)
    REFERENCES taxon_groepen (groep_id),
  CONSTRAINT ck_taxon_groep_code CHECK (REGEXP_LIKE(groep_code, '^[a-z][a-z0-9_]*$', 'c')),
  CONSTRAINT ck_taxon_groep_naam CHECK (CHAR_LENGTH(TRIM(groep_naam)) > 0),
  CONSTRAINT ck_taxon_groep_actief CHECK (actief IN (0, 1)),
  CONSTRAINT ck_taxon_groep_metadata CHECK (groepmetadata IS NULL OR JSON_TYPE(groepmetadata) = 'OBJECT')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Praktische soortgroepen; geen verplichte vaste rijk-tot-soort-hierarchie';

CREATE TABLE taxa (
  taxon_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  taxon_uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
    COMMENT 'Persistente door de importeur toegekende UUID; nooit afleiden uit een naam',
  groep_id BIGINT UNSIGNED NULL COMMENT 'Primaire gebruiksgroep; NULL zolang nog niet beoordeeld',
  wetenschappelijke_naam VARCHAR(500) NOT NULL COMMENT 'Naamgebruik; niet uniek en niet uitsluitend soortniveau',
  naam_zonder_auteur VARCHAR(500) NULL,
  naam_auteur VARCHAR(500) NULL,
  nederlandse_naam VARCHAR(500) NULL,
  weergavenaam VARCHAR(700) NOT NULL
    COMMENT 'Unieke lokale presentatienaam; geen taxonidentiteit of wetenschappelijke naam',
  aanvullende_namen JSON NULL COMMENT 'Array met naam, taal en bron; geen taxon-ID-lijsten',
  taxonrang VARCHAR(64) NULL COMMENT 'Darwin Core taxonRank; onbekend mag NULL zijn',
  taxonrang_bron VARCHAR(128) NULL,
  taxonvorm VARCHAR(32) NOT NULL DEFAULT 'taxon'
    COMMENT 'taxon, aggregaat, hybride of operationele_eenheid',
  taxonomische_status VARCHAR(32) NOT NULL DEFAULT 'unresolved'
    COMMENT 'accepted, synonym, misapplied, doubtful of unresolved; geen taxonrang',
  nomenclatuurcode VARCHAR(64) NULL,
  nomenclatuurstatus VARCHAR(255) NULL,
  naam_identificatie TEXT NULL COMMENT 'Darwin Core scientificNameID; naam is niet hetzelfde als concept',
  concept_identificatie TEXT NULL COMMENT 'Darwin Core taxonConceptID indien extern beschikbaar',
  naam_volgens TEXT NULL COMMENT 'Bron/taxonomische behandeling die de afbakening bepaalt',
  naam_volgens_id TEXT NULL COMMENT 'Darwin Core nameAccordingToID, URI of persistente bron-ID',
  naam_volgens_versie VARCHAR(255) NULL,
  naam_gepubliceerd_in TEXT NULL,
  naam_gepubliceerd_in_id TEXT NULL,
  naam_gepubliceerd_jaar VARCHAR(32) NULL COMMENT 'Letterlijke bibliografische jaarwaarde, geen meetjaar',
  bovenliggend_taxon_id BIGINT UNSIGNED NULL COMMENT 'Taxonomische parent; niet de praktische groep',
  geaccepteerd_taxon_id BIGINT UNSIGNED NULL COMMENT 'Synoniem/verkeerd toegepaste naam naar geaccepteerd naamgebruik',
  oorspronkelijk_taxon_id BIGINT UNSIGNED NULL COMMENT 'Basioniem/oorspronkelijke naamcombinatie',
  rijk VARCHAR(128) NULL,
  stam VARCHAR(128) NULL,
  klasse VARCHAR(128) NULL,
  orde VARCHAR(128) NULL,
  familie VARCHAR(255) NULL,
  geslacht VARCHAR(255) NULL,
  beheerstatus VARCHAR(32) NOT NULL DEFAULT 'voorlopig',
  vastgesteld_door VARCHAR(255) NULL,
  vastgesteld_op DATETIME(6) NULL,
  opmerkingen TEXT NULL,
  taxonmetadata JSON NULL COMMENT 'Aanvullende taxonomische metadata; geen waarnemingen of meetwaarden',
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  gewijzigd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (taxon_id),
  UNIQUE KEY uq_taxa_uuid (taxon_uuid),
  UNIQUE KEY uq_taxa_weergavenaam (weergavenaam),
  KEY ix_taxa_groep (groep_id, beheerstatus),
  KEY ix_taxa_naam (wetenschappelijke_naam),
  KEY ix_taxa_nederlandse_naam (nederlandse_naam),
  KEY ix_taxa_geaccepteerd (geaccepteerd_taxon_id),
  KEY ix_taxa_parent (bovenliggend_taxon_id),
  KEY ix_taxa_oorspronkelijk (oorspronkelijk_taxon_id),
  CONSTRAINT fk_taxa_groep FOREIGN KEY (groep_id) REFERENCES taxon_groepen (groep_id),
  CONSTRAINT fk_taxa_parent FOREIGN KEY (bovenliggend_taxon_id) REFERENCES taxa (taxon_id),
  CONSTRAINT fk_taxa_geaccepteerd FOREIGN KEY (geaccepteerd_taxon_id) REFERENCES taxa (taxon_id),
  CONSTRAINT fk_taxa_oorspronkelijk FOREIGN KEY (oorspronkelijk_taxon_id) REFERENCES taxa (taxon_id),
  CONSTRAINT ck_taxa_uuid CHECK (REGEXP_LIKE(taxon_uuid,
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', 'c')),
  CONSTRAINT ck_taxa_naam CHECK (CHAR_LENGTH(TRIM(wetenschappelijke_naam)) > 0),
  CONSTRAINT ck_taxa_weergavenaam CHECK (
    REGEXP_LIKE(weergavenaam,'[^[:space:]]') AND NOT REGEXP_LIKE(weergavenaam,'[[:cntrl:]]')
    AND BINARY weergavenaam=BINARY TRIM(weergavenaam)),
  CONSTRAINT ck_taxa_nl CHECK (nederlandse_naam IS NULL OR CHAR_LENGTH(TRIM(nederlandse_naam)) > 0),
  CONSTRAINT ck_taxa_rang CHECK (taxonrang IS NULL OR
    (CHAR_LENGTH(TRIM(taxonrang)) > 0 AND LOWER(taxonrang) NOT IN
      ('accepted','synonym','misapplied','doubtful','unresolved'))),
  CONSTRAINT ck_taxa_vorm CHECK (taxonvorm IN ('taxon','aggregaat','hybride','operationele_eenheid')),
  CONSTRAINT ck_taxa_status CHECK (taxonomische_status IN ('accepted','synonym','misapplied','doubtful','unresolved')),
  CONSTRAINT ck_taxa_beheer CHECK (beheerstatus IN ('voorlopig','vastgesteld','vervallen')),
  CONSTRAINT ck_taxa_vastgesteld CHECK (beheerstatus <> 'vastgesteld' OR
    (naam_volgens IS NOT NULL AND CHAR_LENGTH(TRIM(naam_volgens)) > 0
     AND vastgesteld_door IS NOT NULL AND CHAR_LENGTH(TRIM(vastgesteld_door)) > 0
     AND vastgesteld_op IS NOT NULL)),
  CONSTRAINT ck_taxa_namen CHECK (aanvullende_namen IS NULL OR JSON_TYPE(aanvullende_namen) = 'ARRAY'),
  CONSTRAINT ck_taxa_metadata CHECK (taxonmetadata IS NULL OR JSON_TYPE(taxonmetadata) = 'OBJECT')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Bronoverstijgende taxon-naamgebruiken met conceptcontext; geen vogeltabelvervanging';

CREATE TABLE taxa_bronkoppeling (
  koppeling_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_systeem VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL,
  bron_dataset VARCHAR(255) COLLATE utf8mb4_0900_bin NOT NULL,
  bron_versie VARCHAR(255) COLLATE utf8mb4_0900_bin NOT NULL
    COMMENT 'Lijst-/snapshotversie; bij ontbreken expliciete stabiele snapshotidentiteit',
  bron_taxon_id VARCHAR(1024) COLLATE utf8mb4_0900_bin NOT NULL
    COMMENT 'Bron-ID of gedocumenteerde afgeleide sleutel, nooit alleen een ongeduide naam',
  bron_sleuteltype VARCHAR(32) NOT NULL DEFAULT 'oorspronkelijk',
  bron_identiteit_sha256 BINARY(32) GENERATED ALWAYS AS
    (UNHEX(SHA2(CAST(JSON_ARRAY(bron_systeem, bron_dataset, bron_versie, bron_taxon_id)
      AS CHAR CHARACTER SET utf8mb4), 256))) STORED,
  bron_wetenschappelijke_naam VARCHAR(1000) NULL,
  bron_nederlandse_naam VARCHAR(1000) NULL,
  bron_taxonrang VARCHAR(128) NULL,
  bron_taxonomische_status VARCHAR(255) NULL,
  bron_soortgroep VARCHAR(500) NULL,
  bron_naam_identificatie TEXT NULL,
  bron_concept_identificatie TEXT NULL,
  bron_naam_volgens TEXT NULL,
  bron_uri TEXT NULL,
  bron_citatie TEXT NULL,
  bron_licentie VARCHAR(500) NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  bronmetadata JSON NULL COMMENT 'Oorspronkelijke taxonvelden; geen gevoelige vindplaatsen of volledige meetrecords',
  taxon_id BIGINT UNSIGNED NULL COMMENT 'NULL is toegestaan voor een nog onopgeloste bronvermelding',
  doeltaxon_sleutel BIGINT UNSIGNED GENERATED ALWAYS AS (COALESCE(taxon_id, 0)) STORED,
  koppelstatus VARCHAR(32) NOT NULL DEFAULT 'onbeoordeeld',
  taxonrelatie VARCHAR(32) NOT NULL DEFAULT 'onbekend'
    COMMENT 'Richting altijd brontaxon naar centraal taxon; gelijk is conceptueel, niet alleen naamgelijkheid',
  koppelmethode VARCHAR(128) NULL,
  regelversie VARCHAR(128) NULL,
  besluitversie INT UNSIGNED NOT NULL DEFAULT 1,
  onderbouwing TEXT NULL,
  beoordeeld_door VARCHAR(255) NULL,
  beoordeeld_op DATETIME(6) NULL,
  ingetrokken_op DATETIME(6) NULL COMMENT 'Historisch besluit bewaren; niet gebruiken als actuele koppeling',
  actieve_exacte_bron BINARY(32) GENERATED ALWAYS AS
    (CASE WHEN koppelstatus = 'bevestigd' AND taxonrelatie = 'gelijk'
      AND ingetrokken_op IS NULL THEN bron_identiteit_sha256 ELSE NULL END) STORED,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  gewijzigd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (koppeling_id),
  UNIQUE KEY uq_taxa_bron_besluit (bron_identiteit_sha256, besluitversie, doeltaxon_sleutel),
  UNIQUE KEY uq_taxa_bron_actief_exact (actieve_exacte_bron),
  KEY ix_taxa_bron_doel (taxon_id, koppelstatus),
  KEY ix_taxa_bron_status (koppelstatus, ingetrokken_op),
  KEY ix_taxa_bron_dataset (bron_systeem, bron_dataset),
  CONSTRAINT fk_taxa_bron_doel FOREIGN KEY (taxon_id) REFERENCES taxa (taxon_id),
  CONSTRAINT ck_taxa_bron_identiteit CHECK (
    CHAR_LENGTH(TRIM(bron_systeem)) > 0 AND CHAR_LENGTH(TRIM(bron_dataset)) > 0
    AND CHAR_LENGTH(TRIM(bron_versie)) > 0 AND CHAR_LENGTH(TRIM(bron_taxon_id)) > 0),
  CONSTRAINT ck_taxa_bron_sleuteltype CHECK (bron_sleuteltype IN ('oorspronkelijk','afgeleid')),
  CONSTRAINT ck_taxa_bron_hash CHECK (bronbestand_sha256 IS NULL OR
    REGEXP_LIKE(bronbestand_sha256, '^[0-9a-f]{64}$', 'c')),
  CONSTRAINT ck_taxa_bron_metadata CHECK (bronmetadata IS NULL OR JSON_TYPE(bronmetadata) = 'OBJECT'),
  CONSTRAINT ck_taxa_bron_status CHECK (koppelstatus IN ('onbeoordeeld','kandidaat','bevestigd','afgewezen')),
  CONSTRAINT ck_taxa_bron_relatie CHECK (taxonrelatie IN
    ('gelijk','bron_omvat_doel','bron_deel_van_doel','overlap','disjunct','onbekend')),
  CONSTRAINT ck_taxa_bron_versie CHECK (besluitversie > 0),
  CONSTRAINT ck_taxa_bron_beoordeling CHECK (koppelstatus <> 'bevestigd' OR
    (taxonrelatie <> 'onbekend'
     AND koppelmethode IS NOT NULL AND CHAR_LENGTH(TRIM(koppelmethode)) > 0
     AND regelversie IS NOT NULL AND CHAR_LENGTH(TRIM(regelversie)) > 0
     AND onderbouwing IS NOT NULL AND CHAR_LENGTH(TRIM(onderbouwing)) > 0
     AND beoordeeld_door IS NOT NULL AND CHAR_LENGTH(TRIM(beoordeeld_door)) > 0
     AND beoordeeld_op IS NOT NULL)),
  CONSTRAINT ck_taxa_bron_doel CHECK
    ((koppelstatus = 'onbeoordeeld' AND taxon_id IS NULL) OR
     (koppelstatus IN ('kandidaat','bevestigd') AND taxon_id IS NOT NULL) OR koppelstatus = 'afgewezen'),
  CONSTRAINT ck_taxa_bron_intrekking CHECK (ingetrokken_op IS NULL OR
    (ingetrokken_op >= aangemaakt_op AND (beoordeeld_op IS NULL OR ingetrokken_op >= beoordeeld_op)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Geversioneerde bron-taxontoewijzingen; kandidaten en bredere begrippen zijn geen exacte koppeling';
