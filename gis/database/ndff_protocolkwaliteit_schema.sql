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
  doelrelatie ENUM('doelsoort','bijvangst','onbepaald') NOT NULL,
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

-- v2 kent ook taxa die zowel een doelsoort als een niet-doelsoort omvatten.
ALTER TABLE ndff_protocol_soort_geschiktheid
  MODIFY doelrelatie ENUM('doelsoort','bijvangst','onbepaald') NOT NULL;

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

-- De provinciale PQ-reeks is de gezaghebbende primaire bron. Deze afleidingslaag
-- voorkomt dat herkenbare NDFF-PQ-bronrecords als aanvullende waarnemingen
-- worden geteld en laat latere, fijnere matching als nieuwe regelversie toe.
CREATE TABLE IF NOT EXISTS ndff_open_pq_koppeling (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  classificatie ENUM(
    'exact','waarschijnlijk_dezelfde_opname','mogelijk','onafhankelijk',
    'niet_beoordeelbaar','niet_van_toepassing'
  ) NOT NULL,
  ndff_bronrol ENUM('secundaire_controlebron','niet_van_toepassing') NOT NULL,
  primaire_pq_bron ENUM('provincie_zuid_holland','niet_van_toepassing') NOT NULL,
  reden VARCHAR(500) NOT NULL,
  regelversie VARCHAR(64) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id, regelversie),
  KEY ix_ndff_open_pq_selectie (regelversie, classificatie, ndff_bronrol),
  CONSTRAINT fk_ndff_open_pq_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_open_waarneming (waarneming_id),
  CHECK ((classificatie='niet_van_toepassing'
          AND ndff_bronrol='niet_van_toepassing'
          AND primaire_pq_bron='niet_van_toepassing') OR
         (classificatie<>'niet_van_toepassing'
          AND ndff_bronrol='secundaire_controlebron'
          AND primaire_pq_bron='provincie_zuid_holland'))
) ENGINE=InnoDB;

-- SNL is een beoordelings- en subsidiecontext, geen bewijs dat een record een
-- zelfstandige gegevensbron is. Deze laag registreert daarom uitsluitend wat
-- de huidige vergelijking met andere openbare NDFF-records over overlap zegt.
CREATE TABLE IF NOT EXISTS ndff_snl_waarneming_context (
  waarneming_id BIGINT UNSIGNED NOT NULL,
  overlap_status ENUM(
    'overlap_bevestigd','overlap_mogelijk',
    'geen_overlap_gevonden','onvoldoende_onderzocht'
  ) NOT NULL,
  kandidaat_aantal INT UNSIGNED NOT NULL DEFAULT 0,
  kandidaat_waarneming_ids JSON NOT NULL,
  toets_methode VARCHAR(500) NOT NULL,
  bewijsnotitie VARCHAR(1000) NULL,
  regelversie VARCHAR(64) NOT NULL,
  beoordeeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (waarneming_id, regelversie),
  KEY ix_ndff_snl_overlap (regelversie, overlap_status),
  CONSTRAINT fk_ndff_snl_context_waarneming FOREIGN KEY (waarneming_id)
    REFERENCES ndff_open_waarneming (waarneming_id),
  CHECK ((overlap_status IN ('overlap_bevestigd','overlap_mogelijk')
          AND kandidaat_aantal > 0)
      OR (overlap_status IN ('geen_overlap_gevonden','onvoldoende_onderzocht')
          AND kandidaat_aantal = 0)),
  CHECK (overlap_status <> 'overlap_bevestigd' OR bewijsnotitie IS NOT NULL)
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

-- Lokale reconstructie van NEM-dagvlinderroutes uit protocol 03.201. Deze
-- afgeleide tabellen staan in de life-database: zij zijn uitsluitend uit de
-- openbare NDFF-bron gereconstrueerd. Bronrecords blijven ongewijzigd; iedere
-- afleiding is reproduceerbaar via reconstructieversie.
-- Eerste vastgelegde reconstructieregel: ndff-vlinderroute-v1.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_vlinder_routefamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '03.201',
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  bezoekaantal INT UNSIGNED NOT NULL,
  geometrieaantal INT UNSIGNED NOT NULL,
  componentaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, routefamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vlinder_routegeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_vlinder_geometrie_route
    (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_vlinder_geometrie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vlinder_routefamilie
      (reconstructieversie, routefamilie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vlinder_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NULL,
  reconstructiestatus ENUM(
    'gereconstrueerd','handmatige_controle','geen_route'
  ) NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  KEY ix_ndff_vlinder_bezoek_route
    (reconstructieversie, routefamilie_id, jaar),
  CONSTRAINT fk_ndff_vlinder_bezoek_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vlinder_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(periode_start))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vlinder_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  nulregel VARCHAR(255) NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_vlinder_taxon_jaar (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_vlinder_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_vlinder_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK ((waarnemingsstatus='waargenomen' AND aantal > 0) OR
         (waarnemingsstatus='echte_nul' AND aantal = 0))
) ENGINE=InnoDB;

-- De binnen 03.201 getelde vliesvleugeligen (in deze levering: hommels)
-- vormen een eigen NEM-deelreeks. Alleen tijdstippen waarop daadwerkelijk
-- minstens één vliesvleugelige is geteld gelden als bezoek voor deze matrix;
-- dagvlinderbezoeken zonder zo'n telling leveren dus geen nul op.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_vliesvleugel_routefamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '03.201',
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  bezoekaantal INT UNSIGNED NOT NULL,
  geometrieaantal INT UNSIGNED NOT NULL,
  componentaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, routefamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vliesvleugel_routegeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_vliesvleugel_geometrie_route
    (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_vliesvleugel_geometrie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vliesvleugel_routefamilie
      (reconstructieversie, routefamilie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vliesvleugel_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NULL,
  reconstructiestatus ENUM(
    'gereconstrueerd','handmatige_controle','geen_route'
  ) NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  KEY ix_ndff_vliesvleugel_bezoek_route
    (reconstructieversie, routefamilie_id, jaar),
  CONSTRAINT fk_ndff_vliesvleugel_bezoek_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vliesvleugel_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(periode_start))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vliesvleugel_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  nulregel VARCHAR(255) NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_vliesvleugel_taxon_jaar
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_vliesvleugel_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_vliesvleugel_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK ((waarnemingsstatus='waargenomen' AND aantal > 0) OR
         (waarnemingsstatus='echte_nul' AND aantal = 0))
) ENGINE=InnoDB;

-- Lokale reconstructie van het NEM-Landelijk Meetnet Libellen (07.201).
-- De bron is volledig openbaar. Per route en bezoek blijft herkenbaar of het
-- doelbereik algemeen is vastgesteld; bij onbekend doelbereik worden geen
-- afgeleide nullen buiten de daadwerkelijk gemelde taxa opgeslagen.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_libel_routefamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '07.201',
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  doelbereikstatus ENUM('algemene_route','soortgerichte_route','onbepaald') NOT NULL,
  bezoekaantal INT UNSIGNED NOT NULL,
  geometrieaantal INT UNSIGNED NOT NULL,
  componentaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, routefamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_libel_routegeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_libel_geometrie_route (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_libel_geometrie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_libel_routefamilie
      (reconstructieversie, routefamilie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_libel_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NULL,
  reconstructiestatus ENUM(
    'gereconstrueerd','handmatige_controle','geen_route'
  ) NOT NULL,
  doelbereikstatus ENUM('algemene_route','soortgerichte_route','onbepaald') NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  KEY ix_ndff_libel_bezoek_route
    (reconstructieversie, routefamilie_id, jaar),
  CONSTRAINT fk_ndff_libel_bezoek_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_libel_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(periode_start))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_libel_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  nulregel VARCHAR(255) NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_libel_taxon_jaar
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_libel_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_libel_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK ((waarnemingsstatus='waargenomen' AND aantal > 0) OR
         (waarnemingsstatus='echte_nul' AND aantal = 0))
) ENGINE=InnoDB;

-- Openbare reconstructie van het NEM-Meetprogramma Reptielen (10.201).
-- Een bezoek wordt gevormd per routefamilie en kalenderdatum. De FFV-bron
-- bevat geen bezoeken zonder enige reptielenwaarneming; die dekking en de niet
-- afleidbare inspanning blijven daarom expliciet zichtbaar.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_reptiel_routefamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '10.201',
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  bezoekaantal INT UNSIGNED NOT NULL,
  geometrieaantal INT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, routefamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_reptiel_routegeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  geometrierol ENUM('historisch_traject','exacte_locatie') NOT NULL,
  anker_geometrie_sha256 CHAR(64) CHARACTER SET ascii NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_reptiel_geometrie_route (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_reptiel_geometrie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_reptiel_routefamilie
      (reconstructieversie, routefamilie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_reptiel_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  bezoekdatum DATE NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NULL,
  reconstructiestatus ENUM(
    'gereconstrueerd','handmatige_controle','geen_route'
  ) NOT NULL,
  bezoekdekkingstatus ENUM('alleen_positieve_bezoeken') NOT NULL,
  inspanningstatus ENUM('niet_afleidbaar') NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  KEY ix_ndff_reptiel_bezoek_route
    (reconstructieversie, routefamilie_id, jaar),
  CONSTRAINT fk_ndff_reptiel_bezoek_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_reptiel_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(bezoekdatum))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_reptiel_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  adult_aantal INT UNSIGNED NOT NULL,
  subadult_aantal INT UNSIGNED NOT NULL,
  juveniel_aantal INT UNSIGNED NOT NULL,
  onbekend_stadium_aantal INT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  nulregel VARCHAR(255) NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_reptiel_taxon_jaar
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_reptiel_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_reptiel_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (aantal=adult_aantal+subadult_aantal+juveniel_aantal+onbekend_stadium_aantal),
  CHECK ((waarnemingsstatus='waargenomen' AND aantal > 0) OR
         (waarnemingsstatus='echte_nul' AND aantal = 0))
) ENGINE=InnoDB;

-- Openbare reconstructie van NEM-amfibieënprotocol 01.201. Een telgebiedbezoek
-- kan meerdere afzonderlijke wateren omvatten. Alleen wateren met minstens
-- één positieve bronregel gelden aantoonbaar als bezocht. Presentieklassen,
-- schattingen en minimumaantallen blijven onderscheiden van exacte aantallen.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_amfibie_waterfamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waterfamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '01.201',
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  waterbezoekaantal INT UNSIGNED NOT NULL,
  geometrieaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waterfamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_amfibie_watergeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  waterfamilie_id SMALLINT UNSIGNED NOT NULL,
  geometrierol ENUM('anker','versie') NOT NULL,
  anker_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  afstand_anker_m DECIMAL(10,3) NOT NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_amfibie_geometrie_water
    (reconstructieversie, waterfamilie_id),
  CONSTRAINT fk_ndff_amfibie_geometrie_water FOREIGN KEY
    (reconstructieversie, waterfamilie_id)
    REFERENCES Meijendel.ndff_amfibie_waterfamilie
      (reconstructieversie, waterfamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_amfibie_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  bezoekdatum DATE NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  periodecodering ENUM('tijdvenster','datuminterval') NOT NULL,
  bezoekdekkingstatus ENUM('alleen_bezoeken_met_positieve_waterregistratie') NOT NULL,
  inspanningstatus ENUM('niet_afleidbaar') NOT NULL,
  waterbezoekaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  KEY ix_ndff_amfibie_bezoek_jaar (jaar, bezoekdatum),
  CHECK (periode_stop >= periode_start),
  CHECK (jaar = YEAR(bezoekdatum))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_amfibie_waterbezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waterbezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  waterfamilie_id SMALLINT UNSIGNED NOT NULL,
  bevestigingsstatus ENUM('positieve_registratie_aanwezig') NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, waterbezoek_sleutel),
  UNIQUE KEY uq_ndff_amfibie_waterbezoek
    (reconstructieversie, bezoek_sleutel, waterfamilie_id),
  CONSTRAINT fk_ndff_amfibie_waterbezoek_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_amfibie_bezoek
      (reconstructieversie, bezoek_sleutel),
  CONSTRAINT fk_ndff_amfibie_waterbezoek_water FOREIGN KEY
    (reconstructieversie, waterfamilie_id)
    REFERENCES Meijendel.ndff_amfibie_waterfamilie
      (reconstructieversie, waterfamilie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_amfibie_waterbezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waterbezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  bron_taxonnamen VARCHAR(1000) NULL,
  stadia_raw VARCHAR(1000) NULL,
  stadium_status ENUM('niet_van_toepassing','een_stadium','meerdere_stadia') NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  meetwaardetypen_raw VARCHAR(255) NULL,
  meetwaarde_type ENUM(
    'exact','presentieklasse','minimum','schatting','gemengd','echte_nul'
  ) NOT NULL,
  aantal_exact INT UNSIGNED NULL,
  ondergrens INT UNSIGNED NULL,
  bovengrens INT UNSIGNED NULL,
  hoogste_presentieklasse TINYINT UNSIGNED NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  nulregel VARCHAR(500) NOT NULL,
  PRIMARY KEY (
    reconstructieversie, waterbezoek_sleutel, wetenschappelijke_naam
  ),
  KEY ix_ndff_amfibie_taxon_status
    (wetenschappelijke_naam, waarnemingsstatus, meetwaarde_type),
  CONSTRAINT fk_ndff_amfibie_taxon_waterbezoek FOREIGN KEY
    (reconstructieversie, waterbezoek_sleutel)
    REFERENCES Meijendel.ndff_amfibie_waterbezoek
      (reconstructieversie, waterbezoek_sleutel),
  CHECK (
    (waarnemingsstatus='echte_nul' AND meetwaarde_type='echte_nul'
      AND aantal_exact=0 AND ondergrens=0 AND bovengrens=0
      AND bronrecordaantal=0)
    OR
    (waarnemingsstatus='waargenomen' AND meetwaarde_type<>'echte_nul'
      AND bronrecordaantal>0)
  )
) ENGINE=InnoDB;

-- Openbare reconstructie van protocol 17.208. De records zijn akoestische
-- detecties en uitdrukkelijk geen aantallen individuele vleermuizen. De ene
-- NEM-VTT-autoroute en de ene vleerMUS-fietsroute blijven methodisch gescheiden.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_vleermuis_routefamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '17.208',
  routecode VARCHAR(64) CHARACTER SET ascii NOT NULL,
  methodevariant ENUM('nem_vtt_auto','vleermus_fiets') NOT NULL,
  vervoerswijze ENUM('auto','fiets') NOT NULL,
  reconstructiestatus ENUM('waarschijnlijk','handmatige_controle') NOT NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  geometrieaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_omvang_m DECIMAL(12,3) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, routefamilie_id),
  UNIQUE KEY uq_ndff_vleermuis_routecode (reconstructieversie, routecode),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vleermuis_routegeometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  geometrierol ENUM('positieve_detectielocatie') NOT NULL,
  centrum_x_rd DECIMAL(14,3) NOT NULL,
  centrum_y_rd DECIMAL(14,3) NOT NULL,
  oppervlakte_m2 DECIMAL(18,6) NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_vleermuis_geometrie_route
    (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_vleermuis_geometrie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vleermuis_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vleermuis_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  ronde_binnen_jaar TINYINT UNSIGNED NOT NULL,
  methodevariant ENUM('nem_vtt_auto','vleermus_fiets') NOT NULL,
  reconstructiestatus ENUM('gereconstrueerd','handmatige_controle') NOT NULL,
  datumvenster_status ENUM('binnen_huidig_protocol','buiten_huidig_protocol') NOT NULL,
  herhalingsvenster_status ENUM('binnen_huidig_protocol','handmatige_controle') NOT NULL,
  bezoekdekkingstatus ENUM('alleen_bezoeken_met_positieve_detectie') NOT NULL,
  inspanningstatus ENUM('protocolmatig_gestandaardiseerd_metadata_ontbreekt') NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  UNIQUE KEY uq_ndff_vleermuis_bezoek
    (reconstructieversie, routefamilie_id, bezoekdatum),
  KEY ix_ndff_vleermuis_bezoek_route
    (reconstructieversie, routefamilie_id, jaar),
  CONSTRAINT fk_ndff_vleermuis_bezoek_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vleermuis_routefamilie
      (reconstructieversie, routefamilie_id),
  CHECK (jaar = YEAR(bezoekdatum))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vleermuis_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  canonieke_waarneming_id BIGINT UNSIGNED NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  routefamilie_id SMALLINT UNSIGNED NOT NULL,
  bronsysteem ENUM('nem_vtt','vleermus','vttvleermus') NOT NULL,
  selectiestatus ENUM('opgenomen','dubbele_aanlevering_onderdrukt') NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  selectiereden VARCHAR(500) NOT NULL,
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_vleermuis_selectie_route
    (reconstructieversie, routefamilie_id, selectiestatus),
  KEY ix_ndff_vleermuis_selectie_bezoek
    (reconstructieversie, bezoek_sleutel),
  CONSTRAINT fk_ndff_vleermuis_selectie_bron FOREIGN KEY (waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_vleermuis_selectie_canoniek FOREIGN KEY
    (canonieke_waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_vleermuis_selectie_route FOREIGN KEY
    (reconstructieversie, routefamilie_id)
    REFERENCES Meijendel.ndff_vleermuis_routefamilie
      (reconstructieversie, routefamilie_id),
  CONSTRAINT fk_ndff_vleermuis_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_vleermuis_bezoek
      (reconstructieversie, bezoek_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_vleermuis_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  detectieaantal INT UNSIGNED NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  meeteenheid ENUM('akoestische_detectie') NOT NULL,
  nulregel VARCHAR(500) NOT NULL,
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_vleermuis_taxon_status
    (wetenschappelijke_naam, doelrelatie, waarnemingsstatus),
  CONSTRAINT fk_ndff_vleermuis_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_vleermuis_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen' AND detectieaantal>0)
    OR
    (waarnemingsstatus='echte_nul' AND detectieaantal=0
      AND doelrelatie='doelsoort')
  )
) ENGINE=InnoDB;

-- Openbare kwaliteitslaag voor protocol 17.209 (Konijnen in de duinen).
-- De FFV-export bevat exacte positieve sectietellingen, maar geen route- of
-- sectie-id. Kilometerhok, datum en taxon zijn daarom nadrukkelijk geen
-- gereconstrueerd bezoek en er worden geen nullen afgeleid.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_konijn_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '17.209',
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  aantal_exact INT UNSIGNED NOT NULL,
  seizoenstatus ENUM(
    'voorjaar_huidig_venster','najaar_huidig_venster','buiten_huidig_venster'
  ) NOT NULL,
  recordgroepstatus ENUM(
    'uniek_binnen_hokdatum_taxon',
    'meerdere_sectieregels_binnen_hokdatum_taxon',
    'gelijke_telwaarde_binnen_hokdatum_taxon'
  ) NOT NULL,
  hokdatum_taxon_groepsgrootte SMALLINT UNSIGNED NOT NULL,
  exactgelijke_groepsgrootte SMALLINT UNSIGNED NOT NULL,
  daz_overlapstatus ENUM('mogelijke_overlap_17_204','geen_exacte_match') NOT NULL,
  ruimtelijke_status ENUM('kilometerhok_meerdere_sovonplots') NOT NULL,
  meeteenheidstatus ENUM('sectie_zonder_route_of_sectie_id') NOT NULL,
  trendgebruik ENUM('wacht_op_route_sectie_koppeling') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_konijn_doel_seizoen
    (doelrelatie, seizoenstatus, daz_overlapstatus),
  CONSTRAINT fk_ndff_konijn_selectie_bron FOREIGN KEY (waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CHECK (aantal_exact > 0),
  CHECK (exactgelijke_groepsgrootte <= hokdatum_taxon_groepsgrootte)
) ENGINE=InnoDB;

-- Diagnostische samenvatting. Een hok-datum-taxoncombinatie kan meerdere
-- onbekende routesecties bevatten en is dus geen native NEM-meeteenheid.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_konijn_hokdatum_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokdatum_taxon_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  teldatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  hoknummer VARCHAR(64) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  aantal_som INT UNSIGNED NOT NULL,
  aantal_min INT UNSIGNED NOT NULL,
  aantal_max INT UNSIGNED NOT NULL,
  aggregatiestatus ENUM('diagnostische_proxy_geen_meeteenheid') NOT NULL,
  nulstatus ENUM('niet_afleidbaar') NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokdatum_taxon_sleutel),
  KEY ix_ndff_konijn_hokdatum_taxon
    (wetenschappelijke_naam, jaar, teldatum),
  CHECK (jaar = YEAR(teldatum)),
  CHECK (bronrecordaantal > 0),
  CHECK (aantal_som >= aantal_max AND aantal_max >= aantal_min AND aantal_min > 0)
) ENGINE=InnoDB;

-- Reconstructie van NEM 17.204 (Dagactieve Zoogdieren binnen BMP).
-- De zoogdieren zijn tijdens BMP-bezoeken als afzonderlijke nevenregistratie
-- verzameld. Alleen een eenduidig aan een BMP-bezoek gekoppeld positief record
-- bewijst dat de teller aan DAZ deelnam. Andere BMP-bezoeken blijven onbekend.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_daz_bmp_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_id INT NOT NULL,
  plot_id INT NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  deelnamestatus ENUM('bevestigd_door_positieve_17_204') NOT NULL,
  eenduidig_bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ambigu_kandidaatrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulbereikstatus ENUM('zeven_daz_doelsoorten') NOT NULL,
  inspanningstatus ENUM('bmp_bezoek_bekend_daz_inspanning_niet_afzonderlijk') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_id),
  KEY ix_ndff_daz_bmp_bezoek_plot_jaar (plot_id, jaar, bezoekdatum),
  CONSTRAINT fk_ndff_daz_bmp_bezoek_bron FOREIGN KEY (bezoek_id)
    REFERENCES Meijendel.dagbezoeken_bmp (bezoek_id),
  CHECK (jaar = YEAR(bezoekdatum)),
  CHECK (eenduidig_bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_daz_bmp_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '17.204',
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  aantal_exact INT UNSIGNED NOT NULL,
  kandidaat_bezoekaantal SMALLINT UNSIGNED NOT NULL,
  koppelstatus ENUM('eenduidig_bmp_bezoek','meerdere_bmp_bezoeken','geen_bmp_bezoek') NOT NULL,
  bezoek_id INT DEFAULT NULL,
  gebruiksstatus ENUM('opgenomen_in_bezoekmatrix','alleen_bronrecord') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_daz_bmp_selectie_status (koppelstatus, doelrelatie),
  KEY ix_ndff_daz_bmp_selectie_bezoek (reconstructieversie, bezoek_id),
  CONSTRAINT fk_ndff_daz_bmp_selectie_bron FOREIGN KEY (waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_daz_bmp_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_id)
    REFERENCES Meijendel.ndff_daz_bmp_bezoek (reconstructieversie, bezoek_id),
  CHECK (aantal_exact > 0),
  CHECK (
    (koppelstatus='eenduidig_bmp_bezoek' AND bezoek_id IS NOT NULL
      AND gebruiksstatus='opgenomen_in_bezoekmatrix')
    OR
    (koppelstatus<>'eenduidig_bmp_bezoek' AND bezoek_id IS NULL
      AND gebruiksstatus='alleen_bronrecord')
  )
) ENGINE=InnoDB;

-- Alle ruimtelijk en temporeel mogelijke record-bezoekkoppelingen blijven
-- bewaard. Zo blijft zichtbaar waarom een record eenduidig of ambigu is.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_daz_bmp_recordkandidaat (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  bezoek_id INT NOT NULL,
  plot_id INT NOT NULL,
  bezoekdatum DATE NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id, bezoek_id),
  KEY ix_ndff_daz_bmp_kandidaat_bezoek (reconstructieversie, bezoek_id),
  CONSTRAINT fk_ndff_daz_bmp_kandidaat_selectie FOREIGN KEY
    (reconstructieversie, waarneming_id)
    REFERENCES Meijendel.ndff_daz_bmp_recordselectie
      (reconstructieversie, waarneming_id),
  CONSTRAINT fk_ndff_daz_bmp_kandidaat_bezoek FOREIGN KEY (bezoek_id)
    REFERENCES Meijendel.dagbezoeken_bmp (bezoek_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_daz_bmp_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_id INT NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul','onbepaald_ambigu') NOT NULL,
  aantal INT UNSIGNED DEFAULT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ambigu_recordaantal SMALLINT UNSIGNED NOT NULL,
  telwaardestatus ENUM('exact','minimum_door_ambiguiteit','echte_nul','niet_toewijsbaar') NOT NULL,
  nulregel ENUM('bevestigde_daz_deelname','niet_van_toepassing_bijvangst','geblokkeerd_door_ambigu_record') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_id, wetenschappelijke_naam),
  KEY ix_ndff_daz_bmp_taxon_status
    (wetenschappelijke_naam, doelrelatie, waarnemingsstatus),
  CONSTRAINT fk_ndff_daz_bmp_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_id)
    REFERENCES Meijendel.ndff_daz_bmp_bezoek (reconstructieversie, bezoek_id),
  CHECK (
    (waarnemingsstatus='waargenomen' AND aantal>0 AND bronrecordaantal>0)
    OR
    (waarnemingsstatus='echte_nul' AND aantal=0 AND bronrecordaantal=0
      AND ambigu_recordaantal=0 AND doelrelatie='doelsoort')
    OR
    (waarnemingsstatus='onbepaald_ambigu' AND aantal IS NULL
      AND bronrecordaantal=0 AND ambigu_recordaantal>0 AND doelrelatie='doelsoort')
  )
) ENGINE=InnoDB;

-- Openbare reconstructie van NEM 11.202 (Zeereeppaddenstoelen).
-- De oorspronkelijke meeteenheid is een RD-kilometerhok. Alleen onvervaagde
-- records worden tot bezoeken gereconstrueerd; de zes typische doelsoorten
-- vormen de bezoek-soortmatrix. NMV-aantalsklassen blijven klassen en worden
-- nooit opgeteld als aantallen vruchtlichamen.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_zeereep_kilometerhok (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hok_sleutel VARCHAR(32) CHARACTER SET ascii NOT NULL,
  x_km SMALLINT UNSIGNED NOT NULL,
  y_km SMALLINT UNSIGNED NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '11.202',
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hok_sleutel),
  UNIQUE KEY uq_ndff_zeereep_hok_xy (reconstructieversie, x_km, y_km),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_zeereep_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  hok_sleutel VARCHAR(32) CHARACTER SET ascii NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  seizoenstatus ENUM('kernseizoen_okt_dec','buiten_kernseizoen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  inspanningstatus ENUM('bezoek_bevestigd_inspanning_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  UNIQUE KEY uq_ndff_zeereep_hok_datum
    (reconstructieversie, hok_sleutel, bezoekdatum),
  KEY ix_ndff_zeereep_bezoek_jaar (jaar, bezoekdatum),
  CONSTRAINT fk_ndff_zeereep_bezoek_hok FOREIGN KEY
    (reconstructieversie, hok_sleutel)
    REFERENCES Meijendel.ndff_zeereep_kilometerhok
      (reconstructieversie, hok_sleutel),
  CHECK (jaar = YEAR(bezoekdatum)),
  CHECK (bronrecordaantal > 0 AND geregistreerde_taxa > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_zeereep_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('typische_doelsoort') NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  hoogste_nmv_klasse ENUM(
    'geen','aanwezig','exact_1','klasse_1_3','klasse_4_20','klasse_21_plus'
  ) NOT NULL,
  nulregel ENUM('bevestigd_11_202_hokbezoek') NOT NULL,
  kwaliteitsnotitie VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_zeereep_taxon_status
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_zeereep_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_zeereep_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen' AND bronrecordaantal>0
      AND hoogste_nmv_klasse<>'geen')
    OR
    (waarnemingsstatus='echte_nul' AND bronrecordaantal=0
      AND hoogste_nmv_klasse='geen')
  )
) ENGINE=InnoDB;

-- Reconstructie van het historische NEM 11.201 Meetnet Bospaddenstoelen.
-- De zes brongeometrieen zijn technische representaties van drie vaste
-- meetpunten. Exacte vruchtlichaamtellingen zijn canoniek boven de parallelle
-- presentieregels. Het doelbereik is conservatief: alleen telsoorten die op een
-- meetpunt ten minste eenmaal zijn gemeld, gelden daar aantoonbaar als gevolgd.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_meetpunt (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  meetpunt_sleutel VARCHAR(32) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '11.201',
  centrum_x_rd DECIMAL(10,2) NOT NULL,
  centrum_y_rd DECIMAL(10,2) NOT NULL,
  geometrieaantal SMALLINT UNSIGNED NOT NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaaraantal SMALLINT UNSIGNED NOT NULL,
  doelbereikstatus ENUM('conservatief_afgeleid_uit_ooit_waargenomen_telsoorten') NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, meetpunt_id),
  UNIQUE KEY uq_ndff_bospaddenstoel_meetpunt_sleutel
    (reconstructieversie, meetpunt_sleutel),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_geometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  representatietype ENUM('exact_aantal_vlak','presentie_vlak') NOT NULL,
  centrum_x_rd DECIMAL(10,2) NOT NULL,
  centrum_y_rd DECIMAL(10,2) NOT NULL,
  oppervlakte_m2 DECIMAL(14,2) NOT NULL,
  bronrecordaantal INT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, geometrie_sha256),
  KEY ix_ndff_bospaddenstoel_geometrie_meetpunt
    (reconstructieversie, meetpunt_id),
  CONSTRAINT fk_ndff_bospaddenstoel_geometrie_meetpunt FOREIGN KEY
    (reconstructieversie, meetpunt_id)
    REFERENCES Meijendel.ndff_bospaddenstoel_meetpunt
      (reconstructieversie, meetpunt_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  canonieke_waarneming_id BIGINT UNSIGNED NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  bezoekdatum DATE NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  selectiestatus ENUM(
    'opgenomen_exact','opgenomen_presentie','dubbele_presentie_onderdrukt'
  ) NOT NULL,
  selectiereden VARCHAR(750) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_bospaddenstoel_selectie_canoniek
    (reconstructieversie, canonieke_waarneming_id),
  CONSTRAINT fk_ndff_bospaddenstoel_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_bospaddenstoel_selectie_canoniek FOREIGN KEY
    (canonieke_waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_bospaddenstoel_selectie_meetpunt FOREIGN KEY
    (reconstructieversie, meetpunt_id)
    REFERENCES Meijendel.ndff_bospaddenstoel_meetpunt
      (reconstructieversie, meetpunt_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_doelbereik (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  afleidingsregel ENUM('doelsoort_ooit_waargenomen_op_meetpunt') NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  positieve_bezoekaantal SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, meetpunt_id, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_bospaddenstoel_bereik_meetpunt FOREIGN KEY
    (reconstructieversie, meetpunt_id)
    REFERENCES Meijendel.ndff_bospaddenstoel_meetpunt
      (reconstructieversie, meetpunt_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  seizoenstatus ENUM('kernseizoen_jul_nov','buiten_kernseizoen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  canonieke_positieve_resultaten SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  inspanningstatus ENUM('bezoek_bevestigd_duur_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  UNIQUE KEY uq_ndff_bospaddenstoel_meetpunt_datum
    (reconstructieversie, meetpunt_id, bezoekdatum),
  CONSTRAINT fk_ndff_bospaddenstoel_bezoek_meetpunt FOREIGN KEY
    (reconstructieversie, meetpunt_id)
    REFERENCES Meijendel.ndff_bospaddenstoel_meetpunt
      (reconstructieversie, meetpunt_id),
  CHECK (jaar = YEAR(bezoekdatum))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM('waargenomen_exact','waargenomen_presentie','echte_nul') NOT NULL,
  aantal_vruchtlichamen INT UNSIGNED NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulregel ENUM('aantoonbaar_gevolgde_telsoort_op_bevestigd_bezoek') NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_bospaddenstoel_bezoek_taxon_status
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_bospaddenstoel_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_bospaddenstoel_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen_exact' AND aantal_vruchtlichamen>0 AND bronrecordaantal>0)
    OR (waarnemingsstatus='waargenomen_presentie' AND aantal_vruchtlichamen IS NULL AND bronrecordaantal>0)
    OR (waarnemingsstatus='echte_nul' AND aantal_vruchtlichamen=0 AND bronrecordaantal=0)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_jaar_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  meetpunt_id SMALLINT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  jaarstatus ENUM('maximum_exact','alleen_presentie','echte_nul') NOT NULL,
  maximum_vruchtlichamen INT UNSIGNED NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  positief_bezoekaantal SMALLINT UNSIGNED NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, meetpunt_id, jaar, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_bospaddenstoel_jaar_meetpunt FOREIGN KEY
    (reconstructieversie, meetpunt_id)
    REFERENCES Meijendel.ndff_bospaddenstoel_meetpunt
      (reconstructieversie, meetpunt_id),
  CHECK (
    (jaarstatus='maximum_exact' AND maximum_vruchtlichamen>0 AND positief_bezoekaantal>0)
    OR (jaarstatus='alleen_presentie' AND maximum_vruchtlichamen IS NULL AND positief_bezoekaantal>0)
    OR (jaarstatus='echte_nul' AND maximum_vruchtlichamen=0 AND positief_bezoekaantal=0)
  )
) ENGINE=InnoDB;

-- Reconstructie van 12.204 Het Nieuwe Strepen. De NDFF-regels bevatten geen
-- lijst- of waarnemer-ID. Een inventarisatie is daarom een controleerbare
-- datum/ruimtedagcluster; onafhankelijkheid van herhaalbezoeken blijft apart
-- van de waargenomen soorten en echte nullen vastgelegd.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_hns_inventarisatie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '12.204',
  doelhok VARCHAR(16) CHARACTER SET ascii NOT NULL,
  begindatum DATE NOT NULL,
  einddatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  lijststatus ENUM('volledige_lijst_aannemelijk','fragment') NOT NULL,
  seizoenstatus ENUM('binnen_veldseizoen','buiten_veldseizoen') NOT NULL,
  inspanningstatus ENUM(
    'datum_bekend_duur_onbekend','duur_binnen_4_12_uur',
    'mogelijke_meerdageninventarisatie_binnen_14_dagen',
    'duur_buiten_protocol_of_onvolledig'
  ) NOT NULL,
  herhaalstatus ENUM(
    'enkele_inventarisatie','herhaling_aanwezig_onafhankelijkheid_niet_bevestigd'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  doelhok_aandeel DECIMAL(6,5) NOT NULL,
  kwaliteitsnotitie VARCHAR(1200) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel),
  KEY ix_ndff_hns_hok_jaar (doelhok, jaar, lijststatus),
  CHECK (einddatum >= begindatum),
  CHECK (jaar = YEAR(begindatum)),
  CHECK (doelhok_aandeel BETWEEN 0 AND 1)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_hns_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NULL,
  selectiestatus ENUM(
    'opgenomen_volledige_lijst','opgenomen_fragment',
    'vervaagd_jaarrecord_niet_toegewezen'
  ) NOT NULL,
  selectiereden VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_hns_selectie_inventarisatie
    (reconstructieversie, inventarisatie_sleutel),
  CONSTRAINT fk_ndff_hns_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_hns_selectie_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_hns_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CHECK (
    (selectiestatus='vervaagd_jaarrecord_niet_toegewezen'
      AND inventarisatie_sleutel IS NULL)
    OR
    (selectiestatus<>'vervaagd_jaarrecord_niet_toegewezen'
      AND inventarisatie_sleutel IS NOT NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_hns_doelbereik (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  afleidingsregel ENUM('waargenomen_op_aannemelijk_volledige_hns_lijst') NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  positieve_inventarisatieaantal SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, wetenschappelijke_naam),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_hns_inventarisatie_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulregel ENUM('niet_gemeld_op_aannemelijk_volledige_hns_lijst') NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_hns_taxon_status (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_hns_taxon_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_hns_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen' AND bronrecordaantal>0)
    OR (waarnemingsstatus='echte_nul' AND bronrecordaantal=0)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_hns_hok_jaar_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  doelhok VARCHAR(16) CHARACTER SET ascii NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  jaarstatus ENUM('waargenomen','echte_nul') NOT NULL,
  inventarisatieaantal SMALLINT UNSIGNED NOT NULL,
  positief_inventarisatieaantal SMALLINT UNSIGNED NOT NULL,
  onafhankelijkheidsstatus ENUM(
    'niet_van_toepassing_een_inventarisatie',
    'herhaling_aanwezig_onafhankelijkheid_niet_bevestigd'
  ) NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, doelhok, jaar, wetenschappelijke_naam),
  CHECK (
    (jaarstatus='waargenomen' AND positief_inventarisatieaantal>0)
    OR (jaarstatus='echte_nul' AND positief_inventarisatieaantal=0)
  ),
  CHECK (inventarisatieaantal >= positief_inventarisatieaantal)
) ENGINE=InnoDB;

-- Reconstructie van 02.202 Korstmossen op steen, heiden en stuifzanden (NEM).
-- Alleen onvervaagde openbare records worden afgeleid. De landelijke methode
-- werkt met complete soortenlijsten per vast proefvlak; daarom mag een niet
-- gemeld taxon binnen een bevestigd bezoek als echte nul worden vastgelegd.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_korstmos_meetlocatie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  meetlocatie_id SMALLINT UNSIGNED NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '02.202',
  centrum_x_rd DECIMAL(10,2) NOT NULL,
  centrum_y_rd DECIMAL(10,2) NOT NULL,
  oppervlakte_m2 DECIMAL(14,2) NOT NULL,
  ruimtelijke_klasse ENUM('eenduidig_plot','meerdere_plots') NOT NULL,
  sovon_plot_id INT NULL,
  herhaalstatus ENUM('herhaald_vast_proefvlak','eenmalig_proefvlak') NOT NULL,
  bezoekaantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  kwaliteitsnotitie VARCHAR(1200) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, meetlocatie_id),
  UNIQUE KEY uq_ndff_korstmos_geometrie (reconstructieversie, geometrie_sha256),
  CHECK (
    (ruimtelijke_klasse='eenduidig_plot' AND sovon_plot_id IS NOT NULL)
    OR (ruimtelijke_klasse='meerdere_plots' AND sovon_plot_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_korstmos_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  meetlocatie_id SMALLINT UNSIGNED NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  lijststatus ENUM('volledige_soortenlijst_protocolconform') NOT NULL,
  registratiestatus ENUM('geen_dubbelen','parallelle_registraties','abundantieconflict') NOT NULL,
  kwaliteitsnotitie VARCHAR(1200) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  UNIQUE KEY uq_ndff_korstmos_locatie_datum
    (reconstructieversie, meetlocatie_id, bezoekdatum),
  CONSTRAINT fk_ndff_korstmos_bezoek_meetlocatie FOREIGN KEY
    (reconstructieversie, meetlocatie_id)
    REFERENCES Meijendel.ndff_korstmos_meetlocatie
      (reconstructieversie, meetlocatie_id),
  CHECK (jaar = YEAR(bezoekdatum))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_korstmos_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  canonieke_waarneming_id BIGINT UNSIGNED NULL,
  meetlocatie_id SMALLINT UNSIGNED NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM(
    'opgenomen','dubbele_registratie_onderdrukt','abundantieconflict_bewaard'
  ) NOT NULL,
  selectiereden VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_korstmos_selectie_canoniek
    (reconstructieversie, canonieke_waarneming_id),
  CONSTRAINT fk_ndff_korstmos_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_korstmos_selectie_canoniek FOREIGN KEY
    (canonieke_waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_korstmos_selectie_meetlocatie FOREIGN KEY
    (reconstructieversie, meetlocatie_id)
    REFERENCES Meijendel.ndff_korstmos_meetlocatie
      (reconstructieversie, meetlocatie_id),
  CONSTRAINT fk_ndff_korstmos_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_korstmos_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (selectiestatus IN ('opgenomen','dubbele_registratie_onderdrukt')
      AND canonieke_waarneming_id IS NOT NULL)
    OR (selectiestatus='abundantieconflict_bewaard'
      AND canonieke_waarneming_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_korstmos_doelbereik (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  afleidingsregel ENUM('openbaar_taxon_waargenomen_op_02_202_bezoek') NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  positieve_bezoekaantal SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, wetenschappelijke_naam),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_korstmos_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM(
    'waargenomen','waargenomen_abundantieconflict','echte_nul'
  ) NOT NULL,
  bedekkingsklasse_raw VARCHAR(64) NULL,
  bedekkingsrang TINYINT UNSIGNED NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulregel ENUM('niet_gemeld_op_volledige_02_202_soortenlijst') NOT NULL,
  kwaliteitsnotitie VARCHAR(1200) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_korstmos_taxon_status (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_korstmos_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_korstmos_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen' AND bedekkingsklasse_raw IS NOT NULL
      AND bedekkingsrang IN (1,2) AND bronrecordaantal>0)
    OR (waarnemingsstatus='waargenomen_abundantieconflict'
      AND bedekkingsklasse_raw IS NULL AND bedekkingsrang IS NULL
      AND bronrecordaantal>1)
    OR (waarnemingsstatus='echte_nul' AND bedekkingsklasse_raw IS NULL
      AND bedekkingsrang=0 AND bronrecordaantal=0)
  )
) ENGINE=InnoDB;

-- Reconstructie van 02.204 Meetnet mossen (NEM). De native meeteenheid is
-- een volledig geïnventariseerd RD-kilometerhok. Datumclusters binnen hetzelfde
-- hok zijn onderdelen van één inventarisatie en worden niet als onafhankelijke
-- herhaaltellingen behandeld.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_mos_inventarisatie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '02.204',
  hoknummer VARCHAR(16) CHARACTER SET ascii NOT NULL,
  begindatum DATE NOT NULL,
  einddatum DATE NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  jaarstatus ENUM('binnen_een_jaar','overspant_jaargrens') NOT NULL,
  datumclusteraantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  lijststatus ENUM('volledige_soortenlijst_protocolconform') NOT NULL,
  inspanningstatus ENUM('protocolconform_bezoekduur_niet_meegeleverd') NOT NULL,
  plotstatus ENUM('kilometerhok_niet_naar_sovonplot_toegewezen') NOT NULL,
  kwaliteitsnotitie VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel),
  UNIQUE KEY uq_ndff_mos_hok (reconstructieversie, hoknummer),
  CHECK (einddatum >= begindatum),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_mos_datumcluster (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  datumcluster_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATE NOT NULL,
  periode_stop DATE NOT NULL,
  tijdprecisie ENUM('dag','jaar') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  brongeometrieaantal SMALLINT UNSIGNED NOT NULL,
  clusterstatus ENUM('onderdeel_kilometerhokinventarisatie_geen_zelfstandig_bezoek') NOT NULL,
  kwaliteitsnotitie VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, datumcluster_sleutel),
  UNIQUE KEY uq_ndff_mos_inventarisatie_periode
    (reconstructieversie, inventarisatie_sleutel, periode_start, periode_stop),
  CONSTRAINT fk_ndff_mos_datumcluster_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_mos_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CHECK (periode_stop > periode_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_mos_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  canonieke_waarneming_id BIGINT UNSIGNED NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  datumcluster_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM(
    'opgenomen','dubbele_registratie_onderdrukt','abundantieconflict_bewaard'
  ) NOT NULL,
  selectiereden VARCHAR(1000) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_mos_selectie_canoniek
    (reconstructieversie, canonieke_waarneming_id),
  CONSTRAINT fk_ndff_mos_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_mos_selectie_canoniek FOREIGN KEY
    (canonieke_waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_mos_selectie_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_mos_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CONSTRAINT fk_ndff_mos_selectie_datumcluster FOREIGN KEY
    (reconstructieversie, datumcluster_sleutel)
    REFERENCES Meijendel.ndff_mos_datumcluster
      (reconstructieversie, datumcluster_sleutel),
  CHECK (
    (selectiestatus IN ('opgenomen','dubbele_registratie_onderdrukt')
      AND canonieke_waarneming_id IS NOT NULL)
    OR (selectiestatus='abundantieconflict_bewaard'
      AND canonieke_waarneming_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_mos_doelbereik (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  afleidingsregel ENUM('openbaar_taxon_waargenomen_in_02_204_inventarisatie') NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  positieve_inventarisatieaantal SMALLINT UNSIGNED NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, wetenschappelijke_naam),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_mos_inventarisatie_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM(
    'waargenomen_aantalsklasse','waargenomen_presentie',
    'waargenomen_abundantieconflict','echte_nul'
  ) NOT NULL,
  bron_schaal VARCHAR(64) NULL,
  aantalsklasse_raw VARCHAR(64) NULL,
  aantalsrang TINYINT UNSIGNED NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulregel ENUM('niet_gemeld_op_volledige_02_204_soortenlijst') NOT NULL,
  kwaliteitsnotitie VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_mos_taxon_status (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_mos_taxon_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_mos_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen_aantalsklasse'
      AND bron_schaal='BLWG-aantalsklassen' AND aantalsklasse_raw IS NOT NULL
      AND aantalsrang IN (1,2,3) AND bronrecordaantal>0)
    OR (waarnemingsstatus='waargenomen_presentie'
      AND bron_schaal IN ('aanwezig','voorkomen') AND aantalsklasse_raw='minimaal 1.0'
      AND aantalsrang IS NULL AND bronrecordaantal>0)
    OR (waarnemingsstatus='waargenomen_abundantieconflict'
      AND bron_schaal IS NULL AND aantalsklasse_raw IS NULL
      AND aantalsrang IS NULL AND bronrecordaantal>1)
    OR (waarnemingsstatus='echte_nul' AND bron_schaal IS NULL
      AND aantalsklasse_raw IS NULL AND aantalsrang=0 AND bronrecordaantal=0)
  )
) ENGINE=InnoDB;

-- Reconstructie van 12.001 FLORON-streeplijsten. De native meeteenheid is
-- een RD-kilometerhok per inventarisatiejaar. Omdat de FFV-export het
-- oorspronkelijke veld 'volledigheid onderzoek' niet bevat, worden nullen
-- uitsluitend afgeleid voor hok-jaren met minimaal 50 geregistreerde taxa en
-- blijven zij expliciet voorlopig.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_florbase_inventarisatie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '12.001',
  hok_x SMALLINT UNSIGNED NOT NULL,
  hok_y SMALLINT UNSIGNED NOT NULL,
  hoknummer VARCHAR(16) CHARACTER SET ascii NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  begindatum DATE NOT NULL,
  einddatum DATE NOT NULL,
  datumclusteraantal SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  lijststatus ENUM('volledige_lijst_aannemelijk','fragment') NOT NULL,
  volledigheidsdrempel_taxa SMALLINT UNSIGNED NOT NULL DEFAULT 50,
  volledigheidsstatus ENUM(
    'afgeleid_minimaal_50_taxa','onvoldoende_voor_nulafleiding'
  ) NOT NULL,
  inspanningstatus ENUM('bezoekduur_en_volledigheidsvlag_niet_meegeleverd') NOT NULL,
  plotstatus ENUM('kilometerhok_niet_naar_sovonplot_toegewezen') NOT NULL,
  kwaliteitsnotitie VARCHAR(1600) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel),
  UNIQUE KEY uq_ndff_florbase_hokjaar
    (reconstructieversie, hok_x, hok_y, jaar),
  CHECK (einddatum >= begindatum),
  CHECK (volledigheidsdrempel_taxa = 50),
  CHECK (
    (lijststatus='volledige_lijst_aannemelijk'
      AND geregistreerde_taxa>=volledigheidsdrempel_taxa
      AND volledigheidsstatus='afgeleid_minimaal_50_taxa')
    OR (lijststatus='fragment'
      AND geregistreerde_taxa<volledigheidsdrempel_taxa
      AND volledigheidsstatus='onvoldoende_voor_nulafleiding')
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_florbase_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM('opgenomen_volledige_lijst','opgenomen_fragment') NOT NULL,
  selectiereden VARCHAR(1200) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_florbase_selectie_inventarisatie
    (reconstructieversie, inventarisatie_sleutel),
  CONSTRAINT fk_ndff_florbase_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_florbase_selectie_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_florbase_inventarisatie
      (reconstructieversie, inventarisatie_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_florbase_doelbereik (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  afleidingsregel ENUM(
    'openbaar_taxon_waargenomen_op_aannemelijk_volledige_12_001_lijst'
  ) NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  positieve_inventarisatieaantal SMALLINT UNSIGNED NOT NULL,
  taxonomiestatus ENUM('historische_checklistversies_niet_meegeleverd') NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, wetenschappelijke_naam),
  CHECK (laatste_jaar >= eerste_jaar)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_florbase_inventarisatie_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  inventarisatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM(
    'waargenomen','protocolnul_onder_volledigheidsaanname'
  ) NOT NULL,
  meetwaardestatus ENUM(
    'alleen_presentie','aantalsinformatie_niet_aggregeerbaar','niet_van_toepassing'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM(
    'niet_gemeld_op_12_001_hokjaar_met_minimaal_50_taxa',
    'niet_van_toepassing'
  ) NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, inventarisatie_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_florbase_taxon_status (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_florbase_taxon_inventarisatie FOREIGN KEY
    (reconstructieversie, inventarisatie_sleutel)
    REFERENCES Meijendel.ndff_florbase_inventarisatie
      (reconstructieversie, inventarisatie_sleutel),
  CHECK (
    (waarnemingsstatus='waargenomen' AND bronrecordaantal>0
      AND meetwaardestatus<>'niet_van_toepassing'
      AND nulregel='niet_van_toepassing')
    OR (waarnemingsstatus='protocolnul_onder_volledigheidsaanname'
      AND bronrecordaantal=0 AND meetwaardestatus='niet_van_toepassing'
      AND nulregel='niet_gemeld_op_12_001_hokjaar_met_minimaal_50_taxa')
  )
) ENGINE=InnoDB;

-- Openbare reconstructie van HabSlak-protocol 04.006. Een monster is een
-- unieke combinatie van kalenderdatum en onvervaagde openbare geometrie.
-- Beschermde exacte vindplaatsen worden niet naar deze tabellen gekopieerd.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_habslak_monster (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  monster_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '04.006',
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  hoknummer VARCHAR(64) NULL,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  centroide_x_rd DECIMAL(12,3) NOT NULL,
  centroide_y_rd DECIMAL(12,3) NOT NULL,
  oppervlakte_m2 DECIMAL(20,3) NOT NULL,
  eenduidig_plot_id INT NULL,
  plotstatus ENUM(
    'single_volledig_binnen','single_deels','multiple','outside','ongeldig'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  doelbereikstatus ENUM('monstertype_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, monster_sleutel),
  UNIQUE KEY uq_ndff_habslak_monster
    (reconstructieversie, bezoekdatum, openbare_geometrie_sha256),
  KEY ix_ndff_habslak_monster_hokjaar (hoknummer, jaar),
  CHECK (bronrecordaantal > 0),
  CHECK (geregistreerde_taxa > 0),
  CHECK (
    (plotstatus='single_volledig_binnen' AND eenduidig_plot_id IS NOT NULL)
    OR (plotstatus<>'single_volledig_binnen' AND eenduidig_plot_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_habslak_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  monster_sleutel CHAR(64) CHARACTER SET ascii NULL,
  selectiestatus ENUM(
    'opgenomen_monstercontext','vervaagde_doelsoort_alleen_hokjaar',
    'vervaagde_bijvangst_alleen_positief'
  ) NOT NULL,
  doelrelatie ENUM('doelsoort','begeleidende_soort') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_habslak_selectie_monster
    (reconstructieversie, monster_sleutel),
  CONSTRAINT fk_ndff_habslak_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_habslak_selectie_monster FOREIGN KEY
    (reconstructieversie, monster_sleutel)
    REFERENCES Meijendel.ndff_habslak_monster
      (reconstructieversie, monster_sleutel),
  CHECK (
    (selectiestatus='opgenomen_monstercontext' AND monster_sleutel IS NOT NULL)
    OR (selectiestatus<>'opgenomen_monstercontext' AND monster_sleutel IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_habslak_monster_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  monster_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','begeleidende_soort') NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulstatus ENUM('niet_van_toepassing') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, monster_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_habslak_taxon_status (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_habslak_taxon_monster FOREIGN KEY
    (reconstructieversie, monster_sleutel)
    REFERENCES Meijendel.ndff_habslak_monster
      (reconstructieversie, monster_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_habslak_hokjaar (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '04.006',
  hoknummer VARCHAR(64) NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  doelsoort VARCHAR(255) NOT NULL DEFAULT 'Vertigo angustior',
  monsteraantal SMALLINT UNSIGNED NOT NULL,
  unieke_monsterlocaties SMALLINT UNSIGNED NOT NULL,
  minimale_monsterlocaties SMALLINT UNSIGNED NOT NULL DEFAULT 15,
  bemonsteringsstatus ENUM('voldoende_minimaal_15','onvoldoende_minder_dan_15') NOT NULL,
  doelsoort_bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  doelsoortstatus ENUM(
    'waargenomen','protocolnul_onder_doelbereikaanname',
    'niet_beoordeelbaar_onvoldoende_bemonsterd'
  ) NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel),
  UNIQUE KEY uq_ndff_habslak_hokjaar
    (reconstructieversie, hoknummer, jaar, doelsoort),
  CHECK (monsteraantal >= unieke_monsterlocaties),
  CHECK (minimale_monsterlocaties = 15),
  CHECK (
    (doelsoortstatus='waargenomen' AND doelsoort_bronrecordaantal>0)
    OR (doelsoortstatus<>'waargenomen' AND doelsoort_bronrecordaantal=0)
  ),
  CHECK (
    (bemonsteringsstatus='voldoende_minimaal_15' AND unieke_monsterlocaties>=15)
    OR (bemonsteringsstatus='onvoldoende_minder_dan_15' AND unieke_monsterlocaties<15)
  )
) ENGINE=InnoDB;

-- Conservatieve openbare reconstructie van braakbalprotocol 17.002. De
-- brongeometrie is meestal tot 10 x 10 km vervaagd en oorspronkelijke
-- partij-/nest-ID's ontbreken. Daarom zijn dit uitsluitend positieve,
-- regionale hok-jaaraggregaten: geen bezoekmatrix, nullen of plotkoppelingen.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_braakbal_hokjaar (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '17.002',
  jaar SMALLINT UNSIGNED NOT NULL,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  centroide_x_rd DECIMAL(12,3) NOT NULL,
  centroide_y_rd DECIMAL(12,3) NOT NULL,
  oppervlakte_m2 DECIMAL(20,3) NOT NULL,
  vervaagd BOOLEAN NOT NULL,
  vervagingsniveau_km TINYINT UNSIGNED NULL,
  bronperiodestatus ENUM(
    'gedateerde_registratie','jaaraggregaat','meerjaaraggregaat','gemengd',
    'overig_interval'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerde_taxa SMALLINT UNSIGNED NOT NULL,
  som_prooidieren INT UNSIGNED NOT NULL,
  veldmuis_aantal INT UNSIGNED NOT NULL,
  veldmuis_aandeel DECIMAL(9,8) NOT NULL,
  inspanningsstatus ENUM(
    'som_minimaal_150_partij_onbekend','som_minder_dan_150'
  ) NOT NULL,
  ruimtelijke_status ENUM('vervaagd_10km','onvervaagd_bronvlak') NOT NULL,
  nulstatus ENUM('geen_nul_afleidbaar') NOT NULL,
  plotstatus ENUM('niet_gekoppeld_grove_brongeometrie') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel),
  UNIQUE KEY uq_ndff_braakbal_hokjaar
    (reconstructieversie, jaar, openbare_geometrie_sha256),
  CHECK (bronrecordaantal > 0),
  CHECK (geregistreerde_taxa > 0),
  CHECK (som_prooidieren > 0),
  CHECK (veldmuis_aantal <= som_prooidieren),
  CHECK (veldmuis_aandeel >= 0 AND veldmuis_aandeel <= 1),
  CHECK (
    (vervaagd=1 AND ruimtelijke_status='vervaagd_10km'
      AND vervagingsniveau_km=10)
    OR (vervaagd=0 AND ruimtelijke_status='onvervaagd_bronvlak'
      AND vervagingsniveau_km IS NULL)
  ),
  CHECK (
    (inspanningsstatus='som_minimaal_150_partij_onbekend'
      AND som_prooidieren>=150)
    OR (inspanningsstatus='som_minder_dan_150' AND som_prooidieren<150)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_braakbal_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM(
    'vervaagd_regionale_positieve_context',
    'onvervaagd_losse_protocolregistratie'
  ) NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_braakbal_selectie_hokjaar
    (reconstructieversie, hokjaar_sleutel),
  CONSTRAINT fk_ndff_braakbal_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_braakbal_selectie_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_braakbal_hokjaar
      (reconstructieversie, hokjaar_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_braakbal_hokjaar_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  totaal_aantal INT UNSIGNED NOT NULL,
  aandeel_prooidieren DECIMAL(9,8) NOT NULL,
  nulstatus ENUM('niet_van_toepassing_positief') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel, wetenschappelijke_naam),
  KEY ix_ndff_braakbal_taxon_status
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_braakbal_taxon_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_braakbal_hokjaar
      (reconstructieversie, hokjaar_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (totaal_aantal > 0),
  CHECK (aandeel_prooidieren > 0 AND aandeel_prooidieren <= 1)
) ENGINE=InnoDB;

-- Openbare reconstructie van Jaarrond Tuintelling 102.002. De 250 m-vakken
-- zijn privacygeometrieën en geen bewezen tuin-ID's. Alleen een positieve regel
-- bewijst dat de betreffende soortgroep in die periode is geteld.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_tuinvakfamilie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  tuinvakfamilie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '102.002',
  geometrieversies SMALLINT UNSIGNED NOT NULL,
  eerste_periode DATETIME NOT NULL,
  laatste_periode DATETIME NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  identificatiestatus ENUM('afgeleid_binnen_1_meter_geen_tuin_id') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, tuinvakfamilie_sleutel),
  CHECK (geometrieversies > 0),
  CHECK (bronrecordaantal > 0),
  CHECK (laatste_periode >= eerste_periode)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_geometrie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  tuinvakfamilie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  centroide_x_rd DECIMAL(12,3) NOT NULL,
  centroide_y_rd DECIMAL(12,3) NOT NULL,
  oppervlakte_m2 DECIMAL(20,3) NOT NULL,
  eerste_jaar SMALLINT UNSIGNED NOT NULL,
  laatste_jaar SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('outside','multiple','gemengd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, openbare_geometrie_sha256),
  KEY ix_ndff_tuintelling_geometrie_familie
    (reconstructieversie, tuinvakfamilie_sleutel),
  CONSTRAINT fk_ndff_tuintelling_geometrie_familie FOREIGN KEY
    (reconstructieversie, tuinvakfamilie_sleutel)
    REFERENCES Meijendel.ndff_tuintelling_tuinvakfamilie
      (reconstructieversie, tuinvakfamilie_sleutel),
  CHECK (oppervlakte_m2 > 0),
  CHECK (laatste_jaar >= eerste_jaar),
  CHECK (bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_telperiode (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  telperiode_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  tuinvakfamilie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  teltype ENUM('weektelling','dagperiode','tijdstiptelling','overige_periode') NOT NULL,
  methodeversie ENUM('voor_vernieuwing_2022') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  getelde_soortgroepen SMALLINT UNSIGNED NOT NULL,
  plotstatus ENUM('niet_gekoppeld_geen_meijendelplot') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, telperiode_sleutel),
  UNIQUE KEY uq_ndff_tuintelling_telperiode
    (reconstructieversie, tuinvakfamilie_sleutel, periode_start, periode_stop),
  CONSTRAINT fk_ndff_tuintelling_periode_familie FOREIGN KEY
    (reconstructieversie, tuinvakfamilie_sleutel)
    REFERENCES Meijendel.ndff_tuintelling_tuinvakfamilie
      (reconstructieversie, tuinvakfamilie_sleutel),
  CHECK (periode_stop > periode_start),
  CHECK (bronrecordaantal > 0),
  CHECK (getelde_soortgroepen > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_periode_soortgroep (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  telperiode_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  waargenomen_taxa SMALLINT UNSIGNED NOT NULL,
  lokale_doelsoorten SMALLINT UNSIGNED NOT NULL,
  selectiebewijs ENUM('positieve_regel_bevestigt_getelde_soortgroep') NOT NULL,
  doelbereikstatus ENUM('alleen_lokaal_aangetroffen_taxa') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, telperiode_sleutel, soortgroep_raw),
  CONSTRAINT fk_ndff_tuintelling_groep_periode FOREIGN KEY
    (reconstructieversie, telperiode_sleutel)
    REFERENCES Meijendel.ndff_tuintelling_telperiode
      (reconstructieversie, telperiode_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (waargenomen_taxa > 0),
  CHECK (lokale_doelsoorten >= waargenomen_taxa)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_periode_soortgroep_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  telperiode_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM(
    'waargenomen','protocolnul_binnen_lokaal_doelbereik'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM(
    'niet_van_toepassing',
    'niet_gemeld_binnen_positief_bevestigde_soortgroeptelling'
  ) NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (
    reconstructieversie, telperiode_sleutel, soortgroep_raw,
    wetenschappelijke_naam
  ),
  KEY ix_ndff_tuintelling_taxon_status
    (wetenschappelijke_naam, waarnemingsstatus),
  CONSTRAINT fk_ndff_tuintelling_taxon_groep FOREIGN KEY
    (reconstructieversie, telperiode_sleutel, soortgroep_raw)
    REFERENCES Meijendel.ndff_tuintelling_periode_soortgroep
      (reconstructieversie, telperiode_sleutel, soortgroep_raw),
  CHECK (
    (waarnemingsstatus='waargenomen' AND bronrecordaantal>0
      AND JSON_LENGTH(meetwaarden_json)>0
      AND nulregel='niet_van_toepassing')
    OR (waarnemingsstatus='protocolnul_binnen_lokaal_doelbereik'
      AND bronrecordaantal=0 AND JSON_LENGTH(meetwaarden_json)=0
      AND nulregel='niet_gemeld_binnen_positief_bevestigde_soortgroeptelling')
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_tuintelling_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  telperiode_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM('regionale_protocolcontext_geen_meijendelplot') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_tuintelling_selectie_periode
    (reconstructieversie, telperiode_sleutel),
  CONSTRAINT fk_ndff_tuintelling_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_tuintelling_selectie_periode FOREIGN KEY
    (reconstructieversie, telperiode_sleutel)
    REFERENCES Meijendel.ndff_tuintelling_telperiode
      (reconstructieversie, telperiode_sleutel)
) ENGINE=InnoDB;

-- Openbare reconstructie van LiveAtlas 102.005. Gelijke begin- en eindtijd
-- vormen een afgeleid bezoek. De NDFF-levering bevat geen route-ID, route en
-- geen complete-lijststatus per soortgroep; daarom worden geen nullen afgeleid.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_liveatlas_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '102.005',
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  duur_minuten SMALLINT UNSIGNED NOT NULL,
  duurstatus ENUM('korter_dan_15','binnen_advies_15_90','langer_dan_90') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geometrieversies SMALLINT UNSIGNED NOT NULL,
  soortgroepen_met_positieve_regels SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('single_volledig_binnen','multiple','outside','gemengd') NOT NULL,
  plotversie_id BIGINT UNSIGNED NULL,
  eenduidig_plot_id INT NULL,
  routestatus ENUM('route_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  UNIQUE KEY uq_ndff_liveatlas_bezoek
    (reconstructieversie, periode_start, periode_stop),
  CONSTRAINT fk_ndff_liveatlas_bezoek_plot FOREIGN KEY
    (plotversie_id, eenduidig_plot_id)
    REFERENCES Meijendel.ndff_sovon_plot (plotversie_id, plot_id),
  CHECK (periode_stop > periode_start),
  CHECK (duur_minuten > 0),
  CHECK (bronrecordaantal > 0),
  CHECK (geometrieversies > 0),
  CHECK (soortgroepen_met_positieve_regels > 0),
  CHECK (
    (ruimtelijke_status='single_volledig_binnen'
      AND plotversie_id IS NOT NULL AND eenduidig_plot_id IS NOT NULL)
    OR (ruimtelijke_status<>'single_volledig_binnen'
      AND plotversie_id IS NULL AND eenduidig_plot_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_liveatlas_bezoek_soortgroep (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  waargenomen_taxa SMALLINT UNSIGNED NOT NULL,
  volledigheidsstatus ENUM('niet_meegeleverd') NOT NULL,
  nulstatus ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, soortgroep_raw),
  CONSTRAINT fk_ndff_liveatlas_soortgroep_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_liveatlas_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (waargenomen_taxa > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_liveatlas_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  totaal_aantal INT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (
    reconstructieversie, bezoek_sleutel, soortgroep_raw,
    wetenschappelijke_naam
  ),
  KEY ix_ndff_liveatlas_taxon
    (wetenschappelijke_naam, soortgroep_raw),
  CONSTRAINT fk_ndff_liveatlas_taxon_soortgroep FOREIGN KEY
    (reconstructieversie, bezoek_sleutel, soortgroep_raw)
    REFERENCES Meijendel.ndff_liveatlas_bezoek_soortgroep
      (reconstructieversie, bezoek_sleutel, soortgroep_raw),
  CHECK (bronrecordaantal > 0),
  CHECK (totaal_aantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_liveatlas_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  ruimtelijke_status ENUM('single_volledig_binnen','single_deels','multiple','outside','ongeldig') NOT NULL,
  eenduidig_plot_id INT NULL,
  selectiestatus ENUM('positief_protocolrecord_geen_nulafleiding') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_liveatlas_selectie_bezoek
    (reconstructieversie, bezoek_sleutel),
  CONSTRAINT fk_ndff_liveatlas_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_liveatlas_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_liveatlas_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (
    (ruimtelijke_status='single_volledig_binnen' AND eenduidig_plot_id IS NOT NULL)
    OR (ruimtelijke_status<>'single_volledig_binnen' AND eenduidig_plot_id IS NULL)
  )
) ENGINE=InnoDB;

-- Openbare reconstructie van Kwartiertellingen 102.007. Gelijke begin- en
-- eindtijd vormen een afgeleid telinterval. De FFV-levering bevat de gelopen
-- route en het onderscheid tussen complete lijst en soortgerichte telling niet;
-- daarom worden geen routes of nullen afgeleid.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_kwartiertelling_telinterval (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  interval_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '102.007',
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  duur_minuten SMALLINT UNSIGNED NOT NULL,
  duurstatus ENUM(
    'korter_dan_15_toegestaan',
    'protocolconform_15_minuten',
    'bronafwijking_boven_15_minuten'
  ) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geometrieversies SMALLINT UNSIGNED NOT NULL,
  soortgroepen_met_positieve_regels SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM(
    'single_volledig_binnen','multiple','outside','gemengd'
  ) NOT NULL,
  plotversie_id BIGINT UNSIGNED NULL,
  eenduidig_plot_id INT NULL,
  routestatus ENUM('route_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, interval_sleutel),
  UNIQUE KEY uq_ndff_kwartiertelling_interval
    (reconstructieversie, periode_start, periode_stop),
  CONSTRAINT fk_ndff_kwartiertelling_interval_plot FOREIGN KEY
    (plotversie_id, eenduidig_plot_id)
    REFERENCES Meijendel.ndff_sovon_plot (plotversie_id, plot_id),
  CHECK (periode_stop > periode_start),
  CHECK (duur_minuten > 0),
  CHECK (bronrecordaantal > 0),
  CHECK (geometrieversies > 0),
  CHECK (soortgroepen_met_positieve_regels > 0),
  CHECK (
    (ruimtelijke_status='single_volledig_binnen'
      AND plotversie_id IS NOT NULL AND eenduidig_plot_id IS NOT NULL)
    OR (ruimtelijke_status<>'single_volledig_binnen'
      AND plotversie_id IS NULL AND eenduidig_plot_id IS NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_kwartiertelling_interval_soortgroep (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  interval_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  waargenomen_taxa SMALLINT UNSIGNED NOT NULL,
  volledigheidsstatus ENUM(
    'niet_meegeleverd_ononderscheidbaar_soortgericht'
  ) NOT NULL,
  nulstatus ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, interval_sleutel, soortgroep_raw),
  CONSTRAINT fk_ndff_kwartiertelling_soortgroep_interval FOREIGN KEY
    (reconstructieversie, interval_sleutel)
    REFERENCES Meijendel.ndff_kwartiertelling_telinterval
      (reconstructieversie, interval_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (waargenomen_taxa > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_kwartiertelling_interval_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  interval_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  soortgroep_raw VARCHAR(255) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  totaal_aantal INT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (
    reconstructieversie, interval_sleutel, soortgroep_raw,
    wetenschappelijke_naam
  ),
  KEY ix_ndff_kwartiertelling_taxon
    (wetenschappelijke_naam, soortgroep_raw),
  CONSTRAINT fk_ndff_kwartiertelling_taxon_soortgroep FOREIGN KEY
    (reconstructieversie, interval_sleutel, soortgroep_raw)
    REFERENCES Meijendel.ndff_kwartiertelling_interval_soortgroep
      (reconstructieversie, interval_sleutel, soortgroep_raw),
  CHECK (bronrecordaantal > 0),
  CHECK (totaal_aantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_kwartiertelling_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  interval_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  ruimtelijke_status ENUM(
    'single_volledig_binnen','single_deels','multiple','outside','ongeldig'
  ) NOT NULL,
  eenduidig_plot_id INT NULL,
  selectiestatus ENUM('positief_protocolrecord_geen_nulafleiding') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  KEY ix_ndff_kwartiertelling_selectie_interval
    (reconstructieversie, interval_sleutel),
  CONSTRAINT fk_ndff_kwartiertelling_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_kwartiertelling_selectie_interval FOREIGN KEY
    (reconstructieversie, interval_sleutel)
    REFERENCES Meijendel.ndff_kwartiertelling_telinterval
      (reconstructieversie, interval_sleutel),
  CHECK (
    (ruimtelijke_status='single_volledig_binnen' AND eenduidig_plot_id IS NOT NULL)
    OR (ruimtelijke_status<>'single_volledig_binnen' AND eenduidig_plot_id IS NULL)
  )
) ENGINE=InnoDB;

-- Resterende NEM-reeksen. Deze tabellen bewaren de native, uit de openbare
-- levering reconstrueerbare eenheid. Alleen bij 13.201 wordt een niet-gemelde
-- doelsoort vastgelegd; dat is nadrukkelijk geen protocolnul.
CREATE TABLE IF NOT EXISTS Meijendel.ndff_nachtvlinder_hokjaar (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '03.203',
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  hoknummer VARCHAR(64) NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('multiple') NOT NULL,
  telstatus ENUM('positieve_jaargegevens_geen_bezoekstructuur') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel),
  UNIQUE KEY uq_ndff_nachtvlinder_hokjaar
    (reconstructieversie, openbare_geometrie_sha256, jaar),
  CHECK (bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_nachtvlinder_hokjaar_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(500) NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerd_aantal INT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_nachtvlinder_taxon_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_nachtvlinder_hokjaar
      (reconstructieversie, hokjaar_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (geregistreerd_aantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_nachtvlinder_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM('vervaagd_positief_hokjaar') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  CONSTRAINT fk_ndff_nachtvlinder_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_nachtvlinder_selectie_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_nachtvlinder_hokjaar
      (reconstructieversie, hokjaar_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_verspreiding_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '11.204',
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  hoknummer VARCHAR(64) NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('multiple') NOT NULL,
  volledigheidsstatus ENUM('waarnemerskennis_onbekend_geen_complete_lijst') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  CHECK (periode_stop > periode_start),
  CHECK (bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_verspreiding_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(500) NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_bospaddenstoel_verspreiding_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_bospaddenstoel_verspreiding_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_bospaddenstoel_verspreiding_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM('positief_bezoek_geen_nulafleiding') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  CONSTRAINT fk_ndff_bospaddenstoel_verspreiding_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_bospaddenstoel_verspreiding_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_bospaddenstoel_verspreiding_bezoek
      (reconstructieversie, bezoek_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_poldervis_waterlocatie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waterlocatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '13.201',
  openbare_geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('single_volledig_binnen','outside') NOT NULL,
  plotversie_id BIGINT UNSIGNED NULL,
  eenduidig_plot_id INT NULL,
  identificatiestatus ENUM('openbare_geometrie_als_waterproxy') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waterlocatie_sleutel),
  CONSTRAINT fk_ndff_poldervis_waterlocatie_plot FOREIGN KEY
    (plotversie_id, eenduidig_plot_id)
    REFERENCES Meijendel.ndff_sovon_plot (plotversie_id, plot_id),
  CHECK (bronrecordaantal > 0),
  CHECK ((ruimtelijke_status='single_volledig_binnen' AND eenduidig_plot_id IS NOT NULL)
    OR (ruimtelijke_status='outside' AND eenduidig_plot_id IS NULL))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_poldervis_bezoek (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  waterlocatie_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  periode_start DATETIME NOT NULL,
  periode_stop DATETIME NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  methodestatus ENUM('submethode_en_inspanning_niet_meegeleverd') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel),
  CONSTRAINT fk_ndff_poldervis_bezoek_water FOREIGN KEY
    (reconstructieversie, waterlocatie_sleutel)
    REFERENCES Meijendel.ndff_poldervis_waterlocatie
      (reconstructieversie, waterlocatie_sleutel),
  CHECK (periode_stop > periode_start),
  CHECK (bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_poldervis_bezoek_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(500) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  waarnemingsstatus ENUM('waargenomen','doelsoort_niet_gemeld') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerd_aantal INT UNSIGNED NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('niet_van_toepassing','geen_nul_doelmethode_onbekend') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, bezoek_sleutel, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_poldervis_taxon_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_poldervis_bezoek
      (reconstructieversie, bezoek_sleutel),
  CHECK ((waarnemingsstatus='waargenomen' AND bronrecordaantal>0
      AND geregistreerd_aantal>0 AND JSON_LENGTH(meetwaarden_json)>0
      AND nulregel='niet_van_toepassing')
    OR (waarnemingsstatus='doelsoort_niet_gemeld' AND doelrelatie='doelsoort'
      AND bronrecordaantal=0 AND geregistreerd_aantal IS NULL
      AND JSON_LENGTH(meetwaarden_json)=0
      AND nulregel='geen_nul_doelmethode_onbekend'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_poldervis_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  bezoek_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  selectiestatus ENUM('positief_protocolrecord') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  CONSTRAINT fk_ndff_poldervis_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_poldervis_selectie_bezoek FOREIGN KEY
    (reconstructieversie, bezoek_sleutel)
    REFERENCES Meijendel.ndff_poldervis_bezoek
      (reconstructieversie, bezoek_sleutel)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_otter_bever_hokjaar (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  protocol_sleutel VARCHAR(16) CHARACTER SET ascii NOT NULL DEFAULT '17.207',
  hoknummer VARCHAR(64) NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  ruimtelijke_status ENUM('meerdere_plots_binnen_hok') NOT NULL,
  volledigheidsstatus ENUM('alleen_positieve_records_geen_waarnemersdekking') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel),
  UNIQUE KEY uq_ndff_otter_bever_hokjaar
    (reconstructieversie, hoknummer, jaar),
  CHECK (bronrecordaantal > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_otter_bever_hokjaar_taxon (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  wetenschappelijke_naam VARCHAR(500) NOT NULL,
  doelrelatie ENUM('doelsoort') NOT NULL,
  waarnemingsstatus ENUM('waargenomen') NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  geregistreerd_aantal INT UNSIGNED NOT NULL,
  meetwaarden_json JSON NOT NULL,
  nulregel ENUM('geen_nul_afleidbaar') NOT NULL,
  kwaliteitsnotitie VARCHAR(1800) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, hokjaar_sleutel, wetenschappelijke_naam),
  CONSTRAINT fk_ndff_otter_bever_taxon_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_otter_bever_hokjaar
      (reconstructieversie, hokjaar_sleutel),
  CHECK (bronrecordaantal > 0),
  CHECK (geregistreerd_aantal > 0),
  CHECK (JSON_LENGTH(meetwaarden_json) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.ndff_otter_bever_recordselectie (
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  waarneming_id BIGINT UNSIGNED NOT NULL,
  hokjaar_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  eenduidig_plot_id INT NOT NULL,
  selectiestatus ENUM('positieve_puntcontext_geen_hoknul') NOT NULL,
  selectiereden VARCHAR(1400) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (reconstructieversie, waarneming_id),
  CONSTRAINT fk_ndff_otter_bever_selectie_waarneming FOREIGN KEY
    (waarneming_id) REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CONSTRAINT fk_ndff_otter_bever_selectie_hokjaar FOREIGN KEY
    (reconstructieversie, hokjaar_sleutel)
    REFERENCES Meijendel.ndff_otter_bever_hokjaar
      (reconstructieversie, hokjaar_sleutel)
) ENGINE=InnoDB;

-- Primaire SOVON/AVIMAP-bron voor niet-vogelwaarnemingen tijdens BMP-bezoeken.
-- Deze laag staat in Meijendel. Alleen vogelbronregels worden niet geïmporteerd;
-- de afzonderlijke vogelaudit blijft uitsluitend-lezen.
CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_import_batch (
  batch_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  regelversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bronproject_id INT NOT NULL,
  bronmap VARCHAR(1000) NOT NULL,
  bronmanifest_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  bronbestanden_json JSON NOT NULL,
  ontvangen_op DATE NOT NULL,
  actueel TINYINT(1) NOT NULL DEFAULT 1,
  niet_vogel_records INT UNSIGNED NOT NULL,
  niet_vogel_bezoeken INT UNSIGNED NOT NULL,
  niet_vogel_taxa SMALLINT UNSIGNED NOT NULL,
  kwaliteitsnotitie VARCHAR(1500) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id),
  UNIQUE KEY uq_sovon_avimap_manifest (bronmanifest_sha256),
  KEY ix_sovon_avimap_batch_actueel (actueel, ontvangen_op),
  CHECK (actueel IN (0,1)),
  CHECK (niet_vogel_records > 0 AND niet_vogel_bezoeken > 0 AND niet_vogel_taxa > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_taxon (
  batch_id BIGINT UNSIGNED NOT NULL,
  soortgroep_code INT NOT NULL,
  soortnr INT NOT NULL,
  soortgroep_naam VARCHAR(100) NOT NULL,
  nederlandse_naam VARCHAR(255) NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NULL,
  taxon_mapping_status ENUM('exact_ndff','handmatig_referentie','niet_eenduidig') NOT NULL,
  ndff_soort_id BIGINT UNSIGNED NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id, soortgroep_code, soortnr),
  KEY ix_sovon_avimap_taxon_naam (nederlandse_naam),
  KEY ix_sovon_avimap_taxon_ndff (ndff_soort_id),
  CONSTRAINT fk_sovon_avimap_taxon_batch FOREIGN KEY (batch_id)
    REFERENCES Meijendel.sovon_avimap_import_batch (batch_id),
  CONSTRAINT fk_sovon_avimap_taxon_ndff FOREIGN KEY (ndff_soort_id)
    REFERENCES Meijendel.ndff_soorten (ndff_soort_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_bezoek (
  batch_id BIGINT UNSIGNED NOT NULL,
  bron_bezoek_id INT NOT NULL,
  bronproject_id INT NOT NULL,
  plot_id INT NOT NULL,
  plotnaam VARCHAR(255) NOT NULL,
  bezoekdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  dagvanjaar SMALLINT UNSIGNED NULL,
  begintijd TIME NULL,
  eindtijd TIME NULL,
  bezoekduur_min SMALLINT UNSIGNED NULL,
  deelbezoek TINYINT(1) NOT NULL DEFAULT 0,
  deelbezoek_deel VARCHAR(50) NULL,
  gunstig TINYINT(1) NULL,
  omstandigheden_opm VARCHAR(1000) NULL,
  opmerking VARCHAR(1000) NULL,
  bron_aantal_soorten SMALLINT UNSIGNED NULL,
  bron_aantal_records INT UNSIGNED NULL,
  niet_vogel_recordaantal SMALLINT UNSIGNED NOT NULL,
  lopend_jaar TINYINT(1) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id, bron_bezoek_id),
  KEY ix_sovon_avimap_bezoek_plot_jaar (plot_id, jaar, bezoekdatum),
  CONSTRAINT fk_sovon_avimap_bezoek_batch FOREIGN KEY (batch_id)
    REFERENCES Meijendel.sovon_avimap_import_batch (batch_id),
  CHECK (jaar = YEAR(bezoekdatum)),
  CHECK (niet_vogel_recordaantal > 0),
  CHECK (deelbezoek IN (0,1) AND (gunstig IS NULL OR gunstig IN (0,1))
    AND lopend_jaar IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_waarneming (
  batch_id BIGINT UNSIGNED NOT NULL,
  bron_waarneming_id INT NOT NULL,
  bron_bezoek_id INT NOT NULL,
  bronproject_id INT NOT NULL,
  kopid INT NULL,
  plot_id INT NOT NULL,
  telgebied VARCHAR(255) NOT NULL,
  soortgroep_code INT NOT NULL,
  soortnr INT NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  waarnemingsdatum DATE NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  maand TINYINT UNSIGNED NOT NULL,
  dag TINYINT UNSIGNED NOT NULL,
  dagvanjaar SMALLINT UNSIGNED NULL,
  wrntype VARCHAR(10) NULL,
  broedcode SMALLINT UNSIGNED NULL,
  opmerking VARCHAR(1000) NULL,
  cluster_territorium TINYINT(1) NOT NULL,
  cluster_territorium_id INT NULL,
  in_plot TINYINT(1) NOT NULL,
  ioc_sort INT NULL,
  geslacht VARCHAR(10) NULL,
  x_coord INT NOT NULL,
  y_coord INT NOT NULL,
  geom POINT NOT NULL SRID 28992,
  gegevensrol ENUM('daz_doelsoort','daz_bijvangst','bmp_bijvangst_overig') NOT NULL,
  bronstatus ENUM('primaire_sovon_bron') NOT NULL,
  lopend_jaar TINYINT(1) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id, bron_waarneming_id),
  KEY ix_sovon_avimap_waarneming_bezoek (batch_id, bron_bezoek_id),
  KEY ix_sovon_avimap_waarneming_taxon
    (batch_id, soortgroep_code, soortnr, jaar),
  KEY ix_sovon_avimap_waarneming_plot_jaar (plot_id, jaar),
  SPATIAL KEY sx_sovon_avimap_waarneming_geom (geom),
  CONSTRAINT fk_sovon_avimap_waarneming_batch FOREIGN KEY (batch_id)
    REFERENCES Meijendel.sovon_avimap_import_batch (batch_id),
  CONSTRAINT fk_sovon_avimap_waarneming_bezoek FOREIGN KEY
    (batch_id, bron_bezoek_id)
    REFERENCES Meijendel.sovon_avimap_bezoek (batch_id, bron_bezoek_id),
  CONSTRAINT fk_sovon_avimap_waarneming_taxon FOREIGN KEY
    (batch_id, soortgroep_code, soortnr)
    REFERENCES Meijendel.sovon_avimap_taxon (batch_id, soortgroep_code, soortnr),
  CHECK (aantal > 0),
  CHECK (jaar = YEAR(waarnemingsdatum)),
  CHECK (cluster_territorium IN (0,1) AND in_plot IN (0,1)
    AND lopend_jaar IN (0,1))
) ENGINE=InnoDB;

-- Een NDFF-regel wordt alleen vervangen als in de primaire SOVON-bron
-- dezelfde datum, hetzelfde taxon en hetzelfde kilometerhok voorkomen.
-- Een verschil in telwaarde blijft expliciet zichtbaar als bronconflict.
CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_ndff_daz_koppeling (
  batch_id BIGINT UNSIGNED NOT NULL,
  ndff_waarneming_id BIGINT UNSIGNED NOT NULL,
  koppel_sleutel CHAR(64) CHARACTER SET ascii NOT NULL,
  koppelstatus ENUM('sovon_vervangt_ndff_exact','sovon_vervangt_ndff_telconflict','geen_sovon_overlap') NOT NULL,
  sovon_bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  sovon_aantal_som INT UNSIGNED NULL,
  ndff_recordaantal SMALLINT UNSIGNED NOT NULL,
  ndff_aantal_som INT UNSIGNED NOT NULL,
  sovon_bron_waarneming_ids JSON NOT NULL,
  kwaliteitsnotitie VARCHAR(1500) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id, ndff_waarneming_id),
  KEY ix_sovon_avimap_ndff_status (koppelstatus),
  CONSTRAINT fk_sovon_avimap_ndff_batch FOREIGN KEY (batch_id)
    REFERENCES Meijendel.sovon_avimap_import_batch (batch_id),
  CONSTRAINT fk_sovon_avimap_ndff_waarneming FOREIGN KEY (ndff_waarneming_id)
    REFERENCES Meijendel.ndff_open_waarneming (waarneming_id),
  CHECK (ndff_recordaantal > 0 AND ndff_aantal_som > 0),
  CHECK ((koppelstatus='geen_sovon_overlap' AND sovon_bronrecordaantal=0
      AND sovon_aantal_som IS NULL AND JSON_LENGTH(sovon_bron_waarneming_ids)=0)
    OR (koppelstatus<>'geen_sovon_overlap' AND sovon_bronrecordaantal>0
      AND sovon_aantal_som>0 AND JSON_LENGTH(sovon_bron_waarneming_ids)>0))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Meijendel.sovon_avimap_daz_bezoek_taxon (
  batch_id BIGINT UNSIGNED NOT NULL,
  reconstructieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bron_bezoek_id INT NOT NULL,
  wetenschappelijke_naam VARCHAR(255) NOT NULL,
  nederlandse_naam VARCHAR(255) NOT NULL,
  doelrelatie ENUM('doelsoort','bijvangst') NOT NULL,
  waarnemingsstatus ENUM('waargenomen','echte_nul') NOT NULL,
  aantal INT UNSIGNED NOT NULL,
  bronrecordaantal SMALLINT UNSIGNED NOT NULL,
  nulregel ENUM('volledige_daz_soortenlijst_binnen_bevestigd_bezoek','niet_van_toepassing_bijvangst') NOT NULL,
  lopend_jaar TINYINT(1) NOT NULL,
  kwaliteitsnotitie VARCHAR(1500) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (batch_id, reconstructieversie, bron_bezoek_id, wetenschappelijke_naam),
  KEY ix_sovon_avimap_daz_taxon
    (wetenschappelijke_naam, waarnemingsstatus, doelrelatie),
  CONSTRAINT fk_sovon_avimap_daz_batch FOREIGN KEY (batch_id)
    REFERENCES Meijendel.sovon_avimap_import_batch (batch_id),
  CONSTRAINT fk_sovon_avimap_daz_bezoek FOREIGN KEY (batch_id, bron_bezoek_id)
    REFERENCES Meijendel.sovon_avimap_bezoek (batch_id, bron_bezoek_id),
  CHECK ((waarnemingsstatus='waargenomen' AND aantal>0 AND bronrecordaantal>0)
    OR (waarnemingsstatus='echte_nul' AND doelrelatie='doelsoort'
      AND aantal=0 AND bronrecordaantal=0)),
  CHECK (lopend_jaar IN (0,1))
) ENGINE=InnoDB;
