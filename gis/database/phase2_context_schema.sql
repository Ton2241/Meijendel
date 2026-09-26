USE Meijendel_bronnen;

CREATE TABLE IF NOT EXISTS bijen_proefvlak (
  bron_id BIGINT UNSIGNED NOT NULL,
  proefvlak_code CHAR(3) CHARACTER SET ascii NOT NULL,
  deelgebied VARCHAR(255) NOT NULL,
  oppervlakte_ha DECIMAL(8,3) NOT NULL DEFAULT 1.000,
  locatie_status ENUM('kaart_in_rapport_geen_digitale_grens','gegeorefereerd') NOT NULL,
  toelichting TEXT NOT NULL,
  PRIMARY KEY (bron_id, proefvlak_code),
  CONSTRAINT fk_bijen_proefvlak_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE,
  CHECK (proefvlak_code REGEXP '^M(0[1-9]|1[0-8])$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bijen_bezoek (
  bron_id BIGINT UNSIGNED NOT NULL,
  proefvlak_code CHAR(3) CHARACTER SET ascii NOT NULL,
  bezoekdatum DATE NOT NULL,
  bezoekjaar SMALLINT UNSIGNED GENERATED ALWAYS AS (YEAR(bezoekdatum)) STORED,
  ronde TINYINT UNSIGNED NOT NULL,
  duur_minuten SMALLINT UNSIGNED NOT NULL,
  bezoek_status ENUM('volledig_volgens_rapport') NOT NULL,
  resultaten_status ENUM('rapporttabellen_nog_niet_geimporteerd') NOT NULL,
  PRIMARY KEY (bron_id, proefvlak_code, bezoekdatum),
  UNIQUE KEY uq_bijen_bezoek_ronde (bron_id, proefvlak_code, bezoekjaar, ronde),
  CONSTRAINT fk_bijen_bezoek_proefvlak FOREIGN KEY (bron_id, proefvlak_code)
    REFERENCES bijen_proefvlak (bron_id, proefvlak_code) ON DELETE CASCADE,
  CHECK (ronde BETWEEN 1 AND 3),
  CHECK (duur_minuten > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aquatisch_monsterpunt (
  bron_id BIGINT UNSIGNED NOT NULL,
  monsterpunt_code CHAR(3) CHARACTER SET ascii NOT NULL,
  watercode VARCHAR(64) NOT NULL,
  omschrijving VARCHAR(1000) NOT NULL,
  locatie_status ENUM('watercode_bekend_grens_niet_gedigitaliseerd','gegeorefereerd') NOT NULL,
  PRIMARY KEY (bron_id, monsterpunt_code),
  CONSTRAINT fk_aquatisch_monsterpunt_bron FOREIGN KEY (bron_id)
    REFERENCES bron (bron_id) ON DELETE CASCADE,
  CHECK (monsterpunt_code REGEXP '^MP[1-7]$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS aquatisch_monsterprotocol (
  bron_id BIGINT UNSIGNED NOT NULL,
  monsterpunt_code CHAR(3) CHARACTER SET ascii NOT NULL,
  datum_van DATE NOT NULL,
  datum_tot DATE NOT NULL,
  traject_meter DECIMAL(6,2) NULL,
  bemonsterd_oppervlak_m2 DECIMAL(8,3) NULL,
  methode VARCHAR(1000) NOT NULL,
  vergelijkbaarheid ENUM('standaard','afwijkende_inspanning','gedeeltelijke_bemonstering') NOT NULL,
  PRIMARY KEY (bron_id, monsterpunt_code, datum_van),
  CONSTRAINT fk_aquatisch_protocol_punt FOREIGN KEY (bron_id, monsterpunt_code)
    REFERENCES aquatisch_monsterpunt (bron_id, monsterpunt_code) ON DELETE CASCADE,
  CHECK (datum_tot >= datum_van)
) ENGINE=InnoDB;
