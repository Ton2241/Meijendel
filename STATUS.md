# Status Meijendel

Laatste update: 16 juli 2026

Dit document bevat actuele status, resterende risico's en logische vervolgstappen voor Meijendel-onderdelen die ook de VWG-M-site raken. Stabiele architectuur staat in `ARCHITECTURE.md`; open werk staat in `TODO.md`.

## Repositoryhygiëne

Gereed:

- Gegenereerde R- en Sass-bestanden onder `app_cache/` worden niet meer door Git gevolgd en zijn projectbreed genegeerd.
- De Meijendel-deploypreflight controleert na de lokale Shiny/dashboard-pariteitscontrole opnieuw dat de werkboom schoon is.
- Projectbrede begin- en eindcontrole vereist schone werkbomen, actuele upstreams en opruiming van aantoonbaar verouderde worktreeverwijzingen in alle drie repositories.

## SQL-naam en historische PWA

Gereed:

- De lokale canonieke SQL-dump heet `meijendel.sql`.
- Scripts en documentatie in deze repo gebruiken lokaal `meijendel.sql`; het productiepad op de VPS blijft `/srv/vwgm/data/Meijendel.sql`.
- De historische map `pwa_ledenadministratie/` is verwijderd uit de Meijendel-repo.

## Dashboard, websitegrafieken en Shiny

Gereed:

- Het PQ-vegetatiemeetnet staat in de levende MySQL-database in de `pq_`-tabellen. Historische RD-geometrie blijft per opname bewaard; de repositorydump `meijendel.sql` is hiervoor niet aangepast.
- `pq_plot_jaar_vegetatie` levert uitsluitend daadwerkelijk gemeten plot-jaren en voedt vegetatiecovariaten in Shiny en het blok `Vegetatiemeetnet (PQ)` onder `Plots-kenmerken` in het dashboard.
- De publieke website gebruikt alleen de veilige view `website_plot_vegetatie_jaar`; ruwe taxa, PQ-nummers en historische coördinaten blijven intern.
- De Meijendel-productiedeploy maakt vóór iedere MySQL-import een volledige VPS-databaseback-up, valideert na import de PQ-tabellen/view en historische geometrie en herstelt de back-up automatisch als import of validatie faalt.
- `R/check_dashboard_website_parity.R` controleert de gegenereerde Groepen-output voor websitegebruik: verplichte CSV's, kolommen, chart-id's, numerieke waarden, jaarbereik en aanwezigheid van de Meijendel-serie.
- `deploy/update_en_deploy_meijendel.sh` voert deze check automatisch uit na `R/build_groepen_grafieken_dashboard_csv.R` en vóór deploy.
- Websitegrafieken blijven daarmee afgeleid van `groepen_grafieken/groep_dichtheid.csv`; losse websiteberekening blijft uitgesloten.
- `R/check_shiny_dashboard_parity.R` controleert de Shiny-berekeningskern tegen de dashboard-CSV `trim_msi_evg/msi_per_groep_per_jaar.csv`.
- Dashboard-MSI is canoniek voor publicatie en websiteafleiding. Shiny volgt daarom dezelfde MSI-definitie: pre/post-1984 TRIM-modellen, brugfactor op basis van 1981-1983 versus 1984-1986, groeps-MSI op `index_gebrugged`, en `robuust` op soorten met een bruikbare pre- en postreeks.
- `shiny_meijendel/helpers.R` is gelijkgetrokken met de dashboardlogica voor de Shiny-groep-MSI.
- `deploy/update_en_deploy_meijendel.sh` en `deploy/deploy_meijendel_vps.sh` voeren `R/check_shiny_dashboard_parity.R` nu als harde deploygate uit over 1958-2025 voordat Shiny/de dashboardomgeving naar de VPS gaat.
- De paritycontrole tussen Shiny en dashboard is actueel groen.
- De Shiny-deploycontrole toont voortaan ook containerstatus en resourcegebruik.

Open:

- Shiny blijft relatief zwaar doordat de app TRIM-modellen interactief kan draaien; gebruik blijft daarom bedoeld voor redacteuren/beheerders en niet als publieke rekenservice.

## Soortpagina's

Gereed:

- Publieke vogelsoortdetailpagina's combineren legacy/CMS-teksten, vooraf gegenereerde Meijendel-cijfers en read-only Meijendel-kenmerkdata.
- De kopknoppen verwijzen naar `Beschrijving`, `Voorkomen` en alleen bij beschikbare data naar `Kenmerken`.
- Het blok `Vogelkenmerken` leest bestaande Meijendel-tabellen voor ecologische vogelgroepen, Rode/Oranje Lijst, Vogelrichtlijn en soortkenmerken, maar schrijft niets terug naar Meijendel of CMS.
- Kenmerken worden bewust als doorlopende tekst getoond, zonder technische veldcodes of waarde-labels.

Resterende risico's:

- Er is nog geen uitgebreide visuele regressiecheck over meerdere soorten en viewports.

Aanbevolen volgende stap:

- Voer een visuele regressiecheck uit over meerdere soorten en viewports.

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

- Voer een ingelogde redactiecheck uit waarin een redacteur een nieuwsbericht met afbeelding maakt, publiceert en terugziet op startpagina, nieuwsoverzicht en detailpagina.

## Leden en contentbeheer

Gereed:

- Leden met een actuele BMP- of winterkavelkoppeling in `app.teller_assignments` voor het lopende jaar krijgen beperkte toegang tot `Contentbeheer`.
- Beperkte leden zien binnen Contentbeheer alleen de module `Kavels` en daarna alleen de kavelteksten waarvoor zij in het lopende jaar teller zijn.
- Niveau 4 en 5 behouden volledige toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina `Mijn gegevens en rechten` toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie, met fallback naar oude app- of legacyvelden.
- Kavelbezetting kan lokaal vanuit de beveiligde website-CSV-export worden gecontroleerd en verwerkt met `scripts/apply_website_kavelbezetting.py`: volledige jaarroute (`dry-run`, `plan`, `apply`) en lopend-jaar-diffroute (`diff-run`, `diff-plan`, `diff-apply`).

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
- Er is nog geen ingelogde CMS-publicatietest voor deze vaste pagina.

Aanbevolen volgende stap:

- Voer een ingelogde CMS-publicatietest uit voor de vaste pagina `Vogelrichtlijn`.
