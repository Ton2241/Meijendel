# Projectinstructies Meijendel

Hou rekening met de volgende IT-infrastructuur:

1. iMac M1 8GB Tahoe 26.4 of later Opstart Macintosh HD
2. Samsung Portable SSD T7 2 terrabyte
3. NAS DS225+ met 6 GB geheugen
4. MySQL 9.5.0

Antwoord in het Nederlands, compact en praktisch.

Werk standaard op de lokale iMac M1 in mijn thuismap/projectmap. Ga ervan uit dat projecten lokaal staan tenzij ik expliciet zeg dat bestanden op de Samsung Portable SSD T7, op de NAS DS225+ of op de VPS staan. Vraag eerst om bevestiging voordat je paden op externe opslag of NAS gebruikt. Gebruik voor de NAS standaard Synology DSM via de browser.

Bij codewerk:
- onderzoek eerst kort de bestaande code en volg de bestaande patronen, naamgeving en structuur
- zoek eerst naar bestaande helpers of utilities voordat je nieuwe toevoegt
- lever standaard een werkende wijziging op in plaats van alleen een plan, tenzij ik expliciet om analyse of brainstorm vraag
- creëer geen nieuwe bestanden in de repo tenzij ik daar expliciet om vraag; uitzondering: bestanden die noodzakelijk zijn om bij een crash van de VPS de volledige omgeving op `app.vwg-m.nl` te herstellen mogen wel in de repo worden gezet
- wees voorzichtig met bestaande niet-door-jou-gemaakte wijzigingen en draai die nooit terug zonder expliciete instructie
- benoem aannames, risico's en blockers kort en concreet
- houd wijzigingen zo klein mogelijk, maar wel volledig genoeg om het probleem echt op te lossen
- voorkom regressies: laat bij wijzigingen aan dashboard, Shiny-app of VPS-website geen bestaande onderdelen, tekstblokken, grafieken, filters of toelichtingen verdwijnen tenzij daar expliciet om is gevraagd; controleer relevante bestaande UI-elementen na afloop
- voeg tests of verificatiestappen toe als dat logisch is; als je iets niet kon verifiëren, zeg dat expliciet
- commit afgeronde wijzigingen standaard in Git met een korte, beschrijvende commitmelding, tenzij ik expliciet vraag om niet te committen
- beheer vanaf nu de volledige Git-repository als onderdeel van het werk: controleer `git status`, houd wijzigingen logisch gegroepeerd, commit afgeronde wijzigingen, en laat niet-door-jou-gemaakte wijzigingen ongemoeid tenzij ik expliciet anders vraag
- als ik vraag een wijziging door te voeren voor `app.vwg-m.nl` of de VPS-site, voer die wijziging zowel lokaal als op de VPS door, inclusief passende verificatie na deploy

Bij communicatie:
- wees direct, feitelijk en beknopt
- geef bij grotere wijzigingen een korte samenvatting van wat is aangepast en hoe het is gecontroleerd
- stel alleen vragen als dat echt nodig is om veilig verder te kunnen

MySQL:
- gebruik voor lokale database-acties standaard de lokale MySQL-client
- voor inloggen is `-u root -p` nodig

GIS / R-spatial:
- ga ervan uit dat de lokale iMac native Apple Silicon draait: `uname -m` = `arm64` en R `R.version$arch` = `aarch64`
- gebruik geen Intel/Rosetta-R, oude Intel-builds of oude QGIS-bundels als basis voor nieuw spatial werk
- ga ervan uit dat Homebrew en de spatial libraries `gdal`, `geos`, `proj`, `sqlite`, `udunits`, `netcdf` en `cmake` lokaal beschikbaar zijn
- gebruik voor R-spatial standaard actuele Apple Silicon R/RStudio met o.a. `sf`, `terra`, `stars`, `exactextractr`, `tmap`, `leaflet`, `mapview`, `osmdata`, `tidyverse`, `DBI`, `RPostgres` en `duckdb`
- verifieer spatial wijzigingen waar logisch met een kleine `sf`-test (`st_read(system.file("shape/nc.shp", package="sf"))`) en/of `terra`-test (`rast(nrows=100, ncols=100)`)
- werk script-based en reproduceerbaar; vermijd handmatige QGIS -> Excel -> R workflows en analyses buiten scripts
- gebruik GeoPackage (`.gpkg`) als standaard vectorformaat; vermijd shapefiles als hoofdformaat vanwege kolomnaam-, encoding- en meerbestandsproblemen
- overweeg PostGIS als volgende stap voor centrale ruimtelijke opslag en queries; koppel waar relevant met MySQL, Shiny/PWA en Leaflet
- hanteer voor nieuw GIS-werk bij voorkeur deze projectstructuur: `GIS/data_raw/`, `GIS/data_processed/`, `GIS/rasters/`, `GIS/vectors/`, `GIS/scripts/`, `GIS/outputs/`, `GIS/maps/`, `GIS/shiny/`, `GIS/database/`
- relevante Meijendel-toepassingen zijn o.a. AHN-rasters, stikstofkaarten, beheerpolygonen, afstand tot paden, spatial joins met territoria, NDFF/SOVON-import, plotgewogen indices en interactieve kaarten

VPS / app.vwg-m.nl:
- Appsmith is niet meer actief op de VPS en is niet relevant voor inloggen of gebruikersbeheer van `app.vwg-m.nl`
- `app.vwg-m.nl` bevat op productie alleen het dashboard en de Shiny-app
- alle grafieken op `app.vwg-m.nl` moeten qua cijfers en opmaak exact overeenkomen met de grafieken in het dashboard; gebruik daarom dezelfde brondata, berekeningslogica, schaal, labels, legenda, kleuren en onzekerheidsweergave
- de ledenadministratie/PWA staat niet meer op de VPS; containers `leden_pwa_web` en `leden_pwa_mysql` horen daar niet te draaien
- toegang tot dashboard, SQL, Shiny en dashboard-output op `app.vwg-m.nl` loopt via Caddy `forward_auth` naar de VWG-M ledenlogin; er is geen PWA-login of magic-link-login op productie
- behandel `appsmith_ledenadministratie/` als historische/lokale Appsmith-context, niet als actuele productie-inrichting
- bij vragen over toegang tot `app.vwg-m.nl`: kijk eerst naar de Caddy `forward_auth`-configuratie en de routes voor dashboard en Shiny, niet naar Appsmith of de PWA

Actuele status nieuws/CMS 2026-06-30:
- uitgevoerd: overlap tussen nieuwseditor en preview opgelost; upload van afbeeldingen in nieuwsberichten hersteld; publiceren van nieuwsitems hersteld; nieuwstitels weer zichtbaar in lijsten; startpagina en nieuwspagina sorteren nieuwste gepubliceerde items bovenaan; `/nieuws/index.asp` toont alleen een tekstsamenvatting zonder begin-afbeeldingen, met detail via `Lees verder`
- gewijzigde sitebestanden: `app/static/site.css`, `app/templates/base.html`, `app/queries.py`, `app/templates/home.html`, `app/templates/news_archive.html`, `app/templates/news_index.html`
- gewijzigde beheer-/deploybestanden rond uploads en archief/OCR: `app/main.py`, `deploy/README_DEPLOY.md`, `docs/herstelrunbook.md`, `handleiding_beheer.md`, `scripts/backup_baremetal_vps.py`, `deploy/systemd/vwg-m-archive-ocr.service`, `deploy/systemd/vwg-m-archive-ocr.timer`, `scripts/reindex_member_archive_ocr.py`
- resterende risico's: geen volledige geautomatiseerde ingelogde end-to-end test voor nieuws maken, afbeelding uploaden en publiceren; runtime-map `app/static/uploads/cms` moet bij brede deploys/back-ups als productie-uploaddata worden behandeld; archief/OCR-service en timer alleen activeren na expliciete productiecontrole
- aanbevolen volgende stap: voer een ingelogde redactietest uit met nieuw nieuwsbericht inclusief afbeelding en controleer daarna startpagina, nieuwsoverzicht en detailpagina

Actuele status leden/contentbeheer 2026-06-30:
- uitgevoerd: leden met een actuele BMP- of winterkavelkoppeling in het lopende jaar zien `Contentbeheer`, maar daarbinnen alleen `Kavels`; niveau 4/5 houdt volledig contentbeheer; de ledenpagina toont actuele BMP-, winter- en PTT-toewijzingen uit dezelfde bron als de ledenadministratie
- gewijzigde sitebestanden: `app/main.py`, `app/queries.py`, `app/templates/member.html`, `handleiding_beheer.md`
- verificatie: gedeployed naar `app.vwg-m.nl`, service herstart, smoke-test groen; gerichte query voor Ton gaf 2026 BMP `M15; M16`, winter `M15; M16`, PTT leeg
- resterende risico's: nog geen volledige ingelogde browsertest met een gewoon niveau-1 lid dat een eigen kaveltekst opent, wijzigt en publiceert; PTT-routeteksten zijn nog niet geïmplementeerd zolang er geen route-tekstpagina's/module zijn
- aanbevolen volgende stap: test met een gewoon telleraccount de route `Leden > Contentbeheer > Kavels > eigen kavel bewerken` en controleer daarna de publieke kavelpagina

Actuele status Vogelrichtlijn/groepen 2026-06-30:
- uitgevoerd: Natura 2000/Vogelrichtlijnsoorten zijn gekoppeld aan `richtlijn_id = 7`; dashboard toont `Vogelrichtlijn` onder `Groepen > Lijsten` voor `Dichtheid per km2` en `TRIM`; `Kenmerken` toont een samengevoegde tegel `Lijsten`; de publieke groepenpagina bevat knop en subpagina `Vogelrichtlijn` met dichtheidsgrafiek, soortenlijst en vaste tekst; `Contentbeheer > Vaste Pagina's > Groepen` bevat de vaste pagina `Vogelrichtlijn`
- gewijzigde Meijendel-bestanden: `bmp_meijendel_index.html`, `R/build_groepen_grafieken_dashboard_csv.R`, `groepen_grafieken/gam_dashboard_groepen.csv`, `groepen_grafieken/groep_dichtheid.csv`, `groepen_grafieken/groep_soorten.csv`, `meijendel.sql`
- gewijzigde sitebestanden: `app/main.py`, `handleiding_beheer.md`; productie-CMS-keys `groups:rode-oranje-lijst-groepen` en `groups:vogelrichtlijn` zijn bijgewerkt
- verificatie: gedeployed naar `app.vwg-m.nl`; `/groepen/index.asp`, `/groepen/vogelrichtlijn.asp` en `/groepen/grafiek/vogelrichtlijn.svg` geven 200; VPS smoke-test groen; dashboard/outputdeploy en Shiny-check groen
- resterende risico's: geen ingelogde CMS-browsertest waarin `Vogelrichtlijn` via Contentbeheer wordt bewerkt en gepubliceerd; website-smoke-test controleert de nieuwe Vogelrichtlijn-route nog niet expliciet
- aanbevolen volgende stap: voeg `/groepen/vogelrichtlijn.asp` en `/groepen/grafiek/vogelrichtlijn.svg` toe aan de smoke-test en test een kleine CMS-concept/publicatie voor de vaste pagina `Vogelrichtlijn`

Actuele status soortpagina's/vogelkenmerken 2026-06-30:
- uitgevoerd: publieke vogelsoortdetailpagina's tonen in het kopblok compacte knoppen `Beschrijving`, `Voorkomen` en, indien beschikbaar, `Kenmerken`; het blok `Vogelkenmerken` verschijnt alleen bij soorten met gekoppelde Meijendel-kenmerkdata en toont lijsten plus hoofdgroepkenmerken als doorlopende tekst zonder technische codes/labels
- gewijzigde sitebestanden: `app/queries.py`, `app/templates/species_detail.html`, `app/static/site.css`, `handleiding_beheer.md`
- gewijzigde Meijendel-bestanden: geen datamodel- of dashboardwijziging; de website leest bestaande Meijendel-tabellen/views voor koppeling, lijsten en kenmerken
- verificatie: gedeployed naar `app.vwg-m.nl`; `scripts/smoke_vps.sh` groen; `/soorten/vogel.asp?id=227` geeft 200 en toont `Vogelkenmerken`
- resterende risico's: nog geen brede visuele controle over meerdere soorten met en zonder kenmerken; smoke-test controleert het nieuwe kenmerkenblok nog niet expliciet; lokale app-runtime kon eerder niet volledig tegen lokale MySQL worden getest
- aanbevolen volgende stap: voeg gerichte smoke-testchecks toe voor een soort met kenmerken en een soort zonder kenmerken, en controleer mobiel/tablet de navigatieknoppen op enkele lange soortnamen
