# TODO

## Nu open

### Functionele vogelgroepen — inhoudelijke afronding fase B

- Beoordeel de 1.330 verplichte soort-traitcellen uit `v_trait_gap_v1`: 433
  hebben al broninformatie voor context- of inhoudelijke review; voor 897
  ontbreekt nog een directe bron voor de vereiste doelcontext.
- Prioriteer eerst de traits die het primaire groepslidmaatschap bepalen:
  prooi- en foerageeraandelen, grond-/holtebroedaandeel en aandeel lange trek.
- Gebruik soortspecifieke Nederlandse bronnen, Sovon/Vogelatlas, trekatlassen,
  handboeken en gedocumenteerde Meijendel-expertkennis. Registreer elke lokale
  conclusie als afzonderlijke bronwaarde; overschrijf mondiale bronwaarden niet.
- Beoordeel daarna nesthoogte, foerageermethode/-substraat, winterregio en
  holtetype/-oorsprong. Leg onzekerheid expliciet vast en laat onbekend `unknown`.
- Los vóór fase C minimaal `F-Mud`, de zeven afwijkende soortnamen en de dubbele
  vogeltypering Orpheusspotvogel/Braamsluiper op in de gecontroleerde laag zonder
  legacy stilzwijgend te overschrijven.
- Laat het uiteindelijke gaprapport inhoudelijk accorderen. Start fase C pas als
  de verplichte waarden voldoende zijn voor de vastgestelde minimumgroottes.

Technisch gereed in fase B: live-driftcontrole, lokale back-up, nieuwe tabellen en
constraints, 95-soortenscope, drie externe imports met provenance en SHA,
legacyimport, expliciete unknown-matrix en automatische validatiechecks.

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
