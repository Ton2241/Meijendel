# TODO

## Nu open

### GBIF-vangblikken Meijendel 1953-1960

- Bevestig bij de bronhouder waarom versie 1.7 in EML en GBIF CC BY-NC 4.0
  vermeldt terwijl het datapaper CC0 noemt; hanteer tot die tijd CC BY-NC 4.0.
- Vraag correctie of duiding voor de twee occurrences onder ontbrekend event
  `Meij-05August1959pf207`.
- Stel per taxon vast over welke jaren de oorspronkelijke soortmap volledig is
  voordat een leeg sampling event als nulwaarneming wordt gebruikt.
- De volledige bronreeks is op 10 september 2026 in afzonderlijke tabellen
  geïmporteerd en alle events zijn aan de geversioneerde SOVON-plots gekoppeld.
  Laat de analyseblokkades staan totdat bovenstaande bronvragen zijn opgelost.

### NDFF ticket 58679 - beveiligde levering

- De kwaliteitsmetadata is lokaal geïmplementeerd als
  `ndff_protocol`, `ndff_protocol_mapping`, `ndff_protocol_gebruik`,
  `ndff_open_ruimtelijke_beoordeling` en `ndff_analysebesluit`. Regelversie
  `ndff-protocolkwaliteit-v1` dekt alle 54 protocolwaarden, alle 810.830
  openbare records en zowel de openbare als beveiligde protocolteksten. De
  huidige analysebesluiten laten uitsluitend positieve verspreidingscontext
  toe na ruimtelijke en PQ-toets; trend- en effectgebruik blijft geblokkeerd.
- De recordkoppeling is afgerond: alle 810.830 openbare en 14.573 beveiligde
  records hebben precies één `protocol_id`. Expliciete codes en expliciete losse
  waarnemingen zijn afzonderlijk gelabeld; geen lege waarde is als `LOS`
  geïnterpreteerd. Dit verandert de analysebesluiten niet.
- Dagvlinderprotocol `03.201` is lokaal gereconstrueerd als
  `ndff-vlinderroute-v1`. Controleer handmatig de ene ruimtelijk uitgerekte
  routefamilie (172 bezoeken); houd de 63 bezoeken zonder route buiten
  routeanalyse. De 2.891 overige routebezoeken en hun bezoek-soortmatrix zijn
  beschikbaar voor protocolgebonden analyse met zichtbare reconstructiestatus.
- De `03.201`-vliesvleugelreeks is afzonderlijk gereconstrueerd als
  `ndff-vliesvleugelroute-v1`: 217 bevestigde bezoeken, zes taxa en 937 echte
  nullen. Gebruik deze matrix als NEM-deelreeks en niet als dagvlinderbijvangst;
  controleer haar met `--audit-vliesvleugelen`.
- De vier afgeleide dagvlindertabellen horen in `Meijendel`. Controleer met
  `--audit-vlinders` dat geen oude `ndff_vlinder_*`-tabellen in
  `Meijendel_ndff_secure` achterblijven. Pas deze opslagregel ook op iedere
  volgende NEM-reconstructie toe.
- De reconstructies van `07.201`, `10.201`, `01.201`, `17.208`, `17.204`,
  `11.202`, `11.201`, `12.204` en `02.202` zijn afgerond. `11.202` omvat 21 kilometerhokken, 161 bezoeken en
  een matrix voor zes typische zeereeppaddenstoelen; 61 bezoeken buiten het
  kernseizoen en ontbrekende bezoektijd/waarnemersbekwaamheid blijven zichtbaar.
  `17.209` is als positieve sectietelling geclassificeerd, maar kan zonder
  route- en sectie-ID's niet tot native bezoeken of nullen worden
  gereconstrueerd. DAZ-BMP bevat 1.475 bevestigde bezoeken en 7.552 echte
  doelsoortnullen; de 11 mogelijke overlapsignalen met `17.209` blijven zonder
  oorspronkelijke route-/sectiesleutel onbeslist. Ga nu verder met de volgende
  NEM-reeks op basis van omvang en reconstrueerbaarheid. Ken pas nullen toe
  nadat per protocol meeteenheid, bevestigd bezoek en doelsoortenbereik
  vaststaan.
- `02.202` bevat onder `ndff-korstmos-v1` twaalf proefvlakken en 32 bezoeken.
  Gebruik de 960 bezoek-taxonregels voor presentie/occupancy; behandel de twee
  FFV-bedekkingsklassen alleen ordinaal en sluit de tien conflictcombinaties uit
  van abundantievergelijking. Vraag BLWG later alleen om oorspronkelijke
  locatie-ID's, geometrieversies en de zesdelige abundantieklasse wanneer dat
  voor een verdiepende analyse nodig blijkt.
- `02.204` bevat onder `ndff-mos-v1` zeven volledige
  kilometerhokinventarisaties en 777 inventarisatie-taxonregels. Gebruik de 423
  echte nullen alleen op kilometerhokniveau. Behandel de 21 tijdclusters niet
  als onafhankelijke bezoeken en leid geen plotnullen of lokale tijdtrend af.
  Vraag BLWG later alleen om lijst-ID's, bezoekduur en waarnemer wanneer een
  verdiepende validatie dat nodig maakt.
- `12.001` bevat onder `ndff-florbase-v1` 118 aannemelijk volledige
  kilometerhok-jaarlijsten en 65 fragmenten. Gebruik de 101.126 matrixregels
  voorlopig voor verspreidings- en inventarisatievergelijkingen; de 81.721
  nullen blijven expliciet afhankelijk van de ≥50-taxa-aanname. Vraag FLORON
  later gericht om lijst-ID, oorspronkelijke volledigheidsvlag, bezoekduur en
  gebruikte checklistversie. Deze validatie blokkeert het voorlopige gebruik
  niet.
- `12.204` bevat onder `ndff-hns-v1` 23 aannemelijk volledige
  inventarisaties en drie fragmenten. Gebruik de 16.169
  inventarisatie-taxonregels voorlopig voor verspreidings-/occupancyanalyse;
  21 herhaalde inventarisaties blijven gemarkeerd als niet bewezen
  onafhankelijk. Vraag FLORON later uitsluitend om de lijst-/waarnemer-ID's en
  het deelnemersaantal waarmee deze scheiding kan worden bevestigd; deze
  validatie blokkeert het voorlopige gebruik niet.
- `17.002` bevat onder `ndff-braakbal-v1` 37 openbare
  geometrie-jaaraggregaten en 226 positieve taxonregels. Gebruik die alleen
  voor regionale positieve samenstelling en indicatieve verandering in
  registraties. De 18 sommen van minimaal 150 blijven partij-onbekend; leid
  geen nullen, bezoeken of SOVON-plotkoppelingen af. Alleen oorspronkelijke
  partij- en nest-ID's van de Zoogdiervereniging kunnen dit later verbeteren;
  deze validatie blokkeert het voorlopige regionale gebruik niet.
- `102.002` bevat onder `ndff-tuintelling-v1` drie afgeleide
  tuinvakfamilies, 125 telperioden en 1.645 periode-soortgroep-taxonregels.
  Gebruik de 1.337 voorlopige nullen alleen binnen de 213 positief bevestigde
  soortgroeptellingen en het lokale doelbereik van 33 taxa. Gebruik deze reeks
  uitsluitend als regionale tuincontext: geen record ligt eenduidig in een
  Meijendel-SOVON-plot. Oorspronkelijke tuin-, telling- en gekozen-
  soortgroep-ID's kunnen later bij Jaarrond Tuintelling/Sovon worden
  gevalideerd, maar blokkeren dit voorlopige regionale gebruik niet.
- `102.005` bevat onder `ndff-liveatlas-v1` 64 afgeleide bezoeken, 87
  bezoek-soortgroepcombinaties en 169 uitsluitend positieve taxonuitkomsten.
  Gebruik de 12 eenduidig aan één SOVON-plot gekoppelde bezoeken alleen met de
  melding dat route, oorspronkelijk bezoek-ID en complete-lijststatus niet zijn
  meegeleverd. Leid voor geen enkel bezoek nullen af. Vraag Sovon later alleen
  om de oorspronkelijke bezoek-ID's, routes en de complete-lijstvlag per
  soortgroep; deze validatie blokkeert positieve verspreidingscontext en
  indicatieve vergelijking van geregistreerde aantallen niet.
- `102.007` bevat onder `ndff-kwartiertelling-v1` 17 afgeleide
  telintervallen, 18 interval-soortgroepcombinaties en 49 uitsluitend positieve
  taxonuitkomsten. Gebruik de 14 eenduidig aan één SOVON-plot gekoppelde
  intervallen met de melding dat route, oorspronkelijk tel-ID en het onderscheid
  tussen complete lijst en soortgerichte telling ontbreken. Leid geen nullen
  af. Vraag De Vlinderstichting later alleen om de oorspronkelijke tel-ID's,
  routes en lijsttypevlag; dit blokkeert positieve verspreidingscontext en
  indicatieve vergelijking van geregistreerde aantallen niet.
- `11.201` bevat na onderdrukking van 473 parallelle presentieregels 509
  canonieke positieve resultaten, drie vaste meetpunten en 110 bevestigde
  bezoeken. Gebruik de 2.934 bezoek-taxonregels en 977 jaarlijkse maxima via
  `ndff-bospaddenstoel-v1`; vul geen geheel negatieve bezoeken aan. Een latere
  NMV-opvraag kan oorspronkelijke meetpuntnummers, volledig doelbereik en
  ontbrekende bezoeken valideren, maar blokkeert het voorlopige gebruik niet.
- Nadat alle NDFF-protocollen technisch zijn bewerkt, downloadt de eigenaar
  opnieuw een volledig BMP/SAP-bestand. Dit bestand moet behalve de
  vogeltellingen ook de tijdens ieder bezoek geregistreerde zoogdierbijvangst
  bevatten en, indien beschikbaar, de oorspronkelijke locaties. Vergelijk die
  primaire BMP/SAP-regels met `ndff_daz_bmp_*` en vervang daarna de huidige
  voorzichtige datum-/plotreconstructie door de oorspronkelijke koppeling per
  telling. Vul dan ook deelnemende bezoeken zonder zoogdierwaarneming aan,
  herbereken echte nullen en beoordeel de 1.026 meervoudige en 6.473 nu niet
  koppelbare NDFF-records opnieuw. Behoud NDFF als secundaire bron en voer deze
  verbetering pas uit na bronhash, schema-audit, overlapcontrole en een nieuwe
  reconstructieversie.
- Behandel `12.202` niet als nieuw reconstructietraject naast de provinciale
  PQ-reeks: de provincie blijft de gezaghebbende bron.
- Afgerond op 13 september 2026: de resterende NEM-batch `03.203`, `11.204`,
  `13.201` en `17.207` staat in dertien openbare `Meijendel.ndff_*`-tabellen en
  is reproduceerbaar controleerbaar met `--audit-resterende-nem`. Alle 633
  bronrecords zijn gekoppeld; er zijn geen echte nullen afgeleid. `12.202` is
  door een vaste auditpoort buiten een afzonderlijke NDFF-reconstructie
  gehouden.

- Ontvangst is afgerond: het ongewijzigde GeoPackage, de standaardcitatie en de
  groene ontvangst-/analysemanifesten staan onder
  `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679`.
- De afgescheiden lokale bronregistratie is afgerond in
  `Meijendel_ndff_secure`: 14.573 records en 158 taxa. Van deze records zijn
  8.494 uitsluitend voor positieve verspreidingscontext toegelaten; 1.274 zijn
  gelabeld als wachtend op volledige brondata en blijven buiten trendanalyse.
  De beveiligde import heeft de bestaande life-tabellen niet gewijzigd. De
  openbare FFV- en GBIF-bronnen zijn later wel in nieuwe brontabellen van
  `Meijendel` opgenomen; vogel- en provinciale PQ-tabellen bleven ongewijzigd.
- De open koppeling via `Identiteit = SHA-256(obs_uri)` en de koppeling aan de
  55 geversioneerde SOVON-plots zijn uitgevoerd. Behoud de afgeleide
  recordstatussen en forceer geen plot bij `multiple`, `outside` of
  `single_deels`.
- Beoordeel per soortgroep welke van de 8.494 voorlopige
  verspreidingskandidaten wetenschappelijk nuttig genoeg zijn voor verdere
  analyse; zij zijn niet trendklaar.
- Baseer de latere aanvullende bronvalidatie niet uitsluitend op de 1.274 kandidaten uit
  de beveiligde 191-soortenlevering. Over de volledige canonieke laag zijn
  66.125 unieke records kandidaat voor minstens één gebruikstype buiten `V`.
  Behandel de oude 1.274 uitsluitend als beveiligde deelsom. Rond eerst de
  NEM-reconstructies af. Vraag daarna alleen nog ontbrekende sleutels op bij:
  De Vlinderstichting (`03.001` en zo nodig `07.201`), FLORON/Dunea (`12.211`), RAVON (`01.201`), Zoogdiervereniging
  (zo nodig nadere validatie `17.208` en herkomst `17.201`), BLWG (`02.202`) en NMV
  (`11.201`). Inventarisatieprotocollen van FLORON, ANEMOON en EIS volgen
  daarna voor verspreidings- en detectieanalyse; zij zijn niet automatisch
  kandidaten voor aantalsontwikkeling.
- Bepaal per protocol pas na de reconstructiepoging de kleinst noodzakelijke opvraag. Vraag zo nodig:
  stabiele telobject-ID's en geometrieversies, alle uitgevoerde bezoeken,
  complete resultaten waaruit niet-detecties kunnen worden afgeleid, de
  bezoekgegevens die protocolgeldigheid bepalen en methodewijzigingen. Vraag
  geplande of uitgevallen bezoeken, apparatuur en aanvullende metadata alleen
  wanneer het betreffende protocol of analysemodel die werkelijk nodig heeft.
  Los bij LMF-a expliciet de openbare drie-/vierjarige cyclusinconsistentie op.
- Leg de gereconstrueerde native surveystructuur vast en koppel die daarna geversioneerd
  aan SOVON-plots. Splits routes of gebieden niet over plots zonder
  sectiegeometrie én sectie-inspanning. Houd per protocol een eigen
  reconstructieversie en onzekerheidsstatus bij.
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
- Behoud uitsluitend de beveiligde levering en drie veilige views afgescheiden
  in `Meijendel_ndff_secure`; openbare bronregistraties horen in `Meijendel`.
  Het localhost-only Shiny-login-path is ingericht en getest; verleen geen
  bredere rechten op het beveiligde schema.
- De veilige hotspotanalyse per SOVON-plot en vijf tijdvakken is lokaal
  uitgevoerd. Beoordeel de zes meerbronnen-signalen in 2015-2025 inhoudelijk op
  karakteristieke duinsoorten en koppel pas daarna een geversioneerde beheerlaag.
  Houd iedere ecologische kaart gekoppeld aan de brondekkingskaart en gebruik
  NDFF-verandering uitsluitend als registratiecontext, niet als trend.

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
