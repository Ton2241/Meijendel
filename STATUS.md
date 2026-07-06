# Status Meijendel

Laatste update: 30 juni 2026

Dit document bevat actuele status, resterende risico's en logische vervolgstappen voor Meijendel-onderdelen die ook de VWG-M-site raken. Stabiele architectuur staat in `ARCHITECTURE.md`; open werk staat in `TODO.md`.

## SQL-naam en historische PWA

Gereed:

- De lokale canonieke SQL-dump heet `meijendel.sql`.
- Scripts en documentatie in deze repo gebruiken lokaal `meijendel.sql`; het productiepad op de VPS blijft `/srv/vwgm/data/Meijendel.sql`.
- De historische map `pwa_ledenadministratie/` is verwijderd uit de Meijendel-repo.

## Soortpagina's

Gereed:

- Publieke vogelsoortdetailpagina's combineren legacy/CMS-teksten, vooraf gegenereerde Meijendel-cijfers en read-only Meijendel-kenmerkdata.
- De kopknoppen verwijzen naar `Beschrijving`, `Voorkomen` en alleen bij beschikbare data naar `Kenmerken`.
- Het blok `Vogelkenmerken` leest bestaande Meijendel-tabellen voor ecologische vogelgroepen, Rode/Oranje Lijst, Vogelrichtlijn en soortkenmerken, maar schrijft niets terug naar Meijendel of CMS.
- Kenmerken worden bewust als doorlopende tekst getoond, zonder technische veldcodes of waarde-labels.

Resterende risico's:

- Er is nog geen uitgebreide visuele regressiecheck over meerdere soorten en viewports.
- De algemene smoke-test controleert het kenmerkenblok nog niet expliciet.

Aanbevolen volgende stap:

- Voeg gerichte smoke-testchecks toe voor `/soorten/vogel.asp?id=227#kenmerken` of de HTML-inhoud daarvan, plus een soort zonder kenmerken.

## Nieuws en CMS

Gereed:

- Nieuwsitems worden lokaal in de FastAPI/Jinja-site aangepast, gecommit en daarna naar de VPS gedeployed.
- De nieuwseditor ondersteunt afbeeldinguploads vanuit een nieuwsbericht; productiebeelden zijn runtime-data onder `app/static/uploads/cms`.
- De startpagina en `/nieuws/index.asp` sorteren gepubliceerde nieuwsitems op nieuwste bovenaan. Bij gelijke publicatiedatum is de nieuwste database-id leidend.
- `/nieuws/index.asp` toont alleen een korte tekstsamenvatting zonder start-afbeeldingen; de volledige inhoud staat op de detailpagina achter `Lees verder`.
- De editor-/preview-layout is zo aangepast dat invoertekst en preview niet meer over elkaar heen vallen.

Resterende risico's:

- De ingelogde nieuwsflow is nog niet volledig geautomatiseerd getest.
- Brede deploys moeten CMS-uploads expliciet behouden.
- Archief/OCR-systemd units moeten apart op productie worden geactiveerd en gecontroleerd als die live gebruikt worden.

Aanbevolen volgende stap:

- Voeg aan de smoke-test of een aparte redactiecheck toe dat een redacteur een nieuwsbericht met afbeelding kan maken, publiceren en terugzien op startpagina, nieuwsoverzicht en detailpagina.

## Leden en contentbeheer

Gereed:

- Leden met een actuele BMP- of winterkavelkoppeling in `app.teller_assignments` voor het lopende jaar krijgen beperkte toegang tot `Contentbeheer`.
- Beperkte leden zien binnen Contentbeheer alleen de module `Kavels` en daarna alleen de kavelteksten waarvoor zij in het lopende jaar teller zijn.
- Niveau 4 en 5 behouden volledige toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina `Mijn gegevens en rechten` toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie, met fallback naar oude app- of legacyvelden.

Resterende risico's:

- De server-side checks zijn actief en de algemene smoke-test is groen.
- Er is nog geen volledige ingelogde browsertest met een gewoon telleraccount voor kaveltekst openen, wijzigen en publiceren.
- PTT-routeteksten zijn nog niet beschikbaar zolang er geen aparte route-tekstmodule of routepagina's zijn.

Aanbevolen volgende stap:

- Voer een ingelogde test uit met een niveau-1 telleraccount en controleer ledenpagina, Contentbeheer-tegel, kaveltekstlijst, bewerken/publiceren en publieke kavelpagina.

## Vogelrichtlijn en groepen

Gereed:

- De Vogelrichtlijn-groep gebruikt dezelfde `richtlijn_id = 7` bron als de Meijendel-database en het dashboard.
- Dashboardgroepen gebruiken voor `Vogelrichtlijn` dezelfde twee weergaven als andere groepen: `Dichtheid per km2` en `TRIM`.
- Websitegrafiek `vogelrichtlijn` wordt vooraf gegenereerd via `R/build_groepen_grafieken_dashboard_csv.R`.
- De publieke FastAPI/Jinja-site leest deze CSV-output via `/srv/vwgm/www/groepen_grafieken/`.
- `Contentbeheer` beheert de tekst via app-CMS-key `groups:vogelrichtlijn`.

Resterende risico's:

- De route werkt en de algemene smoke-test is groen.
- De smoke-test heeft nog geen expliciete assert voor de Vogelrichtlijnpagina/grafiek.
- Er is nog geen ingelogde CMS-publicatietest voor deze vaste pagina.

Aanbevolen volgende stap:

- Voeg gerichte smoke-testchecks toe voor `/groepen/vogelrichtlijn.asp` en `/groepen/grafiek/vogelrichtlijn.svg`.
