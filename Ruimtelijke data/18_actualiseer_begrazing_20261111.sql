-- Gerichte, herhaalbare actualisering van de begrazingshistorie.
-- Besluit Ton Lansink: 11 november 2026.
-- De 139 historische beheerregistraties en 144 herkomstregels blijven ongemoeid.

START TRANSACTION;

INSERT INTO maatregel_brontype (brontype_code,landelijke_broncategorie,omschrijving)
VALUES ('handmatige_registratie','IBC99','Oorspronkelijke handmatige bronregistratie')
ON DUPLICATE KEY UPDATE
  landelijke_broncategorie=VALUES(landelijke_broncategorie),
  omschrijving=VALUES(omschrijving);

DROP TEMPORARY TABLE IF EXISTS tmp_begrazing_bron_20261111;
CREATE TEMPORARY TABLE tmp_begrazing_bron_20261111 (
  bron_code VARCHAR(96) CHARACTER SET ascii PRIMARY KEY,
  brontype_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(1000) NOT NULL,
  bron_datum DATE NULL,
  zotero_item_key CHAR(8) CHARACTER SET ascii NULL,
  url VARCHAR(1000) NULL,
  raadpleegdatum DATE NOT NULL,
  bronstatus VARCHAR(120) NULL,
  opmerking TEXT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_begrazing_bron_20261111 VALUES
  ('zotero_begrazing_1990_bakker','beheerpublicatie','Begrazing van Meijendel met paarden en koeien','1990-11-01','UNQKQA7F',NULL,'2026-11-11','gepubliceerd','Primaire historische beschrijving van de introductie van Noorse fjordenpaarden op 29 september 1990; Gallowayrunderen volgden kort daarna.'),
  ('zotero_begrazing_1992_monitoring','beheerpublicatie','Monitoring en begrazing in Meijendel','1992-04-01','2DTPDE3F',NULL,'2026-11-11','gepubliceerd','Historische monitoring en kaart van het toenmalige begrazingsgebied; de kaartgrens is nog niet als digitale geometrie over de huidige kavels gelegd.'),
  ('zotero_begrazingsonderzoek_1993','beheerpublicatie','Begrazingsonderzoek: impressies na drie jaar','1993-11-01','EAZMT3DN',NULL,'2026-11-11','gepubliceerd','Historische evaluatie na drie jaar begrazing.'),
  ('zotero_begrazing_1999_de_bonte','onderzoeksrapport','Vegetation development influenced by grazing in the coastal dunes near The Hague, The Netherlands','1999-01-01','2LJHNLXU','https://doi.org/10.1007/BF02802740','2026-11-11','gepubliceerd','Wetenschappelijke evaluatie van vegetatieontwikkeling onder begrazing.'),
  ('zotero_begrazingsbeheer_2012_fauna','onderzoeksrapport','Begrazingsbeheer in relatie tot herstel van faunagemeenschappen in de duinen, Eindrapportage 1e fase 2009-2011','2012-01-01','8BPDBYC5',NULL,'2026-11-11','gepubliceerd','Eindrapportage van de eerste onderzoeksfase naar begrazingsbeheer en faunagemeenschappen.'),
  ('zotero_begrazingsbeheer_2014_obn','onderzoeksrapport','Begrazingsbeheer in relatie tot faunagemeenschappen in droge grasduinen, eindrapportage 2009-2013','2014-01-01','I3QJJ4ID',NULL,'2026-11-11','gepubliceerd','OBN190-DK; noemt voor het Meeuwenhoek-veldonderzoek begrazing met runderen en paarden vanaf 2004.'),
  ('zotero_rabbits_rule_2022','onderzoeksrapport','Rabbits rule: Evaluating livestock grazing in coastal sand dunes of Meijendel, the Netherlands','2022-01-01','U5HPG8GI','https://doi.org/10.18174/575460','2026-11-11','gepubliceerd','Proefschrift over de evaluatie van begrazingsbeheer in Meijendel.'),
  ('eis_bijenmonitoring_2023','onderzoeksrapport','Bijenmonitoring in duingebied Meijendel. Herhaling 2023','2023-01-01',NULL,NULL,'2026-11-11','gepubliceerd','EIS2023-16; beschrijft voor de monitoringsjaren 2019, 2021 en 2023 de winter- en jaarrondbegrazingsregimes.'),
  ('handmatig_begrazing_m74_20261111','handmatige_registratie','Handmatige bronvaststelling begrazing M74 vanaf 1996','2026-11-11',NULL,NULL,'2026-11-11','bevestigd_door_ton','Ton bevestigde op 11 november 2026 dat M74 vanaf 1996 zonder onderbreking wordt begraasd. De publicaties bevestigen deze specifieke kavelstart niet onafhankelijk.');

INSERT INTO maatregel_bron
  (bron_code,brontype_code,titel,bron_datum,zotero_item_key,url,raadpleegdatum,bronstatus,opmerking)
SELECT bron_code,brontype_code,titel,bron_datum,zotero_item_key,url,raadpleegdatum,bronstatus,opmerking
FROM tmp_begrazing_bron_20261111
ON DUPLICATE KEY UPDATE
  brontype_code=VALUES(brontype_code),titel=VALUES(titel),bron_datum=VALUES(bron_datum),
  zotero_item_key=VALUES(zotero_item_key),url=VALUES(url),raadpleegdatum=VALUES(raadpleegdatum),
  bronstatus=VALUES(bronstatus),opmerking=VALUES(opmerking);

UPDATE maatregel_bron
SET titel='Integrale begrazing door vee in Meijendel',raadpleegdatum='2026-11-11',
    opmerking='Beschrijft invoering en uitbreiding van extensieve begrazing vanaf september 1990 en de administratieve toevoeging van Meeuwenhoek in 2005.'
WHERE bron_code='zotero_begrazing_2008';
UPDATE maatregel_bron
SET titel='Twintig jaar paarden en koeien in Meijendel, een panacee voor alle kwalen?',raadpleegdatum='2026-11-11',
    opmerking='Bevestigt start in september 1990, de verlaging van de graasdruk in 1995 en noemt oppervlakten van Kijfhoek-Bierlap, Helmduinen en Kikkervalleien.'
WHERE bron_code='zotero_begrazing_2012';

UPDATE maatregel_uitvoering oud
LEFT JOIN maatregel_uitvoering nieuw ON nieuw.uitvoering_code='begrazing_meeuwenhoek_2004'
SET oud.uitvoering_code='begrazing_meeuwenhoek_2004'
WHERE oud.uitvoering_code='begrazing_meeuwenhoek_voor_2008'
  AND nieuw.uitvoering_id IS NULL;

UPDATE maatregel_uitvoering SET
  uitvoering_status_code='in_uitvoering',
  omschrijving='Noorse fjordenpaarden zijn op 29 september 1990 uitgezet; Gallowayrunderen volgden kort daarna.',
  datum_vanaf='1990-09-29',datum_tot=NULL,datum_precisie='dag',cycliciteit='doorlopend tot heden',
  opmerking='Bronnen noemen circa 270 of 275 hectare. De historische grens uit 1992 is nog niet digitaal over de huidige kavels gelegd.'
WHERE uitvoering_code='begrazing_kijfhoek_bierlap_1990';

UPDATE maatregel_uitvoering SET
  omschrijving='De best onderbouwde eerste uitzetting in de Helmduinen vond eind 1991 plaats.',
  opmerking='De historische beheersevaluatie noemt eind 1991; OBN en het Natura 2000-beheerplan gebruiken 1992. Het bronverschil blijft bewaard.'
WHERE uitvoering_code='begrazing_helmduinen_1991';

UPDATE maatregel_uitvoering SET
  maatregel_id=(SELECT id FROM maatregelen WHERE code='maaibeheer_aanvullend'),
  naam='Aanvullend maaibeheer Zeereep, Helmduinen, Prinsenduin en Ganzenhoek',
  omschrijving='In 2017 is beperkt gemaaid; begrazing in 2016 en 2017 is als afzonderlijke uitvoering geregistreerd.',
  datum_vanaf='2017-01-01',datum_tot='2017-12-31',datum_precisie='jaar',cycliciteit='eenmalig beperkt',
  opmerking='De eerdere gemengde registratie is ontvlochten: deze uitvoering bevat alleen het in 2017 gemelde maaibeheer.'
WHERE uitvoering_code='pas_22h_aanvullend_beheer';

UPDATE maatregel_uitvoering SET
  uitvoering_status_code='in_uitvoering',
  naam='Begrazingsgebied uitbreiden met Meeuwenhoek',
  omschrijving='Veldonderzoek noemt begrazing met runderen en paarden vanaf 2004; in 2005 is Meeuwenhoek administratief aan Kijfhoek en Bierlap toegevoegd.',
  datum_vanaf='2004-01-01',datum_tot=NULL,datum_precisie='jaar',cycliciteit='doorlopend tot heden',
  opmerking='Het totale naamgebied omvat M10-12-76, M12a, M73, M74 en M75. De uitbreidingsuitvoering koppelt alleen de vier overige kavels, omdat M74 al afzonderlijk vanaf 1996 is geregistreerd.'
WHERE uitvoering_code='begrazing_meeuwenhoek_2004';

DROP TEMPORARY TABLE IF EXISTS tmp_begrazing_uitvoering_20261111;
CREATE TEMPORARY TABLE tmp_begrazing_uitvoering_20261111 (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii PRIMARY KEY,
  project_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  maatregel_code VARCHAR(50) CHARACTER SET ascii NOT NULL,
  maatregeltype_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  activiteit_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  uitvoering_status_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,omschrijving TEXT NULL,locatie_naam VARCHAR(255) NOT NULL,
  locatie_precisie VARCHAR(32) CHARACTER SET ascii NOT NULL,datum_vanaf DATE NULL,datum_tot DATE NULL,
  datum_precisie VARCHAR(16) CHARACTER SET ascii NOT NULL,cycliciteit VARCHAR(120) NULL,uitvoerder VARCHAR(255) NULL,
  gerealiseerde_hoeveelheid DECIMAL(16,4) NULL,hoeveelheid_eenheid VARCHAR(24) NULL,opmerking TEXT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_begrazing_uitvoering_20261111 VALUES
  ('begrazingsdruk_kijfhoek_bierlap_1995','integrale_begrazing_1990','begrazing','MT01','A01','uitgevoerd_voor_2026','Begrazingsdruk Kijfhoek en Bierlap verlagen','De bezetting is verlaagd van circa een dier per 12 hectare naar circa een dier per 18 hectare.','Historisch begrazingsgebied Kijfhoek en Bierlap','onbekend','1995-01-01','1995-12-31','jaar','intensiteitswijziging binnen doorlopende begrazing','Duinwaterbedrijf Zuid-Holland',18,'ha_per_dier','Geen plotkoppelingen totdat de historische gebiedsgrens uit 1992 is gedigitaliseerd.'),
  ('begrazing_m74_1996','integrale_begrazing_1990','begrazing','MT01','A01','in_uitvoering','Doorlopende begrazing kavel M74','M74 wordt volgens de door Ton bevestigde lokale kavelinformatie vanaf 1996 zonder onderbreking begraasd.','Kavel M74','benoemd_deelgebied','1996-01-01',NULL,'jaar','doorlopend tot heden','Dunea',NULL,NULL,'Handmatige bronvaststelling van 11 november 2026; de specifieke kavelstart is niet onafhankelijk in de publicaties teruggevonden.'),
  ('pas_22h_schapenbegrazing_2016','pas_meijendel_grijze_duinen','begrazing','MT01','A01','uitgevoerd_voor_2026','Tijdelijke begrazing met Kempense schapen','Van half november tot half december 2016 zijn tweehonderd Kempense schapen ingezet voor aanvullend beheer.','Zeereep Meijendel, Helmduinen, Prinsenduin en Ganzenhoek','benoemd_deelgebied','2016-11-15','2016-12-15','periode','tijdelijke kudde','Dunea',200,'aantal','De bron verdeelt de kudde niet over de vier naamgebieden of de zes gekoppelde kavels.'),
  ('pas_22h_deelbegrazing_2017','pas_meijendel_grijze_duinen','begrazing','MT01','A01','uitgevoerd_voor_2026','Begrazing van delen van maatregelgebied 22h','In 2017 zijn delen van het maatregelgebied begraasd; aantal dieren, oppervlakte en verdeling ontbreken.','Zeereep Meijendel, Helmduinen, Prinsenduin en Ganzenhoek','benoemd_deelgebied','2017-01-01','2017-12-31','jaar','eenmalig gedeeltelijk','Dunea',NULL,NULL,'Geen aantal, oppervlakte of verdeling over naamgebieden en kavels afgeleid.'),
  ('begrazingsregime_meijendel_2019_2023','integrale_begrazing_1990','begrazing','MT01','A01','uitgevoerd_voor_2026','Graasdruk verlagen en seizoensregime toepassen','Vanaf 2019 is de graasdruk verlaagd van circa een dier per 15-18 hectare naar een dier per 30 hectare. In de monitoringsjaren zijn Buitenduinen alleen in de winter en andere eenheden jaarrond begraasd.','Meijendel, meerdere begrazingseenheden','meijendel_breed','2019-01-01','2023-12-31','periode','monitoringsjaren 2019, 2021 en 2023','Dunea',30,'ha_per_dier','Geen directe kavelkoppelingen; de bron beschrijft beheerregimes per naamgebied en geen exacte uitvoeringsgeometrie.'),
  ('pas_3c_begrazing_vanaf_2022','pas_meijendel_grijze_duinen','begrazing','MT01','A01','in_uitvoering','Voortgezette begrazing Vallei Meijendel, Langestrook en De Loopert','Dunea heeft de in 2017-2021 uitgevoerde jaarlijkse begrazing daarna als regulier beheer voortgezet.','Vallei Meijendel, Langestrook en De Loopert','benoemd_deelgebied','2022-01-01',NULL,'jaar','jaarlijks voortgezet','Dunea',110,'ha','Er worden geen afzonderlijke jaarregels vanaf 2022 geconstrueerd; de bron bevestigt de voortzetting als beheer maar specificeert geen kalenderjaren.');

INSERT INTO maatregel_uitvoering
  (uitvoering_code,project_id,maatregel_id,maatregeltype_code,activiteit_code,uitvoering_status_code,naam,omschrijving,locatie_naam,locatie_precisie,datum_vanaf,datum_tot,datum_precisie,cycliciteit,uitvoerder,gerealiseerde_hoeveelheid,hoeveelheid_eenheid,opmerking)
SELECT s.uitvoering_code,p.project_id,m.id,s.maatregeltype_code,s.activiteit_code,s.uitvoering_status_code,s.naam,s.omschrijving,s.locatie_naam,s.locatie_precisie,s.datum_vanaf,s.datum_tot,s.datum_precisie,s.cycliciteit,s.uitvoerder,s.gerealiseerde_hoeveelheid,s.hoeveelheid_eenheid,s.opmerking
FROM tmp_begrazing_uitvoering_20261111 s
JOIN maatregel_project p ON p.project_code=s.project_code
JOIN maatregelen m ON m.code=s.maatregel_code
ON DUPLICATE KEY UPDATE
  project_id=VALUES(project_id),maatregel_id=VALUES(maatregel_id),maatregeltype_code=VALUES(maatregeltype_code),
  activiteit_code=VALUES(activiteit_code),uitvoering_status_code=VALUES(uitvoering_status_code),naam=VALUES(naam),
  omschrijving=VALUES(omschrijving),locatie_naam=VALUES(locatie_naam),locatie_precisie=VALUES(locatie_precisie),
  datum_vanaf=VALUES(datum_vanaf),datum_tot=VALUES(datum_tot),datum_precisie=VALUES(datum_precisie),
  cycliciteit=VALUES(cycliciteit),uitvoerder=VALUES(uitvoerder),gerealiseerde_hoeveelheid=VALUES(gerealiseerde_hoeveelheid),
  hoeveelheid_eenheid=VALUES(hoeveelheid_eenheid),opmerking=VALUES(opmerking);

DELETE j FROM maatregel_uitvoering_jaar j JOIN maatregel_uitvoering u USING (uitvoering_id)
WHERE u.uitvoering_code='pas_22h_aanvullend_beheer' AND j.jaar IN (2016,2018,2019,2020,2021);
UPDATE maatregel_uitvoering_jaar j JOIN maatregel_uitvoering u USING (uitvoering_id)
SET j.toelichting='Beperkt gemaaid; de deelbegrazing is als afzonderlijke uitvoering geregistreerd.'
WHERE u.uitvoering_code='pas_22h_aanvullend_beheer' AND j.jaar=2017;
UPDATE maatregel_uitvoering_jaar j
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN maatregel_bron b ON b.bron_code='zotero_begrazing_1990_bakker'
SET j.bron_id=b.bron_id,j.toelichting='Noorse fjordenpaarden uitgezet op 29 september; Gallowayrunderen volgden kort daarna.'
WHERE u.uitvoering_code='begrazing_kijfhoek_bierlap_1990' AND j.jaar=1990;

DROP TEMPORARY TABLE IF EXISTS tmp_begrazing_jaar_20261111;
CREATE TEMPORARY TABLE tmp_begrazing_jaar_20261111 (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,jaar SMALLINT UNSIGNED NOT NULL,
  jaarstatus VARCHAR(24) CHARACTER SET ascii NOT NULL,bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,toelichting VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_code,jaar)
) ENGINE=InnoDB;
INSERT INTO tmp_begrazing_jaar_20261111 VALUES
  ('begrazingsdruk_kijfhoek_bierlap_1995',1995,'uitgevoerd','zotero_begrazing_2012','Graasdruk verlaagd van circa een dier per 12 hectare naar circa een dier per 18 hectare.'),
  ('begrazing_m74_1996',1996,'uitgevoerd','handmatig_begrazing_m74_20261111','Doorlopende begrazing van M74 begon volgens de handmatige bronvaststelling in 1996.'),
  ('begrazing_meeuwenhoek_2004',2004,'uitgevoerd','zotero_begrazingsbeheer_2014_obn','Begrazing met runderen en paarden vanaf 2004.'),
  ('pas_22h_schapenbegrazing_2016',2016,'uitgevoerd','zotero_n2000_evaluatie_2025','Half november tot half december begraasd met 200 Kempense schapen.'),
  ('pas_22h_deelbegrazing_2017',2017,'uitgevoerd','zotero_n2000_evaluatie_2025','Delen van het maatregelgebied zijn begraasd.'),
  ('begrazingsregime_meijendel_2019_2023',2019,'uitgevoerd','eis_bijenmonitoring_2023','Monitoringsjaar met verlaagde graasdruk en onderscheiden winter- en jaarrondbegrazing.'),
  ('begrazingsregime_meijendel_2019_2023',2021,'uitgevoerd','eis_bijenmonitoring_2023','Monitoringsjaar met verlaagde graasdruk en onderscheiden winter- en jaarrondbegrazing.'),
  ('begrazingsregime_meijendel_2019_2023',2023,'uitgevoerd','eis_bijenmonitoring_2023','Monitoringsjaar met verlaagde graasdruk en onderscheiden winter- en jaarrondbegrazing.');
INSERT INTO maatregel_uitvoering_jaar (uitvoering_id,jaar,jaarstatus,bron_id,toelichting)
SELECT u.uitvoering_id,s.jaar,s.jaarstatus,b.bron_id,s.toelichting
FROM tmp_begrazing_jaar_20261111 s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
ON DUPLICATE KEY UPDATE jaarstatus=VALUES(jaarstatus),bron_id=VALUES(bron_id),toelichting=VALUES(toelichting);

UPDATE maatregel_uitvoering_bron ub
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN maatregel_bron b USING (bron_id)
SET ub.bronrol='bevestiging',ub.bewijsnotitie='Bevestigt invoering in 1990 en noemt circa 270 hectare; de bronwaarde blijft naast de 275 hectare uit 2012 bewaard.'
WHERE u.uitvoering_code='begrazing_kijfhoek_bierlap_1990' AND b.bron_code='zotero_begrazing_2008' AND ub.bronrol='primaire_uitvoeringsbron';
UPDATE maatregel_uitvoering_bron ub
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN maatregel_bron b USING (bron_id)
SET ub.bronrol='bevestiging',ub.bewijsnotitie='Bevestigt de administratieve toevoeging van Meeuwenhoek aan Kijfhoek en Bierlap in 2005; dit is onderscheiden van de fysieke start in 2004.'
WHERE u.uitvoering_code='begrazing_meeuwenhoek_2004' AND b.bron_code='zotero_begrazing_2008' AND ub.bronrol='primaire_uitvoeringsbron';

DROP TEMPORARY TABLE IF EXISTS tmp_begrazing_uitvoering_bron_20261111;
CREATE TEMPORARY TABLE tmp_begrazing_uitvoering_bron_20261111 (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  bronrol VARCHAR(32) CHARACTER SET ascii NOT NULL,pagina_of_paragraaf VARCHAR(255) NULL,bewijsnotitie VARCHAR(1500) NOT NULL,
  PRIMARY KEY (uitvoering_code,bron_code,bronrol)
) ENGINE=InnoDB;
INSERT INTO tmp_begrazing_uitvoering_bron_20261111 VALUES
  ('begrazing_kijfhoek_bierlap_1990','zotero_begrazing_1990_bakker','primaire_uitvoeringsbron',NULL,'Primaire bron voor de introductie van paarden op 29 september 1990; runderen volgden kort daarna.'),
  ('begrazing_kijfhoek_bierlap_1990','zotero_begrazing_1992_monitoring','bevestiging',NULL,'Bevestigt en karteert het toenmalige begrazingsgebied; de kaartgrens is nog niet digitaal over de huidige kavels gelegd.'),
  ('begrazing_kijfhoek_bierlap_1990','zotero_begrazingsonderzoek_1993','bevestiging',NULL,'Beschrijft de ontwikkeling na drie jaar begrazing.'),
  ('begrazing_kijfhoek_bierlap_1990','zotero_begrazing_1999_de_bonte','bevestiging',NULL,'Wetenschappelijke evaluatie van de vegetatieontwikkeling onder begrazing.'),
  ('begrazingsdruk_kijfhoek_bierlap_1995','zotero_begrazing_2012','primaire_uitvoeringsbron',NULL,'Beschrijft de verlaging van circa een dier per 12 hectare naar circa een dier per 18 hectare.'),
  ('begrazingsdruk_kijfhoek_bierlap_1995','zotero_begrazing_1999_de_bonte','bevestiging',NULL,'Ondersteunt de evaluatie van de gewijzigde begrazingsdruk; de historische gebiedsgrens wordt niet naar actuele kavels vertaald.'),
  ('begrazing_m74_1996','handmatig_begrazing_m74_20261111','primaire_uitvoeringsbron',NULL,'Ton bevestigde de ononderbroken begrazing van M74 vanaf 1996; de specifieke kavelstart is niet onafhankelijk gepubliceerd.'),
  ('begrazing_helmduinen_1991','zotero_rabbits_rule_2022','tegenstrijdig_bewijs',NULL,'Het proefschrift en enkele tabellen gebruiken 1992; de historische beheersevaluatie noemt eind 1991.'),
  ('begrazing_meeuwenhoek_2004','zotero_begrazingsbeheer_2014_obn','primaire_uitvoeringsbron',NULL,'Noemt begrazing met runderen en paarden vanaf 2004.'),
  ('begrazing_meeuwenhoek_2004','zotero_begrazingsbeheer_2012_fauna','bevestiging',NULL,'Onderzoekscontext voor de vijf Meeuwenhoek-kavels; geen uitbreiding naar de overige elf kavels van de actuele regio.'),
  ('pas_22h_schapenbegrazing_2016','zotero_n2000_evaluatie_2025','primaire_uitvoeringsbron',NULL,'Bevestigt inzet van 200 Kempense schapen van half november tot half december 2016.'),
  ('pas_22h_deelbegrazing_2017','zotero_n2000_evaluatie_2025','primaire_uitvoeringsbron',NULL,'Bevestigt dat in 2017 delen van het maatregelgebied zijn begraasd.'),
  ('begrazingsregime_meijendel_2019_2023','eis_bijenmonitoring_2023','primaire_uitvoeringsbron',NULL,'Beschrijft voor 2019, 2021 en 2023 winterbegrazing in Buitenduinen en jaarrondbegrazing in de overige genoemde eenheden.'),
  ('begrazingsregime_meijendel_2019_2023','zotero_rabbits_rule_2022','bevestiging',NULL,'Biedt beheerhistorische context voor de lagere graasdruk vanaf 2019.'),
  ('pas_3c_begrazing_vanaf_2022','zotero_n2000_evaluatie_2025','primaire_uitvoeringsbron',NULL,'Bevestigt dat Dunea de in 2017-2021 uitgevoerde jaarlijkse begrazing daarna als beheer voortzet.'),
  ('kikkervalleien_begrazing_1997','zotero_begrazing_2012','tegenstrijdig_bewijs',NULL,'Van der Hagen noemt circa 30 hectare Kikkervalleien; Holland''s Duinen 55 noemt circa 50 hectare. Beide waarden blijven als bronwaarden bestaan.');
INSERT INTO maatregel_uitvoering_bron (uitvoering_id,bron_id,bronrol,pagina_of_paragraaf,bewijsnotitie)
SELECT u.uitvoering_id,b.bron_id,s.bronrol,s.pagina_of_paragraaf,s.bewijsnotitie
FROM tmp_begrazing_uitvoering_bron_20261111 s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
ON DUPLICATE KEY UPDATE pagina_of_paragraaf=VALUES(pagina_of_paragraaf),bewijsnotitie=VALUES(bewijsnotitie);

DELETE pk FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN plots p USING (plot_id)
WHERE u.uitvoering_code='begrazing_meeuwenhoek_2004' AND p.kavel_nummer='M74';
UPDATE maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN maatregel_bron b ON b.bron_code='zotero_begrazingsbeheer_2014_obn'
SET pk.bron_id=b.bron_id,
    pk.opmerking='De actuele nameninventaris doorsnijdt deze kavel met Meeuwenhoek. OBN noemt begrazing vanaf 2004; de exacte uitvoeringsvoetafdruk binnen de kavel is niet gepubliceerd.'
WHERE u.uitvoering_code='begrazing_meeuwenhoek_2004';

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT u.uitvoering_id,p.plot_id,'expliciet_in_bron',NULL,'geverifieerd',b.bron_id,
       'Ton bevestigde op 11 november 2026 dat M74 vanaf 1996 zonder onderbreking wordt begraasd.'
FROM maatregel_uitvoering u
JOIN plots p ON p.kavel_nummer='M74'
JOIN maatregel_bron b ON b.bron_code='handmatig_begrazing_m74_20261111'
WHERE u.uitvoering_code='begrazing_m74_1996'
ON DUPLICATE KEY UPDATE koppelmethode=VALUES(koppelmethode),doorsnijding_pct=VALUES(doorsnijding_pct),verificatiestatus=VALUES(verificatiestatus),bron_id=VALUES(bron_id),opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT u.uitvoering_id,p.plot_id,'benoemd_gebied_gevalideerd',NULL,'geverifieerd',b.bron_id,
       CONCAT(CASE u.uitvoering_code WHEN 'pas_22h_schapenbegrazing_2016' THEN 'De tijdelijke kudde van 200 Kempense schapen is in 2016 ingezet. ' ELSE 'De bron meldt in 2017 begrazing van delen. ' END,
              'De bron verdeelt de uitvoering niet over de naamgebieden of de zes gekoppelde kavels; dit is uitsluitend de gezamenlijke scope.')
FROM maatregel_uitvoering u
JOIN plots p ON p.kavel_nummer IN ('M13s','M15','M16','M17a','M77','M78/79')
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
WHERE u.uitvoering_code IN ('pas_22h_schapenbegrazing_2016','pas_22h_deelbegrazing_2017')
ON DUPLICATE KEY UPDATE koppelmethode=VALUES(koppelmethode),doorsnijding_pct=VALUES(doorsnijding_pct),verificatiestatus=VALUES(verificatiestatus),bron_id=VALUES(bron_id),opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT u.uitvoering_id,p.plot_id,'benoemd_gebied_gevalideerd',NULL,'geverifieerd',b.bron_id,
       'Dunea heeft de jaarlijkse begrazing na 2021 voortgezet. De vervolguitvoering gebruikt dezelfde dertien gezamenlijk gevalideerde kavels, maar krijgt zonder kalenderjaarspecifieke bron geen jaarregels.'
FROM maatregel_uitvoering u
JOIN plots p ON p.kavel_nummer IN ('M1a','M1b','M3','M4-5','M45','M51','M52','M53','M54a','M54b','M55','M83','M85')
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
WHERE u.uitvoering_code='pas_3c_begrazing_vanaf_2022'
ON DUPLICATE KEY UPDATE koppelmethode=VALUES(koppelmethode),doorsnijding_pct=VALUES(doorsnijding_pct),verificatiestatus=VALUES(verificatiestatus),bron_id=VALUES(bron_id),opmerking=VALUES(opmerking);

COMMIT;
