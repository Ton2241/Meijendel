-- Bronvast model voor werkzaamheden en natuurmaatregelen in Meijendel.
-- MySQL 9.7.1; landelijke codering waar mogelijk volgens Datamodel
-- Natuurmaatregelen 1.2 (13 juni 2026).

USE Meijendel;

CREATE TABLE IF NOT EXISTS maatregel_werkcategorie (
  werkcategorie_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  omschrijving VARCHAR(120) NOT NULL,
  PRIMARY KEY (werkcategorie_code)
) ENGINE=InnoDB;

INSERT INTO maatregel_werkcategorie (werkcategorie_code, omschrijving) VALUES
  ('natuurbeheer', 'Natuurbeheer en natuurherstel'),
  ('waterwinning', 'Waterwinning en hydrologische infrastructuur'),
  ('infrastructuur', 'Gebouwen, kabels, wegen en overige infrastructuur'),
  ('recreatie', 'Recreatievoorzieningen en rustbeheer'),
  ('onderzoek_monitoring', 'Onderzoek en monitoring')
ON DUPLICATE KEY UPDATE omschrijving=VALUES(omschrijving);

CREATE TABLE IF NOT EXISTS maatregel_type (
  maatregeltype_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  omschrijving VARCHAR(160) NOT NULL,
  PRIMARY KEY (maatregeltype_code)
) ENGINE=InnoDB;

INSERT INTO maatregel_type (maatregeltype_code, omschrijving) VALUES
  ('MT01', 'Aanvullend beheer, continu'),
  ('MT02', 'Aanvullend beheer, niet-continu'),
  ('MT03', 'Eenvoudige inrichting'),
  ('MT04', 'Complexe inrichting'),
  ('MT05', 'Beleid'),
  ('MT06', 'Onderzoek'),
  ('MT07', 'Monitoring')
ON DUPLICATE KEY UPDATE omschrijving=VALUES(omschrijving);

CREATE TABLE IF NOT EXISTS maatregel_activiteit_type (
  activiteit_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  omschrijving VARCHAR(160) NOT NULL,
  PRIMARY KEY (activiteit_code)
) ENGINE=InnoDB;

INSERT INTO maatregel_activiteit_type (activiteit_code, omschrijving) VALUES
  ('A01', 'Begrazen'),
  ('A04', 'Dunnen'),
  ('A05', 'Vellen of kappen'),
  ('A06', 'Maaien en afvoeren'),
  ('A07', 'Opslag verwijderen'),
  ('A09', 'Bomen en struiken verwijderen'),
  ('B01', 'Baggeren of slib verwijderen'),
  ('B03', 'Afgraven'),
  ('B04', 'Plaggen of chopperen'),
  ('C01', 'Waterpeil of hydrologie aanpassen'),
  ('D01', 'Beheer aanpassen'),
  ('E01', 'Waterdynamiek herstellen'),
  ('E02', 'Winddynamiek herstellen'),
  ('F01', 'Soort herintroduceren'),
  ('F04', 'Exoten bestrijden'),
  ('G03', 'Recreatie beperken'),
  ('G04', 'Verkeer beperken'),
  ('L01', 'Leiding, put of installatie aanleggen of verwijderen'),
  ('L02', 'Gebouw of voorziening bouwen of aanpassen'),
  ('M01', 'Monitoren'),
  ('O01', 'Onderzoeken')
ON DUPLICATE KEY UPDATE omschrijving=VALUES(omschrijving);

CREATE TABLE IF NOT EXISTS maatregel_uitvoering_status (
  uitvoering_status_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  landelijk_status_code VARCHAR(8) CHARACTER SET ascii NULL,
  omschrijving VARCHAR(160) NOT NULL,
  is_feitelijk_uitgevoerd TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (uitvoering_status_code),
  CHECK (is_feitelijk_uitgevoerd IN (0,1))
) ENGINE=InnoDB;

INSERT INTO maatregel_uitvoering_status
  (uitvoering_status_code, landelijk_status_code, omschrijving, is_feitelijk_uitgevoerd) VALUES
  ('gepland', 'AS03', 'Plan of voorgenomen uitvoering', 0),
  ('in_uitvoering', 'AS04', 'In realisatie', 1),
  ('overgangsbeheer', 'AS05', 'Overgangsbeheer na inrichting', 1),
  ('uitgevoerd', 'AS06', 'Feitelijk uitgevoerd', 1),
  ('uitgevoerd_voor_2026', 'AS06*', 'Feitelijk uitgevoerd voor 1 januari 2026', 1),
  ('vervallen', 'AS99', 'Vervallen', 0),
  ('niet_uitgevoerd', NULL, 'Aantoonbaar niet uitgevoerd', 0),
  ('onbekend', NULL, 'Uitvoering niet uit de geraadpleegde bronnen vast te stellen', 0)
ON DUPLICATE KEY UPDATE
  landelijk_status_code=VALUES(landelijk_status_code),
  omschrijving=VALUES(omschrijving),
  is_feitelijk_uitgevoerd=VALUES(is_feitelijk_uitgevoerd);

CREATE TABLE IF NOT EXISTS maatregel_brontype (
  brontype_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  landelijke_broncategorie VARCHAR(8) CHARACTER SET ascii NULL,
  omschrijving VARCHAR(160) NOT NULL,
  PRIMARY KEY (brontype_code)
) ENGINE=InnoDB;

INSERT INTO maatregel_brontype (brontype_code, landelijke_broncategorie, omschrijving) VALUES
  ('natura2000_beheerplan', 'IBC01', 'Natura 2000-beheerplan of evaluatie daarvan'),
  ('inrichtingsplan', 'IBC03', 'Inrichtings- of uitvoeringsplan'),
  ('onderzoeksrapport', 'IBC09', 'Onderzoeks- of monitoringsrapport'),
  ('beheerpublicatie', 'IBC99', 'Beheerhistorische publicatie'),
  ('officiele_webpagina', 'IBC99', 'Officiële webpagina van overheid of terreinbeheerder'),
  ('subsidiebesluit', 'IBC99', 'Subsidiebesluit of openstellingsbesluit')
ON DUPLICATE KEY UPDATE
  landelijke_broncategorie=VALUES(landelijke_broncategorie),
  omschrijving=VALUES(omschrijving);

CREATE TABLE IF NOT EXISTS maatregel_project (
  project_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  project_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,
  omschrijving TEXT NULL,
  werkcategorie_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  verantwoordelijke_organisatie VARCHAR(255) NULL,
  bestuurlijke_status VARCHAR(120) NULL,
  juridisch_categorie VARCHAR(120) NULL,
  natura2000_gebied VARCHAR(255) NULL,
  deelgebied VARCHAR(255) NULL,
  druk_aandachtspunt TEXT NULL,
  doel_omschrijving TEXT NULL,
  plan_startdatum DATE NULL,
  plan_einddatum DATE NULL,
  programma VARCHAR(255) NULL,
  financiering VARCHAR(255) NULL,
  externe_projectcode VARCHAR(120) NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  gewijzigd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (project_id),
  UNIQUE KEY uq_maatregel_project_code (project_code),
  KEY ix_maatregel_project_categorie (werkcategorie_code, plan_startdatum),
  CONSTRAINT fk_maatregel_project_werkcategorie FOREIGN KEY (werkcategorie_code)
    REFERENCES maatregel_werkcategorie (werkcategorie_code),
  CHECK (plan_einddatum IS NULL OR plan_startdatum IS NULL OR plan_einddatum >= plan_startdatum)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_bron (
  bron_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  brontype_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  bron_datum DATE NULL,
  zotero_item_key CHAR(8) CHARACTER SET ascii NULL,
  url VARCHAR(1000) NULL,
  raadpleegdatum DATE NOT NULL,
  bronstatus VARCHAR(120) NULL,
  opmerking TEXT NULL,
  PRIMARY KEY (bron_id),
  UNIQUE KEY uq_maatregel_bron_code (bron_code),
  KEY ix_maatregel_bron_zotero (zotero_item_key),
  CONSTRAINT fk_maatregel_bron_type FOREIGN KEY (brontype_code)
    REFERENCES maatregel_brontype (brontype_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_uitvoering (
  uitvoering_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  project_id BIGINT UNSIGNED NOT NULL,
  maatregel_id INT NULL,
  maatregeltype_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  activiteit_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  uitvoering_status_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,
  omschrijving TEXT NULL,
  locatie_naam VARCHAR(255) NOT NULL,
  locatie_precisie ENUM('exacte_geometrie','benoemd_deelgebied','meijendel_breed','onbekend') NOT NULL,
  datum_vanaf DATE NULL,
  datum_tot DATE NULL,
  datum_precisie ENUM('dag','maand','jaar','periode','onbekend') NOT NULL,
  cycliciteit VARCHAR(120) NULL,
  uitvoerder VARCHAR(255) NULL,
  gerealiseerde_hoeveelheid DECIMAL(16,4) NULL,
  hoeveelheid_eenheid VARCHAR(24) NULL,
  opmerking TEXT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  gewijzigd_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (uitvoering_id),
  UNIQUE KEY uq_maatregel_uitvoering_code (uitvoering_code),
  KEY ix_maatregel_uitvoering_project (project_id, datum_vanaf),
  KEY ix_maatregel_uitvoering_maatregel (maatregel_id),
  CONSTRAINT fk_maatregel_uitvoering_project FOREIGN KEY (project_id)
    REFERENCES maatregel_project (project_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_uitvoering_maatregel FOREIGN KEY (maatregel_id)
    REFERENCES maatregelen (id),
  CONSTRAINT fk_maatregel_uitvoering_type FOREIGN KEY (maatregeltype_code)
    REFERENCES maatregel_type (maatregeltype_code),
  CONSTRAINT fk_maatregel_uitvoering_activiteit FOREIGN KEY (activiteit_code)
    REFERENCES maatregel_activiteit_type (activiteit_code),
  CONSTRAINT fk_maatregel_uitvoering_status FOREIGN KEY (uitvoering_status_code)
    REFERENCES maatregel_uitvoering_status (uitvoering_status_code),
  CHECK (datum_tot IS NULL OR datum_vanaf IS NULL OR datum_tot >= datum_vanaf),
  CHECK ((gerealiseerde_hoeveelheid IS NULL AND hoeveelheid_eenheid IS NULL) OR
         (gerealiseerde_hoeveelheid IS NOT NULL AND gerealiseerde_hoeveelheid >= 0 AND hoeveelheid_eenheid IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_uitvoering_jaar (
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  jaarstatus ENUM('uitgevoerd','niet_uitgevoerd','onbekend') NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  toelichting VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_id, jaar),
  KEY ix_maatregel_uitvoering_jaar_bron (bron_id),
  CONSTRAINT fk_maatregel_uitvoering_jaar_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_uitvoering_jaar_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id),
  CHECK (jaar BETWEEN 1900 AND 2100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_uitvoering_bron (
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  bronrol ENUM('primaire_uitvoeringsbron','bevestiging','plancontext','evaluatie','tegenstrijdig_bewijs') NOT NULL,
  pagina_of_paragraaf VARCHAR(255) NULL,
  bewijsnotitie VARCHAR(1500) NOT NULL,
  PRIMARY KEY (uitvoering_id, bron_id, bronrol),
  CONSTRAINT fk_maatregel_uitvoering_bron_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_uitvoering_bron_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id)
) ENGINE=InnoDB;

-- Expliciete beoordeling of een uitvoering aan de 55 Meijendel-plots kan
-- worden gekoppeld. Alleen uitzonderingen en beoordeelde gevallen hoeven hier
-- een regel te krijgen; een ontbrekende regel betekent nog niet beoordeeld.
CREATE TABLE IF NOT EXISTS maatregel_uitvoering_plotscope (
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  plotscope_status ENUM('binnen_meijendel_plotgebied','buiten_meijendel_plotgebied','onbepaald') NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  vastgesteld_op DATE NOT NULL,
  verificatiestatus ENUM('geverifieerd','te_beoordelen','afgekeurd') NOT NULL,
  opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_id),
  KEY ix_maatregel_uitvoering_plotscope_status (plotscope_status, verificatiestatus),
  KEY ix_maatregel_uitvoering_plotscope_bron (bron_id),
  CONSTRAINT fk_maatregel_uitvoering_plotscope_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_uitvoering_plotscope_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_geometrie (
  geometrie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  geometrie_type ENUM('TG01_zoekgebied','TG02_plangebied','TG03_uitvoeringsgebied','TG04_effectgebied') NOT NULL,
  geometrie GEOMETRY NOT NULL SRID 28992,
  geometrie_jaar SMALLINT UNSIGNED NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  geometrie_opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (geometrie_id),
  UNIQUE KEY uq_maatregel_geometrie (uitvoering_id, geometrie_type, geometrie_jaar),
  SPATIAL KEY sx_maatregel_geometrie (geometrie),
  KEY ix_maatregel_geometrie_bron (bron_id),
  CONSTRAINT fk_maatregel_geometrie_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_geometrie_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id),
  CHECK (geometrie_jaar IS NULL OR geometrie_jaar BETWEEN 1900 AND 2100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plot_gebied (
  gebied_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(160) NOT NULL,
  gebiedstype ENUM('meijendel_deelgebied','speciaal_gebied') NOT NULL,
  karakterisering VARCHAR(500) NULL,
  sortering SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (gebied_code),
  UNIQUE KEY uq_plot_gebied_naam (naam),
  UNIQUE KEY uq_plot_gebied_sortering (sortering)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plot_gebiedsindeling (
  indeling_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,
  plotversie_id BIGINT UNSIGNED NOT NULL,
  vastgesteld_op DATE NOT NULL,
  status ENUM('concept','vastgesteld','vervangen') NOT NULL,
  bron_url VARCHAR(1000) NULL,
  besluitnotitie VARCHAR(1500) NOT NULL,
  aangemaakt_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (indeling_code),
  KEY ix_plot_gebiedsindeling_status (status, vastgesteld_op),
  CONSTRAINT fk_plot_gebiedsindeling_plotversie FOREIGN KEY (plotversie_id)
    REFERENCES ndff_sovon_plotversie (plotversie_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plot_gebied_lidmaatschap (
  indeling_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  plot_id INT NOT NULL,
  gebied_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  lidmaatschap_status ENUM('actueel_met_geometrie','historisch_zonder_geometrie') NOT NULL,
  bewijswijze ENUM('gebruiker_bevestigd','afgeleid_en_gebruiker_bevestigd') NOT NULL,
  opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (indeling_code, plot_id),
  KEY ix_plot_gebied_lidmaatschap_gebied (indeling_code, gebied_code),
  CONSTRAINT fk_plot_gebied_lidmaatschap_indeling FOREIGN KEY (indeling_code)
    REFERENCES plot_gebiedsindeling (indeling_code) ON DELETE CASCADE,
  CONSTRAINT fk_plot_gebied_lidmaatschap_plot FOREIGN KEY (plot_id)
    REFERENCES plots (plot_id),
  CONSTRAINT fk_plot_gebied_lidmaatschap_gebied FOREIGN KEY (gebied_code)
    REFERENCES plot_gebied (gebied_code)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plot_gebied_geometrie (
  indeling_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  gebied_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  plotversie_id BIGINT UNSIGNED NOT NULL,
  gebied_geometrie MULTIPOLYGON NOT NULL SRID 28992,
  bronplot_aantal SMALLINT UNSIGNED NOT NULL,
  oppervlakte_ha DECIMAL(14,6) NOT NULL,
  geometrie_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  afgeleid_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (indeling_code, gebied_code, plotversie_id),
  SPATIAL KEY sx_plot_gebied_geometrie (gebied_geometrie),
  CONSTRAINT fk_plot_gebied_geometrie_indeling FOREIGN KEY (indeling_code)
    REFERENCES plot_gebiedsindeling (indeling_code) ON DELETE CASCADE,
  CONSTRAINT fk_plot_gebied_geometrie_gebied FOREIGN KEY (gebied_code)
    REFERENCES plot_gebied (gebied_code),
  CONSTRAINT fk_plot_gebied_geometrie_plotversie FOREIGN KEY (plotversie_id)
    REFERENCES ndff_sovon_plotversie (plotversie_id),
  CHECK (bronplot_aantal > 0),
  CHECK (oppervlakte_ha > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_uitvoering_gebied (
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  indeling_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  gebied_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  relatietype ENUM('locatie_binnen_gebied','volledig_gebied') NOT NULL,
  verificatiestatus ENUM('geverifieerd','te_beoordelen','afgekeurd') NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_id, indeling_code, gebied_code),
  KEY ix_maatregel_uitvoering_gebied_selectie (indeling_code, gebied_code, verificatiestatus),
  KEY ix_maatregel_uitvoering_gebied_bron (bron_id),
  CONSTRAINT fk_maatregel_uitvoering_gebied_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_uitvoering_gebied_indeling FOREIGN KEY (indeling_code)
    REFERENCES plot_gebiedsindeling (indeling_code),
  CONSTRAINT fk_maatregel_uitvoering_gebied_gebied FOREIGN KEY (gebied_code)
    REFERENCES plot_gebied (gebied_code),
  CONSTRAINT fk_maatregel_uitvoering_gebied_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_plot_koppeling (
  uitvoering_id BIGINT UNSIGNED NOT NULL,
  plot_id INT NOT NULL,
  koppelmethode ENUM('expliciet_in_bron','geometrische_doorsnijding','benoemd_gebied_gevalideerd') NOT NULL,
  doorsnijding_pct DECIMAL(5,2) NULL,
  verificatiestatus ENUM('geverifieerd','te_beoordelen','afgekeurd') NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_id, plot_id),
  KEY ix_maatregel_plot_koppeling_plot (plot_id, verificatiestatus),
  KEY ix_maatregel_plot_koppeling_bron (bron_id),
  CONSTRAINT fk_maatregel_plot_koppeling_uitvoering FOREIGN KEY (uitvoering_id)
    REFERENCES maatregel_uitvoering (uitvoering_id) ON DELETE CASCADE,
  CONSTRAINT fk_maatregel_plot_koppeling_plot FOREIGN KEY (plot_id)
    REFERENCES plots (plot_id),
  CONSTRAINT fk_maatregel_plot_koppeling_bron FOREIGN KEY (bron_id)
    REFERENCES maatregel_bron (bron_id),
  CHECK (doorsnijding_pct IS NULL OR (doorsnijding_pct >= 0 AND doorsnijding_pct <= 100))
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_plot_jaar_maatregel_bronvast AS
SELECT
  pk.plot_id,
  uj.jaar,
  u.uitvoering_id,
  u.uitvoering_code,
  u.project_id,
  p.project_code,
  u.maatregel_id,
  u.activiteit_code,
  pk.koppelmethode,
  pk.doorsnijding_pct,
  uj.bron_id
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN maatregel_project p ON p.project_id=u.project_id
JOIN maatregel_uitvoering_jaar uj ON uj.uitvoering_id=u.uitvoering_id
WHERE pk.verificatiestatus='geverifieerd'
  AND uj.jaarstatus='uitgevoerd';

CREATE OR REPLACE VIEW v_plot_gebied_actueel AS
SELECT
  l.indeling_code,
  l.plot_id,
  p.kavel_nummer,
  p.in_gebruik,
  l.gebied_code,
  g.naam AS gebied_naam,
  g.gebiedstype,
  l.lidmaatschap_status,
  l.bewijswijze,
  l.opmerking
FROM plot_gebied_lidmaatschap l
JOIN plot_gebiedsindeling i USING (indeling_code)
JOIN plot_gebied g USING (gebied_code)
JOIN plots p USING (plot_id)
WHERE i.indeling_code=(
  SELECT i2.indeling_code
  FROM plot_gebiedsindeling i2
  WHERE i2.status='vastgesteld'
  ORDER BY i2.vastgesteld_op DESC, i2.indeling_code DESC
  LIMIT 1
);

CREATE OR REPLACE VIEW v_plot_gebied_geometrie_actueel AS
SELECT
  gg.indeling_code,
  gg.gebied_code,
  g.naam AS gebied_naam,
  g.gebiedstype,
  gg.plotversie_id,
  gg.gebied_geometrie,
  gg.bronplot_aantal,
  gg.oppervlakte_ha,
  gg.geometrie_sha256,
  gg.afgeleid_op
FROM plot_gebied_geometrie gg
JOIN plot_gebiedsindeling i USING (indeling_code)
JOIN plot_gebied g USING (gebied_code)
WHERE i.indeling_code=(
  SELECT i2.indeling_code
  FROM plot_gebiedsindeling i2
  WHERE i2.status='vastgesteld'
  ORDER BY i2.vastgesteld_op DESC, i2.indeling_code DESC
  LIMIT 1
);

-- Jaarfeiten en toestandsregistraties; uitvoering is optioneel, nooit gefingeerd.
CREATE TABLE IF NOT EXISTS maatregel_plot_jaar_registratie (
  registratie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  plot_id INT NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  maatregel_id INT NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  uitvoering_id BIGINT UNSIGNED NULL,
  intensiteit_code VARCHAR(30) NOT NULL DEFAULT '',
  uitvoerder_of_diersoort VARCHAR(50) NOT NULL DEFAULT '',
  deel_label VARCHAR(100) NOT NULL DEFAULT '',
  dekking_pct DECIMAL(5,2) NULL,
  opmerking VARCHAR(255) NULL,
  beoordelingsstatus VARCHAR(32) NOT NULL DEFAULT 'overgenomen_bronregistratie',
  UNIQUE KEY uq_mpjr (plot_id,jaar,bron_id,maatregel_id,intensiteit_code,uitvoerder_of_diersoort,deel_label),
  FOREIGN KEY (plot_id) REFERENCES plots(plot_id),
  FOREIGN KEY (maatregel_id) REFERENCES maatregelen(id),
  FOREIGN KEY (bron_id) REFERENCES maatregel_bron(bron_id),
  FOREIGN KEY (uitvoering_id) REFERENCES maatregel_uitvoering(uitvoering_id),
  CHECK (dekking_pct IS NULL OR dekking_pct BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maatregel_toegankelijkheid_registratie (
  registratie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  plot_id INT NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  bron_id BIGINT UNSIGNED NOT NULL,
  niveau ENUM('plot','deel') NOT NULL,
  ouder_registratie_id BIGINT UNSIGNED NULL,
  deel_label VARCHAR(100) NOT NULL DEFAULT '',
  status_code VARCHAR(30) NOT NULL,
  aandeel_pct DECIMAL(5,2) NULL,
  barriere_type VARCHAR(50) NOT NULL DEFAULT '',
  geom_wkt LONGTEXT NULL,
  uitvoering_id BIGINT UNSIGNED NULL,
  opmerking VARCHAR(255) NULL,
  beoordelingsstatus VARCHAR(32) NOT NULL DEFAULT 'overgenomen_bronregistratie',
  UNIQUE KEY uq_mtr (plot_id,jaar,bron_id,niveau,deel_label),
  FOREIGN KEY (plot_id) REFERENCES plots(plot_id),
  FOREIGN KEY (bron_id) REFERENCES maatregel_bron(bron_id),
  FOREIGN KEY (uitvoering_id) REFERENCES maatregel_uitvoering(uitvoering_id),
  FOREIGN KEY (ouder_registratie_id) REFERENCES maatregel_toegankelijkheid_registratie(registratie_id),
  CHECK (aandeel_pct IS NULL OR aandeel_pct BETWEEN 0 AND 100),
  CHECK (niveau='deel' OR (deel_label='' AND aandeel_pct IS NULL AND ouder_registratie_id IS NULL)),
  CHECK (status_code IN ('vrij','beperkt','afgesloten','deels beperkt, deels vrij','deels afgesloten, deels vrij','onbekend'))
) ENGINE=InnoDB;

-- Uitsluitend herkomstmetadata: precies één doel, geen tweede beheerfeit.
CREATE TABLE IF NOT EXISTS maatregel_registratie_herkomst (
  herkomst_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  brontabel VARCHAR(64) CHARACTER SET ascii NOT NULL,
  bronsleutel VARCHAR(255) NOT NULL,
  oorspronkelijke_rij JSON NOT NULL,
  rij_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  migratieversie VARCHAR(64) CHARACTER SET ascii NOT NULL,
  beheer_registratie_id BIGINT UNSIGNED NULL,
  toegang_registratie_id BIGINT UNSIGNED NULL,
  uitvoering_id BIGINT UNSIGNED NULL,
  plot_id INT NULL,
  jaar SMALLINT UNSIGNED NULL,
  UNIQUE KEY uq_mrh_bron (brontabel,bronsleutel),
  FOREIGN KEY (beheer_registratie_id) REFERENCES maatregel_plot_jaar_registratie(registratie_id),
  FOREIGN KEY (toegang_registratie_id) REFERENCES maatregel_toegankelijkheid_registratie(registratie_id),
  FOREIGN KEY (uitvoering_id,plot_id) REFERENCES maatregel_plot_koppeling(uitvoering_id,plot_id),
  FOREIGN KEY (uitvoering_id,jaar) REFERENCES maatregel_uitvoering_jaar(uitvoering_id,jaar),
  CHECK ((beheer_registratie_id IS NOT NULL)+(toegang_registratie_id IS NOT NULL)+(uitvoering_id IS NOT NULL)=1),
  CHECK ((uitvoering_id IS NOT NULL AND plot_id IS NOT NULL AND jaar IS NOT NULL)
      OR (uitvoering_id IS NULL AND plot_id IS NULL AND jaar IS NULL))
) ENGINE=InnoDB;
