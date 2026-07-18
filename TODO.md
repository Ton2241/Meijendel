# TODO

## Nu open

### Functionele vogelgroepen — fase B

- Maak een verse dump van de lokale levende Meijendel-MySQL-database en herhaal
  de fase-A-audit; verklaar ieder verschil met de repositorydump voordat wordt
  gemigreerd.
- Bouw de nieuwe trait-, bron-, import-, legacy-mapping- en
  groepsdefinitietabellen naast de bestaande `soorten_kenmerken`-tabellen.
- Vul eerst de verplichte traits aan voor soorten met een bruikbare TRIM-reeks;
  ontbrekend blijft `unknown` en wordt niet als afwezigheid geïnterpreteerd.
- Prioritaire structurele hiaten bij 95 bruikbare soorten: 5 zonder
  foerageercategorie, 8 zonder adult-voedselcategorie, 7 zonder nestcategorie en
  19 zonder migratiecategorie. Controleer daarna per soort de inhoudelijke
  volledigheid van de specifieke verplichte traits.
- Importeer externe bronnen reproduceerbaar met datasetversie, licentie,
  taxonomie, bestands-SHA en omzettingsregels; voeg lokale Meijendel-/duinkennis
  als afzonderlijk onderbouwde waarde toe.
- Los vóór afleiding van groepen minimaal `F-Mud`, de zeven afwijkende
  soortnamen en de dubbele vogeltypering Orpheusspotvogel/Braamsluiper op in de
  nieuwe gecontroleerde laag; overschrijf legacy niet stilzwijgend.
- Lever na inhoudelijke review een gaprapport op waarin iedere verplichte waarde
  `approved`, `rejected` of `unknown` is. Start fase C pas als dit rapport groen
  genoeg is voor de vastgestelde minimumgroottes.

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
