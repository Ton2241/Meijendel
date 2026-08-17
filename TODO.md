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
- Aanvraagstand 17 augustus 2026: Eencelligen, Geleedpotigen (overig), Insecten
  (overig), Kevers, Amfibieën, Dagvlinders en Korstmossen zijn voor alle 34
  hokken afgedekt en gevalideerd. Ook Kranswieren, wieren en algen en
  Kreeftachtigen, Libellen, Microvlinders, Mossen, Nachtvlinders,
  Ongewervelden (overig), Reptielen, Schimmels, Snavelinsecten en Spinachtigen
  zijn nu voor alle drie bundels afgedekt en gevalideerd. Ook Sprinkhanen en
  krekels, Vaatplanten, Vissen, Vleermuizen, Vliegen en muggen en
  Vliesvleugeligen en Weekdieren zijn nu volledig afgedekt en gevalideerd.
  Weekdieren bundels 1, 2 en 3 bevatten respectievelijk 7.117, 3.845 en 3.045
  records. Ook Zoogdieren (overig) is voor alle drie bundels afgedekt en
  gevalideerd, met respectievelijk 19.082, 9.538 en 12.985 records. Daarmee zijn
  alle 26 niet-vogelgroepen voor alle 34 hokken compleet en gevalideerd. De
  aanvraagfase is afgerond. De geïntegreerde, ontdubbelde stagingdataset is op
  17 augustus 2026 gebouwd en gevalideerd: 886.762 fysieke bronrecords leveren
  810.830 unieke `Identiteit`-waarden op; 75.932 extra exportvoorkomens zijn
  verwijderd zonder verlies van herkomst. Er zijn geen echte inhouds- of
  geometrieconflicten. Zie `docs/NDFF_STAGINGDATASET.md`.
  Eencelligen-bundel 2, Geleedpotigen-bundel 3 en Insecten-bundel 1 zijn door
  vertraagde e-mailbevestigingen elk dubbel geleverd. De paren bevatten
  respectievelijk exact dezelfde 57, 75 en 702 `Identiteit`-waarden en gelden
  inhoudelijk eenmaal. Controleer daarom na iedere verzending eerst de pagina
  én Gmail en herhaal een aanvraag niet zolang de bevestiging nog vertraagd kan
  zijn. Archiveer een NDFF-bevestiging pas uit de Gmail-inbox nadat de
  selectie-URL is gecontroleerd en het bijbehorende GeoPackage is gedownload en
  gevalideerd; verplaats deze berichten niet naar de prullenbak.
- Beperk alle definitieve aanvragen tot en met 31 december 2025. Gebruik de
  Amfibieën-proef met eindjaar 2026 alleen voor schema- en kwaliteitscontrole en
  vraag die selectie opnieuw aan voor de definitieve reeks.
- De proeflevering `Amfibieën`, hok `83-461`, periode `1950-2026`, is
  gevalideerd: schema, CRS, bronvelden en geometrieën zijn bruikbaar, maar
  taxoncode ontbreekt en vervaagde/grote geometrieën vereisen een ruimtelijke
  kwaliteitsklasse. Gebruik de proef niet als definitieve levering.
- Leg daarna de definitieve één-op-éénmapping vast van ieder FFV-soortgroeplabel
  naar een eigen tabel `ndff_<soortgroep>` met een genormaliseerde ASCII-naam in
  `snake_case`.
- Gebruik voor de planning 34 kilometerhokken die de actuele kavelpolygonen
  raken. Controleer voor iedere aanvraag het actuele FFV-resultaataantal; voer
  niet blind een vaste bundeling uit. Tel de reeds verzonden Amfibieën-proef voor
  hok 83-461 niet als volledige dekking van dat hok.
- Ontwerp per FFV-soortgroep een eigen `ndff_<soortgroep>`-waarnemingstabel plus
  een reproduceerbare koppeling naar `plots`; ondersteun meerdere
  kavelkoppelingen bij overlappende
  NDFF-vlakken en bewaar overlapoppervlak/-aandeel.
- Afgerond: alle aanvragen zijn geïntegreerd en primair op `Identiteit`
  ontdubbeld. `Identiteit` bleek stabiel. Bij 74.896 extra bronvoorkomens
  verschilt uitsluitend het exportcontextveld `Hoknummer`; alle overige velden
  en de geometrie zijn gelijk. Ieder fysiek voorkomen blijft controleerbaar in
  de herkomstlaag; eventuele toekomstige echte conflicten worden apart
  geregistreerd en nooit stil samengevoegd.
- Maak vóór de import een afzonderlijke tabel `ndff_soorten`; wijzig de
  vogelgerichte tabel `soorten` niet. Leg de taxonomische vertaling naar
  `pq_vegetatie_taxon.SRTNUM` vast in een aparte, controleerbare vertaaltabel.
- Onderzoek daarna binnen de geïntegreerde stagingdataset of NDFF-vaatplanten
  dezelfde bronopnamen bevatten als de bestaande PQ-waarnemingen. Selecteer
  kandidaten op bronhouder/protocol en vergelijk per opname datum, afstand,
  taxon, volledige soortenlijst en waar mogelijk bedekking. Registreer de
  uitkomst in `ndff_pq_koppeling` als `exact`,
  `waarschijnlijk_dezelfde_opname`, `mogelijk`, `onafhankelijk` of
  `niet_beoordeelbaar`; valideer per klasse een handmatige steekproef. Behoud
  beide bronrecords, maar voorkom dat een bevestigde gedeelde opname in analyses
  dubbel als onafhankelijke waarneming meetelt.
- Filter de database-import tegen één geversioneerde SOVON-plotlaag. Neem
  records zonder plotintersectie niet op in de database, maar registreer ze in
  de uitsluitingsaudit. Behandel vervaagde, grote en meerplot-geometrieën niet
  automatisch als aanwezigheid per geraakt plot.
- Werk het voorgestelde NDFF-schema uit en toets het lokaal zonder import:
  `ndff_import`, `ndff_waarneming_register`, de tabellen per FFV-soortgroep,
  `ndff_import_record`, `ndff_waarneming_geometrie`,
  `ndff_waarneming_plot`, `ndff_vervaagde_waarneming`,
  `ndff_gebiedswaarneming` en eventueel `ndff_onzekere_plot_overlap`.
- Bewaar per waarneming zowel een afzonderlijke vervagingsstatus als het
  vervagingsniveau en behoud de ruwe FFV-waarde. Bereken het bruikbare aandeel
  voor SOVON-plotkoppeling pas afgeleid per soort; veronderstel niet dat alle
  records van één soort dezelfde vervaging hebben.
- Voer na voltooiing van alle downloads op de geïntegreerde stagingdataset een
  beslisanalyse uit voordat vervaagde records worden toegelaten of uitgesloten.
  Rapporteer per soortgroep, soort en tijdvak de vervagingsverdeling,
  vaststellings-/telmethode, protocol, bronhouder, ontbrekende methodevelden en
  methodewisselingen. Classificeer de gegevens waar aantoonbaar mogelijk als
  eenmalige melding, periodieke niet-gestandaardiseerde reeks of structurele
  protocolreeks. Beoordeel waarnemerskwaliteit alleen met expliciete
  validatie-/kwaliteitsvelden; registreer `niet_beoordeelbaar` als zulke
  informatie ontbreekt. Leg daarna per analysetype het definitieve besluit en
  de onderbouwing vast.
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
