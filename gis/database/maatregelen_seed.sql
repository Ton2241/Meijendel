-- Eerste bronvaste invoer van werkzaamheden in Meijendel.
-- Stand bronbeoordeling: 13 oktober 2026.
-- Geen geometrieën of plotkoppelingen: de geraadpleegde bronnen leveren daarvoor
-- nog geen voldoende nauwkeurige, gevalideerde begrenzing.

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
  ('zotero_kikkervalleien_2010','beheerpublicatie','Natuurherstel van de Kikkervalleien in Noord-Meijendel','2010-04-01','USGTMZNW',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag.'),
  ('zotero_stuifgaten_2017','beheerpublicatie','Grenzen slechten in Meijendel: stuifgaten in de zeereep','2017-11-01','C224J22K',NULL,'2026-10-13','gepubliceerd','Volledige PDF geraadpleegd vanaf de gekoppelde Zotero-opslag.'),
  ('zotero_n2000_evaluatie_2025','natura2000_beheerplan','Evaluatie Natura 2000-beheerplan Meijendel & Berkheide','2025-04-25','DUNY3DCC',NULL,'2026-10-13','definitief','Definitieve evaluatie; uitvoeringsstatus gebaseerd op jaarrapportages en gesprekken met terreinbeheerders.'),
  ('zotero_n2000_ontwerp_2026','natura2000_beheerplan','Ontwerp Natura 2000-beheerplan Meijendel & Berkheide 2026-2032','2026-01-13','LAW9SJXC','https://www.zuid-holland.nl/politiek-bestuur/gedeputeerde-staten/besluiten/besluit/ontwerpbesluit-vaststelling-natura-2000-beheerplan-meijendel-en-berkheide-2026-2','2026-10-13','ontwerp','Alleen gebruikt voor geactualiseerde historische uitvoering en als plancontext; ontwerpmaatregelen zijn niet als uitgevoerd aangemerkt.'),
  ('dunea_optimalisatie_waterwinning_2018','officiele_webpagina','Optimalisatie waterwinsysteem Meijendel afgerond','2018-10-22',NULL,'https://www.dunea.nl/zakelijk/nieuwsbrieven/nieuwsbrief-2018-10/optimalisatie-waterwinsysteem-meijendel-afgerond','2026-10-13','officiele_publicatie','Dunea meldt afronding van het achtjarige programma.'),
  ('dunea_beheer_meijendel_2023','officiele_webpagina','Beheersmaatregelen Meijendel ter bevordering van oorspronkelijke flora en fauna','2023-11-13',NULL,'https://www.dunea.nl/over-dunea/algemeen/nieuws/2023/beheersmaatregelen-meijendel-ter-bevordering-van-oorspronkelijke-flora-en-fauna','2026-10-13','officiele_publicatie','Dunea beschrijft start en aard van de werkzaamheden in Meeuwenduin en Prinsenduin.'),
  ('dunea_jaarverslag_2024','onderzoeksrapport','Dunea jaarverslag 2024','2025-01-01',NULL,'https://www.dunea.nl/duinen/-/media/bestanden/over-dunea/jaarberichten/dunea-jaarverslag-2024.pdf','2026-10-13','vastgesteld_jaarverslag','Bevestigt voortzetting beheerwerk en start konijnenproef in 2024.'),
  ('dunea_slagbomen_2025','officiele_webpagina','Vervangen slagbomen Meijendel','2025-11-25',NULL,'https://www.dunea.nl/algemeen/nieuws/2025/vervangen-slagbomen-meijendel','2026-10-13','officiele_publicatie','Werkperiode 1 tot en met 12 december 2025.'),
  ('dunea_reguliere_werkzaamheden_2026','officiele_webpagina','Reguliere werkzaamheden in Meijendel','2026-10-13',NULL,'https://www.dunea.nl/duinen/werkzaamheden/reguliere-werkzaamheden','2026-10-13','actuele_webpagina','De pagina bevat geplande werkzaamheden bij de Paardenstal en elektriciteitswerk in Vallei Meijendel; uitvoering is niet als voltooid bevestigd.'),
  ('pzh_bendel_subsidie_2026','subsidiebesluit','Openstellingsbesluit subsidie natuurmaatregelen 2026','2026-04-22',NULL,'https://zoek.officielebekendmakingen.nl/prb-2026-6828.html','2026-10-13','subsidie_openstelling','Subsidieerbaarheid van Bendel-nabeheer bewijst geen uitvoering.'),
  ('dunea_dynamiek_2024','officiele_webpagina','Dynamiek in het duin','2024-12-18',NULL,'https://www.dunea.nl/zakelijk/nieuwsbrieven/nieuwsbrief-2024-12/dynamiek-in-het-duin','2026-10-13','officiele_publicatie','Bevestigt vijf in 2015 voltooide kerven en aanvang van het werk in september 2014.');

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
  ('konijnen_bijplaatsing','Konijnenbijplaatsingsproef Meijendel','Proef met bijplaatsing en monitoring van konijnen voor herstel van de begrazingsfunctie.','onderzoek_monitoring','Dunea','in_uitvoering','Meijendel & Berkheide','Meijendel','2024-01-01','2026-12-31',NULL,NULL,NULL),
  ('optimalisatie_waterwinning','Optimalisatie waterwinsysteem Meijendel','Achtjarig programma met putten, leidingen, schoning van infiltratiepannen en natuurherstel.','waterwinning','Dunea','afgerond','Meijendel & Berkheide','Meijendel','2010-01-01','2018-10-22',NULL,'Projectomvang 40 miljoen euro; natuurherstel voor 50 procent gesubsidieerd',NULL),
  ('slagbomen_2025','Vervanging slagbomen Meijendel','Vervanging van slagbomen bij toegangen tot Meijendel.','infrastructuur','Dunea','afgerond','Meijendel & Berkheide','Meijendel','2025-12-01','2025-12-12',NULL,NULL,NULL),
  ('vallei_elektriciteit_2026','Elektriciteitswerk Vallei Meijendel','Kabel, elektriciteitskast en voorbereiding van drie laadpunten met zes plaatsen.','infrastructuur','Dunea','uitvoering_niet_bevestigd','Meijendel & Berkheide','Vallei Meijendel','2026-09-23',NULL,NULL,NULL,NULL),
  ('paardenstal_2026_2027','Werkzaamheden Paardenstal','Op de actuele werkzaamhedenpagina aangekondigde werkzaamheden bij de Paardenstal.','infrastructuur','Dunea','gepland','Meijendel & Berkheide','Paardenstal','2026-11-01','2027-03-31',NULL,NULL,NULL),
  ('bendel_nabeheer_2026','Nabeheer Bendel','Subsidieerbaar nabeheer voor H2130 en H2190; uitvoering niet bewezen.','natuurbeheer','Nog niet vastgesteld','subsidie_openstelling','Meijendel & Berkheide','Bendel',NULL,NULL,'Subsidieregeling natuurmaatregelen 2026',NULL,'97-NP-263');

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
  ('kikkervalleien_begrazing_1997','kikkervalleien_herstel','begrazing','MT01','A01','overgangsbeheer','Begrazingsgebied uitbreiden','Na de herinrichting is circa 50 ha toegevoegd aan het sinds 1991 begraasde gebied van circa 125 ha.','Kikkervalleien en Helmduinen','benoemd_deelgebied','1997-01-01',NULL,'jaar','doorlopend na inrichting','Dunea',50,'ha',NULL),
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
  ('meeuwenduin_prinsenduin_opslag_2023_2024','meeuwenduin_prinsenduin_beheer','bosreductie_struweelbeheer','MT02','A09','uitgevoerd_voor_2026','Bomen, struiken en exoten verwijderen','Werk gestart in november 2023 en in 2024 voortgezet; gericht op onder meer Amerikaanse vogelkers, den, hulst en esdoorn.','Meeuwenduin en Prinsenduin','benoemd_deelgebied','2023-11-01','2024-12-31','periode','seizoenswerk november-maart','Dunea',NULL,NULL,NULL),
  ('konijnen_bijplaatsing_2024_2026','konijnen_bijplaatsing',NULL,'MT06','F01','in_uitvoering','Konijnen bijplaatsen en volgen','Pilot gestart in 2024, loopt volgens jaarverslag door tot en met 2026 en wordt gemonitord.','Meijendel','meijendel_breed','2024-01-01','2026-12-31','periode',NULL,'Dunea',NULL,NULL,'Onderzoek en beheerproef; niet als regulier begrazingsbeheer geclassificeerd.'),
  ('waterwinning_putten_2010_2018','optimalisatie_waterwinning',NULL,'MT04','L01','uitgevoerd_voor_2026','Nieuwe winputten aanleggen','Bijna 700 nieuwe putten aangelegd binnen het optimalisatieprogramma.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',700,'aantal','Bron zegt bijna 700; hoeveelheid is daarom afgerond.'),
  ('waterwinning_leidingen_2010_2018','optimalisatie_waterwinning',NULL,'MT04','L01','uitgevoerd_voor_2026','Leidingen aanleggen','6,5 kilometer leiding aangelegd.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',6.5,'km',NULL),
  ('waterwinning_pannen_2010_2018','optimalisatie_waterwinning','hydrologie_optimaliseren','MT04','B01','uitgevoerd_voor_2026','Infiltratiepannen schonen en oevers natuurvriendelijk maken','370.000 m3 materiaal verwijderd; pannen schoongemaakt en oevers natuurvriendelijk ingericht.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',370000,'m3',NULL),
  ('waterwinning_plaggen_2010_2018','optimalisatie_waterwinning','plaggen_chopperen_afgraven','MT04','B04','uitgevoerd_voor_2026','Duinen plaggen bij optimalisatie waterwinning','Bijna 400.000 m2 duin geplagd; 100.000 m3 zand hergebruikt.','Meijendel','meijendel_breed','2010-01-01','2018-10-22','periode','eenmalig programma','Dunea',40,'ha','Bron zegt bijna 400.000 m2; hoeveelheid is omgerekend en afgerond.'),
  ('slagbomen_2025','slagbomen_2025','rust_en_recreatiebeheer','MT03','G04','uitgevoerd_voor_2026','Slagbomen vervangen','Vervanging uitgevoerd in de aangekondigde werkperiode 1-12 december 2025.','Meijendel','meijendel_breed','2025-12-01','2025-12-12','dag','eenmalig','Dunea',NULL,NULL,NULL),
  ('vallei_elektriciteit_2026','vallei_elektriciteit_2026',NULL,'MT03','L01','onbekend','Elektriciteitskabel en laadvoorbereiding','Start aangekondigd op 23 september 2026; voltooiing niet bevestigd.','Vallei Meijendel','benoemd_deelgebied','2026-09-23',NULL,'dag','eenmalig','Dunea',3,'aantal','Drie laadpunten, voorbereid voor zes plaatsen.'),
  ('paardenstal_2026_2027','paardenstal_2026_2027',NULL,'MT03','L02','gepland','Werkzaamheden Paardenstal','Geplande werkperiode 1 november 2026 tot en met 31 maart 2027.','Paardenstal','benoemd_deelgebied','2026-11-01','2027-03-31','dag','eenmalig','Dunea',NULL,NULL,NULL),
  ('bendel_nabeheer_2026','bendel_nabeheer_2026',NULL,'MT02','D01','gepland','Subsidieerbaar nabeheer Bendel','Openstelling noemt nabeheer voor H2130 en H2190; geen bewijs van opdracht of uitvoering.','Bendel','benoemd_deelgebied',NULL,NULL,'onbekend',NULL,NULL,NULL,NULL,'Alleen plan- en subsidiecontext.');

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
  ('meeuwenduin_prinsenduin_opslag_2023_2024',2023,'uitgevoerd','dunea_beheer_meijendel_2023','Werk gestart in november 2023.'),
  ('meeuwenduin_prinsenduin_opslag_2023_2024',2024,'uitgevoerd','dunea_jaarverslag_2024','Werk in 2024 voortgezet.'),
  ('konijnen_bijplaatsing_2024_2026',2024,'uitgevoerd','dunea_jaarverslag_2024','Pilot gestart.'),
  ('waterwinning_putten_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_leidingen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_pannen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('waterwinning_plaggen_2010_2018',2018,'uitgevoerd','dunea_optimalisatie_waterwinning_2018','Programma afgerond.'),
  ('slagbomen_2025',2025,'uitgevoerd','dunea_slagbomen_2025','Werkperiode 1-12 december 2025.');

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
         WHEN uitvoering_code LIKE 'pan13_%' THEN 'zotero_pan13_1991'
         WHEN uitvoering_code LIKE 'kikkervalleien_%' THEN 'zotero_kikkervalleien_2010'
         WHEN uitvoering_code LIKE 'zeereep_%' THEN 'zotero_stuifgaten_2017'
         WHEN uitvoering_code LIKE 'pas_%' OR uitvoering_code='ganzenhoek_dunning_2017' OR uitvoering_code='kikkervallei_watercrassula' THEN 'zotero_n2000_evaluatie_2025'
         WHEN uitvoering_code='meeuwenduin_prinsenduin_opslag_2023_2024' THEN 'dunea_beheer_meijendel_2023'
         WHEN uitvoering_code='konijnen_bijplaatsing_2024_2026' THEN 'dunea_jaarverslag_2024'
         WHEN uitvoering_code LIKE 'waterwinning_%' THEN 'dunea_optimalisatie_waterwinning_2018'
         WHEN uitvoering_code='slagbomen_2025' THEN 'dunea_slagbomen_2025'
         WHEN uitvoering_code IN ('vallei_elektriciteit_2026','paardenstal_2026_2027') THEN 'dunea_reguliere_werkzaamheden_2026'
         WHEN uitvoering_code='bendel_nabeheer_2026' THEN 'pzh_bendel_subsidie_2026'
       END AS bron_code,
       CASE
         WHEN uitvoering_status_code IN ('gepland','onbekend') THEN 'plancontext'
         ELSE 'primaire_uitvoeringsbron'
       END AS bronrol,
       NULL AS pagina_of_paragraaf,
       CONCAT('Bronbasis voor uitvoering ', CONVERT(uitvoering_code USING utf8mb4), '; status en omvang zijn niet ruimer geïnterpreteerd dan de bron ondersteunt.')
FROM tmp_maatregel_uitvoering_seed;

INSERT INTO tmp_maatregel_uitvoering_bron_seed VALUES
  ('zeereep_vijf_kerven_2014_2015','dunea_dynamiek_2024','bevestiging',NULL,'Dunea bevestigt aanvang in september 2014 en voltooiing van vijf kerven in 2015.'),
  ('zeereep_kerven_nabeheer','zotero_n2000_ontwerp_2026','bevestiging','4.2','Ontwerpbeheerplan bevestigt nabeheer in 2016 en 2024.'),
  ('pas_3d_begrazing_zuid','zotero_n2000_ontwerp_2026','bevestiging','4.2','Actualiseert onderbreking in 2020, hervatting in 2021 en vaste rasters in 2025.'),
  ('pas_24b_ouderijs','zotero_n2000_ontwerp_2026','tegenstrijdig_bewijs','4.2','Evaluatie noemt jaarlijks maaien; ontwerp actualiseert dat dit ten tijde van 2025 niet meer gebeurt.'),
  ('pas_22a_tafelberg_scheepje','zotero_n2000_ontwerp_2026','bevestiging','4.1.2','Bevestigt niet maaien in 2016 en hervatting in 2025.'),
  ('meeuwenduin_prinsenduin_opslag_2023_2024','dunea_jaarverslag_2024','bevestiging',NULL,'Jaarverslag bevestigt voortzetting in 2024.');

INSERT INTO maatregel_uitvoering_bron
  (uitvoering_id, bron_id, bronrol, pagina_of_paragraaf, bewijsnotitie)
SELECT u.uitvoering_id, b.bron_id, s.bronrol, s.pagina_of_paragraaf, s.bewijsnotitie
FROM tmp_maatregel_uitvoering_bron_seed s
JOIN maatregel_uitvoering u ON u.uitvoering_code=s.uitvoering_code
JOIN maatregel_bron b ON b.bron_code=s.bron_code
ON DUPLICATE KEY UPDATE
  pagina_of_paragraaf=VALUES(pagina_of_paragraaf), bewijsnotitie=VALUES(bewijsnotitie);

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

DROP TEMPORARY TABLE IF EXISTS tmp_plot_gebied_lidmaatschap_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_bron_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_jaar_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_uitvoering_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_project_seed;
DROP TEMPORARY TABLE IF EXISTS tmp_maatregel_bron_seed;
