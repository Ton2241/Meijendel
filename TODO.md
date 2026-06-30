# TODO

## Nu open

- Archiefmodule afronden: aparte uploadpagina, `.doc`-support, PDF-/documentindexering, full-text search, categoriepagina's, uploadrechten vanaf bestuurslidniveau en duidelijke foutafhandeling.
- Verifiëren dat archiefdocumenten doorzoekbaar zijn na upload en na herindexering.
- Archiefupload testen met grote bestanden tot 100 MB.
- Nieuws/CMS na de wijzigingen van 2026-06-30 nog handmatig end-to-end testen met ingelogde redacteur: concept maken, afbeelding uploaden, preview controleren, publiceren, en resultaat controleren op startpagina, `/nieuws/index.asp` en detailpagina.
- Leden/contentbeheer na de wijzigingen van 2026-06-30 handmatig end-to-end testen met een gewoon niveau-1 telleraccount: ledenpagina met actuele kavels/routes controleren, Contentbeheer openen, alleen `Kavels` zien, alleen eigen kavel(s) zien, kaveltekst wijzigen/publiceren en publieke kavelpagina controleren.
- Smoke-test uitbreiden met controles voor nieuwsvolgorde en nieuwsoverzicht: nieuwste item bovenaan, korte tekstsamenvatting zichtbaar, geen begin-afbeelding in de overzichtskaart.
- Smoke-test uitbreiden met controles voor de Vogelrichtlijn-groep: `/groepen/vogelrichtlijn.asp` geeft 200, bevat de vaste tekst en soortenlijst, en `/groepen/grafiek/vogelrichtlijn.svg` geeft `image/svg+xml`.
- Ingelogde CMS-test uitvoeren voor `Contentbeheer > Vaste Pagina's > Groepen > Vogelrichtlijn`: concept opslaan, preview controleren, publiceren en publieke pagina controleren.

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
- Historische kavel-/tellerdata uit `Meijendel.sql` en lokale MySQL blijven controleren tegen Postgres.
- Later procedure bouwen om relevante Postgres-kavel/tellergegevens terug te synchroniseren naar de lokale live MySQL-omgeving.

## Kwaliteit

- Smoke-tests blijven uitbreiden voor ledenroutes, archief, CMS, dashboard, SQL, Shiny en host-aliases.
- Voorkom dat dashboard, Shiny of grafiekoutputs divergeren van dezelfde dashboardbron.
- Rond wijzigingen af met relevante verificatie en commit ze daarna standaard in Git.
- Recent uitgevoerd voor nieuws/CMS: editor-preview-overlap opgelost, afbeeldinguploads hersteld, publiceren hersteld, nieuwstitels in lijsten gecorrigeerd, nieuwste nieuwsitems bovenaan gesorteerd en `/nieuws/index.asp` omgezet naar korte tekstsamenvattingen met `Lees verder`.
- Recent uitgevoerd voor leden/contentbeheer: beperkte Contentbeheer-toegang voor actuele BMP-/wintertellers toegevoegd, gewone leden zien daar alleen eigen kavelteksten, en de ledenpagina toont actuele BMP-, winter- en PTT-toewijzingen uit dezelfde bron als de ledenadministratie.
- Recent uitgevoerd voor Vogelrichtlijn/groepen: dashboardgroep `Vogelrichtlijn` toegevoegd aan `Groepen > Lijsten`, `Kenmerken` gebruikt één tegel `Lijsten`, websitegroep is hernoemd naar `Rode, Oranje en Vogelrichtlijn lijst groepen`, subpagina `/groepen/vogelrichtlijn.asp` toont grafiek/soorten/tekst, en `groups:vogelrichtlijn` is beschikbaar in Contentbeheer.
