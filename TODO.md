# TODO

## Nu open

### NDFF ticket 58679 - beveiligde levering

- Wacht op de gezipte shapefile, Excel en standaardcitatie van de NDFF.
- Sla de ongewijzigde bestanden op in
  `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/original`.
- Maak en controleer vóór inhoudelijk gebruik het ontvangstmanifest met
  `gis/scripts/validate_ndff_secure_delivery.py`.
- Vergelijk de NDFF-identiteiten met de open staging; overschrijf de open
  geometrie niet en bewaar de exacte geometrie uitsluitend in de beveiligde
  lokale laag.
- Koppel exact aan de 55 geversioneerde SOVON-plots en classificeer iedere
  waarneming als `single`, `multiple` of `outside`; forceer geen keuze bij de 77
  bekende overlappende plotparen.
- Rond daarna de PQ-overlapaudit en toelatingsbeslissing per analysetype af.
  Ken iedere NDFF-waarneming een expliciete PQ-status en beslisregelversie toe;
  een ontbrekende of `niet_beoordeelbaar` status blijft geblokkeerd waar
  onafhankelijkheid relevant is.
- Voeg aan iedere latere NDFF-analyse een verplichte controletabel toe met
  aantallen per PQ-status, uitgesloten records en beslisregelversie. Alleen
  `onafhankelijk` en `niet_van_toepassing` mogen zelfstandig meetellen.
- Beoordeel en voer `gis/database/ndff_secure_schema.sql` pas uit na validatie
  van het werkelijke leveringsschema; wijzig de life-database nog niet.

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

- Beoordeel de aangewezen MySQL-9.5-rollback uiterlijk op 25 augustus 2026.
  Verwijder container, image en versiegescheiden datamap pas nadat een verse
  back-up van de actieve 9.7.1-productie checksumgeldig en proefhersteld is en
  de observatieperiode zonder MySQL-regressie is afgerond.
- Container-CVE's blijven wekelijks monitoren. De remediatie van 18 augustus
  2026 is afgerond: beide MySQL-images en de minimale Shiny-runtime zijn 0
  `CRITICAL`/0 `HIGH`. Blijf nieuwe kandidaten vóór activering exact scannen en
  doorloop opnieuw de geïsoleerde test, preflight en rooktest.
- Bij elke functionele wijziging `handleiding_beheer.md` en auditlogging bijwerken waar relevant.
- Bij verzoeken om wijzigingen aan `app.vwg-m.nl` of de VPS-site: lokaal aanpassen, committen, naar de VPS deployen en productie verifiëren.
- Bij brede deploys controleren dat `app/static/uploads/cms` op de VPS behouden blijft; dit is runtime-uploaddata en mag niet door een schone rsync worden verwijderd.
- DNS-cutover voorbereiden en pas uitvoeren op het afgesproken moment: `www.vwg-m.nl` wordt hoofdhost, `app.vwg-m.nl` blijft alias.
- Caddyconfig na DNS-cutover valideren voor `www.vwg-m.nl`, `vwg-m.nl` en `app.vwg-m.nl`.
- NAS-pullscript later bijwerken als de NAS-kopie expliciet de nieuwe canonieke SQL-check moet afdwingen.
- Restoreprocedure testen op een lege server of tijdelijke VPS.
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
