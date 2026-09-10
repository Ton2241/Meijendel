# TODO

## Nu open

### GBIF-vangblikken Meijendel 1953-1960

- Bevestig bij de bronhouder waarom versie 1.7 in EML en GBIF CC BY-NC 4.0
  vermeldt terwijl het datapaper CC0 noemt; hanteer tot die tijd CC BY-NC 4.0.
- Vraag correctie of duiding voor de twee occurrences onder ontbrekend event
  `Meij-05August1959pf207`.
- Stel per taxon vast over welke jaren de oorspronkelijke soortmap volledig is
  voordat een leeg sampling event als nulwaarneming wordt gebruikt.
- Ontwerp pas daarna afzonderlijke tabellen voor vangblikken, sampling events,
  vangsten en kwaliteitsvlaggen en koppel de geversioneerde locaties aan de
  SOVON-plots. Wijzig de life database nog niet. Voer de uiteindelijke import
  samen met de toegelaten NDFF-levering uit als één gecontroleerde migratie,
  met afzonderlijke bronlagen en één gezamenlijke preflight en rollback.

### NDFF ticket 58679 - beveiligde levering

- Ontvangst is afgerond: het ongewijzigde GeoPackage, de standaardcitatie en de
  groene ontvangst-/analysemanifesten staan onder
  `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679`.
- De afgescheiden lokale bronregistratie is afgerond in
  `Meijendel_ndff_secure`: 14.573 records en 158 taxa. Van deze records zijn
  8.494 uitsluitend voor positieve verspreidingscontext toegelaten; 1.274 zijn
  gelabeld als wachtend op volledige brondata en blijven buiten trendanalyse.
  De life-database is niet gewijzigd.
- De open koppeling via `Identiteit = SHA-256(obs_uri)` en de koppeling aan de
  55 geversioneerde SOVON-plots zijn uitgevoerd. Behoud de afgeleide
  recordstatussen en forceer geen plot bij `multiple`, `outside` of
  `single_deels`.
- Beoordeel per soortgroep welke van de 8.494 voorlopige
  verspreidingskandidaten wetenschappelijk nuttig genoeg zijn voor opname in
  het afzonderlijke beveiligde schema; zij zijn niet trendklaar.
- Vraag voor de 1.274 ruimtelijk geschikte meetnet-/gebiedsmonitoringrecords de
  volledige native meetreeksen rechtstreeks op bij de bronorganisaties, niet
  opnieuw bij NDFF. Start met Zoogdiervereniging (572
  vleermuistransectrecords), Dunea/FLORON (478 LMF-a-records) en RAVON (72
  reguliere amfibieënrecords). Vraag daarna ANEMOON (112 slakken), BLWG (21
  korstmos-/mosrecords), FLORON (12 Het Nieuwe Strepen),
  Staatsbosbeheer/opdrachtgever (5 SNL-records), De Vlinderstichting (1) en
  RAVON/opdrachtgever (1 Natura 2000-record).
- Vraag per bron minstens: stabiele telobject-ID en alle geometrieversies; alle
  geplande, uitgevoerde en niet-uitgevoerde bezoeken; bezoek-ID; duur,
  route/lengte/oppervlakte, methode en apparatuur; volledige doelsoortenlijst;
  positieve en nulresultaten; protocolversies; kwaliteits- en
  wijzigingsmetadata. Los bij LMF-a expliciet de openbare drie-/vierjarige
  cyclusinconsistentie op.
- Leg eerst de native surveystructuur vast en koppel die daarna geversioneerd
  aan SOVON-plots. Splits routes of gebieden niet over plots zonder
  sectiegeometrie én sectie-inspanning. Stel het definitieve surveyschema pas
  vast na ontvangst van minstens één representatieve bronlevering.
- Onderzoek de herkomst van de 163 PQ-risicorecords met status
  `niet_beoordeelbaar`; de 162 exacte PQ-dubbels blijven uitgesloten als
  zelfstandige NDFF-evidentie. Behandel de provinciale PQ-reeks in de
  life-database altijd als oorspronkelijke, gezaghebbende bron en NDFF-PQ
  uitsluitend als secundaire QA-bron; gebruik NDFF-PQ nooit als aanvulling of
  vervanging, ongeacht de overlapstatus.
- Voeg aan iedere latere NDFF-analyse een verplichte controletabel toe met
  aantallen per PQ-status, uitgesloten records en beslisregelversie. Alleen
  `onafhankelijk` en `niet_van_toepassing` mogen alleen zelfstandig meetellen
  als het record geen PQ-bronrecord is.
- Behoud de lokale import en de drie veilige views afgescheiden van de gewone
  life-database en VPS. Het localhost-only Shiny-login-path is ingericht en
  getest; verleen geen bredere schemarechten.

### Wintertellingen — geparkeerde vervolgstappen

- Punt 7 (geparkeerd): laat de technische indeling `water_wetland` versus
  `overige_vogels` en de ecologische interpretatie van de 220 soorten door een
  soortenexpert nalopen voordat deze indeling opnieuw voor analyse of presentatie
  wordt gebruikt. De indeling is geen dashboardfilter meer en beïnvloedt de
  geldigheid van nullen niet.
- Punt 8 (geparkeerd): vergelijk gevalideerde lokale soortindices met passende
  landelijke Sovon-reeksen en werk pas daarna verklaringen of een publieksartikel
  bij. Bouw tot die beoordeling geen samengestelde wintervogelindicator en voer
  geen causale beheer-, recreatie-, habitat- of klimaatanalyse uit.

### Functionele vogelgroepen — fase E afgerond

Fase C is technisch afgerond: 954 classificaties voor alle 159
territoriumhoudende broedvogels, binaire en gewogen
lidmaatschappen, soortgebonden rationale/provenance, strikte en inclusieve
drempelvarianten en leave-one-species-out-minimumstatus zijn vastgelegd.

- De zes soortenlijsten, inclusief Zaadeters, zijn inhoudelijk geaccordeerd en lokaal aangesloten op
  dashboard, Shiny en website-output. Legacy blijft daarnaast beschikbaar.
- Houd luchtfoerageerders uitsluitend exploratief en vermeld bij de
  bodem-insectengroep altijd de drempelgevoeligheid.
- Voer bij iedere wijziging van traits, groepsregels of TRIM-soortselectie de
  binaire, gewogen, leave-one-species-out- en beide paritychecks opnieuw uit.
- De productiepublicatie is uitgevoerd via de verplichte Meijendel- en
  VWG_M-preflights; vervolgwijzigingen blijven dezelfde release- en
  paritycontroles doorlopen.
- Behoud `F-Mud`, de zeven afwijkende soortnamen en de dubbele legacytypering als
  zichtbare legacykwaliteitsissues; corrigeer ze alleen gecontroleerd en zonder
  historische data stilzwijgend te herschrijven.

- Archiefmodule afronden: aparte uploadpagina, `.doc`-support, PDF-/documentindexering, full-text search, categoriepagina's, uploadrechten vanaf bestuurslidniveau en duidelijke foutafhandeling.
- Verifiëren dat archiefdocumenten doorzoekbaar zijn na upload en na herindexering.
- Archiefupload testen met grote bestanden tot 100 MB.
- Nieuws/CMS na de wijzigingen van 2026-06-30 nog handmatig end-to-end testen met ingelogde redacteur: concept maken, afbeelding uploaden, preview controleren, publiceren, en resultaat controleren op startpagina, `/nieuws/index.asp` en detailpagina.
- Leden/contentbeheer na de wijzigingen van 2026-06-30 handmatig end-to-end testen met een gewoon niveau-1 telleraccount: ledenpagina met actuele kavels/routes controleren, Contentbeheer openen, alleen `Kavels` zien, alleen eigen kavel(s) zien, kaveltekst wijzigen/publiceren en publieke kavelpagina controleren.
- Ingelogde CMS-test uitvoeren voor `Contentbeheer > Vaste Pagina's > Groepen > Vogelrichtlijn`: concept opslaan, preview controleren, publiceren en publieke pagina controleren.
- Mobiel/tablet visueel controleren of de kopknoppen `Beschrijving`, `Voorkomen` en `Kenmerken` bruikbaar blijven bij lange soortnamen.

## Productie en beheer

- Container-CVE's blijven wekelijks monitoren. De remediatie van 18 augustus
  2026 is afgerond: beide MySQL-images en de minimale Shiny-runtime zijn 0
  `CRITICAL`/0 `HIGH`. Blijf nieuwe kandidaten vóór activering exact scannen en
  doorloop opnieuw de geïsoleerde test, preflight en rooktest.
- Bij elke functionele wijziging `handleiding_beheer.md` en auditlogging bijwerken waar relevant.
- Bij verzoeken om wijzigingen aan `app.vwg-m.nl` of de VPS-site: lokaal aanpassen, committen, naar de VPS deployen en productie verifiëren.
- Bij brede deploys controleren dat `app/static/uploads/cms` op de VPS behouden blijft; dit is runtime-uploaddata en mag niet door een schone rsync worden verwijderd.
- Na iedere toekomstige Caddy- of DNS-wijziging de configuratie en volledige
  multi-hostrooktest voor `www.vwg-m.nl`, `vwg-m.nl` en `app.vwg-m.nl`
  opnieuw valideren. De DNS-cutover zelf is afgerond.
- NAS-pullscript later bijwerken als de NAS-kopie expliciet de nieuwe canonieke SQL-check moet afdwingen.
- De restoreprocedure is op 5 september 2026 volledig groen getest op een lege,
  tijdelijke externe VPS. Herhaal dit voortaan periodiek en na materiële
  wijzigingen aan back-upformaat, databaseversies of herstelcode.
- De geteste herstelverbeteringen zijn op 5 september via de normale
  VWG_M-productiepreflight uitgerold als commit
  `0377210908cf70f38dcbacbc50a3d13b1a2ecde8`. Alle 754 tests en acht
  finance-integratietests slaagden zonder skips; de aansluitende verse
  bare-metalback-up is 2.743.074.285 bytes groot en heeft SHA-256
  `7d66ad014fd12d7be74d0fc517be009380bf28c9b550aa3acbd58fdbeb47f133`.
  De handmatig gestarte NAS-pull is daarna inclusief forced read-only
  sleutelproef, checksum en volledige inhoudscontrole groen afgerond; alleen de
  bekende niet-blokkerende lokale `pg_restore`-versiewaarschuwing bleef staan.
- Archief/OCR-service en timer pas als productie-actief beschouwen nadat installatie, rechten, logging en herindexering op de VPS expliciet zijn gecontroleerd.

## Datamigratie

- Legacy-pagina's gefaseerd per pagina omzetten naar bewerkbare CMS-pagina's.
- Postgres verder leidend maken voor leden, kavels, routes en tellerkoppelingen vanaf 2026.
- Historische kavel-/tellerdata uit `meijendel.sql` en lokale MySQL blijven controleren tegen Postgres; gebruik in `VWG_M` eerst `website/vwg-m-linux-app/scripts/check_teller_migration_readiness.py`.
- Kavelbezetting via de website-CSV lokaal verwerken met `scripts/apply_website_kavelbezetting.py`; gebruik voor lopende jaren eerst de diff-route en pas `apply`/`diff-apply` uitvoeren nadat de CSV en het SQL-plan zijn gecontroleerd.

## Kwaliteit

- Smoke-tests blijven uitbreiden voor ledenroutes, archief, CMS, dashboard, SQL, Shiny en host-aliases.
- Voorkom dat dashboard, Shiny of grafiekoutputs divergeren van dezelfde dashboardbron.
- Rond wijzigingen af met relevante verificatie en commit ze daarna standaard in Git.
