-- Eerste bronvaste invoer van werkzaamheden in Meijendel.
-- Stand bronbeoordeling: 15 oktober 2026.
-- Geen uitvoeringsgeometrieën; plotkoppelingen worden alleen opgenomen waar de
-- geraadpleegde bronnen de betrokken kavels expliciet noemen.

USE Meijendel;

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_bron_seed;
CREATE TEMPORARY TABLE tmp_maatregel_bron_seed (
  bron_code VARCHAR(96) CHARACTER SET ascii PRIMARY KEY,
  brontype_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  titel VARCHAR(500) NOT NULL,
  bron_datum DATE NULL,
  zotero_item_key VARCHAR(16) CHARACTER SET ascii NULL,
  url VARCHAR(1000) NULL,
  raadpleegdatum DATE NOT NULL,
  bronstatus VARCHAR(80) NULL,
  opmerking TEXT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_bron_seed
  (bron_code, brontype_code, titel, bron_datum, zotero_item_key, url, raadpleegdatum, bronstatus, opmerking) VALUES
  ('zotero_pan13_1991','beheerpublicatie','De slibverwijdering van Pan 13','1991-04-01','96NVCM5S',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag.'),
  ('zotero_broedvogelmonitoring_2006','beheerpublicatie','Broedvogelmonitoring Meijendel 2006','2007-11-01','PPHE9GVI',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag; PPHE9GVI is de beschikbare Zotero-bijlagecode.'),
  ('zotero_kikkervalleien_2010','beheerpublicatie','Natuurherstel van de Kikkervalleien in Noord-Meijendel','2010-04-01','USGTMZNW',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag.'),
  ('zotero_stuifgaten_2017','beheerpublicatie','Grenzen slechten in Meijendel: stuifgaten in de zeereep','2017-11-01','C224J22K',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag.'),
  ('zotero_n2000_evaluatie_2025','natura2000_beheerplan','Evaluatie Natura 2000-beheerplan Meijendel & Berkheide','2025-04-25','DUNY3DCC',NULL,'2026-10-13','definitief','Definitieve evaluatie; uitvoeringsstatus gebaseerd op jaarrapportages en gesprekken met terreinbeheerders.'),
  ('zotero_n2000_ontwerp_2026','natura2000_beheerplan','Ontwerp Natura 2000-beheerplan Meijendel & Berkheide 2026-2032','2026-01-13','LAW9SJXC','https://www.zuid-holland.nl/politiek-bestuur/gedeputeerde-staten/besluiten/besluit/ontwerpbesluit-vaststelling-natura-2000-beheerplan-meijendel-en-berkheide-2026-2','2026-10-13','ontwerp','Alleen gebruikt voor geactualiseerde historische uitvoering en als plancontext; ontwerpmaatregelen zijn niet als uitgevoerd aangemerkt.'),
  ('dunea_optimalisatie_waterwinning_2018','officiele_webpagina','Optimalisatie waterwinsysteem Meijendel afgerond','2018-10-22',NULL,'https://www.dunea.nl/zakelijk/nieuwsbrieven/nieuwsbrief-2018-10/optimalisatie-waterwinsysteem-meijendel-afgerond','2026-10-13','officiele_publicatie','Dunea meldt afronding van het achtjarige programma.'),
  ('dunea_beheer_meijendel_2023','officiele_webpagina','Beheersmaatregelen Meijendel ter bevordering van oorspronkelijke flora en fauna','2023-11-13',NULL,'https://www.dunea.nl/over-dunea/algemeen/nieuws/2023/beheersmaatregelen-meijendel-ter-bevordering-van-oorspronkelijke-flora-en-fauna','2026-10-13','officiele_publicatie','Dunea beschrijft start en aard van de werkzaamheden in Meeuwenduin en Prinsenduin.'),
  ('dunea_jaarverslag_2024','onderzoeksrapport','Dunea jaarverslag 2024','2025-01-01',NULL,'https://www.dunea.nl/duinen/-/media/bestanden/over-dunea/jaarberichten/dunea-jaarverslag-2024.pdf','2026-10-13','vastgesteld_jaarverslag','Bevestigt voortzetting beheerwerk en start konijnenproef in 2024.'),
  ('odh_konijnenontheffing_2023','inrichtingsplan','Beschikking Wet natuurbescherming: pilot uitzetten konijnen in Meijendel','2023-08-28',NULL,'https://omgevingsdiensthaaglanden.nl/wp-content/uploads/besluiten/2023/08/30/4e5424ce-bc9f-42ce-870f-1a146507f6d1/Besluit%20op%20aanvraag%2001069060-ODH701135.pdf','2026-10-14','definitieve_beschikking','Zaak 01069060, kenmerk ODH701135. Bevat het activiteitenplan met de twee uitzetlocaties Kleine Pan en Waterschapsvallei en kaartbijlagen; vergunning geldig tot en met 31 maart 2026.'),
  ('dunea_slagbomen_2025','officiele_webpagina','Vervangen slagbomen Meijendel','2025-11-25',NULL,'https://www.dunea.nl/algemeen/nieuws/2025/vervangen-slagbomen-meijendel','2026-10-13','officiele_publicatie','Werkperiode 1 tot en met 12 december 2025.'),
  ('dunea_reguliere_werkzaamheden_2026','officiele_webpagina','Reguliere werkzaamheden in Meijendel','2026-10-13',NULL,'https://www.dunea.nl/duinen/werkzaamheden/reguliere-werkzaamheden','2026-10-13','actuele_webpagina','De pagina bevat geplande werkzaamheden bij de Paardenstal en elektriciteitswerk in Vallei Meijendel; uitvoering is niet als voltooid bevestigd.'),
  ('odh_paardenstal_beschikking_2025','inrichtingsplan','Beschikking flora- en fauna-activiteit: renovatie dak Paardenstal Hart van Meijendel','2025-11-05',NULL,'https://cuatro.sim-cdn.nl/wassenaar/uploads/besluit_op_aanvraag_01132870-odh1498120.pdf?cb=o8hXZHXK','2026-10-15','definitieve_beschikking','Zaak 01132870, kenmerk ODH1498120. Definitieve vergunning voor renovatie van de Paardenstal bij Hart van Meijendel; de kaartbijlagen begrenzen het plangebied. Geldig tot en met 15 maart 2027.'),
  ('pzh_bendel_subsidie_2026','subsidiebesluit','Openstellingsbesluit subsidie natuurmaatregelen 2026','2026-04-22',NULL,'https://zoek.officielebekendmakingen.nl/prb-2026-6828.html','2026-10-13','subsidie_openstelling','Subsidieerbaarheid van Bendel-nabeheer bewijst geen uitvoering.'),
  ('staatsbosbeheer_bendel_2026','officiele_webpagina','Herinrichting Bendel',NULL,NULL,'https://www.staatsbosbeheer.nl/wat-we-doen/werk-in-uitvoering/hollands-duin-herinrichting-bendel','2026-10-15','actuele_webpagina','Staatsbosbeheer lokaliseert Bendel expliciet in Berkheide-Noord en noemt als looptijd najaar 2025 tot voorjaar 2026.'),
  ('dunea_dynamiek_2024','officiele_webpagina','Dynamiek in het duin','2024-12-18',NULL,'https://www.dunea.nl/zakelijk/nieuwsbrieven/nieuwsbrief-2024-12/dynamiek-in-het-duin','2026-10-13','officiele_publicatie','Bevestigt vijf in 2015 voltooide kerven en aanvang van het werk in september 2014.'),
  ('zotero_vogelrapport_1967','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1967',NULL,'JVDIWBDE',NULL,'2026-10-14','gepubliceerd','Volledige rapporttekst geraadpleegd; 1967 is het rapportjaar, een exacte publicatiedatum is niet vastgelegd.'),
  ('zotero_vogelrapport_1968','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1968',NULL,'3B2FN68M',NULL,'2026-10-14','gepubliceerd','Volledige rapporttekst geraadpleegd; 1968 is het rapportjaar, een exacte publicatiedatum is niet vastgelegd.'),
  ('zotero_vogelrapport_1969','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1969',NULL,'F87WJAIG',NULL,'2026-10-14','gepubliceerd','Volledige rapporttekst geraadpleegd; 1969 is het rapportjaar. De reparatie bij Plas 20 is opgenomen, de onbedoelde droogval door Rijnverontreiniging niet.'),
  ('zotero_vogelrapport_1972','beheerpublicatie','Meijendelonderzoek - Vogelpopulaties: Rapport 1972',NULL,'EP58F3ZI',NULL,'2026-10-14','gepubliceerd','Volledige rapporttekst geraadpleegd; 1972 is het rapportjaar. Dubbele Zotero-exemplaren zijn niet als afzonderlijke bron geregistreerd.'),
  ('zotero_vogelrapport_1973','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1973','1974-08-01','HDRX28C3',NULL,'2026-10-14','gepubliceerd','Rapport over kalenderjaar 1973; publicatiedatum augustus 1974.'),
  ('zotero_vogelrapport_1974','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1974','1976-11-01','HTUFWIAS',NULL,'2026-10-14','gepubliceerd','Rapport over kalenderjaar 1974; publicatiedatum november 1976.'),
  ('zotero_vogelrapport_1975','beheerpublicatie','Vogelpopulatieonderzoek Meijendel - Rapport 1975',NULL,'8CFXEBIQ',NULL,'2026-10-14','gepubliceerd','Volledige rapporttekst geraadpleegd; 1975 is het rapportjaar, een exacte publicatiedatum is niet vastgelegd.'),
  ('zotero_rietpoten_1992','onderzoeksrapport','De toepassing van rietpoten ter bestrijding van winderosie in Meijendel: het effect na drie jaar','1992-04-01','NZWRNSSI',NULL,'2026-10-14','gepubliceerd','Beschrijft aanleg van proefvlakken van 29 oktober tot en met 6 november 1987.'),
  ('zotero_begrazing_2008','beheerpublicatie','Begrazingsbeheer in Meijendel','2008-04-01','4BFHKS7Q',NULL,'2026-10-14','gepubliceerd','Beschrijft invoering en uitbreiding van extensieve begrazing vanaf september 1990.'),
  ('zotero_begrazing_2012','onderzoeksrapport','Evaluatie begrazingsbeheer Meijendel','2012-11-01','JQZFPPEK',NULL,'2026-10-14','gepubliceerd','Bevestigt start in september 1990 en noemt oppervlakten van Kijfhoek-Bierlap en Helmduinen.'),
  ('zotero_valleien_2003','beheerpublicatie','Vegetatieontwikkeling in duinvalleien van Meijendel na opheffen van infiltratieplassen','2003-04-01','9Z4K34B6',NULL,'2026-10-14','gepubliceerd','Holland''s Duinen 42, april 2003. Beschrijft maaien in de Libellenvallei, plaggen langs het Parnassiapad en de Kikkervalleien.'),
  ('zotero_natuurherstel_2005','beheerpublicatie','Natuurherstel in de Kikkervalleien','2005-11-01','G3K24ZDB',NULL,'2026-10-14','gepubliceerd','Aanvullende bevestiging van de in 1997 uitgevoerde eerste herstelfase.'),
  ('zotero_slib_plassen_2005','beheerpublicatie','Slib in infiltratieplassen van Meijendel','2005-04-01','MUAD7GB2',NULL,'2026-10-14','gepubliceerd','Alleen de als uitgevoerd beschreven slibverwijdering in plas 8.4.2 uit 2002 is ingevoerd; prioriteiten en voorstellen niet.'),
  ('zotero_plas20_2006','beheerpublicatie','Schone start voor infiltratieplas 20 in Meijendel','2006-03-01','4KR5RBAH',NULL,'2026-10-14','gepubliceerd','Holland''s Duinen 48, maart 2006. Zotero noemt ten onrechte 1989; dat jaar verwijst in de tekst naar de eerdere slibverwijdering in Plas 13. Uitgestelde valleiwerkzaamheden zijn niet als uitgevoerd ingevoerd.'),
  ('zotero_hollands_duinen_86_2025','beheerpublicatie','Holland''s Duinen - nummer 86','2025-05-01','ZS99KGRA',NULL,'2026-10-14','gepubliceerd','Het artikel Vlinders in Meijendel: aantallen in 2024 langs twee telroutes toont op p. 49, figuur 1, de ligging van de dagvlinderroute Parnassiapad. Gebruikt als aanvullende ruimtelijke context, niet als bron voor het plagjaar.'),
  ('zotero_meijendel_mededelingen_30_1996','beheerpublicatie','Meijendel Mededelingen - aflevering 30','1996-11-01','2TXQMXTB',NULL,'2026-10-14','gepubliceerd','Volledige aflevering geraadpleegd. Pagina 99 koppelt Sprang PI letterlijk aan kavel 13s en beschrijft het betrokken rietgebied als gelegen in kavels 13s en 14; gebruikt als ruimtelijke plancontext voor de herinrichting van 1997.'),
  ('zotero_hollands_duinen_88_2026','beheerpublicatie','Holland''s Duinen - nummer 88','2026-04-01','JI7RKU9B','https://www.dunea.nl/duinen/-/media/bestanden/duinen/hollands-duinen/dunea---hollands-duinen-nummer-88.pdf','2026-10-15','gepubliceerd','Het artikel Herinrichting Bendel - Werk om trots op te zijn! op pagina 47-50 beschrijft uitvoering van oktober 2025 tot maart 2026 en lokaliseert het project in Berkheide.'),
  ('zotero_prinsenduin_2020','onderzoeksrapport','Is livestock grazing a key factor for changing vegetation patterns in lime rich coastal dunes in the Netherlands?','2020-03-14','IVRJVABT','https://doi.org/10.1007/s11852-020-00733-z','2026-10-15','gepubliceerd','Figuur 1 onderscheidt Prinsenduin, Lange Strooken en Helmduinen als afzonderlijke onderzoeksgebieden. Gebruikt als ruimtelijke context; de plottoedeling volgt uit de combinatie met de nameninventaris en Tons vaststelling.'),
  ('denhaag_pim_archeologie_2013','onderzoeksrapport','Dunea. Programma Investeringen Meijendel, gemeenten Den Haag en Wassenaar','2013-01-01',NULL,'https://doi.org/10.17026/DANS-XTN-EEV7','2026-10-15','gepubliceerd','Haagse Archeologische Rapportage 1306 van M. Benjamins. Afbeelding 1 begrenst de PIM-werkgebieden; bijlage 2 specificeert het leidingwerk per winningsserie. Alleen het publicatiejaar 2013 is bekend, daarom is 1 januari als datumprecisie op jaarniveau vastgelegd.');

INSERT INTO maatregel_bron
  (bron_code, brontype_code, titel, bron_datum, zotero_item_key, url, raadpleegdatum, bronstatus, opmerking)
SELECT bron_code, brontype_code, titel, bron_datum, zotero_item_key, url, raadpleegdatum, bronstatus, opmerking
FROM tmp_maatregel_bron_seed
ON DUPLICATE KEY UPDATE
  brontype_code=VALUES(brontype_code), titel=VALUES(titel), bron_datum=VALUES(bron_datum),
  zotero_item_key=VALUES(zotero_item_key), url=VALUES(url), raadpleegdatum=VALUES(raadpleegdatum),
  bronstatus=VALUES(bronstatus), opmerking=VALUES(opmerking);

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_project_seed;
CREATE TEMPORARY TABLE tmp_maatregel_project_seed (
  project_code VARCHAR(96) CHARACTER SET ascii PRIMARY KEY,
  naam VARCHAR(255) NOT NULL,
  omschrijving TEXT NULL,
  werkcategorie_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  verantwoordelijke_organisatie VARCHAR(255) NULL,
  bestuurlijke_status VARCHAR(120) NULL,
  natura2000_gebied VARCHAR(255) NULL,
  deelgebied VARCHAR(255) NULL,
  plan_startdatum DATE NULL,
  plan_einddatum DATE NULL,
  programma VARCHAR(255) NULL,
  financiering VARCHAR(255) NULL,
  externe_projectcode VARCHAR(120) NULL
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_project_seed VALUES
  ('pan13_slibverwijdering','Slibverwijdering en oeveraanpassing Pan 13','Schoonmaken van infiltratiepan 13 en plaatselijk verflauwen van oevers.','waterwinning','Duinwaterbedrijf Zuid-Holland','afgerond','Meijendel & Berkheide','Pan 13','1988-10-01','1989-01-31',NULL,NULL,NULL),
  ('kikkervalleien_herstel','Natuurherstel Kikkervalleien en Pan 26.1','Herstel van circa 50 ha vochtige en droge duinvallei na buitengebruikstelling van een groot deel van Pan 26.1.','natuurbeheer','Dunea','afgerond_met_nabeheer','Meijendel & Berkheide','Kikkervalleien, Pan 26.1 en Sprang PI','1997-01-01',NULL,NULL,NULL,NULL),
  ('zeereep_kerven','Pilot dynamisch zeereepbeheer Meijendel','Aanleg van vijf kerven en daaropvolgend nabeheer voor wind- en zanddynamiek.','natuurbeheer','Dunea','uitgevoerd_met_doorlopend_nabeheer','Meijendel & Berkheide','Zeereep Meijendel','2013-01-01',NULL,'PAS','Provincie Zuid-Holland', 'PAS-1'),
  ('pas_meijendel_grijze_duinen','PAS-beheer grijze duinen Meijendel','Uitvoering van de in de eerste Natura 2000-beheerplanperiode beschreven beheermaatregelen.','natuurbeheer','Dunea, Staatsbosbeheer en Defensie','gemengd_uitgevoerd','Meijendel & Berkheide','Meijendel','2014-01-01','2025-12-31','PAS',NULL,NULL),
  ('kikkervallei_watercrassula','Bestrijding watercrassula Kikkervallei','Afdekken en vervolgbestrijding van watercrassula.','natuurbeheer','Dunea','doorlopend','Meijendel & Berkheide','Kikkervallei','2015-01-01',NULL,NULL,NULL,NULL),
  ('meeuwenduin_prinsenduin_beheer','Verwijdering bomen, struiken en exoten Meeuwenduin en Prinsenduin','Herstel van open duin door verwijdering van opslag en exoten.','natuurbeheer','Dunea','uitgevoerd_en_voortgezet','Meijendel & Berkheide','Meeuwenduin en Prinsenduin','2023-11-01','2024-12-31',NULL,'Gedeeltelijk RVO',NULL),
  ('konijnen_bijplaatsing','Konijnenbijplaatsingsproef Meijendel','Proef met bijplaatsing en monitoring van konijnen voor herstel van de begrazingsfunctie.','onderzoek_monitoring','Dunea','uitvoering_2024_bevestigd_vervolg_onbekend','Meijendel & Berkheide','Kleine Pan en Waterschapsvallei','2024-01-01','2026-03-31',NULL,NULL,NULL),
  ('optimalisatie_waterwinning','Optimalisatie waterwinsysteem Meijendel','Achtjarig programma met putten, leidingen, schoning van infiltratiepannen en natuurherstel.','waterwinning','Dunea','afgerond','Meijendel & Berkheide','Meijendel','2010-01-01','2018-10-22',NULL,'Projectomvang 40 miljoen euro; natuurherstel voor 50 procent gesubsidieerd',NULL),
  ('slagbomen_2025','Vervanging slagbomen Meijendel','Vervanging van slagbomen bij toegangen tot Meijendel.','infrastructuur','Dunea','afgerond','Meijendel & Berkheide','Meijendel','2025-12-01','2025-12-12',NULL,NULL,NULL),
  ('vallei_elektriciteit_2026','Elektriciteitswerk Vallei Meijendel','Kabel, elektriciteitskast en voorbereiding van drie laadpunten met zes plaatsen.','infrastructuur','Dunea','uitvoering_niet_bevestigd','Meijendel & Berkheide','Vallei Meijendel','2026-09-23',NULL,NULL,NULL,NULL),
  ('paardenstal_2026_2027','Werkzaamheden Paardenstal','Geplande renovatie van dak, gevels en kozijnen, plaatsing van zonnecollectoren en aanleg van water- en elektriciteitsleidingen, met voorafgaande maatregelen voor vleermuizen.','infrastructuur','Dunea','gepland','Meijendel & Berkheide','Paardenstal','2026-11-01','2027-03-31',NULL,NULL,NULL),
  ('bendel_nabeheer_2026','Herinrichting en nabeheer Bendel','Afgeronde herinrichting in 2025-2026 en afzonderlijk subsidieerbaar nabeheer voor H2130 en H2190; Bendel ligt in Berkheide-Noord, buiten de 55 Meijendel-plots.','natuurbeheer','Staatsbosbeheer','herinrichting_afgerond_nabeheer_gepland','Meijendel & Berkheide','Bendel, Berkheide-Noord','2025-10-01',NULL,'Subsidieregeling natuurmaatregelen 2026','Provincie Zuid-Holland en Europese Commissie','97-NP-263'),
  ('historische_waterwinning_1967_1975','Historische werkzaamheden waterwinning 1967-1975','Schoonmaak, peilbeheer, leidingen en aanleg of afwerking van infiltratieplassen zoals jaarlijks beschreven in de vogelrapporten.','waterwinning','Duinwaterleiding van s-Gravenhage','afgerond','Meijendel & Berkheide','Meijendel','1967-01-01','1975-12-31',NULL,NULL,NULL),
  ('historische_recreatiepaden_1974_1975','Aanleg wandel- en ruiterpaden 1974-1975','Aanleg en voltooiing van paden rond Ganzenhoek en kavel 13.','recreatie','Duinwaterleiding van s-Gravenhage','afgerond','Meijendel & Berkheide','Ganzenhoek en omgeving','1974-01-01','1975-12-31',NULL,NULL,NULL),
  ('rietpotenproef_1987','Rietpotenproef tegen winderosie','Aanleg van proefvlakken met rietpoten in stuifplekken in Noord-Meijendel.','natuurbeheer','Duinwaterleiding van s-Gravenhage','afgerond','Meijendel & Berkheide','Noord-Meijendel','1987-10-29','1987-11-06',NULL,NULL,NULL),
  ('integrale_begrazing_1990','Invoering extensieve begrazing vanaf 1990','Stapsgewijze invoering en uitbreiding van extensieve begrazing in Meijendel.','natuurbeheer','Duinwaterbedrijf Zuid-Holland','uitgevoerd_met_doorlopend_beheer','Meijendel & Berkheide','Meijendel','1990-09-01',NULL,NULL,NULL,NULL),
  ('duinvalleibeheer_1975_2003','Historisch beheer duinvalleien 1975-2003','Maaien en plaggen in de Libellenvallei en langs het Parnassiapad.','natuurbeheer','Duinwaterbedrijf Zuid-Holland','afgerond_of_voortgezet','Meijendel & Berkheide','Libellenvallei en Parnassiapad','1975-01-01','2003-12-31',NULL,NULL,NULL),
  ('slibverwijdering_plassen_2002_2006','Slibverwijdering en inrichting infiltratieplassen 2002-2006','Slibverwijdering en hydrologische en infrastructurele aanpassingen in plas 8.4.2 en Plas 20.1.','waterwinning','Duinwaterbedrijf Zuid-Holland','afgerond','Meijendel & Berkheide','Infiltratieplassen 8.4.2 en 20.1','2002-01-01','2006-03-01',NULL,NULL,NULL);

INSERT INTO maatregel_project
  (project_code, naam, omschrijving, werkcategorie_code, verantwoordelijke_organisatie,
   bestuurlijke_status, natura2000_gebied, deelgebied, plan_startdatum, plan_einddatum,
   programma, financiering, externe_projectcode)
SELECT project_code, naam, omschrijving, werkcategorie_code, verantwoordelijke_organisatie,
       bestuurlijke_status, natura2000_gebied, deelgebied, plan_startdatum, plan_einddatum,
       programma, financiering, externe_projectcode
FROM tmp_maatregel_project_seed
ON DUPLICATE KEY UPDATE
  naam=VALUES(naam), omschrijving=VALUES(omschrijving), werkcategorie_code=VALUES(werkcategorie_code),
  verantwoordelijke_organisatie=VALUES(verantwoordelijke_organisatie), bestuurlijke_status=VALUES(bestuurlijke_status),
  natura2000_gebied=VALUES(natura2000_gebied), deelgebied=VALUES(deelgebied),
  plan_startdatum=VALUES(plan_startdatum), plan_einddatum=VALUES(plan_einddatum),
  programma=VALUES(programma), financiering=VALUES(financiering), externe_projectcode=VALUES(externe_projectcode);

-- Correctie binnen deze seed: de aanvankelijk samengestelde M2/M3-regel is
-- gesplitst in twee atomaire uitvoeringen met een eigen activiteitstype.
DELETE FROM maatregel_uitvoering
WHERE uitvoering_code='pannen_2_3_schoonmaak_1967';

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_seed;
CREATE TEMPORARY TABLE tmp_maatregel_uitvoering_seed (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii PRIMARY KEY,
  project_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  maatregel_code VARCHAR(50) CHARACTER SET ascii NULL,
  maatregeltype_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  activiteit_code VARCHAR(8) CHARACTER SET ascii NOT NULL,
  uitvoering_status_code VARCHAR(32) CHARACTER SET ascii NOT NULL,
  naam VARCHAR(255) NOT NULL,
  omschrijving TEXT NULL,
  locatie_naam VARCHAR(255) NOT NULL,
  locatie_precisie VARCHAR(32) CHARACTER SET ascii NOT NULL,
  datum_vanaf DATE NULL,
  datum_tot DATE NULL,
  datum_precisie VARCHAR(16) CHARACTER SET ascii NOT NULL,
  cycliciteit VARCHAR(120) NULL,
  uitvoerder VARCHAR(255) NULL,
  gerealiseerde_hoeveelheid DECIMAL(16,4) NULL,
  hoeveelheid_eenheid VARCHAR(24) NULL,
  opmerking TEXT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_uitvoering_seed VALUES
  ('pan13_slib_1988_1989','pan13_slibverwijdering','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Slib verwijderen Pan 13','Verwijdering van alle gemeten bodemslib en een geringe hoeveelheid onderliggend zand.','Pan 13','benoemd_deelgebied','1988-10-01','1989-01-31','maand',NULL,'Duinwaterbedrijf Zuid-Holland',14000,'m3',NULL),
  ('pan13_oeveraanpassing_1988_1989','pan13_slibverwijdering','hydrologie_optimaliseren','MT03','C01','uitgevoerd_voor_2026','Drie oevertaluds verflauwen','Drie steile taluds zijn flauwer gemaakt; bestaande rietkragen zijn waar mogelijk behouden.','Pan 13','benoemd_deelgebied','1988-10-01','1989-01-31','maand',NULL,'Duinwaterbedrijf Zuid-Holland',3,'aantal',NULL),
  ('kikkervalleien_bodem_1997','kikkervalleien_herstel','plaggen_chopperen_afgraven','MT04','B03','uitgevoerd_voor_2026','Voedselrijke bodem en vegetatie verwijderen','Bovenste voedselrijke bodemlaag en vegetatie verwijderd en plaatselijk oorspronkelijk reliëf hersteld.','Kikkervalleien en Pan 26.1','benoemd_deelgebied','1997-01-01','1997-12-31','jaar',NULL,'Dunea',50,'ha','Omvang betreft het gehele gecreëerde kale gebied; niet uitsluitend de afgegraven bodem.'),
  ('kikkervalleien_infra_1997','kikkervalleien_herstel','hydrologie_optimaliseren','MT04','L01','uitgevoerd_voor_2026','Leidingen en putten verwijderen','Omgevende leidingen en putten van Sprang PI en I uit het duingebied verwijderd.','Kikkervalleien, Sprang PI en I','benoemd_deelgebied','1997-01-01','1997-12-31','jaar',NULL,'Dunea',NULL,NULL,NULL),
  ('kikkervalleien_begrazing_1997','kikkervalleien_herstel','begrazing','MT01','A01','in_uitvoering','Begrazingsgebied uitbreiden','Na de herinrichting is circa 50 ha toegevoegd aan het sinds 1991 begraasde gebied van circa 125 ha.','Kikkervalleien en Helmduinen','benoemd_deelgebied','1997-01-01',NULL,'jaar','doorlopend tot heden','Dunea',50,'ha','Ton bevestigde op 14 oktober 2026 dat deze begrazing sinds de uitbreiding doorloopt tot heden. De open einddatum betekent voortgezet beheer en niet een onbekende einddatum.'),
  ('kikkervalleien_duindoorn_nabeheer','kikkervalleien_herstel','bosreductie_struweelbeheer','MT01','A09','uitgevoerd_voor_2026','Duindoorn bestrijden','Handmatige en later vooral machinale bestrijding van Duindoorn als nabeheer.','Kikkervalleien','benoemd_deelgebied',NULL,NULL,'onbekend','meerjarig','Dunea',NULL,NULL,'De bron uit 2010 noemt geen sluitende uitvoeringsjaren.'),
  ('zeereep_vijf_kerven_2014_2015','zeereep_kerven','zeereepbeheer','MT04','E02','uitgevoerd_voor_2026','Vijf kerven aanleggen','Op vijf plekken vegetatie en een tot twee decimeter bodem verwijderd; werk gestart winter 2013/2014 en afgerond winter 2014/2015.','Zeereep Meijendel','benoemd_deelgebied','2013-12-01','2015-03-31','periode',NULL,'Dunea',10.9434,'ha','109.434 m2 feitelijk afgegraven oppervlak.'),
  ('zeereep_kerven_nabeheer','zeereep_kerven','zeereepbeheer','MT02','E02','uitgevoerd','Nabeheer kerven en stuifkuilen','Openhouden en zo nodig ontdoen van vegetatie om zandtransport te behouden.','Zeereep Meijendel','benoemd_deelgebied','2016-01-01',NULL,'jaar','waar nodig','Dunea',NULL,NULL,NULL),
  ('pas_3d_begrazing_zuid','pas_meijendel_grijze_duinen','begrazing','MT01','A01','in_uitvoering','Begrazing Zeereep, Helmduinen en Prinsenduin','Jaarlijkse begrazing; in 2020 onderbroken na het doden van schapen door honden, in 2021 hervat en in 2025 binnen vaste rasters.','Zeereep Meijendel, Helmduinen en Prinsenduin','benoemd_deelgebied',NULL,NULL,'onbekend','jaarlijks','Dunea',75,'ha',NULL),
  ('pas_22h_aanvullend_beheer','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','D01','uitgevoerd_voor_2026','Aanvullend beheer Zeereep, Helmduinen, Prinsenduin en Ganzenhoek','Monitoring en bij vergrassing of verstruweling maaien, afvoeren of gescheperd begrazen.','Zeereep Meijendel, Helmduinen, Prinsenduin en Ganzenhoek','benoemd_deelgebied','2016-01-01','2021-12-31','periode','waar nodig','Dunea',1,'ha','2016: 200 Kempense schapen; 2017 beperkt gemaaid en delen begraasd; 2018-2021 onbekend.'),
  ('pas_23_maaibeheer','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','A06','niet_uitgevoerd','Aanvullend maaibeheer noordelijke Kijfhoek, Bierlap en Meeuwenhoek','In 2016 onderzocht; van 2016 tot en met 2019 niet uitgevoerd.','Kijfhoek, Bierlap en Meeuwenhoek','benoemd_deelgebied','2016-01-01','2019-12-31','periode','jaarlijks voorgenomen','Dunea',1,'ha',NULL),
  ('pas_23_vogelkers_2020','pas_meijendel_grijze_duinen','exotenbestrijding','MT02','F04','uitgevoerd_voor_2026','Amerikaanse vogelkers gericht bestrijden','Vervangende uitvoering van maatregel 23 in 2020.','Kijfhoek, Bierlap en Meeuwenhoek','benoemd_deelgebied','2020-01-01','2020-12-31','jaar','eenmalig','Dunea',1,'ha',NULL),
  ('pas_3b_vallei_begrazing','pas_meijendel_grijze_duinen','begrazing','MT01','A01','in_uitvoering','Begrazing Vallei Meijendel','Maaibeheer vervangen door statische en gescheperde extensieve begrazing met 38 heideschapen.','Vallei Meijendel','benoemd_deelgebied',NULL,NULL,'onbekend','jaarlijks','Dunea',38,'aantal',NULL),
  ('pas_3c_begrazing','pas_meijendel_grijze_duinen','begrazing','MT01','A01','uitgevoerd_voor_2026','Begrazing Vallei Meijendel, Langestrook en De Loopert','Uitgevoerd van 2017 tot en met 2021 en daarna als beheer voortgezet.','Vallei Meijendel, Langestrook en De Loopert','benoemd_deelgebied','2017-01-01','2021-12-31','periode','jaarlijks','Dunea',110,'ha',NULL),
  ('pas_24a_weiduin','pas_meijendel_grijze_duinen','begrazing','MT01','A01','in_uitvoering','Begrazing Weiduin','Jaarlijkse beweiding met vier Drentse heideschapen.','Weiduin','benoemd_deelgebied',NULL,NULL,'onbekend','jaarlijks','Dunea en eigenaar',4,'aantal',NULL),
  ('pas_24b_ouderijs','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT01','A06','vervallen','Maaibeheer Oude Rijs','Werd jaarlijks gemaaid; ten tijde van 2025 niet meer.','Oude Rijs','benoemd_deelgebied',NULL,'2025-12-31','onbekend','voorheen jaarlijks','Dunea en eigenaar',NULL,NULL,NULL),
  ('pas_24c_voorlinden','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','D01','onbekend','Beheer duingrasland Voorlinden','Eigenaar wilde maatregelen zelf uitvoeren; uitvoering niet bekend.','Voorlinden','benoemd_deelgebied',NULL,NULL,'onbekend',NULL,'Eigenaar Voorlinden',NULL,NULL,NULL),
  ('pas_22b_maaibeheer','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT01','A06','in_uitvoering','Aanvullend maaibeheer Ruijgenhoek, Langestrook en De Loopert','Volgens evaluatie jaarlijks gemaaid en voortgezet als regulier beheer.','Ruijgenhoek, Langestrook en De Loopert','benoemd_deelgebied',NULL,NULL,'onbekend','jaarlijks','Dunea',3,'ha',NULL),
  ('pas_22c_uilenbosch','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','A06','vervallen','Aanvullend maaibeheer Uilenbosch','2016 onbekend; 2017-2021 gemaaid; in 2022 gestopt.','Uilenbosch','benoemd_deelgebied','2016-01-01','2022-12-31','periode','jaarlijks','Dunea in overleg met Defensie',2,'ha',NULL),
  ('pas_22d_waalsdorp','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','D01','uitgevoerd_voor_2026','Aanvullend beheer Waalsdorp','Maaien, schapenbegrazing en in 2018-2019 ook struweelverwijdering.','Waalsdorp','benoemd_deelgebied','2016-01-01','2021-12-31','periode','jaarlijks voorgenomen','Staatsbosbeheer en Dunea',1,'ha',NULL),
  ('pas_22a_tafelberg_scheepje','pas_meijendel_grijze_duinen','maaibeheer_aanvullend','MT02','A06','in_uitvoering','Maaibeheer Tafelberg en t Scheepje','In 2016 gestopt wegens integrale begrazing; in 2025 deels hervat vanwege waterveiligheid.','Tafelberg en t Scheepje','benoemd_deelgebied','2016-01-01',NULL,'jaar','gewijzigd beheer','Dunea',1,'ha',NULL),
  ('ganzenhoek_dunning_2017','pas_meijendel_grijze_duinen','bosreductie_struweelbeheer','MT02','A04','uitgevoerd_voor_2026','Grote dunning Ganzenhoekbos','Grote dunning in 2017 ten behoeve van geleidelijke omvorming naar inheems duinbos.','Ganzenhoekbos','benoemd_deelgebied','2017-01-01','2017-12-31','jaar','eenmalig','Staatsbosbeheer',NULL,NULL,NULL),
  ('kikkervallei_watercrassula','kikkervallei_watercrassula','exotenbestrijding','MT01','F04','in_uitvoering','Watercrassula afdekken en bestrijden','Aangetroffen in 2015 en 2017, afgedekt met zeil en sindsdien bestreden.','Kikkervallei','benoemd_deelgebied','2015-01-01',NULL,'jaar','doorlopend','Dunea',NULL,NULL,NULL),
  ('meeuwenduin_prinsenduin_opslag_2023_2024','meeuwenduin_prinsenduin_beheer','bosreductie_struweelbeheer','MT02','A09','uitgevoerd_voor_2026','Bomen, struiken en exoten verwijderen in Meeuwenduin en Prinsenduin','Werk gestart in november 2023; gericht op onder meer Amerikaanse vogelkers, den, hulst en esdoorn.','Meeuwenduin en Prinsenduin','benoemd_deelgebied','2023-11-01','2023-12-31','periode','seizoenswerk november-maart','Dunea',NULL,NULL,'De bestaande uitvoeringcode blijft als stabiele sleutel behouden, maar deze uitvoering bevat alleen het in 2023 gestarte werk in beide naamgebieden.'),
  ('prinsenduin_opslag_2024','meeuwenduin_prinsenduin_beheer','bosreductie_struweelbeheer','MT02','A09','uitgevoerd_voor_2026','Bomen en struwelen verwijderen in Prinsenduin','Voortzetting in 2024 van de in 2023 gestarte natuurherstelwerkzaamheden bij Prinsenduin.','Prinsenduin','benoemd_deelgebied','2024-01-01','2024-12-31','jaar',NULL,'Dunea',NULL,NULL,'Afzonderlijke uitvoering voorkomt dat de voortzetting in 2024 ook aan Meeuwenduin wordt toegeschreven.'),
  ('konijnen_bijplaatsing_2024_2026','konijnen_bijplaatsing',NULL,'MT06','F01','uitgevoerd','Konijnen bijplaatsen en volgen','Pilot in 2024 uitgevoerd op twee uitzetlocaties en daar gemonitord. Voor 2025 en 2026 is in de geraadpleegde bronnen geen uitvoering per kalenderjaar bevestigd.','Kleine Pan en Waterschapsvallei','benoemd_deelgebied','2024-01-01','2024-12-31','jaar',NULL,'Dunea',NULL,NULL,'Onderzoek en beheerproef; niet als regulier begrazingsbeheer geclassificeerd. De beschikking gold tot en met 31 maart 2026, maar dat vergunnings- en planbereik is niet als feitelijke uitvoering in 2025 of 2026 geregistreerd.'),
  ('waterwinning_putten_2010_2018','optimalisatie_waterwinning',NULL,'MT04','L01','uitgevoerd_voor_2026','Nieuwe winputten aanleggen','Bijna 700 nieuwe putten aangelegd binnen het optimalisatieprogramma.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',700,'aantal','Bron zegt bijna 700; hoeveelheid is daarom afgerond.'),
  ('waterwinning_leidingen_2010_2018','optimalisatie_waterwinning',NULL,'MT04','L01','uitgevoerd_voor_2026','Leidingwerk vernieuwen en aansluiten','In totaal is 6,5 kilometer leiding vernieuwd; het PIM-rapport specificeert vervanging en aansluiting van leidingwerk in meerdere winningsseries.','Serie RA, Serie WV, Serie E, Serie LV en Complex 8','benoemd_deelgebied','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',6.5,'km','Dunea geeft geen verdeling van de totale 6,5 kilometer over de afzonderlijke winningsseries of kavels.'),
  ('waterwinning_pannen_2010_2018','optimalisatie_waterwinning','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Infiltratiepannen schonen en oevers natuurvriendelijk maken','370.000 m3 materiaal verwijderd; pannen schoongemaakt en oevers natuurvriendelijk ingericht.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',370000,'m3',NULL),
  ('waterwinning_plaggen_2010_2018','optimalisatie_waterwinning','plaggen_chopperen_afgraven','MT04','B04','uitgevoerd_voor_2026','Duinen plaggen bij optimalisatie waterwinning','Bijna 400.000 m2 duin geplagd; 100.000 m3 zand hergebruikt.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',40,'ha','Bron zegt bijna 400.000 m2; hoeveelheid is omgerekend en afgerond.'),
  ('slagbomen_2025','slagbomen_2025','rust_en_recreatiebeheer','MT03','G04','uitgevoerd_voor_2026','Slagbomen vervangen','Vervanging uitgevoerd in de aangekondigde werkperiode 1-12 december 2025.','Meijendel','meijendel_breed','2025-12-01','2025-12-12','dag','eenmalig','Dunea',NULL,NULL,NULL),
  ('vallei_elektriciteit_2026','vallei_elektriciteit_2026',NULL,'MT03','L01','onbekend','Elektriciteitskabel en laadvoorbereiding','Start aangekondigd op 23 september 2026; voltooiing niet bevestigd.','Vallei Meijendel','benoemd_deelgebied','2026-09-23',NULL,'dag','eenmalig','Dunea',3,'aantal','Drie laadpunten, voorbereid voor zes plaatsen.'),
  ('paardenstal_2026_2027','paardenstal_2026_2027',NULL,'MT03','L02','gepland','Werkzaamheden Paardenstal','Geplande renovatie van dak, gevels en kozijnen, plaatsing van zonnecollectoren en aanleg van water- en elektriciteitsleidingen. Vooraf zijn mitigerende maatregelen voor vleermuisverblijfplaatsen vereist.','Paardenstal','benoemd_deelgebied','2026-11-01','2027-03-31','dag','eenmalig','Dunea',NULL,NULL,'Dunea noemt 1 november 2026 tot en met 31 maart 2027 als werkperiode. De ODH-beschikking onderbouwt aard en ligging, maar bewijst geen uitvoering.'),
  ('bendel_nabeheer_2026','bendel_nabeheer_2026',NULL,'MT02','D01','gepland','Subsidieerbaar nabeheer Bendel','Openstelling noemt nabeheer voor H2130 en H2190; geen bewijs van opdracht of uitvoering.','Bendel','benoemd_deelgebied',NULL,NULL,'onbekend',NULL,NULL,NULL,NULL,'Alleen plan- en subsidiecontext.'),
  ('bendel_herinrichting_2025_2026','bendel_nabeheer_2026','plaggen_chopperen_afgraven','MT04','B03','uitgevoerd','Herinrichting Bendel','Herstel van historische duinakkers, dynamisch grijs duin en grotere en kleinere vochtige duinvalleien; tevens zijn twee duinpoelen gegraven.','Bendel, Berkheide-Noord','benoemd_deelgebied','2025-10-01','2026-03-31','maand','eenmalig','Staatsbosbeheer',NULL,NULL,'Holland''s Duinen 88 beschrijft uitvoering van oktober 2025 tot maart 2026 en afronding voor het broedseizoen van 2026. De uitvoering ligt buiten de 55 Meijendel-plots.'),
  ('kavel1b_herstel_1967','historische_waterwinning_1967_1975','geomorfologie_herstel_stortplaatsen','MT03','D01','uitgevoerd_voor_2026','Afrastering verwijderen en zand vastleggen in M1b','Oude afrastering verwijderd, helm en bomen geplant en in augustus grondwerk en aanvullende helmbeplanting uitgevoerd.','Kavel M1b','benoemd_deelgebied','1967-01-01','1967-08-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('pan2_peilverlaging_1967','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT03','C01','uitgevoerd_voor_2026','Waterpeil verlagen in M2','De infiltratiepannen in M2 zijn voor samenhangende werkzaamheden drooggezet.','Kavel M2','benoemd_deelgebied','1967-09-01','1967-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('pan3_schoonmaak_1967','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Infiltratiepannen M3 schoonmaken','De pannen in M3 zijn volledig schoongemaakt; bodemslib en veel riet zijn verwijderd.','Kavel M3','benoemd_deelgebied','1967-09-01','1967-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('pannen_16_17_peilverlaging_1967','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT03','C01','uitgevoerd_voor_2026','Waterpeil verlagen in M16 en M17','In de laatste twee maanden van 1967 is het waterpeil tot het minimum verlaagd; de bodems zijn niet schoongemaakt.','Kavels M16 en M17','benoemd_deelgebied','1967-11-01','1967-12-31','maand',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('hoofdader_leidingen_5_6_71_1967','historische_waterwinning_1967_1975',NULL,'MT04','L01','uitgevoerd_voor_2026','Leidingwerk in de hoofdader','Tot begin mei is aan leidingen in de hoofdader gewerkt.','Kavels M5, M6 en M71','benoemd_deelgebied','1967-01-01','1967-05-10','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('nieuwe_pannen_10_12_1967','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT04','C01','uitgevoerd_voor_2026','Nieuwe infiltratiepannen M10 en M12 in gebruik nemen','Nieuw aangelegde infiltratiepannen kregen voor het eerst water in mei respectievelijk juli 1967.','Kavels M10 en M12','benoemd_deelgebied','1967-05-01','1967-07-31','maand',NULL,'Duinwaterleiding van s-Gravenhage',2,'aantal',NULL),
  ('hoofdader_rietmaaien_6_1968','historische_waterwinning_1967_1975','maaibeheer_aanvullend','MT02','A06','uitgevoerd_voor_2026','Riet maaien in de hoofdader bij M6','Begin juni 1968 is het riet in de hoofdader gemaaid.','Kavel M6','benoemd_deelgebied','1968-06-01','1968-06-10','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('pannen_2_3_16_17_peilherstel_1968','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT03','C01','uitgevoerd_voor_2026','Waterpeil in M2, M3, M16 en M17 herstellen','Na de werkzaamheden in 1967 was het waterpeil op 18 februari 1968 weer hersteld.','Kavels M2, M3, M16 en M17','benoemd_deelgebied','1968-02-18','1968-02-18','dag',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('plas20_reparatie_1969','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT03','L01','uitgevoerd_voor_2026','Reparatie bij Plas 20','Plas 20 stond in maart en april 1969 zeer laag wegens reparatiewerk.','Plas 20','benoemd_deelgebied','1969-03-01','1969-04-30','maand',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,'De bron noemt niet welk onderdeel is gerepareerd.'),
  ('ganzenhoek_pan_1972_1973','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT04','C01','uitgevoerd_voor_2026','Nieuwe infiltratiepan Ganzenhoek aanleggen en in gebruik nemen','De aanleg liep in 1972 door; de pan bij M77 is in 1972 in gebruik genomen en werkzaamheden liepen in 1973 door.','Ganzenhoek, kavel M77','benoemd_deelgebied','1972-01-01','1973-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',1,'aantal',NULL),
  ('ganzenhoek_helm_populier_13_14_1972','historische_waterwinning_1967_1975','geomorfologie_herstel_stortplaatsen','MT03','D01','uitgevoerd_voor_2026','Zand vastleggen met helm en populieren','Na zandverplaatsing bij M13 en M14 is vanaf half april maandenlang helm geplant; op de nieuwe panoevers zijn populieren geplant.','Kavels M13 en M14','benoemd_deelgebied','1972-04-15','1972-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('leidingherstel_kavel2_1972_1973','historische_waterwinning_1967_1975',NULL,'MT03','L01','uitgevoerd_voor_2026','Leiding herstellen in M2','Een plas in M2 stond in 1972 grotendeels droog wegens leidingreparatie; begin 1973 viel de ronde plas opnieuw droog door leidingherstel.','Kavel M2','benoemd_deelgebied','1972-01-01','1973-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('ganzenhoek_afwerking_pan_1973_1974','historische_waterwinning_1967_1975',NULL,'MT03','L02','uitgevoerd_voor_2026','Nieuwe pan Ganzenhoek afwerken','In 1973 is konijnenraster geplaatst en zijn losse zandheuvels met takken bedekt; in 1974 is hakhout op de panoevers aangebracht.','Ganzenhoek, kavel M77','benoemd_deelgebied','1973-01-01','1974-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('pannen_drooglegging_4_7_1974','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT03','C01','uitgevoerd_voor_2026','Pannen M4 en M7 droogleggen voor werkzaamheden','Voor werkzaamheden stonden plassen in M4 en M7 van maart tot en met mei droog; in M7 liep dit door tot juni.','Kavels M4 en M7','benoemd_deelgebied','1974-03-01','1974-06-30','maand',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('nieuwe_plas_14_16_1975','historische_waterwinning_1967_1975','hydrologie_optimaliseren','MT04','C01','uitgevoerd_voor_2026','Nieuwe plas op grens M14-M16 aanleggen','In april 1975 begon de aanleg van een nieuwe plas op de grens van M14 en M16; een aangrenzende plas in M16 werd drooggezet.','Grens kavels M14 en M16','benoemd_deelgebied','1975-04-01','1975-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',1,'aantal',NULL),
  ('ganzenhoek_wandelpad_1974_1975','historische_recreatiepaden_1974_1975','rust_en_recreatiebeheer','MT03','L02','uitgevoerd_voor_2026','Wandelpad langs M13, M13s, M14 en M77 aanleggen','Het wandelpad op de grens van M13, M14 en M77 is in 1974 aangelegd en in 1975 langs M13, M13s, M14 en M77 voltooid.','Ganzenhoek en kavels M13, M13s, M14 en M77','benoemd_deelgebied','1974-01-01','1975-12-31','periode',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('ruiterpad_kavel13_1974','historische_recreatiepaden_1974_1975','rust_en_recreatiebeheer','MT03','L02','uitgevoerd_voor_2026','Ruiterpad door M13 aanleggen','Door aanleg van een ruiterpad is het noordelijke deel van M13 afgescheiden.','Kavel M13','benoemd_deelgebied','1974-01-01','1974-12-31','jaar',NULL,'Duinwaterleiding van s-Gravenhage',NULL,NULL,NULL),
  ('rietpoten_noord_1987','rietpotenproef_1987',NULL,'MT06','D01','uitgevoerd_voor_2026','Rietpoten in stuifplekken aanbrengen','In elf proef- en referentiestuifplekken zijn tussen 29 oktober en 6 november 1987 proefvlakken aangelegd en rietpoten geplaatst.','Driehoek Klippad, Bunkerpad en Wassenaarse Slag','benoemd_deelgebied','1987-10-29','1987-11-06','dag','eenmalige proef','Terreinbeheer DZH',11,'aantal','Binnenduinproef; niet als zeereepbeheer geclassificeerd.'),
  ('begrazing_kijfhoek_bierlap_1990','integrale_begrazing_1990','begrazing','MT01','A01','uitgevoerd_voor_2026','Extensieve begrazing Kijfhoek en Bierlap invoeren','Extensieve begrazing is in september 1990 ingevoerd in Kijfhoek en Bierlap.','Kijfhoek en Bierlap','benoemd_deelgebied','1990-09-01',NULL,'maand','doorlopend na invoering','Duinwaterbedrijf Zuid-Holland',275,'ha',NULL),
  ('begrazing_helmduinen_1991','integrale_begrazing_1990','begrazing','MT01','A01','in_uitvoering','Extensieve begrazing Helmduinen invoeren','De Helmduinen worden sinds 1991 extensief begraasd.','Helmduinen','benoemd_deelgebied','1991-01-01',NULL,'jaar','doorlopend tot heden','Duinwaterbedrijf Zuid-Holland',125,'ha','Ton bevestigde op 14 oktober 2026 dat deze begrazing sinds de invoering doorloopt tot heden. De open einddatum betekent voortgezet beheer en niet een onbekende einddatum.'),
  ('begrazing_meeuwenhoek_voor_2008','integrale_begrazing_1990','begrazing','MT01','A01','uitgevoerd_voor_2026','Begrazingsgebied uitbreiden met Meeuwenhoek','De begrazing is later uitgebreid met de Meeuwenhoek; de bron uit 2008 noemt geen invoeringsjaar.','Meeuwenhoek','benoemd_deelgebied',NULL,NULL,'onbekend','doorlopend na invoering','Duinwaterbedrijf Zuid-Holland',NULL,NULL,'Geen jaarregel omdat de bron geen betrouwbaar invoeringsjaar geeft.'),
  ('maaibeheer_libellenvallei_1975_2003','duinvalleibeheer_1975_2003','maaibeheer_aanvullend','MT01','A06','uitgevoerd_voor_2026','Libellenvallei jaarlijks maaien','Volgens de bron uit 2003 is de Libellenvallei sinds 1975 jaarlijks in het najaar gemaaid.','Libellenvallei','benoemd_deelgebied','1975-01-01','2003-12-31','periode','jaarlijks in het najaar','Duinwaterbedrijf Zuid-Holland',NULL,NULL,'Alleen 1975 krijgt een jaarregel; de bron onderbouwt het terugkerende beheer als periode, niet iedere afzonderlijke jaaruitvoering.'),
  ('plaggen_parnassiapad2_1993','duinvalleibeheer_1975_2003','plaggen_chopperen_afgraven','MT02','B04','uitgevoerd_voor_2026','Proefvlak Parnassiapad 2 plaggen','Proefvlak Parnassiapad 2 is volgens de in 2001 beschreven ouderdom ongeveer in 1993 geplagd.','Parnassiapad 2','benoemd_deelgebied','1993-01-01','1993-12-31','jaar',NULL,'Duinwaterbedrijf Zuid-Holland',NULL,NULL,'Jaar is uit de bron afgeleid als circa acht jaar voor 2001.'),
  ('plaggen_parnassiapad1_1997','duinvalleibeheer_1975_2003','plaggen_chopperen_afgraven','MT02','B04','uitgevoerd_voor_2026','Proefvlak Parnassiapad 1 plaggen','Proefvlak Parnassiapad 1 is volgens de in 2001 beschreven ouderdom ongeveer in 1997 geplagd.','Parnassiapad 1','benoemd_deelgebied','1997-01-01','1997-12-31','jaar',NULL,'Duinwaterbedrijf Zuid-Holland',NULL,NULL,'Jaar is uit de bron afgeleid als circa vier jaar voor 2001.'),
  ('slib_plas_8_4_2_2002','slibverwijdering_plassen_2002_2006','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Slib verwijderen uit plas 8.4.2','In 2002 is opnieuw slib verwijderd uit de regelmatig verstopte plas 8.4.2.','Plas 8.4.2','benoemd_deelgebied','2002-01-01','2002-12-31','jaar',NULL,'Duinwaterbedrijf Zuid-Holland',NULL,NULL,NULL),
  ('slib_plas20_2005_2006','slibverwijdering_plassen_2002_2006','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Slib verwijderen uit Plas 20.1','Tussen 1 september 2005 en 1 maart 2006 is circa 39.000 m3 slib uit Plas 20.1 verwijderd.','Plas 20.1','benoemd_deelgebied','2005-09-01','2006-03-01','dag',NULL,'Duinwaterbedrijf Zuid-Holland',39000,'m3',NULL),
  ('plas20_hydrologie_2005_2006','slibverwijdering_plassen_2002_2006','hydrologie_optimaliseren','MT04','C01','uitgevoerd_voor_2026','Plas 20.1 hydrologisch en ecologisch aanpassen','Het westelijke deel 20.1.1 is losgekoppeld van de waterwinning, oevers zijn verflauwd en het waterpeil is verhoogd van 4,60 naar 5,20 meter NAP.','Plas 20.1 en 20.1.1','benoemd_deelgebied','2005-09-01','2006-03-01','dag',NULL,'Duinwaterbedrijf Zuid-Holland',0.6,'m','Peilverhoging van 0,60 meter; uitgestelde schoonmaak van twee natte valleien is niet als uitgevoerd opgenomen.'),
  ('plas20_infrastructuur_2005_2006','slibverwijdering_plassen_2002_2006',NULL,'MT03','L02','uitgevoerd_voor_2026','Brug, zanddam en uitkijkpunt bij Plas 20.1 aanpassen','Een houten brug is vervangen door een Waco, een zanddam is aangelegd en het uitkijkpunt is vernieuwd.','Plas 20.1','benoemd_deelgebied','2005-09-01','2006-03-01','dag',NULL,'Duinwaterbedrijf Zuid-Holland',NULL,NULL,NULL);

INSERT INTO maatregel_uitvoering
  (uitvoering_code, project_id, maatregel_id, maatregeltype_code, activiteit_code,
   uitvoering_status_code, naam, omschrijving, locatie_naam, locatie_precisie,
   datum_vanaf, datum_tot, datum_precisie, cycliciteit, uitvoerder,
   gerealiseerde_hoeveelheid, hoeveelheid_eenheid, opmerking)
SELECT s.uitvoering_code, p.project_id, m.id, s.maatregeltype_code, s.activiteit_code,
       s.uitvoering_status_code, s.naam, s.omschrijving, s.locatie_naam, s.locatie_precisie,
       s.datum_vanaf, s.datum_tot, s.datum_precisie, s.cycliciteit, s.uitvoerder,
       s.gerealiseerde_hoeveelheid, s.hoeveelheid_eenheid, s.opmerking
FROM tmp_maatregel_uitvoering_seed s
JOIN maatregel_project p ON p.project_code=s.project_code
LEFT JOIN maatregelen m ON m.code=s.maatregel_code
ON DUPLICATE KEY UPDATE
  project_id=VALUES(project_id), maatregel_id=VALUES(maatregel_id),
  maatregeltype_code=VALUES(maatregeltype_code), activiteit_code=VALUES(activiteit_code),
  uitvoering_status_code=VALUES(uitvoering_status_code), naam=VALUES(naam), omschrijving=VALUES(omschrijving),
  locatie_naam=VALUES(locatie_naam), locatie_precisie=VALUES(locatie_precisie),
  datum_vanaf=VALUES(datum_vanaf), datum_tot=VALUES(datum_tot), datum_precisie=VALUES(datum_precisie),
  cycliciteit=VALUES(cycliciteit), uitvoerder=VALUES(uitvoerder),
  gerealiseerde_hoeveelheid=VALUES(gerealiseerde_hoeveelheid), hoeveelheid_eenheid=VALUES(hoeveelheid_eenheid),
  opmerking=VALUES(opmerking);

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_jaar_seed;
CREATE TEMPORARY TABLE tmp_maatregel_jaar_seed (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  jaar SMALLINT UNSIGNED NOT NULL,
  jaarstatus VARCHAR(24) CHARACTER SET ascii NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  toelichting VARCHAR(1000) NULL,
  PRIMARY KEY (uitvoering_code, jaar)
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_jaar_seed VALUES
  ('pan13_slib_1988_1989',1988,'uitgevoerd','zotero_pan13_1991','Werk begon in oktober 1988.'),
  ('pan13_slib_1988_1989',1989,'uitgevoerd','zotero_pan13_1991','Werk eindigde in januari 1989.'),
  ('pan13_oeveraanpassing_1988_1989',1988,'uitgevoerd','zotero_pan13_1991',NULL),
  ('pan13_oeveraanpassing_1988_1989',1989,'uitgevoerd','zotero_pan13_1991',NULL),
  ('kikkervalleien_bodem_1997',1997,'uitgevoerd','zotero_kikkervalleien_2010',NULL),
  ('kikkervalleien_infra_1997',1997,'uitgevoerd','zotero_kikkervalleien_2010',NULL),
  ('kikkervalleien_begrazing_1997',1997,'uitgevoerd','zotero_kikkervalleien_2010','Begrazingsgebied direct na de ingreep uitgebreid.'),
  ('zeereep_vijf_kerven_2014_2015',2014,'uitgevoerd','zotero_stuifgaten_2017','Werk uitgevoerd in winter 2013/2014 en daarna onderbroken.'),
  ('zeereep_vijf_kerven_2014_2015',2015,'uitgevoerd','zotero_stuifgaten_2017','Werk afgerond in winter 2014/2015.'),
  ('zeereep_kerven_nabeheer',2016,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('zeereep_kerven_nabeheer',2024,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3d_begrazing_zuid',2020,'niet_uitgevoerd','zotero_n2000_ontwerp_2026','Tijdelijk gestopt na het doden van schapen door honden.'),
  ('pas_3d_begrazing_zuid',2021,'uitgevoerd','zotero_n2000_ontwerp_2026','Hervat binnen verplaatsbaar wolvenraster.'),
  ('pas_3d_begrazing_zuid',2025,'uitgevoerd','zotero_n2000_ontwerp_2026','Begrazing binnen vaste rasters.'),
  ('pas_22h_aanvullend_beheer',2016,'uitgevoerd','zotero_n2000_evaluatie_2025','Half november tot half december begraasd met 200 Kempense schapen.'),
  ('pas_22h_aanvullend_beheer',2017,'uitgevoerd','zotero_n2000_evaluatie_2025','Beperkt gemaaid en delen begraasd.'),
  ('pas_22h_aanvullend_beheer',2018,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22h_aanvullend_beheer',2019,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22h_aanvullend_beheer',2020,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22h_aanvullend_beheer',2021,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_23_maaibeheer',2016,'niet_uitgevoerd','zotero_n2000_evaluatie_2025','Mogelijkheden onderzocht; geen maaivlakken onderscheiden.'),
  ('pas_23_maaibeheer',2017,'niet_uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_23_maaibeheer',2018,'niet_uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_23_maaibeheer',2019,'niet_uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_23_vogelkers_2020',2020,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3c_begrazing',2017,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3c_begrazing',2018,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3c_begrazing',2019,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3c_begrazing',2020,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_3c_begrazing',2021,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_24b_ouderijs',2025,'niet_uitgevoerd','zotero_n2000_ontwerp_2026','Ten tijde van 2025 niet meer gemaaid.'),
  ('pas_24c_voorlinden',2025,'onbekend','zotero_n2000_ontwerp_2026','Niet bekend of de eigenaar de maatregel uitvoerde.'),
  ('pas_22c_uilenbosch',2016,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2017,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2018,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2019,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2020,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2021,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22c_uilenbosch',2022,'niet_uitgevoerd','zotero_n2000_evaluatie_2025','Maaibeheer gestopt.'),
  ('pas_22d_waalsdorp',2016,'uitgevoerd','zotero_n2000_evaluatie_2025','Gemaaid en begraasd door schapen.'),
  ('pas_22d_waalsdorp',2017,'uitgevoerd','zotero_n2000_evaluatie_2025','Beperkt gemaaid en delen begraasd.'),
  ('pas_22d_waalsdorp',2018,'uitgevoerd','zotero_n2000_evaluatie_2025','Gemaaid, begraasd en plaatselijk struweel verwijderd.'),
  ('pas_22d_waalsdorp',2019,'uitgevoerd','zotero_n2000_evaluatie_2025','Gemaaid, begraasd en struweel verwijderd.'),
  ('pas_22d_waalsdorp',2020,'onbekend','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22d_waalsdorp',2021,'niet_uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('pas_22a_tafelberg_scheepje',2016,'niet_uitgevoerd','zotero_n2000_ontwerp_2026','Maaien gestopt vanwege integrale begrazing sinds 2014.'),
  ('pas_22a_tafelberg_scheepje',2025,'uitgevoerd','zotero_n2000_ontwerp_2026','Deel uit begrazing gehaald voor waterveiligheid en maaien hervat.'),
  ('ganzenhoek_dunning_2017',2017,'uitgevoerd','zotero_n2000_evaluatie_2025',NULL),
  ('kikkervallei_watercrassula',2015,'uitgevoerd','zotero_n2000_evaluatie_2025','Watercrassula aangetroffen en bestreden.'),
  ('kikkervallei_watercrassula',2017,'uitgevoerd','zotero_n2000_evaluatie_2025','Opnieuw aangetroffen en bestreden.'),
  ('kikkervallei_watercrassula',2018,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2019,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2020,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2021,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2022,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2023,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2024,'uitgevoerd','zotero_n2000_evaluatie_2025','Sinds 2017 bestreden; bronstand 25 april 2025.'),
  ('kikkervallei_watercrassula',2025,'uitgevoerd','zotero_n2000_evaluatie_2025','Bestrijding liep bij de bronstand van 25 april 2025 door.'),
  ('meeuwenduin_prinsenduin_opslag_2023_2024',2023,'uitgevoerd','dunea_beheer_meijendel_2023','Werk gestart in november 2023.'),
  ('prinsenduin_opslag_2024',2024,'uitgevoerd','dunea_jaarverslag_2024','Werk bij Prinsenduin in 2024 voortgezet.'),
  ('konijnen_bijplaatsing_2024_2026',2024,'uitgevoerd','dunea_jaarverslag_2024','Pilot gestart.'),
  ('waterwinning_putten_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_leidingen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_pannen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_plaggen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('slagbomen_2025',2025,'uitgevoerd','dunea_slagbomen_2025','Werkperiode 1-12 december 2025.'),
  ('bendel_herinrichting_2025_2026',2025,'uitgevoerd','zotero_hollands_duinen_88_2026','Herinrichting uitgevoerd vanaf oktober 2025.'),
  ('bendel_herinrichting_2025_2026',2026,'uitgevoerd','zotero_hollands_duinen_88_2026','Werk in maart 2026 afgerond, vóór het broedseizoen.'),
  ('kavel1b_herstel_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Afrastering verwijderd; helm en bomen geplant; in augustus grondwerk en helmbeplanting.'),
  ('pan2_peilverlaging_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Infiltratiepannen in M2 drooggezet.'),
  ('pan3_schoonmaak_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Pannen in M3 volledig schoongemaakt.'),
  ('pannen_16_17_peilverlaging_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Peil in de laatste twee maanden tot het minimum verlaagd.'),
  ('hoofdader_leidingen_5_6_71_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Leidingwerk liep tot begin mei.'),
  ('nieuwe_pannen_10_12_1967',1967,'uitgevoerd','zotero_vogelrapport_1967','Nieuwe pannen kregen in mei en juli voor het eerst water.'),
  ('hoofdader_rietmaaien_6_1968',1968,'uitgevoerd','zotero_vogelrapport_1968','Riet begin juni gemaaid.'),
  ('pannen_2_3_16_17_peilherstel_1968',1968,'uitgevoerd','zotero_vogelrapport_1968','Waterpeil was op 18 februari weer hersteld.'),
  ('plas20_reparatie_1969',1969,'uitgevoerd','zotero_vogelrapport_1969','Plas stond in maart en april zeer laag wegens reparatie.'),
  ('ganzenhoek_pan_1972_1973',1972,'uitgevoerd','zotero_vogelrapport_1972','Aanleg voortgezet en pan in gebruik genomen.'),
  ('ganzenhoek_pan_1972_1973',1973,'uitgevoerd','zotero_vogelrapport_1973','Werkzaamheden aan en rond de nieuwe pan liepen door.'),
  ('ganzenhoek_helm_populier_13_14_1972',1972,'uitgevoerd','zotero_vogelrapport_1972','Helm en populieren geplant om nieuw zand en oevers vast te leggen.'),
  ('leidingherstel_kavel2_1972_1973',1972,'uitgevoerd','zotero_vogelrapport_1972','Plas grotendeels droog wegens leidingreparatie.'),
  ('leidingherstel_kavel2_1972_1973',1973,'uitgevoerd','zotero_vogelrapport_1973','Ronde plas begin 1973 droog wegens leidingherstel.'),
  ('ganzenhoek_afwerking_pan_1973_1974',1973,'uitgevoerd','zotero_vogelrapport_1973','Konijnenraster geplaatst en zandheuvels met takken bedekt.'),
  ('ganzenhoek_afwerking_pan_1973_1974',1974,'uitgevoerd','zotero_vogelrapport_1974','Hakhout op de panoevers aangebracht.'),
  ('pannen_drooglegging_4_7_1974',1974,'uitgevoerd','zotero_vogelrapport_1974','Pannen voor werkzaamheden drooggelegd.'),
  ('nieuwe_plas_14_16_1975',1975,'uitgevoerd','zotero_vogelrapport_1975','Aanleg begon in april.'),
  ('ganzenhoek_wandelpad_1974_1975',1974,'uitgevoerd','zotero_vogelrapport_1974','Pad aangelegd op de grens van M13, M14 en M77.'),
  ('ganzenhoek_wandelpad_1974_1975',1975,'uitgevoerd','zotero_vogelrapport_1975','Pad langs M13, M13s, M14 en M77 voltooid.'),
  ('ruiterpad_kavel13_1974',1974,'uitgevoerd','zotero_vogelrapport_1974','Ruiterpad aangelegd.'),
  ('rietpoten_noord_1987',1987,'uitgevoerd','zotero_rietpoten_1992','Proefvlakken aangelegd van 29 oktober tot en met 6 november.'),
  ('begrazing_kijfhoek_bierlap_1990',1990,'uitgevoerd','zotero_begrazing_2008','Begrazing ingevoerd in september.'),
  ('begrazing_helmduinen_1991',1991,'uitgevoerd','zotero_begrazing_2008','Begrazing vanaf 1991.'),
  ('maaibeheer_libellenvallei_1975_2003',1975,'uitgevoerd','zotero_valleien_2003','Start van het volgens de bron jaarlijks uitgevoerde najaarsmaaien.'),
  ('plaggen_parnassiapad2_1993',1993,'uitgevoerd','zotero_valleien_2003','Circa-jaar, afgeleid uit de in 2001 genoemde ouderdom van acht jaar.'),
  ('plaggen_parnassiapad1_1997',1997,'uitgevoerd','zotero_valleien_2003','Circa-jaar, afgeleid uit de in 2001 genoemde ouderdom van vier jaar.'),
  ('slib_plas_8_4_2_2002',2002,'uitgevoerd','zotero_slib_plassen_2005','Slib opnieuw verwijderd.'),
  ('slib_plas20_2005_2006',2005,'uitgevoerd','zotero_plas20_2006','Werk begon op 1 september 2005.'),
  ('slib_plas20_2005_2006',2006,'uitgevoerd','zotero_plas20_2006','Werk eindigde op 1 maart 2006.'),
  ('plas20_hydrologie_2005_2006',2005,'uitgevoerd','zotero_plas20_2006','Hydrologische en oeveraanpassingen uitgevoerd binnen de werkperiode.'),
  ('plas20_hydrologie_2005_2006',2006,'uitgevoerd','zotero_plas20_2006','Hydrologische en oeveraanpassingen afgerond binnen de werkperiode.'),
  ('plas20_infrastructuur_2005_2006',2005,'uitgevoerd','zotero_plas20_2006','Brug, dam en uitkijkvoorziening aangepast binnen de werkperiode.'),
  ('plas20_infrastructuur_2005_2006',2006,'uitgevoerd','zotero_plas20_2006','Infrastructurele aanpassingen afgerond binnen de werkperiode.');

-- De bron over 2024 noemt alleen Prinsenduin. Verwijder bij actualisatie de
-- oude gecombineerde jaar- en bronrelatie; 2024 krijgt hieronder een eigen
-- uitvoering en kan daardoor niet meer aan Meeuwenduin worden toegeschreven.
DELETE j
FROM maatregel_uitvoering_jaar j
JOIN maatregel_uitvoering u USING (uitvoering_id)
WHERE u.uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024'
  AND j.jaar=2024;

DELETE ub
FROM maatregel_uitvoering_bron ub
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN maatregel_bron b USING (bron_id)
WHERE u.uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024'
  AND b.bron_code='dunea_jaarverslag_2024'
  AND ub.bronrol='bevestiging';

INSERT INTO maatregel_uitvoering_jaar (uitvoering_id, jaar, jaarstatus, bron_id, toelichting)
SELECT u.uitvoering_id, s.jaar, s.jaarstatus, b.bron_id, s.toelichting
FROM tmp_maatregel_jaar_seed s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
ON DUPLICATE KEY UPDATE
  jaarstatus=VALUES(jaarstatus), bron_id=VALUES(bron_id), toelichting=VALUES(toelichting);

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_bron_seed;
CREATE TEMPORARY TABLE tmp_maatregel_uitvoering_bron_seed (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  bronrol VARCHAR(32) CHARACTER SET ascii NOT NULL,
  pagina_of_paragraaf VARCHAR(255) NULL,
  bewijsnotitie VARCHAR(1500) NOT NULL,
  PRIMARY KEY (uitvoering_code, bron_code, bronrol)
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_uitvoering_bron_seed
SELECT uitvoering_code,
       CASE
         WHEN uitvoering_code IN ('kavel1b_herstel_1967','pan2_peilverlaging_1967','pan3_schoonmaak_1967','pannen_16_17_peilverlaging_1967','hoofdader_leidingen_5_6_71_1967','nieuwe_pannen_10_12_1967') THEN 'zotero_vogelrapport_1967'
         WHEN uitvoering_code IN ('hoofdader_rietmaaien_6_1968','pannen_2_3_16_17_peilherstel_1968') THEN 'zotero_vogelrapport_1968'
         WHEN uitvoering_code='plas20_reparatie_1969' THEN 'zotero_vogelrapport_1969'
         WHEN uitvoering_code IN ('ganzenhoek_pan_1972_1973','ganzenhoek_helm_populier_13_14_1972','leidingherstel_kavel2_1972_1973') THEN 'zotero_vogelrapport_1972'
         WHEN uitvoering_code='ganzenhoek_afwerking_pan_1973_1974' THEN 'zotero_vogelrapport_1973'
         WHEN uitvoering_code IN ('pannen_drooglegging_4_7_1974','ganzenhoek_wandelpad_1974_1975','ruiterpad_kavel13_1974') THEN 'zotero_vogelrapport_1974'
         WHEN uitvoering_code='nieuwe_plas_14_16_1975' THEN 'zotero_vogelrapport_1975'
         WHEN uitvoering_code='rietpoten_noord_1987' THEN 'zotero_rietpoten_1992'
         WHEN uitvoering_code IN ('begrazing_kijfhoek_bierlap_1990','begrazing_helmduinen_1991','begrazing_meeuwenhoek_voor_2008') THEN 'zotero_begrazing_2008'
         WHEN uitvoering_code IN ('maaibeheer_libellenvallei_1975_2003','plaggen_parnassiapad2_1993','plaggen_parnassiapad1_1997') THEN 'zotero_valleien_2003'
         WHEN uitvoering_code='slib_plas_8_4_2_2002' THEN 'zotero_slib_plassen_2005'
         WHEN uitvoering_code IN ('slib_plas20_2005_2006','plas20_hydrologie_2005_2006','plas20_infrastructuur_2005_2006') THEN 'zotero_plas20_2006'
         WHEN uitvoering_code LIKE 'pan13_%' THEN 'zotero_pan13_1991'
         WHEN uitvoering_code LIKE 'kikkervalleien_%' THEN 'zotero_kikkervalleien_2010'
         WHEN uitvoering_code LIKE 'zeereep_%' THEN 'zotero_stuifgaten_2017'
         WHEN uitvoering_code LIKE 'pas_%' OR uitvoering_code='ganzenhoek_dunning_2017' OR uitvoering_code='kikkervallei_watercrassula' THEN 'zotero_n2000_evaluatie_2025'
         WHEN uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024' THEN 'dunea_beheer_meijendel_2023'
         WHEN uitvoering_code='prinsenduin_opslag_2024' THEN 'dunea_jaarverslag_2024'
         WHEN uitvoering_code='konijnen_bijplaatsing_2024_2026' THEN 'dunea_jaarverslag_2024'
         WHEN uitvoering_code LIKE 'waterwinning_%' THEN 'dunea_optimalisatie_waterwinning_2018'
         WHEN uitvoering_code='slagbomen_2025' THEN 'dunea_slagbomen_2025'
         WHEN uitvoering_code IN ('vallei_elektriciteit_2026','paardenstal_2026_2027') THEN 'dunea_reguliere_werkzaamheden_2026'
         WHEN uitvoering_code='bendel_nabeheer_2026' THEN 'pzh_bendel_subsidie_2026'
         WHEN uitvoering_code='bendel_herinrichting_2025_2026' THEN 'zotero_hollands_duinen_88_2026'
       END AS bron_code,
       CASE
         WHEN uitvoering_status_code IN ('gepland','onbekend') THEN 'plancontext'
         ELSE 'primaire_uitvoeringsbron'
       END AS bronrol,
       CASE
         WHEN uitvoering_code IN ('kikkervalleien_begrazing_1997','kikkervalleien_bodem_1997') THEN 'p. 5 en 22'
         ELSE NULL
       END AS pagina_of_paragraaf,
       CASE
         WHEN uitvoering_code='kikkervalleien_begrazing_1997' THEN 'Pagina 5 beschrijft de uitbreiding van het sinds 1991 begraasde Helmduinengebied met circa 50 hectare Kikkervalleien direct na de herinrichting van 1997. Pagina 22 benoemt M13, M13s en M14 expliciet als de kavels waarin de Kikkervalleien liggen.'
         WHEN uitvoering_code='kikkervalleien_bodem_1997' THEN 'Pagina 5 beschrijft dat in het najaar van 1997 de vegetatie en voedselrijke bovengrond in en rond Pan 26.1 zijn verwijderd. Pagina 22 benoemt M13, M13s en M14 expliciet als de kavels waarin de Kikkervalleien liggen en toont het bewerkte gebied met een zwarte begrenzing.'
         ELSE CONCAT('Bronbasis voor uitvoering ', CONVERT(uitvoering_code USING utf8mb4), '; status en omvang zijn niet ruimer geïnterpreteerd dan de bron ondersteunt.')
       END AS bewijsnotitie
FROM tmp_maatregel_uitvoering_seed;

INSERT INTO tmp_maatregel_uitvoering_bron_seed VALUES
  ('pan13_slib_1988_1989','zotero_broedvogelmonitoring_2006','bevestiging','p. 56-57','Benoemt Pan 13 expliciet als de lange plassenserie in kavels 2 en 3 en bevestigt drooglegging, slibverwijdering en visverwijdering in 1988.'),
  ('zeereep_vijf_kerven_2014_2015','dunea_dynamiek_2024','bevestiging',NULL,'Dunea bevestigt aanvang in september 2014 en voltooiing van vijf kerven in 2015.'),
  ('zeereep_kerven_nabeheer','zotero_n2000_ontwerp_2026','bevestiging','4.2','Ontwerpbeheerplan bevestigt nabeheer in 2016 en 2024.'),
  ('pas_3d_begrazing_zuid','zotero_n2000_ontwerp_2026','bevestiging','4.2','Actualiseert onderbreking in 2020, hervatting in 2021 en vaste rasters in 2025.'),
  ('pas_24b_ouderijs','zotero_n2000_ontwerp_2026','tegenstrijdig_bewijs','4.2','Evaluatie noemt jaarlijks maaien; ontwerp actualiseert dat dit ten tijde van 2025 niet meer gebeurt.'),
  ('pas_22a_tafelberg_scheepje','zotero_n2000_ontwerp_2026','bevestiging','4.1.2','Bevestigt niet maaien in 2016 en hervatting in 2025.'),
  ('begrazing_kijfhoek_bierlap_1990','zotero_begrazing_2012','bevestiging',NULL,'Bevestigt invoering in september 1990 en een begraasd oppervlak van 275 hectare.'),
  ('begrazing_helmduinen_1991','zotero_begrazing_2012','bevestiging',NULL,'Bevestigt begrazing van 125 hectare Helmduinen sinds 1991.'),
  ('kikkervalleien_begrazing_1997','zotero_valleien_2003','bevestiging',NULL,'Beschrijft toevoeging van de Kikkervalleien aan het begrazingsgebied na de herinrichting; de bron formuleert het vervolg als 1998.'),
  ('kikkervalleien_bodem_1997','zotero_natuurherstel_2005','bevestiging',NULL,'Bevestigt uitvoering van de eerste herstelfase in de winter van 1997.'),
  ('kikkervalleien_infra_1997','zotero_natuurherstel_2005','bevestiging',NULL,'Bevestigt de herinrichting na beëindiging van waterwinning in een deel van de Kikkervalleien.'),
  ('kikkervalleien_infra_1997','zotero_meijendel_mededelingen_30_1996','plancontext','p. 99','Koppelt Sprang PI letterlijk aan kavel 13s en plaatst het voor regeneratie bestemde rietgebied in kavels 13s en 14. Dit is ruimtelijke plancontext; de uitvoering van het verwijderen van leidingen en putten in 1997 wordt door de primaire bron bevestigd.'),
  ('kikkervallei_watercrassula','zotero_kikkervalleien_2010','plancontext','p. 22','Ruimtelijke context: het Kikkervalleiengebied ligt praktisch geheel binnen M13, M13s en M14. De Watercrassulabestrijding zelf wordt bevestigd door de Natura 2000-evaluatie van 2025, p. 13.'),
  ('kikkervalleien_begrazing_1997','zotero_begrazing_2008','bevestiging',NULL,'Bevestigt uitbreiding van de begrazing met de Kikkervallei na de herstelwerkzaamheden.'),
  ('ganzenhoek_pan_1972_1973','zotero_vogelrapport_1973','bevestiging',NULL,'Bevestigt dat de werkzaamheden rond de in 1972 in gebruik genomen pan in 1973 doorliepen.'),
  ('leidingherstel_kavel2_1972_1973','zotero_vogelrapport_1973','bevestiging',NULL,'Beschrijft de droogval van de ronde plas in M2 door leidingherstel begin 1973.'),
  ('ganzenhoek_afwerking_pan_1973_1974','zotero_vogelrapport_1974','bevestiging',NULL,'Beschrijft het aanbrengen van hakhout op de oevers in 1974.'),
  ('ganzenhoek_wandelpad_1974_1975','zotero_vogelrapport_1975','bevestiging',NULL,'Bevestigt voltooiing van het wandelpad langs M13, M13s, M14 en M77 in 1975.'),
  ('plas20_reparatie_1969','zotero_plas20_2006','bevestiging','figuur 1-2','Beschrijft Plas 20 als één langgerekt plassensysteem met een noordelijk, midden- en zuidelijk deel. Ton koppelde deze delen op 14 oktober 2026 respectievelijk aan M16, M17a en M17b.'),
  ('plaggen_parnassiapad2_1993','zotero_hollands_duinen_86_2025','bevestiging','p. 49, figuur 1','De routekaart toont de ligging van het Parnassiapad aan de noordzijde van de Helmduinen. Ton bevestigde op 14 oktober 2026 dat het geplagde Parnassiapad 2 aan M15 moet worden gekoppeld.'),
  ('konijnen_bijplaatsing_2024_2026','odh_konijnenontheffing_2023','bevestiging','p. 5 en bijlagen p. 4-5','De beschikking en het opgenomen activiteitenplan noemen twee uitzetlocaties: Kleine Pan en Waterschapsvallei. De kaartbijlagen begrenzen deze locaties. Ton bevestigde op 14 oktober 2026 de koppeling aan respectievelijk M8 en M41.'),
  ('meeuwenduin_prinsenduin_opslag_2023_2024','zotero_prinsenduin_2020','plancontext','figuur 1','Figuur 1 onderscheidt Prinsenduin van de Prinsenberg en plaatst het als zuidwestelijk onderzoeksgebied in de paraboolduinen. Ton lokaliseerde Prinsenduin op 15 oktober 2026 in M17a.'),
  ('prinsenduin_opslag_2024','zotero_prinsenduin_2020','plancontext','figuur 1','Figuur 1 onderscheidt Prinsenduin van de Prinsenberg en plaatst het als zuidwestelijk onderzoeksgebied in de paraboolduinen. Ton lokaliseerde Prinsenduin op 15 oktober 2026 in M17a.'),
  ('paardenstal_2026_2027','odh_paardenstal_beschikking_2025','plancontext','p. 1-2 en kaartbijlagen p. 12-14','De definitieve ODH-beschikking beschrijft dak-, gevel-, kozijn-, zonnecollector-, water- en elektriciteitswerk en vereiste vleermuismaatregelen. De kaartbijlagen begrenzen de Paardenstal naast De Tapuit en Boerderij Meyendel. De beschikking bewijst vergunningverlening en ligging, niet dat de geplande uitvoering al is begonnen of voltooid.'),
  ('bendel_herinrichting_2025_2026','staatsbosbeheer_bendel_2026','bevestiging','Locatie en looptijd','Staatsbosbeheer lokaliseert de herinrichting in Berkheide-Noord en noemt najaar 2025 tot voorjaar 2026 als looptijd.'),
  ('waterwinning_leidingen_2010_2018','denhaag_pim_archeologie_2013','bevestiging','p. 4 en bijlage 2, p. 38-39','Afbeelding 1 begrenst de PIM-werkgebieden. Bijlage 2 noemt expliciet vervanging of aansluiting van leidingwerk in Serie RA, Serie WV, Serie E, Serie LV en Complex 8. Dunea meldt voor het programma als geheel 6,5 kilometer vernieuwde leiding, maar verdeelt deze lengte niet over series of kavels.');

INSERT INTO maatregel_uitvoering_bron
  (uitvoering_id, bron_id, bronrol, pagina_of_paragraaf, bewijsnotitie)
SELECT u.uitvoering_id, b.bron_id, s.bronrol, s.pagina_of_paragraaf, s.bewijsnotitie
FROM tmp_maatregel_uitvoering_bron_seed s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
ON DUPLICATE KEY UPDATE
  pagina_of_paragraaf=VALUES(pagina_of_paragraaf), bewijsnotitie=VALUES(bewijsnotitie);

INSERT INTO maatregel_uitvoering_plotscope
  (uitvoering_id,plotscope_status,bron_id,vastgesteld_op,verificatiestatus,opmerking)
SELECT
  u.uitvoering_id,
  'buiten_meijendel_plotgebied',
  b.bron_id,
  '2026-10-15',
  'geverifieerd',
  'Staatsbosbeheer lokaliseert Bendel expliciet in Berkheide-Noord. De levende plotlaag bevat 55 Meijendel-plots en geen Berkheide-plots. Daarom krijgt deze uitvoering geen relatie in maatregel_plot_koppeling.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='staatsbosbeheer_bendel_2026'
WHERE u.uitvoering_code IN ('bendel_nabeheer_2026','bendel_herinrichting_2025_2026')
ON DUPLICATE KEY UPDATE
  plotscope_status=VALUES(plotscope_status),
  bron_id=VALUES(bron_id),
  vastgesteld_op=VALUES(vastgesteld_op),
  verificatiestatus=VALUES(verificatiestatus),
  opmerking=VALUES(opmerking);

INSERT INTO plot_gebied
  (gebied_code,naam,gebiedstype,karakterisering,sortering) VALUES
  ('buitenduin_noord','Buitenduin Noord','meijendel_deelgebied',NULL,10),
  ('buitenduin_zuid','Buitenduin Zuid','meijendel_deelgebied',NULL,20),
  ('kijfhoek_en_bierlap','Kijfhoek en Bierlap','meijendel_deelgebied',NULL,30),
  ('vallei_meijendel','Vallei Meijendel','meijendel_deelgebied',NULL,40),
  ('zuid_oosthoek','Zuid-oosthoek','meijendel_deelgebied',NULL,50),
  ('haagsche_golfclub','Haagsche Golfclub','speciaal_gebied','Golfterrein.',60),
  ('voorlinden','Voorlinden','speciaal_gebied','Museumterrein met gebouw.',70),
  ('hertenkamp','Hertenkamp','speciaal_gebied','Geheel omheind, open gebied dat als park functioneert.',80)
ON DUPLICATE KEY UPDATE
  naam=VALUES(naam), gebiedstype=VALUES(gebiedstype),
  karakterisering=VALUES(karakterisering), sortering=VALUES(sortering);

INSERT INTO plot_gebiedsindeling
  (indeling_code,naam,plotversie_id,vastgesteld_op,status,bron_url,besluitnotitie)
SELECT
  'vogelplot-gebiedsindeling-v1',
  'Vogelplots Meijendel: vijf deelgebieden en drie speciale gebieden',
  v.plotversie_id,
  '2026-10-13',
  'vastgesteld',
  'https://www.vwg-m.nl/meijendel/index.asp',
  'Indeling en uitzonderingen door Ton bevestigd op 13 oktober 2026; de globale historische overzichtskaart dient als naamcontext. M54q is genormaliseerd naar het bestaande plot M54a.'
FROM ndff_sovon_plotversie v
WHERE v.versie='2025'
ORDER BY v.plotversie_id DESC
LIMIT 1
ON DUPLICATE KEY UPDATE
  naam=VALUES(naam), plotversie_id=VALUES(plotversie_id),
  vastgesteld_op=VALUES(vastgesteld_op), status=VALUES(status),
  bron_url=VALUES(bron_url), besluitnotitie=VALUES(besluitnotitie);

DROP TEMPORARY TABLE IF EXISTS tmp_plot_gebied_lidmaatschap_seed;
CREATE TEMPORARY TABLE tmp_plot_gebied_lidmaatschap_seed (
  plot_id INT NOT NULL PRIMARY KEY,
  gebied_code VARCHAR(64) CHARACTER SET ascii NOT NULL,
  lidmaatschap_status VARCHAR(32) CHARACTER SET ascii NOT NULL,
  bewijswijze VARCHAR(40) CHARACTER SET ascii NOT NULL,
  opmerking VARCHAR(1000) NULL
) ENGINE=InnoDB;

INSERT INTO tmp_plot_gebied_lidmaatschap_seed VALUES
  (20758,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3532,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3511,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3506,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3512,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3524,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3525,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (29456,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3513,'buitenduin_noord','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (999995,'buitenduin_noord','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd','Historisch M17 is door Ton gelijkgesteld aan M17a.'),
  (999994,'buitenduin_noord','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999993,'buitenduin_noord','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (3529,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3533,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3515,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3496,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3490,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3508,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (29459,'buitenduin_zuid','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3583,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3528,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3527,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3531,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3502,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3519,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3526,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3501,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3518,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3530,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3498,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3516,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3520,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3521,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3522,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3509,'kijfhoek_en_bierlap','actueel_met_geometrie','gebruiker_bevestigd','M63 door Ton toegevoegd aan Kijfhoek en Bierlap.'),
  (999998,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999990,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999987,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999996,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999997,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999999,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999986,'kijfhoek_en_bierlap','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (29455,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3581,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (20247,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (12381,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd','De aangeleverde aanduiding M54q is genormaliseerd naar bestaand plot M54a.'),
  (12382,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (27371,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (9917,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3504,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3510,'vallei_meijendel','actueel_met_geometrie','gebruiker_bevestigd','M85 door Ton toegevoegd aan Vallei Meijendel.'),
  (999989,'vallei_meijendel','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999988,'vallei_meijendel','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (999992,'vallei_meijendel','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (3523,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3500,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3497,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3517,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (112100,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3507,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3505,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (3534,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (100425,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (29457,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (10626,'zuid_oosthoek','actueel_met_geometrie','gebruiker_bevestigd',NULL),
  (999991,'zuid_oosthoek','historisch_zonder_geometrie','afgeleid_en_gebruiker_bevestigd',NULL),
  (3503,'haagsche_golfclub','actueel_met_geometrie','gebruiker_bevestigd','M66 is een golfterrein.'),
  (3514,'voorlinden','actueel_met_geometrie','gebruiker_bevestigd','M91 is Voorlinden, een museumterrein met gebouw.'),
  (3499,'hertenkamp','actueel_met_geometrie','gebruiker_bevestigd','M105 is een geheel omheind, open parkgebied.');

INSERT INTO plot_gebied_lidmaatschap
  (indeling_code,plot_id,gebied_code,lidmaatschap_status,bewijswijze,opmerking)
SELECT
  'vogelplot-gebiedsindeling-v1',s.plot_id,s.gebied_code,
  s.lidmaatschap_status,s.bewijswijze,s.opmerking
FROM tmp_plot_gebied_lidmaatschap_seed s
JOIN plots p ON p.plot_id=s.plot_id
ON DUPLICATE KEY UPDATE
  gebied_code=VALUES(gebied_code),
  lidmaatschap_status=VALUES(lidmaatschap_status),
  bewijswijze=VALUES(bewijswijze),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_uitvoering_gebied
  (uitvoering_id,indeling_code,gebied_code,relatietype,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  'vogelplot-gebiedsindeling-v1',
  'voorlinden',
  'locatie_binnen_gebied',
  'geverifieerd',
  b.bron_id,
  'Het ontwerpbeheerplan noemt Voorlinden; Ton bevestigde op 13 oktober 2026 dat M91 Voorlinden is. De precieze uitvoeringsvoetafdruk binnen het plot is onbekend.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_ontwerp_2026'
WHERE u.uitvoering_code='pas_24c_voorlinden'
ON DUPLICATE KEY UPDATE
  relatietype=VALUES(relatietype),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_uitvoering_gebied
  (uitvoering_id,indeling_code,gebied_code,relatietype,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  'vogelplot-gebiedsindeling-v1',
  'kijfhoek_en_bierlap',
  'volledig_gebied',
  'geverifieerd',
  b.bron_id,
  'De bron beschrijft de invoering voor Kijfhoek en Bierlap als geheel en noemt 275 hectare. Dit is een gebiedsrelatie; er worden geen afzonderlijke plotuitvoeringen uit afgeleid.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_begrazing_2008'
WHERE u.uitvoering_code='begrazing_kijfhoek_bierlap_1990'
ON DUPLICATE KEY UPDATE
  relatietype=VALUES(relatietype),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CASE p.kavel_nummer
    WHEN 'M16' THEN 'Helmduinen; door Ton op 15 oktober 2026 als grootste deel van het in 1991 begonnen begrazingsgebied gekoppeld aan M16. De bron bevestigt Helmduinen, circa 125 hectare en start eind 1991, maar geeft geen kavelverdeling of doorsnijdingspercentage.'
    WHEN 'M15' THEN 'Helmduinen; door Ton op 15 oktober 2026 als gedeeltelijk begrazingsgebied gekoppeld aan M15. De bron bevestigt Helmduinen, circa 125 hectare en start eind 1991, maar geeft geen kavelverdeling of doorsnijdingspercentage.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_begrazing_2012'
JOIN plots p ON p.kavel_nummer IN ('M15','M16')
WHERE u.uitvoering_code='begrazing_helmduinen_1991'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN plots p ON p.plot_id=pk.plot_id
WHERE u.uitvoering_code='begrazing_helmduinen_1991'
  AND p.kavel_nummer='M17a';

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN plots p ON p.plot_id=pk.plot_id
WHERE u.uitvoering_code='begrazing_helmduinen_1991'
  AND p.kavel_nummer IN ('M13','M13s','M14');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT('Kikkervalleien; Holland''s Duinen 55 (april 2010), pagina 5, beschrijft toevoeging van circa 50 hectare aan het sinds 1991 begraasde Helmduinengebied. Pagina 22 benoemt ', p.kavel_nummer, ' expliciet als een van de drie kavels waarin de Kikkervalleien liggen. Ton bevestigde deze toedeling op 14 oktober 2026. De oppervlakte per kavel is niet gegeven; daarom blijft het doorsnijdingspercentage leeg.')
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_kikkervalleien_2010'
JOIN plots p ON p.kavel_nummer IN ('M13','M13s','M14')
WHERE u.uitvoering_code='kikkervalleien_begrazing_1997'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT('Kikkervalleien; Holland''s Duinen 55 (april 2010), pagina 5, beschrijft handmatige en later vooral machinale Duindoornbestrijding en jaarlijks maaien als nabeheer na de herinrichting van 1997. Pagina 22 benoemt ', p.kavel_nummer, ' expliciet als een van de drie kavels waarin de Kikkervalleien liggen. Ton bevestigde deze koppeling op 15 oktober 2026. De bron geeft geen sluitende uitvoeringsjaren of behandelingsoppervlakte per kavel; daarom blijft het doorsnijdingspercentage leeg en worden geen jaarregels toegevoegd.')
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_kikkervalleien_2010'
JOIN plots p ON p.kavel_nummer IN ('M13','M13s','M14')
WHERE u.uitvoering_code='kikkervalleien_duindoorn_nabeheer'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT('Kikkervalleien; Holland''s Duinen 55 (april 2010), pagina 5, beschrijft verwijdering van vegetatie en voedselrijke bovengrond in en rond Pan 26.1 in het najaar van 1997. Pagina 22 benoemt ', p.kavel_nummer, ' expliciet als een van de drie kavels waarin de Kikkervalleien liggen en toont het bewerkte gebied met een zwarte begrenzing. De totale ingreep besloeg circa 50 hectare, maar de oppervlakte per kavel is niet gegeven; daarom blijft het doorsnijdingspercentage leeg.')
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_kikkervalleien_2010'
JOIN plots p ON p.kavel_nummer IN ('M13','M13s','M14')
WHERE u.uitvoering_code='kikkervalleien_bodem_1997'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  CASE
    WHEN p.kavel_nummer='M13' THEN 'benoemd_gebied_gevalideerd'
    ELSE 'expliciet_in_bron'
  END,
  NULL,
  'geverifieerd',
  CASE
    WHEN p.kavel_nummer='M13' THEN b2010.bron_id
    ELSE b1996.bron_id
  END,
  CASE p.kavel_nummer
    WHEN 'M13' THEN 'Sprang I ligt volgens de bronkaarten aan de oostzijde van het werkgebied; Holland''s Duinen 55 (april 2010), pagina 22, plaatst het geschoonde gebied praktisch geheel binnen M13, M13s en M14. Ton bevestigde M13 op 14 oktober 2026. Omdat geen exacte leiding- of putgeometrie beschikbaar is, blijft het doorsnijdingspercentage leeg.'
    WHEN 'M13s' THEN 'Meijendel Mededelingen 30 (november 1996), pagina 99, koppelt Sprang PI letterlijk aan kavel 13s. De verwijdering van leidingen en putten in 1997 wordt bevestigd door Holland''s Duinen 55, pagina 5. De exacte uitvoeringsvoetafdruk binnen de kavel is onbekend; daarom blijft het doorsnijdingspercentage leeg.'
    WHEN 'M14' THEN 'Meijendel Mededelingen 30 (november 1996), pagina 99, plaatst het voor regeneratie bestemde rietgebied van Sprang PI in kavels 13s en 14. De verwijdering van leidingen en putten in 1997 wordt bevestigd door Holland''s Duinen 55, pagina 5. De exacte uitvoeringsvoetafdruk binnen de kavel is onbekend; daarom blijft het doorsnijdingspercentage leeg.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b2010 ON b2010.bron_code='zotero_kikkervalleien_2010'
JOIN maatregel_bron b1996 ON b1996.bron_code='zotero_meijendel_mededelingen_30_1996'
JOIN plots p ON p.kavel_nummer IN ('M13','M13s','M14')
WHERE u.uitvoering_code='kikkervalleien_infra_1997'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT('Kikkervallei; de Natura 2000-evaluatie van 25 april 2025, pagina 13, bevestigt de Watercrassulabestrijding. Holland''s Duinen 55 (april 2010), pagina 22, plaatst het Kikkervalleiengebied praktisch geheel binnen M13, M13s en M14. Ton bevestigde op 14 oktober 2026 dat maatregel 7 aan deze drie kavels wordt gekoppeld. De exacte besmettings- en behandelingsvoetafdruk binnen ', p.kavel_nummer, ' is onbekend; daarom blijft het doorsnijdingspercentage leeg.')
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_kikkervalleien_2010'
JOIN plots p ON p.kavel_nummer IN ('M13','M13s','M14')
WHERE u.uitvoering_code='kikkervallei_watercrassula'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Parnassiapad 2 is door Ton op 14 oktober 2026 eenduidig gekoppeld aan M15. Holland''s Duinen 86 (mei 2025), p. 49 figuur 1, toont de route Parnassiapad als aanvullende ruimtelijke context. De geplagde uitvoeringsvoetafdruk binnen M15 is niet begrensd; daarom blijft het doorsnijdingspercentage leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_hollands_duinen_86_2025'
JOIN plots p ON p.kavel_nummer='M15'
WHERE u.uitvoering_code='plaggen_parnassiapad2_1993'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Parnassiapad 1 is door Ton op 14 oktober 2026 gekoppeld aan M15. Holland''s Duinen 42 (april 2003), tabel 1 en bijlage A, onderscheidt Parnassiapad 1 als de in circa 1997 geplagde blokken E en F. De publicatie bevat geen kavelgrens of exacte plaggeometrie; daarom blijft het doorsnijdingspercentage leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_valleien_2003'
JOIN plots p ON p.kavel_nummer='M15'
WHERE u.uitvoering_code='plaggen_parnassiapad1_1997'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  CASE p.kavel_nummer
    WHEN 'M8' THEN 'De ODH-beschikking en kaartbijlage benoemen en begrenzen locatie A, Kleine Pan. De nameninventaris koppelt Kleine Pan aan M8. Ton bevestigde deze plotkoppeling op 14 oktober 2026. Alleen de uitzetlocatie binnen de kavel is betrokken; de uitvoeringsvoetafdruk en het doorsnijdingspercentage zijn niet vastgesteld.'
    WHEN 'M41' THEN 'De ODH-beschikking en kaartbijlage benoemen en begrenzen locatie B, Waterschapsvallei. Vergelijking met de actuele SOVON-kavelgeometrie plaatst deze locatie in M41. Ton bevestigde deze plotkoppeling op 14 oktober 2026. Alleen de uitzetlocatie binnen de kavel is betrokken; de uitvoeringsvoetafdruk en het doorsnijdingspercentage zijn niet vastgesteld.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='odh_konijnenontheffing_2023'
JOIN plots p ON p.kavel_nummer IN ('M8','M41')
WHERE u.uitvoering_code='konijnen_bijplaatsing_2024_2026'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Voorlinden is door Ton op 13 oktober 2026 eenduidig gekoppeld aan M91. De bron bewijst geen volledig uitvoeringsvlak; daarom blijft het doorsnijdingspercentage leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_ontwerp_2026'
JOIN plots p ON p.kavel_nummer='M91'
WHERE u.uitvoering_code='pas_24c_voorlinden'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_plot_koppeling_seed;
CREATE TEMPORARY TABLE tmp_maatregel_plot_koppeling_seed (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  plot_id INT NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  opmerking VARCHAR(1000) NOT NULL,
  PRIMARY KEY (uitvoering_code,plot_id)
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_plot_koppeling_seed VALUES
  ('kavel1b_herstel_1967',3505,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M1b expliciet.'),
  ('pan2_peilverlaging_1967',3523,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M2 expliciet bij het droogzetten.'),
  ('pan3_schoonmaak_1967',3504,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M3 expliciet bij de volledige schoonmaak.'),
  ('pannen_16_17_peilverlaging_1967',3525,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M16 expliciet.'),
  ('pannen_16_17_peilverlaging_1967',999995,'zotero_vogelrapport_1967','De terreinbijlage noemt historisch kavel M17 expliciet; dit blijft gekoppeld aan het historische plotrecord.'),
  ('hoofdader_leidingen_5_6_71_1967',999988,'zotero_vogelrapport_1967','De terreinbijlage noemt historisch kavel M5 expliciet.'),
  ('hoofdader_leidingen_5_6_71_1967',3521,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M6 expliciet.'),
  ('hoofdader_leidingen_5_6_71_1967',3501,'zotero_vogelrapport_1967','De terreinbijlage noemt kavel M71 expliciet.'),
  ('nieuwe_pannen_10_12_1967',999998,'zotero_vogelrapport_1967','De terreinbijlage noemt historisch kavel M10 expliciet.'),
  ('nieuwe_pannen_10_12_1967',999987,'zotero_vogelrapport_1967','De terreinbijlage noemt historisch kavel M12 expliciet.'),
  ('hoofdader_rietmaaien_6_1968',3521,'zotero_vogelrapport_1968','De terreinbijlage noemt kavel M6 expliciet.'),
  ('pannen_2_3_16_17_peilherstel_1968',3523,'zotero_vogelrapport_1968','De terreinbijlage noemt kavel M2 expliciet.'),
  ('pannen_2_3_16_17_peilherstel_1968',3504,'zotero_vogelrapport_1968','De terreinbijlage noemt kavel M3 expliciet.'),
  ('pannen_2_3_16_17_peilherstel_1968',3525,'zotero_vogelrapport_1968','De terreinbijlage noemt kavel M16 expliciet.'),
  ('pannen_2_3_16_17_peilherstel_1968',999995,'zotero_vogelrapport_1968','De terreinbijlage noemt historisch kavel M17 expliciet.'),
  ('ganzenhoek_pan_1972_1973',3532,'zotero_vogelrapport_1972','De bron lokaliseert de nieuwe pan bij kavel M77.'),
  ('ganzenhoek_helm_populier_13_14_1972',3511,'zotero_vogelrapport_1972','De terreinbijlage noemt kavel M13 expliciet.'),
  ('ganzenhoek_helm_populier_13_14_1972',3512,'zotero_vogelrapport_1972','De terreinbijlage noemt kavel M14 expliciet.'),
  ('leidingherstel_kavel2_1972_1973',3523,'zotero_vogelrapport_1972','De terreinbijlagen voor 1972 en 1973 noemen kavel M2 expliciet.'),
  ('ganzenhoek_afwerking_pan_1973_1974',3532,'zotero_vogelrapport_1973','De bron koppelt de afwerking aan de nieuwe pan bij M77.'),
  ('pannen_drooglegging_4_7_1974',999989,'zotero_vogelrapport_1974','De terreinbijlage noemt historisch kavel M4 expliciet.'),
  ('pannen_drooglegging_4_7_1974',3498,'zotero_vogelrapport_1974','De terreinbijlage noemt kavel M7 expliciet.'),
  ('nieuwe_plas_14_16_1975',3512,'zotero_vogelrapport_1975','De bron noemt de grens van M14 en M16.'),
  ('nieuwe_plas_14_16_1975',3525,'zotero_vogelrapport_1975','De bron noemt de grens van M14 en M16.'),
  ('ganzenhoek_wandelpad_1974_1975',3511,'zotero_vogelrapport_1975','De bron over 1975 noemt M13 expliciet.'),
  ('ganzenhoek_wandelpad_1974_1975',3506,'zotero_vogelrapport_1975','De bron over 1975 noemt M13s expliciet.'),
  ('ganzenhoek_wandelpad_1974_1975',3512,'zotero_vogelrapport_1975','De bronnen over 1974 en 1975 noemen M14 expliciet.'),
  ('ganzenhoek_wandelpad_1974_1975',3532,'zotero_vogelrapport_1975','De bronnen over 1974 en 1975 noemen M77 expliciet.'),
  ('ruiterpad_kavel13_1974',3511,'zotero_vogelrapport_1974','De terreinbijlage noemt kavel M13 expliciet.');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  s.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  s.opmerking
FROM tmp_maatregel_plot_koppeling_seed s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
JOIN plots p ON p.plot_id=s.plot_id
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_nameninventaris_plot_seed;
CREATE TEMPORARY TABLE tmp_maatregel_nameninventaris_plot_seed (
  uitvoering_code VARCHAR(128) CHARACTER SET ascii NOT NULL,
  plot_id INT NOT NULL,
  bron_code VARCHAR(96) CHARACTER SET ascii NOT NULL,
  naamobject_grondslag VARCHAR(500) NOT NULL,
  PRIMARY KEY (uitvoering_code,plot_id)
) ENGINE=InnoDB;

INSERT INTO tmp_maatregel_nameninventaris_plot_seed VALUES
  ('begrazing_kijfhoek_bierlap_1990',3519,'zotero_begrazing_2012','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('begrazing_kijfhoek_bierlap_1990',3520,'zotero_begrazing_2012','Kijfhoek [OBJ-27B6483878; geometrie 11]'),
  ('begrazing_kijfhoek_bierlap_1990',3509,'zotero_begrazing_2012','Kijfhoek [OBJ-27B6483878; geometrie 11]'),
  ('begrazing_kijfhoek_bierlap_1990',3516,'zotero_begrazing_2012','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('begrazing_kijfhoek_bierlap_1990',3518,'zotero_begrazing_2012','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('begrazing_kijfhoek_bierlap_1990',3526,'zotero_begrazing_2012','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('begrazing_kijfhoek_bierlap_1990',3527,'zotero_begrazing_2012','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('begrazing_meeuwenhoek_voor_2008',3502,'zotero_begrazing_2008','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('begrazing_meeuwenhoek_voor_2008',3519,'zotero_begrazing_2008','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('begrazing_meeuwenhoek_voor_2008',3527,'zotero_begrazing_2008','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('begrazing_meeuwenhoek_voor_2008',3528,'zotero_begrazing_2008','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('begrazing_meeuwenhoek_voor_2008',3531,'zotero_begrazing_2008','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_22a_tafelberg_scheepje',3511,'zotero_n2000_evaluatie_2025','Tafelberg [OBJ-87A3731527; geometrie 37]'),
  ('pas_22a_tafelberg_scheepje',3521,'zotero_n2000_evaluatie_2025','''t Scheepje [OBJ-3DB0CB7DAA; geometrie 18]'),
  ('pas_22a_tafelberg_scheepje',3498,'zotero_n2000_evaluatie_2025','''t Scheepje [OBJ-3DB0CB7DAA; geometrie 18]'),
  ('pas_22a_tafelberg_scheepje',3532,'zotero_n2000_evaluatie_2025','Tafelberg [OBJ-87A3731527; geometrie 37]'),
  ('pas_22c_uilenbosch',29457,'zotero_n2000_evaluatie_2025','Uilenbosch [OBJ-4EDC595A83; geometrie 21]'),
  ('pas_22c_uilenbosch',10626,'zotero_n2000_evaluatie_2025','Uilenbosch [OBJ-4EDC595A83; geometrie 21]'),
  ('pas_22c_uilenbosch',112100,'zotero_n2000_evaluatie_2025','Uilenbosch [OBJ-4EDC595A83; geometrie 21]'),
  ('pas_23_vogelkers_2020',3502,'zotero_n2000_evaluatie_2025','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_23_vogelkers_2020',3519,'zotero_n2000_evaluatie_2025','Bierlap [OBJ-636B14D1E3; geometrie 25] + Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_23_vogelkers_2020',3520,'zotero_n2000_evaluatie_2025','Kijfhoek [OBJ-27B6483878; geometrie 11]'),
  ('pas_23_vogelkers_2020',3509,'zotero_n2000_evaluatie_2025','Kijfhoek [OBJ-27B6483878; geometrie 11]'),
  ('pas_23_vogelkers_2020',3516,'zotero_n2000_evaluatie_2025','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('pas_23_vogelkers_2020',3518,'zotero_n2000_evaluatie_2025','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('pas_23_vogelkers_2020',3526,'zotero_n2000_evaluatie_2025','Bierlap [OBJ-636B14D1E3; geometrie 25]'),
  ('pas_23_vogelkers_2020',3527,'zotero_n2000_evaluatie_2025','Bierlap [OBJ-636B14D1E3; geometrie 25] + Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_23_vogelkers_2020',3528,'zotero_n2000_evaluatie_2025','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_23_vogelkers_2020',3531,'zotero_n2000_evaluatie_2025','Meeuwenhoek [OBJ-78715810AF; geometrie 34]'),
  ('pas_24b_ouderijs',27371,'zotero_n2000_evaluatie_2025','Oude Rijs [OBJ-A82FC1291F; geometrie 46]'),
  ('pas_24b_ouderijs',3517,'zotero_n2000_evaluatie_2025','Oude Rijs [OBJ-A82FC1291F; geometrie 46]'),
  ('pas_24b_ouderijs',3510,'zotero_n2000_evaluatie_2025','Oude Rijs [OBJ-A82FC1291F; geometrie 46]');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  s.plot_id,
  'geometrische_doorsnijding',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'Letterlijke maatregellocatie gekoppeld via ',s.naamobject_grondslag,
    ' uit meijendel_nameninventaris_2026-10-14 en actuele plotgeometrie ',
    'sovon-avimap-2025-download-2026-10-02. Dit bewijst de naamgebied-plotdoorsnijding, ',
    'niet het exacte werkoppervlak; daarom blijft doorsnijding_pct leeg.'
  )
FROM tmp_maatregel_nameninventaris_plot_seed s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
JOIN plots p ON p.plot_id=s.plot_id
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Libellenvallei; door Ton op 14 oktober 2026 gekoppeld aan M17b. Holland''s Duinen 42 (april 2003) vermeldt dat de vallei sinds 1975 jaarlijks in het najaar wordt gemaaid.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_valleien_2003'
JOIN plots p ON p.kavel_nummer='M17b'
WHERE u.uitvoering_code='maaibeheer_libellenvallei_1975_2003'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CASE p.kavel_nummer
    WHEN 'M16' THEN 'Noordelijke plas van het volledige Plas 20-systeem; door Ton op 14 oktober 2026 gekoppeld aan M16, met Holland''s Duinen 48 (maart 2006), figuur 1-2, als ruimtelijke context.'
    WHEN 'M17a' THEN 'Middelste plas van het volledige Plas 20-systeem; door Ton op 14 oktober 2026 gekoppeld aan M17a, met Holland''s Duinen 48 (maart 2006), figuur 1-2, als ruimtelijke context.'
    WHEN 'M17b' THEN 'Zuidelijke plas van het volledige Plas 20-systeem; door Ton op 14 oktober 2026 gekoppeld aan M17b, met Holland''s Duinen 48 (maart 2006), figuur 1-2, als ruimtelijke context.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_plas20_2006'
JOIN plots p ON p.kavel_nummer IN ('M16','M17a','M17b')
WHERE u.uitvoering_code IN (
  'plas20_reparatie_1969',
  'plas20_hydrologie_2005_2006',
  'plas20_infrastructuur_2005_2006',
  'slib_plas20_2005_2006'
)
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  CASE p.kavel_nummer
    WHEN 'M2' THEN b1991.bron_id
    WHEN 'M3' THEN b2006.bron_id
  END,
  CASE p.kavel_nummer
    WHEN 'M2' THEN 'De primaire bron noemt kavel 2 als het zuidelijke deel van Pan 13; het broedvogelverslag over 2006 bevestigt dat Pan 13 in kavels 2 en 3 ligt.'
    WHEN 'M3' THEN 'Het broedvogelverslag over 2006 noemt Pan 13 expliciet als plassenserie in kavels 2 en 3.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b1991 ON b1991.bron_code='zotero_pan13_1991'
JOIN maatregel_bron b2006 ON b2006.bron_code='zotero_broedvogelmonitoring_2006'
JOIN plots p ON p.kavel_nummer IN ('M2','M3')
WHERE u.uitvoering_code IN ('pan13_slib_1988_1989','pan13_oeveraanpassing_1988_1989')
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Plas 8.4.2 is op de overzichtskaart in Van der Hagen (2005) herkenbaar als de zuidwestelijke plas van Complex 8. Vergelijking met de actuele TOP10NL-watergeometrie en SOVON-kavelgeometrie plaatst de volledige plas in M32. Ton bevestigde M32 op 15 oktober 2026. De in 2002 gebaggerde werkvoetafdruk binnen de plas is niet afzonderlijk begrensd; daarom blijft doorsnijding_pct leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_slib_plassen_2005'
JOIN plots p ON p.kavel_nummer='M32'
WHERE u.uitvoering_code='slib_plas_8_4_2_2002'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'Maatregel 22d betreft gericht aanvullend beheer van één hectare in Waalsdorp. ',
    'De actuele TOP10NL-geometrie Vlakte van Waalsdorp [OBJ-FC72913747; geometrie 70] raakt ',
    p.kavel_nummer,
    '. Ton bevestigde op 15 oktober 2026 de koppeling aan M84 en M43 en sloot M84s uit. ',
    'De precieze uitvoeringsvoetafdruk binnen de twee kavels is niet bekend; daarom blijft doorsnijding_pct leeg.'
  )
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
JOIN plots p ON p.kavel_nummer IN ('M84','M43')
WHERE u.uitvoering_code='pas_22d_waalsdorp'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CASE
    WHEN p.kavel_nummer IN ('M10-12-76','M12a','M73','M74','M75') THEN
      'Meeuwenduin is door Ton op 15 oktober 2026 gelijkgesteld aan het naamgebied Meeuwenhoek. De actuele Meeuwenhoek-geometrie [OBJ-78715810AF; geometrie 34] raakt deze kavel. De exacte werkvoetafdruk binnen de kavel is niet bekend.'
    ELSE
      'Prinsenduin is een afzonderlijk duingebied en niet de Prinsenberg. Ton lokaliseerde Prinsenduin op 15 oktober 2026 in M17a, mede op grond van figuur 1 in Van der Hagen et al. (2020). De exacte werkvoetafdruk binnen de kavel is niet bekend.'
  END
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='dunea_beheer_meijendel_2023'
JOIN plots p ON p.kavel_nummer IN ('M10-12-76','M12a','M73','M74','M75','M17a')
WHERE u.uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN plots p ON p.plot_id=pk.plot_id
WHERE u.uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024'
  AND p.kavel_nummer IN ('M2','M3','M35','M36');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Prinsenduin is een afzonderlijk duingebied en niet de Prinsenberg. Ton lokaliseerde Prinsenduin op 15 oktober 2026 in M17a, mede op grond van figuur 1 in Van der Hagen et al. (2020). Het Dunea-jaarverslag 2024 bevestigt voortzetting bij Prinsenduin, maar niet de exacte werkvoetafdruk binnen de kavel.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='dunea_jaarverslag_2024'
JOIN plots p ON p.kavel_nummer='M17a'
WHERE u.uitvoering_code='prinsenduin_opslag_2024'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN plots p ON p.plot_id=pk.plot_id
WHERE u.uitvoering_code='prinsenduin_opslag_2024'
  AND p.kavel_nummer IN ('M2','M3','M35','M36');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  'Dunea lokaliseert de kabels, elektriciteitskast en laadvoorbereiding op het parkeerterrein bij De Tapuit, bezoekerscentrum Dunea en Boerderij Meyendel. De openbare locatiepunten van deze drie voorzieningen liggen volgens de actuele kavelgeometrie alle in M51. Ton bevestigde de koppeling aan M51 op 15 oktober 2026. Het exacte kabeltracé en de werkvoetafdruk zijn niet gepubliceerd; daarom blijft doorsnijding_pct leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='dunea_reguliere_werkzaamheden_2026'
JOIN plots p ON p.kavel_nummer='M51'
WHERE u.uitvoering_code='vallei_elektriciteit_2026'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'expliciet_in_bron',
  NULL,
  'geverifieerd',
  b.bron_id,
  'De kaartbijlagen op pagina 12-14 van de ODH-beschikking begrenzen de Paardenstal bij De Tapuit en Boerderij Meyendel. Ton bevestigde op 15 oktober 2026 dat de Paardenstal in M51 ligt. De exacte werkvoetafdruk binnen de kavel is niet gepubliceerd; daarom blijft doorsnijding_pct leeg.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='odh_paardenstal_beschikking_2025'
JOIN plots p ON p.kavel_nummer='M51'
WHERE u.uitvoering_code='paardenstal_2026_2027'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u USING (uitvoering_id)
JOIN plots p USING (plot_id)
WHERE u.uitvoering_code='ganzenhoek_dunning_2017'
  AND p.kavel_nummer='M13s';

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'De Natura 2000-evaluatie van 25 april 2025 noemt Ganzenhoek en bevestigt de grote dunning van het Ganzenhoekbos in 2017. ',
    'De actuele Ganzenhoek-geometrie in de nameninventaris raakt M13s, M77 en M78/79. ',
    'Ton bepaalde op 15 oktober 2026 dat deze dunning uitsluitend aan M77 en M78/79 wordt gekoppeld en niet aan M13s. ',
    'De exacte werkvoetafdruk binnen de twee kavels is niet bekend; daarom blijft doorsnijding_pct leeg.'
  )
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
JOIN plots p ON p.kavel_nummer IN ('M77','M78/79')
WHERE u.uitvoering_code='ganzenhoek_dunning_2017'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'De Natura 2000-evaluatie van 25 april 2025 beschrijft jaarlijks aanvullend maaibeheer in Ruijgenhoek, Langestrook en De Loopert, totaal 3 hectare, en vermeldt dat Dunea dit beheer voortzet. ',
    'Ton lokaliseerde Ruygenhoek in M32. De actuele TOP10NL-geometrie van De Loopert [OBJ-70B5AFD1B2; geometrie 29] raakt M45 en M83. ',
    'De actuele TOP10NL-geometrie van Lange Strook [OBJ-2F95388B74; geometrie 14] raakt M1a en M1b; de schrijfwijzen Langestrook, Lange Strook en Lange Strooken blijven als bronvarianten onderscheiden. ',
    'De bron verdeelt de drie hectare niet over de gebieden of kavels; daarom blijft doorsnijding_pct leeg.'
  )
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
JOIN plots p ON p.kavel_nummer IN ('M1a','M1b','M32','M45','M83')
WHERE u.uitvoering_code='pas_22b_maaibeheer'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'Maatregel 22h omvat Zeereep Meijendel, Helmduinen, Prinsenduin en Ganzenhoek. Ton bepaalde op 15 oktober 2026 de gezamenlijke uitvoeringsscope als M15 en M16 voor Helmduinen; M17a voor Prinsenduin; M13s, M77 en M78/79 voor Ganzenhoek; en M17a, M16, M15, M13s en M78/79 voor de buitenste zeereep direct achter het strand. ',
    'De jaarbron meldt uitvoering in 2016 en 2017 voor de maatregel als geheel, maar verdeelt het werk niet over naamgebieden of kavels. Een plot-jaarrij betekent daarom uitvoeringsscope en geen bewijs dat in die kavel in dat jaar feitelijk is gewerkt; doorsnijding_pct blijft leeg.'
  )
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='zotero_n2000_evaluatie_2025'
JOIN plots p ON p.kavel_nummer IN ('M13s','M15','M16','M17a','M77','M78/79')
WHERE u.uitvoering_code='pas_22h_aanvullend_beheer'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DELETE pk
FROM maatregel_plot_koppeling pk
JOIN maatregel_uitvoering u ON u.uitvoering_id=pk.uitvoering_id
JOIN plots p ON p.plot_id=pk.plot_id
WHERE u.uitvoering_code='waterwinning_leidingen_2010_2018'
  AND p.kavel_nummer NOT IN ('M41','M42','M43','M45','M84','M84s','M85');

INSERT INTO maatregel_plot_koppeling
  (uitvoering_id,plot_id,koppelmethode,doorsnijding_pct,verificatiestatus,bron_id,opmerking)
SELECT
  u.uitvoering_id,
  p.plot_id,
  'benoemd_gebied_gevalideerd',
  NULL,
  'geverifieerd',
  b.bron_id,
  CONCAT(
    'Het PIM-rapport uit 2013 specificeert leidingvervanging of -aansluiting in Serie RA, Serie WV, Serie E, Serie LV en Complex 8. ',
    'De werkgebieden op afbeelding 1 zijn op 15 oktober 2026 over de actuele kavelgeometrie gelegd; Ton bevestigde vervolgens de gezamenlijke koppeling aan M41, M42, M43, M45, M84, M84s en M85. ',
    'De gepubliceerde totale lengte van 6,5 kilometer is niet per serie of kavel uitgesplitst; daarom blijft doorsnijding_pct leeg.'
  )
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='denhaag_pim_archeologie_2013'
JOIN plots p ON p.kavel_nummer IN ('M41','M42','M43','M45','M84','M84s','M85')
WHERE u.uitvoering_code='waterwinning_leidingen_2010_2018'
ON DUPLICATE KEY UPDATE
  koppelmethode=VALUES(koppelmethode),
  doorsnijding_pct=VALUES(doorsnijding_pct),
  verificatiestatus=VALUES(verificatiestatus),
  bron_id=VALUES(bron_id),
  opmerking=VALUES(opmerking);

DROP TEMPORARY TABLE IF EXISTS tmp_plot_gebied_lidmaatschap_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_plot_koppeling_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_nameninventaris_plot_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_bron_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_jaar_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_project_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_bron_seed;
