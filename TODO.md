# TODO

## Nu open

### NDFF/FFV-waarnemingen — ontwerp en proefimport

- Download vogelgegevens niet opnieuw via FFV; gebruik alleen de niet-vogelgroepen.
- Vraag bronbestanden als `GeoPackage RD` aan, steeds voor één niet-vogelgroep.
  Bundel een beperkt aantal hokken tot maximaal circa 80.000 waarnemingen en
  splits een bundel zo nodig verder op. Houd rekening met maximaal 100.000
  waarnemingen per aanvraag en maximaal vijf aanvragen per uur.
- De FFV-interface kan bij `Waarnemingen` niet meerdere soortgroepen selecteren:
  alleen alle soortgroepen samen of één afzonderlijke FFV-soortgroep. Omdat
  `alle soortgroepen` ook Vogels bevat en vaak boven 100.000 uitkomt, moet de
  definitieve reeks per FFV-soortgroep en per bundel van maximaal twaalf hokken
  worden aangevraagd. Voor 26 niet-vogelgroepen en drie ruimtelijke bundels is
  de voorlopige basisraming 78 unieke aanvragen. De eerdere raming van circa 23
  aanvragen is daardoor niet meer geldig; bepaal het uiteindelijke aantal uit
  de feitelijke resultaataantallen en benodigde extra splitsingen.
- Aanvraagstand 15 augustus 2026, eerste uurreeks: Eencelligen is voor alle 34
  hokken afgedekt in drie ruimtelijke bundels; bundel 2 is door de eenmalige
  e-mailbevestigingsstap dubbel geleverd maar bevat in beide bestanden exact
  dezelfde 57 `Identiteit`-waarden. Geleedpotigen (overig) bundel 1 is afgedekt;
  begin de volgende uurreeks met bundels 2 en 3. Er zijn vijf succesvolle
  aanvragen gedaan en de FFV-uurlimiet is daarna bevestigd.
- Beperk alle definitieve aanvragen tot en met 31 december 2025. Gebruik de
  Amfibieën-proef met eindjaar 2026 alleen voor schema- en kwaliteitscontrole en
  vraag die selectie opnieuw aan voor de definitieve reeks.
- De proeflevering `Amfibieën`, hok `83-461`, periode `1950-2026`, is
  gevalideerd: schema, CRS, bronvelden en geometrieën zijn bruikbaar, maar
  taxoncode ontbreekt en vervaagde/grote geometrieën vereisen een ruimtelijke
  kwaliteitsklasse. Gebruik de proef niet als definitieve levering.
- Leg daarna de definitieve mapping vast van alle FFV-soortgroepen naar de
  afgesproken hoofdtabellen: insecten, mossen, korstmossen, vaatplanten,
  schimmels, amfibieën/reptielen, zoogdieren, waterorganismen en overige
  ongewervelden.
- Gebruik voor de planning 34 kilometerhokken die de actuele kavelpolygonen
  raken. Controleer voor iedere aanvraag het actuele FFV-resultaataantal; voer
  niet blind een vaste bundeling uit. Tel de reeds verzonden Amfibieën-proef voor
  hok 83-461 niet als volledige dekking van dat hok.
- Ontwerp per hoofdgroep een eigen waarnemingstabel plus een reproduceerbare
  koppeling naar `plots`; ondersteun meerdere kavelkoppelingen bij overlappende
  NDFF-vlakken en bewaar overlapoppervlak/-aandeel.
- Rond eerst alle aanvragen af; bouw daarna één geïntegreerde stagingdataset en
  ontdubbel primair op `Identiteit`. Test met een overlappende herdownload of die
  waarde tussen leveringen stabiel blijft en leg een conservatieve fallback voor
  twijfelgevallen vast.
- Filter de database-import tegen één geversioneerde SOVON-plotlaag. Neem
  records zonder plotintersectie niet op in de database, maar registreer ze in
  de uitsluitingsaudit. Behandel vervaagde, grote en meerplot-geometrieën niet
  automatisch als aanwezigheid per geraakt plot.
- Werk het voorgestelde NDFF-schema uit en toets het lokaal zonder import:
  `ndff_import`, `ndff_waarneming_register`, hoofdgroeptabellen,
  `ndff_import_record`, `ndff_waarneming_geometrie`,
  `ndff_waarneming_plot`, `ndff_vervaagde_waarneming`,
  `ndff_gebiedswaarneming` en eventueel `ndff_onzekere_plot_overlap`.
- Bepaal pas op de geïntegreerde dataset of een dominante-overlapregel
  verantwoord is. Test als startpunt 90% overlap plus centroid in hetzelfde plot,
  rapporteer aantallen/grensgevallen en laat de regel inhoudelijk goedkeuren
  voordat meerplot-geometrieën als reguliere plotwaarneming worden toegelaten.
- Ontwerp een gedeelde importadministratie met selectie, SHA-256, peildatum,
  bronvermelding, recordtellingen, idempotente herimport en herkenbare
  correctie-/verwijderstatus.
- Voer pas na inhoudelijke goedkeuring van schema, mapping en proefresultaat een
  import in de levende MySQL-database uit. Tot dat moment blijven de downloads
  losse bronbestanden en worden `meijendel.sql`, dashboard, Shiny en productie
  niet gewijzigd.

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
