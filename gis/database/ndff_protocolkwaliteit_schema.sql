-- Niet-gevoelige kwaliteitsmetadata voor openbare en beveiligde NDFF-bronnen.
-- Bestaande waarnemingstabellen blijven ongewijzigd.

USE Meijendel;

CREATE TABLE IF NOT EXISTS ndff_protocol (
  protocol_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL,
  protocol_code VARCHAR(16) CHARACTER SET ascii NULL,
  protocol_naam VARCHAR(500) NOT NULL,
  levering_scope ENUM('beide','alleen_openbaar') NOT NULL,
  bron_nummers VARCHAR(255) NULL,
  bron_urls JSON NOT NULL,
  bronbestand VARCHAR(255) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  broncontrole_datum DATE NOT NULL,
  PRIMARY KEY (protocol_id),
  UNIQUE KEY uq_ndff_protocol_sleutel (protocol_sleutel),
  UNIQUE KEY uq_ndff_protocol_naam (protocol_naam),
  CHECK ((protocol_sleutel = 'LOS' AND protocol_code IS NULL) OR
         (protocol_sleutel <> 'LOS' AND protocol_code = protocol_sleutel))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_protocol_mapping (
  mapping_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_scope ENUM('openbaar','beveiligd') NOT NULL,
  protocol_raw VARCHAR(500) NOT NULL,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  mapping_methode ENUM('expliciete_code','expliciet_losse_waarneming') NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (mapping_id),
  UNIQUE KEY uq_ndff_protocol_mapping (bron_scope, protocol_raw, regelversie),
  KEY ix_ndff_protocol_mapping_protocol (protocol_id),
  CONSTRAINT fk_ndff_protocol_mapping_protocol FOREIGN KEY (protocol_id)
    REFERENCES ndff_protocol (protocol_id)
) ENGINE=InnoDB;

-- Gecontroleerde woordenlijstcorrectie voor reeds lokaal toegepaste versie v1.
ALTER TABLE ndff_protocol_mapping
  MODIFY mapping_methode ENUM(
    'exacte_code','losse_waarneming',
    'expliciete_code','expliciet_losse_waarneming'
  ) NOT NULL;
UPDATE ndff_protocol_mapping
SET mapping_methode = CASE mapping_methode
  WHEN 'exacte_code' THEN 'expliciete_code'
  WHEN 'losse_waarneming' THEN 'expliciet_losse_waarneming'
  ELSE mapping_methode
END;
ALTER TABLE ndff_protocol_mapping
  MODIFY mapping_methode ENUM(
    'expliciete_code','expliciet_losse_waarneming'
  ) NOT NULL;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_open_waarneming_protocol (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  bewijsmethode ENUM('expliciete_code','expliciet_losse_waarneming') NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  gekoppeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id),
  KEY ix_ndff_open_protocol_id (protocol_id),
  CONSTRAINT fk_ndff_open_protocol_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_open_protocol_protocol FOREIGN KEY (protocol_id)
    REFERENCES Meijendel.ndff_protocol (protocol_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel_ndff_secure.ndff_waarneming_protocol (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  bewijsmethode ENUM('expliciete_code','expliciet_losse_waarneming') NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  gekoppeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id),
  KEY ix_ndff_secure_protocol_id (protocol_id),
  CONSTRAINT fk_ndff_secure_protocol_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES Meijendel_ndff_secure.ndff_waarneming_register (waarneming_id),
  CONSTRAINT fk_ndff_secure_protocol_protocol FOREIGN KEY (protocol_id)
    REFERENCES Meijendel.ndff_protocol (protocol_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_protocol_gebruik (
  protocol_gebruik_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  hoofdtype ENUM('V','I','TV','TA','TK') NOT NULL,
  aanvullend_gebruik TEXT NULL,
  aanvullende_typen VARCHAR(32) CHARACTER SET ascii NOT NULL DEFAULT '',
  wetenschappelijk_gebruik TEXT NOT NULL,
  passende_analyse TEXT NOT NULL,
  benodigde_onderzoekscontext TEXT NOT NULL,
  begrenzing TEXT NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  bronbestand_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  toelichting_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  broncontrole_datum DATE NOT NULL,
  PRIMARY KEY (protocol_gebruik_id),
  UNIQUE KEY uq_ndff_protocol_gebruik (protocol_id, regelversie),
  CONSTRAINT fk_ndff_protocol_gebruik_protocol FOREIGN KEY (protocol_id)
    REFERENCES ndff_protocol (protocol_id),
  CHECK (aanvullende_typen REGEXP '^$|^(V|I|TV|TA|TK)(,(V|I|TV|TA|TK))*$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_protocol_soortgroep_geschiktheid (
  protocol_soortgroep_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  doelrelatie ENUM(
    'doelgroep','gemengd','bijvangst','algemene_bron','doelsoortafhankelijk'
  ) NOT NULL,
  toegestane_typen VARCHAR(32) CHARACTER SET ascii NOT NULL,
  recordaantal_bij_classificatie BIGINT UNSIGNED NOT NULL,
  reden VARCHAR(1000) NOT NULL,
  bron_urls JSON NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  beoordeeld_op DATE NOT NULL,
  PRIMARY KEY (protocol_soortgroep_id),
  UNIQUE KEY uq_ndff_protocol_soortgroep
    (protocol_id, soortgroep_raw, regelversie),
  KEY ix_ndff_protocol_soortgroep_selectie
    (doelrelatie, regelversie),
  CONSTRAINT fk_ndff_protocol_soortgroep_protocol FOREIGN KEY (protocol_id)
    REFERENCES ndff_protocol (protocol_id),
  CHECK (toegestane_typen REGEXP '^(V|I|TV|TA|TK)(,(V|I|TV|TA|TK))*$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_protocol_soort_geschiktheid (
  protocol_soort_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  toegestane_typen VARCHAR(32) CHARACTER SET ascii NOT NULL,
  recordaantal_bij_classificatie BIGINT UNSIGNED NOT NULL,
  reden VARCHAR(1000) NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  beoordeeld_op DATE NOT NULL,
  PRIMARY KEY (protocol_soort_id),
  UNIQUE KEY uq_ndff_protocol_soort
    (protocol_id, soortgroep_raw, wetenschappelijke_naam, regelversie),
  KEY ix_ndff_protocol_soort_selectie
    (doelrelatie, regelversie),
  CONSTRAINT fk_ndff_protocol_soort_protocol FOREIGN KEY (protocol_id)
    REFERENCES ndff_protocol (protocol_id),
  CHECK (toegestane_typen REGEXP '^(V|I|TV|TA|TK)(,(V|I|TV|TA|TK))*$')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_open_ruimtelijke_beoordeling (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  plotversie_id BIGINT UNSIGNED NOT NULL,
  geometrie_type VARCHAR(32) CHARACTER SET ascii NOT NULL,
  geometrie_oppervlakte_m2 DECIMAL(20,6) NOT NULL,
  vervaagd TINYINT(1) NOT NULL,
  vervagingsniveau_km SMALLINT UNSIGNED NULL,
  plot_match_count SMALLINT UNSIGNED NOT NULL,
  eenduidig_plot_id INT NULL,
  ruimtelijke_klasse ENUM('single','multiple','outside','ongeldig') NOT NULL,
  toewijzingskwaliteit ENUM('single_volledig_binnen','single_deels','multiple','outside','ongeldig') NOT NULL,
  is_plotcontext_ruimtelijk_toelaatbaar TINYINT(1) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id, regelversie),
  KEY ix_ndff_open_ruimte_klasse (regelversie, ruimtelijke_klasse, toewijzingskwaliteit),
  KEY ix_ndff_open_ruimte_plot (plotversie_id, eenduidig_plot_id),
  CONSTRAINT fk_ndff_open_ruimte_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_open_ruimte_plot FOREIGN KEY (plotversie_id, eenduidig_plot_id)
    REFERENCES ndff_sovon_plot (plotversie_id, plot_id),
  CHECK (vervaagd IN (0,1)),
  CHECK (is_plotcontext_ruimtelijk_toelaatbaar IN (0,1)),
  CHECK ((ruimtelijke_klasse = 'single' AND plot_match_count = 1 AND eenduidig_plot_id IS NOT NULL) OR
         (ruimtelijke_klasse = 'multiple' AND plot_match_count > 1 AND eenduidig_plot_id IS NULL) OR
         (ruimtelijke_klasse IN ('outside','ongeldig') AND plot_match_count = 0 AND eenduidig_plot_id IS NULL)),
  CHECK (is_plotcontext_ruimtelijk_toelaatbaar = 0 OR
         (vervaagd = 0 AND toewijzingskwaliteit = 'single_volledig_binnen'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ndff_analysebesluit (
  analysebesluit_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_scope ENUM('openbaar','beveiligd') NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  protocol_id SMALLINT UNSIGNED NOT NULL,
  analysetype ENUM('V','I','TV','TA','TK') NOT NULL,
  protocolgeschiktheid ENUM('primair','voorwaardelijk','niet_onderbouwd') NOT NULL,
  gegevensgeschiktheid ENUM('geschikt','voorwaardelijk','onvoldoende','niet_beoordeeld') NOT NULL,
  eindbesluit ENUM('toegelaten','voorlopig_toegelaten','alleen_verspreidingscontext','wacht_op_brondata','uitgesloten_huidige_levering') NOT NULL,
  vereist_ruimtelijke_toets TINYINT(1) NOT NULL DEFAULT 1,
  vereist_pq_toets TINYINT(1) NOT NULL DEFAULT 1,
  recordaantal_bij_besluit BIGINT UNSIGNED NOT NULL,
  reden VARCHAR(1000) NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  besloten_op DATE NOT NULL,
  PRIMARY KEY (analysebesluit_id),
  UNIQUE KEY uq_ndff_analysebesluit
    (bron_scope, soortgroep_raw, protocol_id, analysetype, regelversie),
  KEY ix_ndff_analysebesluit_selectie
    (bron_scope, analysetype, eindbesluit, regelversie),
  CONSTRAINT fk_ndff_analysebesluit_protocol FOREIGN KEY (protocol_id)
    REFERENCES ndff_protocol (protocol_id),
  CHECK (vereist_ruimtelijke_toets IN (0,1)),
  CHECK (vereist_pq_toets IN (0,1))
) ENGINE=InnoDB;

-- Protocolgeschikte gegevens mogen voorlopig worden gebruikt zolang de
-- leveringsgeschiktheid afzonderlijk als niet beoordeeld herkenbaar blijft.
ALTER TABLE ndff_analysebesluit
  MODIFY eindbesluit ENUM(
    'toegelaten','voorlopig_toegelaten','alleen_verspreidingscontext',
    'wacht_op_brondata','alleen_na_doelsoortselectie',
    'wacht_op_doelsoortafbakening','uitgesloten_huidige_levering'
  ) NOT NULL;
