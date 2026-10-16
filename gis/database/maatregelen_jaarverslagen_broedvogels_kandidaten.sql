-- Alleen-lezen voorbereidingsset voor werkzaamheden en maatregelen uit de
-- broedvogeljaarverslagen. Stand 16 oktober 2026.
--
-- Dit bestand schrijft NIET naar permanente tabellen. Alle objecten zijn
-- tijdelijk en verdwijnen bij het sluiten van de MySQL-sessie. De kandidaten
-- worden pas na inhoudelijke goedkeuring opgenomen in maatregelen_seed.sql.

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_bron_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_bron_candidate (
  bron_code VARCHAR(96) CHARACTER SET ascii PRIMARY KEY,
  brontype_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(500) NOT NULL,
  rapportjaar SMALLINT UNSIGNED NULL,
  zotero_item_key CHAR(8) CHARACTER SET ascii NOT NULL,
  bronstatus VARCHAR(32) NOT NULL,
  raadpleegdatum DATE NOT NULL
);

INSERT INTO tmp_jaarverslag_bron_candidate VALUES
  ('zotero_vogeljaarverslagen_1958_1984','beheerpublicatie','Vogelpopulatieonderzoek Meijendel: jaarverslagen 1958–1984',NULL,'Q6ZVIPGC','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1985','beheerpublicatie','Vogelwerkgroep Meijendel – Jaarverslag 1985',1985,'6Q4HVJRB','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1987','beheerpublicatie','Vogelwerkgroep Meijendel en Meeuwengroep Meijendel – Jaarverslag 1987',1987,'JKQQNZG7','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1991','beheerpublicatie','Vogelwerkgroep Meijendel – Jaarverslag 1991',1991,'7SBASTZA','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1992','beheerpublicatie','Vogelwerkgroep Meijendel – Jaarverslag 1992',1992,'EIFHHD7U','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1993_1994','beheerpublicatie','Vogelwerkgroep Meijendel – Jaarverslag 1993 en 1994',NULL,'D2QGN8BQ','gepubliceerd','2026-10-16'),
  ('zotero_vogelrapport_1998','beheerpublicatie','Vogelwerkgroep Meijendel 1998 jaarverslag',1998,'RWHAWSJD','gepubliceerd','2026-10-16'),
  ('zotero_broedvogelmonitoring_2001','beheerpublicatie','Vogelwerkgroep Meijendel 2001 jaarverslag',2001,'2JBJ6E36','gepubliceerd','2026-10-16');

-- Alleen de drie nog ontbrekende projectkaders. Bestaande projecten worden
-- hieronder rechtstreeks via hun project_code hergebruikt.
DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_project_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_project_candidate (
  project_code VARCHAR(96) CHARACTER SET ascii PRIMARY KEY,
  naam VARCHAR(255) NOT NULL,
  omschrijving TEXT NULL,
  werkcategorie_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  verantwoordelijke_organisatie VARCHAR(255) NULL,
  bestuurlijke_status VARCHAR(120) NULL,
  natura2000_gebied VARCHAR(255) NULL,
  deelgebied VARCHAR(255) NULL,
  plan_startdatum DATE NULL,
  plan_einddatum DATE NULL
);

INSERT INTO tmp_jaarverslag_project_candidate VALUES
  ('historisch_terreinbeheer_1958_2001','Historisch terreinbeheer 1958-2001','Faunabeheer, maaien, hout- en vegetatiebeheer zoals vastgelegd in de broedvogeljaarverslagen.','natuurbeheer','Duinwaterleiding van s-Gravenhage / Duinwaterbedrijf Zuid-Holland','afgerond','Meijendel & Berkheide','Meijendel','1958-01-01','2001-12-31'),
  ('historische_waterwinning_1984_2002','Historische werkzaamheden waterwinning 1984-2002','Aanpassingen aan hoofdaders, infiltratieplassen, waterpeilen en winningsconstructies.','waterwinning','Duinwaterleiding van s-Gravenhage / Duinwaterbedrijf Zuid-Holland','afgerond','Meijendel & Berkheide','Meijendel','1984-01-01','2002-12-31'),
  ('historische_recreatie_inrichting_1966_2001','Historische recreatie-inrichting 1966-2001','Openstelling, paden en routevoorzieningen zoals beschreven in de broedvogeljaarverslagen.','recreatie','Duinwaterleiding van s-Gravenhage / Duinwaterbedrijf Zuid-Holland','afgerond','Meijendel & Berkheide','Meijendel','1966-01-01','2001-12-31');

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_uitvoering_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_uitvoering_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii PRIMARY KEY,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  maatregeltype_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  activiteit_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  uitvoering_status_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,
  locatie_naam VARCHAR(255) NOT NULL,
  locatie_precisie VARCHAR(32) CHARACTER SET ascii NOT NULL,
  datum_vanaf DATE NULL,
  datum_tot DATE NULL,
  datum_precisie VARCHAR(16) CHARACTER SET ascii NOT NULL,
  cycliciteit VARCHAR(120) NULL,
  beslisnotitie VARCHAR(1000) NOT NULL
);

INSERT INTO tmp_jaarverslag_uitvoering_candidate VALUES
  ('corvidenbestrijding_1958_1966','zotero_vogeljaarverslagen_1958_1984','MT02','D01','uitgevoerd_voor_2026','Ekster en Vlaamse gaai bestrijden','Meijendel','meijendel_breed','1958-01-01','1966-12-31','periode','herhaald, vijf expliciet bevestigde jaren','Alleen de jaren 1958, 1960, 1961, 1965 en 1966 worden als uitgevoerd voorbereid.'),
  ('openstelling_kavel4_6_1966','zotero_vogeljaarverslagen_1958_1984','MT03','L02','uitgevoerd_voor_2026','Delen van kavels 4 en 6 voor publiek toegankelijk maken','Kavels 4 en 6','benoemd_deelgebied','1966-01-01','1966-12-31','jaar',NULL,'De bron meldt gedeeltelijke openstelling; geen oppervlakte afleiden.'),
  ('waterstandverlaging_kavel14_1967','zotero_vogelrapport_1967','MT03','C01','uitgevoerd_voor_2026','Waterstand tijdens het broedseizoen verlagen','Kavel 14','benoemd_deelgebied','1967-01-01','1967-12-31','jaar',NULL,'Algemene opmerkingen noemen de verlaging en het broedseizoen, maar geen begin- of einddatum.'),
  ('zandwal_egaliseren_helm_kavel14_1968','zotero_vogelrapport_1968','MT03','D01','uitgevoerd_voor_2026','Zandwal egaliseren en met helm beplanten','Kavel 14','benoemd_deelgebied','1968-01-01','1968-12-31','jaar',NULL,'Uitgevoerd na het broedseizoen; exacte datum ontbreekt.'),
  ('hoofdader_ophogen_putten_1984','zotero_vogeljaarverslagen_1958_1984','MT04','L01','uitgevoerd_voor_2026','Hoofdader ophogen en puttenserie en vaste constructies aanbrengen','Hoofdader in kavels 52, 4, 5, 7, 8 en 10','benoemd_deelgebied','1984-10-01','1984-12-31','dag',NULL,'De bron vermeldt als gevolg dat nat duin droog duin werd.'),
  ('infiltratieplas17_2_uitgraven_1984','zotero_vogeljaarverslagen_1958_1984','MT04','B03','uitgevoerd_voor_2026','Infiltratieplas 17.2 uitgraven','Pan 17.2 in kavel 4','benoemd_deelgebied','1984-10-10','1984-10-24','dag',NULL,'Letterlijke bronregel.'),
  ('spoelplas43_vernieuwen_1984','zotero_vogeljaarverslagen_1958_1984','MT04','L02','uitgevoerd_voor_2026','Spoelplas vernieuwen en uitbreiden','Kavel 43','benoemd_deelgebied','1984-10-10','1984-10-24','dag',NULL,'De tijdsaanduiding idem verwijst naar 10-24 oktober 1984.'),
  ('hoofdader_installaties_1985','zotero_vogelrapport_1985','MT04','L01','uitgevoerd_voor_2026','Installaties en vaste constructies in de Hoofdader aanbrengen','Kavels 1A, 1B, 2, 3, 52, 4/5, 6, 7, 8, 10, 42 en 43','benoemd_deelgebied','1985-06-01','1985-12-31','maand',NULL,'Het eerste handgeschreven installatiewoord wordt niet zonder tweede lezing genormaliseerd.'),
  ('jaarlijks_maaien_geschikte_gebieden_voor_1987','zotero_vogelrapport_1987','MT01','A06','uitgevoerd_voor_2026','Geschikte terreindelen jaarlijks maaien','Niet nader begrensde geschikte gebieden','onbekend',NULL,NULL,'onbekend','jaarlijks, begonnen voor of in 1987','Geen jaar- of plotregel construeren; de bron noemt alleen dat het beheer al was begonnen.'),
  ('galloways_toevoegen_1991','zotero_vogelrapport_1991','MT02','A01','uitgevoerd_voor_2026','Galloway-runderen aan begrazing toevoegen','Meijendel','meijendel_breed','1991-01-01','1991-12-31','jaar','eenmalige uitbreiding van de kudde','Het verslag lokaliseert de toevoeging niet binnen een afzonderlijk begrazingsgebied.'),
  ('moerasjes_wisselmaaien_15_16_voor_1991','zotero_vogelrapport_1991','MT01','A06','uitgevoerd_voor_2026','Moerasjes volgens wisselschema maaien','Kavels 15 en 16','benoemd_deelgebied',NULL,NULL,'onbekend','wisselschema, meerdere jaren tot en met 1991','Geen afzonderlijke jaren construeren uit de formulering de laatste jaren.'),
  ('pan20_maaien_1991','zotero_vogelrapport_1991','MT02','A06','uitgevoerd_voor_2026','Pan 20 uitgebreid maaien','Pan 20','benoemd_deelgebied','1991-09-01','1991-12-31','periode','eenmalig','Bron zegt najaar 1991, zonder maand.'),
  ('pan20_houtopslag_verwijderen_1991','zotero_vogelrapport_1991','MT02','A09','uitgevoerd_voor_2026','Struikgewas en geboomte in Pan 20 verwijderen','Pan 20','benoemd_deelgebied','1991-09-01','1991-12-31','periode','eenmalig','Afzonderlijke activiteit binnen dezelfde najaarsingreep.'),
  ('rijnland_pad_sprang_pi_1993','zotero_vogelrapport_1993_1994','MT03','L02','uitgevoerd_voor_2026','Onverhard pad langs Rijnland richting Sprang Pi verlengen','Kavel 13s','benoemd_deelgebied','1993-06-15','1993-06-30','periode','eenmalig','Half juni; duindoornbos gedeeltelijk gerooid en werkwagen bij Sprang Pi geplaatst.'),
  ('waterstandverlaging_10_12_76_1994','zotero_vogelrapport_1993_1994','MT03','C01','uitgevoerd_voor_2026','Waterstand verlagen','Kavel 10/12/76','benoemd_deelgebied','1994-01-01','1994-12-31','jaar','eenmalig','Bron noemt verstoring in pan 27.2 en 27.4, maar begrenst de handeling tot kavel 10/12/76.'),
  ('houtkap_10_12_76_1994','zotero_vogelrapport_1993_1994','MT02','A05','uitgevoerd_voor_2026','Hout kappen','Kavel 10/12/76','benoemd_deelgebied','1994-01-01','1994-12-31','jaar','eenmalig','Letterlijke bronvermelding.'),
  ('sprokkelhoutpad_10_12_76_1994','zotero_vogelrapport_1993_1994','MT03','L02','uitgevoerd_voor_2026','Sprokkelhoutpad aanleggen','Kavel 10/12/76','benoemd_deelgebied','1994-01-01','1994-12-31','jaar','eenmalig','Letterlijke bronvermelding.'),
  ('pan26_plassen_1997_1998','zotero_vogelrapport_1998','MT04','C01','uitgevoerd_voor_2026','Plassen in Pan 26 droogleggen, verkleinen en uitdiepen','Pan 26, kavels 14 en 15','benoemd_deelgebied','1997-09-01','1998-03-31','maand','eenmalig','M14 en M15 zijn voor deze hydrologische handelingen expliciet genoemd.'),
  ('libellenvallei_routevoorzieningen_2001','zotero_broedvogelmonitoring_2001','MT03','L02','uitgevoerd_voor_2026','Routepaaltjes en strooiselpaden aanbrengen','Kavel 17B','benoemd_deelgebied','2001-01-01','2001-12-31','jaar','eenmalig','Alleen het in M17B uitgevoerde deel opnemen.'),
  ('hoofdader_peilverlaging_75_77_2001','zotero_broedvogelmonitoring_2001','MT03','C01','uitgevoerd_voor_2026','Hoofdader verlagen voor regeneratiewerk Berkheide','Kavel 75 en een deel van kavel 77','benoemd_deelgebied','2001-03-15','2001-12-31','periode','eenmalig','Vanaf half maart; einddatum ontbreekt.'),
  ('dennenbos_kappen_77_2001','zotero_broedvogelmonitoring_2001','MT02','A05','uitgevoerd_voor_2026','Klein deel dennenbos kappen','Kavel 77','benoemd_deelgebied','2001-01-01','2001-12-31','jaar','eenmalig buiten de broedtijd','Exacte datum en oppervlakte ontbreken.'),
  ('pan20_wisselpeilproef_2002','zotero_broedvogelmonitoring_2001','MT06','C01','uitgevoerd_voor_2026','Proef met wisselend waterpeil in Pan 20','Pan 20','benoemd_deelgebied','2002-03-01','2002-05-31','maand','proef','Maximaal 30 cm verhogen of verlagen; in maart hoger gezet en in april-mei verlaagd.'),
  ('libellenvallei_noordpad_2001_niet_uitgevoerd','zotero_broedvogelmonitoring_2001','MT03','L02','niet_uitgevoerd','Pad langs de noordhelling van Libellenvallei aanleggen','Kavel 17B','benoemd_deelgebied','2001-01-01','2001-12-31','jaar','eenmalig plan','Van aanleg door bosschages en drassige delen, deels parallel aan het Oude Slag, is vooralsnog afgezien.');

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_projecttoedeling_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_projecttoedeling_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii PRIMARY KEY,
  project_code VARCHAR(96) CHARACTER SET ascii NOT NULL
);

INSERT INTO tmp_jaarverslag_projecttoedeling_candidate VALUES
  ('corvidenbestrijding_1958_1966','historisch_terreinbeheer_1958_2001'),
  ('openstelling_kavel4_6_1966','historische_recreatie_inrichting_1966_2001'),
  ('waterstandverlaging_kavel14_1967','historische_waterwinning_1967_1975'),
  ('zandwal_egaliseren_helm_kavel14_1968','historisch_terreinbeheer_1958_2001'),
  ('hoofdader_ophogen_putten_1984','historische_waterwinning_1984_2002'),
  ('infiltratieplas17_2_uitgraven_1984','historische_waterwinning_1984_2002'),
  ('spoelplas43_vernieuwen_1984','historische_waterwinning_1984_2002'),
  ('hoofdader_installaties_1985','historische_waterwinning_1984_2002'),
  ('jaarlijks_maaien_geschikte_gebieden_voor_1987','historisch_terreinbeheer_1958_2001'),
  ('galloways_toevoegen_1991','integrale_begrazing_1990'),
  ('moerasjes_wisselmaaien_15_16_voor_1991','duinvalleibeheer_1975_2003'),
  ('pan20_maaien_1991','duinvalleibeheer_1975_2003'),
  ('pan20_houtopslag_verwijderen_1991','historisch_terreinbeheer_1958_2001'),
  ('rijnland_pad_sprang_pi_1993','historische_recreatie_inrichting_1966_2001'),
  ('waterstandverlaging_10_12_76_1994','historische_waterwinning_1984_2002'),
  ('houtkap_10_12_76_1994','historisch_terreinbeheer_1958_2001'),
  ('sprokkelhoutpad_10_12_76_1994','historische_recreatie_inrichting_1966_2001'),
  ('pan26_plassen_1997_1998','kikkervalleien_herstel'),
  ('libellenvallei_routevoorzieningen_2001','historische_recreatie_inrichting_1966_2001'),
  ('hoofdader_peilverlaging_75_77_2001','historische_waterwinning_1984_2002'),
  ('dennenbos_kappen_77_2001','historisch_terreinbeheer_1958_2001'),
  ('pan20_wisselpeilproef_2002','historische_waterwinning_1984_2002'),
  ('libellenvallei_noordpad_2001_niet_uitgevoerd','historische_recreatie_inrichting_1966_2001');

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_uitvoering_bron_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_uitvoering_bron_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  bronrol VARCHAR(32) CHARACTER SET ascii NOT NULL,
  pagina_of_paragraaf VARCHAR(255) NULL,
  bewijsnotitie VARCHAR(1500) NOT NULL,
  PRIMARY KEY (uitvoering_code, bron_code, bronrol)
);

INSERT INTO tmp_jaarverslag_uitvoering_bron_candidate
SELECT uitvoering_code, bron_code,
       CASE WHEN uitvoering_status_code='niet_uitgevoerd' THEN 'plancontext'
            ELSE 'primaire_uitvoeringsbron' END,
       CASE
         WHEN uitvoering_code LIKE '%1958_1966' THEN 'Jaarbladen 1958, 1960, 1961, 1965 en 1966'
         WHEN uitvoering_code LIKE '%1966' THEN 'Jaarblad 1966, algemene opmerkingen'
         WHEN uitvoering_code LIKE '%1967' THEN 'Jaarverslag 1967, algemene opmerkingen'
         WHEN uitvoering_code LIKE '%1968' THEN 'Jaarverslag 1968, algemene opmerkingen'
         WHEN uitvoering_code LIKE '%1984' THEN 'Jaarblad 1984, werkzaamheden in het terrein'
         WHEN uitvoering_code LIKE '%1985' THEN 'Jaarverslag 1985, werkzaamheden in het terrein'
         WHEN uitvoering_code LIKE '%1987' THEN 'Jaarverslag 1987, terreinbeheer'
         WHEN uitvoering_code LIKE '%1991' OR uitvoering_code LIKE '%voor_1991' THEN 'Jaarverslag 1991, terreinbeheer'
         WHEN uitvoering_code LIKE '%1993' THEN 'Jaarverslag 1993, kavel 13s'
         WHEN uitvoering_code LIKE '%1994' THEN 'Jaarverslag 1994, kavel 10/12/76'
         WHEN uitvoering_code LIKE '%1997_1998' THEN 'Jaarverslag 1998, Pan 26'
         WHEN uitvoering_code LIKE '%2001%' THEN 'Jaarverslag 2001, terreinwerkzaamheden'
         WHEN uitvoering_code LIKE '%2002' THEN 'Jaarverslag 2001, vooruitblik 2002'
       END,
       CONCAT('De jaarverslagtekst is de directe bewijsbasis voor ', naam, '. De registratie wordt niet ruimer gemaakt dan plaats, periode en uitvoeringsstatus in de bron toelaten.')
FROM tmp_jaarverslag_uitvoering_candidate;

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_jaar_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_jaar_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  jaarstatus VARCHAR(24) CHARACTER SET ascii NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  toelichting VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_code, jaar)
);

INSERT INTO tmp_jaarverslag_jaar_candidate VALUES
  ('corvidenbestrijding_1958_1966',1958,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('corvidenbestrijding_1958_1966',1960,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('corvidenbestrijding_1958_1966',1961,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('corvidenbestrijding_1958_1966',1965,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('corvidenbestrijding_1958_1966',1966,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('openstelling_kavel4_6_1966',1966,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('waterstandverlaging_kavel14_1967',1967,'uitgevoerd','zotero_vogelrapport_1967',NULL),
  ('zandwal_egaliseren_helm_kavel14_1968',1968,'uitgevoerd','zotero_vogelrapport_1968',NULL),
  ('hoofdader_ophogen_putten_1984',1984,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('infiltratieplas17_2_uitgraven_1984',1984,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('spoelplas43_vernieuwen_1984',1984,'uitgevoerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('hoofdader_installaties_1985',1985,'uitgevoerd','zotero_vogelrapport_1985',NULL),
  ('galloways_toevoegen_1991',1991,'uitgevoerd','zotero_vogelrapport_1991',NULL),
  ('pan20_maaien_1991',1991,'uitgevoerd','zotero_vogelrapport_1991',NULL),
  ('pan20_houtopslag_verwijderen_1991',1991,'uitgevoerd','zotero_vogelrapport_1991',NULL),
  ('rijnland_pad_sprang_pi_1993',1993,'uitgevoerd','zotero_vogelrapport_1993_1994',NULL),
  ('waterstandverlaging_10_12_76_1994',1994,'uitgevoerd','zotero_vogelrapport_1993_1994',NULL),
  ('houtkap_10_12_76_1994',1994,'uitgevoerd','zotero_vogelrapport_1993_1994',NULL),
  ('sprokkelhoutpad_10_12_76_1994',1994,'uitgevoerd','zotero_vogelrapport_1993_1994',NULL),
  ('pan26_plassen_1997_1998',1997,'uitgevoerd','zotero_vogelrapport_1998',NULL),
  ('pan26_plassen_1997_1998',1998,'uitgevoerd','zotero_vogelrapport_1998',NULL),
  ('libellenvallei_routevoorzieningen_2001',2001,'uitgevoerd','zotero_broedvogelmonitoring_2001',NULL),
  ('hoofdader_peilverlaging_75_77_2001',2001,'uitgevoerd','zotero_broedvogelmonitoring_2001',NULL),
  ('dennenbos_kappen_77_2001',2001,'uitgevoerd','zotero_broedvogelmonitoring_2001',NULL),
  ('pan20_wisselpeilproef_2002',2002,'uitgevoerd','zotero_broedvogelmonitoring_2001',NULL),
  ('libellenvallei_noordpad_2001_niet_uitgevoerd',2001,'niet_uitgevoerd','zotero_broedvogelmonitoring_2001',NULL);

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_plot_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_plot_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  kavel_nummer VARCHAR(32) CHARACTER SET ascii NOT NULL,
  koppelmethode VARCHAR(40) CHARACTER SET ascii NOT NULL,
  verificatiestatus VARCHAR(24) CHARACTER SET ascii NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  opmerking VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_code, kavel_nummer)
);

INSERT INTO tmp_jaarverslag_plot_candidate VALUES
  ('openstelling_kavel4_6_1966','M4-5','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984','Historische kavels 4 en 5 vormen de actuele combinatie M4-5.'),
  ('openstelling_kavel4_6_1966','M6','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('waterstandverlaging_kavel14_1967','M14','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1967',NULL),
  ('zandwal_egaliseren_helm_kavel14_1968','M14','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1968',NULL),
  ('hoofdader_ophogen_putten_1984','M52','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('hoofdader_ophogen_putten_1984','M4-5','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984','Bron noemt de historische kavels 4 en 5.'),
  ('hoofdader_ophogen_putten_1984','M7','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('hoofdader_ophogen_putten_1984','M8','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('hoofdader_ophogen_putten_1984','M10-12-76','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984','Bron noemt historische kavel 10; de actuele gecombineerde plotcode wordt gebruikt.'),
  ('infiltratieplas17_2_uitgraven_1984','M4-5','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984','Bron noemt historische kavel 4.'),
  ('spoelplas43_vernieuwen_1984','M43','expliciet_in_bron','geverifieerd','zotero_vogeljaarverslagen_1958_1984',NULL),
  ('hoofdader_installaties_1985','M1a','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M1b','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M2','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M3','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M52','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M4-5','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M6','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M7','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M8','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M10-12-76','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M42','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('hoofdader_installaties_1985','M43','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1985',NULL),
  ('moerasjes_wisselmaaien_15_16_voor_1991','M15','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1991',NULL),
  ('moerasjes_wisselmaaien_15_16_voor_1991','M16','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1991',NULL),
  ('pan20_maaien_1991','M16','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('pan20_maaien_1991','M17a','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('pan20_maaien_1991','M17b','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('pan20_houtopslag_verwijderen_1991','M16','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('pan20_houtopslag_verwijderen_1991','M17a','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('pan20_houtopslag_verwijderen_1991','M17b','benoemd_gebied_gevalideerd','geverifieerd','zotero_vogelrapport_1991','Ton lokaliseerde het volledige Pan 20-systeem op 14 oktober 2026.'),
  ('rijnland_pad_sprang_pi_1993','M13s','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1993_1994',NULL),
  ('waterstandverlaging_10_12_76_1994','M10-12-76','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1993_1994',NULL),
  ('houtkap_10_12_76_1994','M10-12-76','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1993_1994',NULL),
  ('sprokkelhoutpad_10_12_76_1994','M10-12-76','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1993_1994',NULL),
  ('pan26_plassen_1997_1998','M14','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1998',NULL),
  ('pan26_plassen_1997_1998','M15','expliciet_in_bron','geverifieerd','zotero_vogelrapport_1998',NULL),
  ('libellenvallei_routevoorzieningen_2001','M17b','expliciet_in_bron','geverifieerd','zotero_broedvogelmonitoring_2001','Bron noemt kavel 17B rechtstreeks.'),
  ('hoofdader_peilverlaging_75_77_2001','M75','expliciet_in_bron','geverifieerd','zotero_broedvogelmonitoring_2001',NULL),
  ('hoofdader_peilverlaging_75_77_2001','M77','expliciet_in_bron','geverifieerd','zotero_broedvogelmonitoring_2001',NULL),
  ('dennenbos_kappen_77_2001','M77','expliciet_in_bron','geverifieerd','zotero_broedvogelmonitoring_2001',NULL),
  ('pan20_wisselpeilproef_2002','M16','benoemd_gebied_gevalideerd','geverifieerd','zotero_broedvogelmonitoring_2001','Volledige Pan 20-systeem volgens gebruikersvaststelling.'),
  ('pan20_wisselpeilproef_2002','M17a','benoemd_gebied_gevalideerd','geverifieerd','zotero_broedvogelmonitoring_2001','Volledige Pan 20-systeem volgens gebruikersvaststelling.'),
  ('pan20_wisselpeilproef_2002','M17b','benoemd_gebied_gevalideerd','geverifieerd','zotero_broedvogelmonitoring_2001','Volledige Pan 20-systeem volgens gebruikersvaststelling.'),
  ('libellenvallei_noordpad_2001_niet_uitgevoerd','M17b','expliciet_in_bron','geverifieerd','zotero_broedvogelmonitoring_2001','Plotkoppeling beschrijft het afgewezen plangebied, niet uitgevoerde werkzaamheden.');

DROP TEMPORARY TABLE IF EXISTS tmp_jaarverslag_bestaand_update_candidate;
CREATE TEMPORARY TABLE tmp_jaarverslag_bestaand_update_candidate (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii PRIMARY KEY,
  nieuwe_bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  voorgestelde_wijziging VARCHAR(1000) NOT NULL
);

INSERT INTO tmp_jaarverslag_bestaand_update_candidate VALUES
  ('begrazing_kijfhoek_bierlap_1990','zotero_vogelrapport_1991','Bron als bevestiging koppelen; geen extra kavel of jaar afleiden.'),
  ('begrazing_helmduinen_1991','zotero_vogelrapport_1991','Bron als bevestiging koppelen; geen extra kavel afleiden.'),
  ('kikkervalleien_bodem_1997','zotero_vogelrapport_1998','Einddatum 1998-03-31 en jaarregel 1998 toevoegen; bestaande plotkoppelingen niet uitbreiden.'),
  ('kikkervalleien_infra_1997','zotero_vogelrapport_1998','Einddatum 1998-03-31 en jaarregel 1998 toevoegen; bestaande plotkoppelingen niet uitbreiden.');

INSERT INTO tmp_jaarverslag_uitvoering_bron_candidate
SELECT uitvoering_code, nieuwe_bron_code, 'bevestiging',
       CASE WHEN nieuwe_bron_code='zotero_vogelrapport_1991'
            THEN 'Jaarverslag 1991, terreinbeheer'
            ELSE 'Jaarverslag 1998, Pan 26' END,
       voorgestelde_wijziging
FROM tmp_jaarverslag_bestaand_update_candidate;

-- Beoordelingsoverzicht. Geen permanente tabel wordt gelezen of gewijzigd.
SELECT 'bronnen' AS onderdeel, COUNT(*) AS aantal FROM tmp_jaarverslag_bron_candidate
UNION ALL
SELECT 'nieuwe_projecten', COUNT(*) FROM tmp_jaarverslag_project_candidate
UNION ALL
SELECT 'nieuwe_uitvoeringen', COUNT(*) FROM tmp_jaarverslag_uitvoering_candidate
UNION ALL
SELECT 'projecttoedelingen', COUNT(*) FROM tmp_jaarverslag_projecttoedeling_candidate
UNION ALL
SELECT 'uitvoering_bronkoppelingen', COUNT(*) FROM tmp_jaarverslag_uitvoering_bron_candidate
UNION ALL
SELECT 'jaarregels', COUNT(*) FROM tmp_jaarverslag_jaar_candidate
UNION ALL
SELECT 'plotkoppelingen', COUNT(*) FROM tmp_jaarverslag_plot_candidate
UNION ALL
SELECT 'updates_bestaande_uitvoeringen', COUNT(*) FROM tmp_jaarverslag_bestaand_update_candidate;

SELECT * FROM tmp_jaarverslag_uitvoering_candidate ORDER BY COALESCE(datum_vanaf,'9999-12-31'), uitvoering_code;
SELECT * FROM tmp_jaarverslag_project_candidate ORDER BY project_code;
SELECT * FROM tmp_jaarverslag_projecttoedeling_candidate ORDER BY uitvoering_code;
SELECT * FROM tmp_jaarverslag_uitvoering_bron_candidate ORDER BY uitvoering_code, bron_code;
SELECT * FROM tmp_jaarverslag_jaar_candidate ORDER BY jaar, uitvoering_code;
SELECT * FROM tmp_jaarverslag_plot_candidate ORDER BY uitvoering_code, kavel_nummer;
SELECT * FROM tmp_jaarverslag_bestaand_update_candidate ORDER BY uitvoering_code;

-- Alle aantallen hieronder moeten nul zijn. Hiermee wordt alleen gecontroleerd
-- of iedere kandidaat naar een voorbereide of al bestaande sleutel verwijst.
SELECT 'uitvoering_zonder_project' AS controle, COUNT(*) AS aantal
FROM tmp_jaarverslag_projecttoedeling_candidate t
LEFT JOIN tmp_jaarverslag_project_candidate n USING (project_code)
LEFT JOIN maatregel_project b USING (project_code)
WHERE n.project_code IS NULL AND b.project_code IS NULL;

SELECT 'uitvoering_zonder_bron' AS controle, COUNT(*) AS aantal
FROM tmp_jaarverslag_uitvoering_bron_candidate t
LEFT JOIN tmp_jaarverslag_bron_candidate n USING (bron_code)
LEFT JOIN maatregel_bron b USING (bron_code)
WHERE n.bron_code IS NULL AND b.bron_code IS NULL;

SELECT 'projecttoedeling_zonder_uitvoering' AS controle, COUNT(*) AS aantal
FROM tmp_jaarverslag_projecttoedeling_candidate p
LEFT JOIN tmp_jaarverslag_uitvoering_candidate u USING (uitvoering_code)
WHERE u.uitvoering_code IS NULL;

SELECT 'uitvoering_zonder_projecttoedeling' AS controle, COUNT(*) AS aantal
FROM tmp_jaarverslag_uitvoering_candidate u
LEFT JOIN tmp_jaarverslag_projecttoedeling_candidate p USING (uitvoering_code)
WHERE p.uitvoering_code IS NULL;
