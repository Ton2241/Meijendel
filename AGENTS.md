# Projectinstructies Meijendel

Hou rekening met de volgende IT-infrastructuur:

1. iMac M1 8GB Tahoe 26.4 of later Opstart Macintosh HD
2. Samsung Portable SSD T7 2 terrabyte
3. NAS DS225+ met 6 GB geheugen
4. MySQL 9.7.1 op iMac en VPS

Antwoord in het Nederlands, compact en praktisch.

Werk standaard op de lokale iMac M1 in mijn thuismap/projectmap. Ga ervan uit dat projecten lokaal staan tenzij ik expliciet zeg dat bestanden op de Samsung Portable SSD T7, op de NAS DS225+ of op de VPS staan. Vraag eerst om bevestiging voordat je paden op externe opslag of NAS gebruikt. Gebruik voor de NAS standaard Synology DSM via de browser.

## Lokale uitvoercontext is verplicht

- Voer `/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh`
  vanaf de eerste poging rechtstreeks uit in de lokale uitvoercontext op de
  iMac, met toegang tot `.git`, het netwerk en schrijfbare macOS-mappen voor
  tijdelijke bestanden en caches.
- Hetzelfde geldt voor Git-controles zoals `git status`, `git fetch`,
  `git worktree` en upstreamcontroles, en voor repositoryscripts, tests,
  R/Python-generatie en validatie die tijdelijke bestanden of caches kunnen
  maken.
- Probeer zulke opdrachten niet eerst in de beperkte Codex-sandbox. Mappen
  onder `/var/folders/.../T`, `/tmp` en `/var/tmp` en caches van macOS-tools
  kunnen daar onschrijfbaar zijn; die bekende uitvoerbeperking is geen
  project-, Git- of testresultaat.
- Gebruik de beperkte sandbox alleen voor zuivere bestandslezingen, zoals een
  gerichte `sed`- of `rg`-inspectie, waarvan vaststaat dat zij geen tijdelijke
  bestanden of caches maken.

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
- voer tests, R/Python-generatie en andere controles die tijdelijke bestanden
  of caches maken vanaf de eerste poging uit in een lokale uitvoercontext met
  schrijfbare tijdelijke macOS-mappen; gebruik altijd een bestaande
  repositoriespecifieke controle- of generatiescript als dat beschikbaar is
- gebruik vóór fetch, lokale generatie en deploy
  `scripts/check_local_workspace.sh`; de vaste deploy- en generatiescripts
  roepen deze controle zelf aan
- commit afgeronde wijzigingen standaard met een korte, beschrijvende commitmelding en push de commit daarna naar GitHub, tenzij expliciet is gevraagd om niet te committen of niet te pushen.
- beheer vanaf nu de volledige Git-repository als onderdeel van het werk: controleer `git status`, houd wijzigingen logisch gegroepeerd, commit afgeronde wijzigingen, en laat niet-door-jou-gemaakte wijzigingen ongemoeid tenzij ik expliciet anders vraag
- als ik vraag een wijziging door te voeren voor `app.vwg-m.nl` of de VPS-site, voer die wijziging zowel lokaal als op de VPS door, inclusief passende verificatie na deploy

Bij iedere nieuwe opdrachtdraad en productiedeploy:
- controleer aan het begin én einde `VWG_Project`, `VWG_M` en `Meijendel`: haal remote refs op, meld de actieve branch en eis dat iedere lokale branch gelijkloopt met haar upstream; buiten een expliciet actieve taak hoort iedere werkboom schoon te zijn
- behandel een vooraf aangetroffen vuile werkboom niet als een normale toestand: stel eerst eigenaar en oorzaak vast; rond de wijziging veilig af en commit/push haar, of vraag de gebruiker als de bedoeling niet betrouwbaar is vast te stellen
- neem gegenereerde caches, tijdelijke bestanden en runtime-output nooit op in Git; als zo'n bestand al gevolgd wordt, haal het gecontroleerd uit Git en voeg het patroon toe aan `.gitignore`
- controleer `git worktree list --porcelain` op verwijzingen naar niet-bestaande tijdelijke worktrees en ruim alleen aantoonbaar `prunable` metadata op
- controleer eerst werkboom, actieve branch en lokale/remote branches; ga niet automatisch verder op de toevallig actieve branch
- gebruik een bestaande branch alleen als die aantoonbaar bij de taak past; maak anders vanaf de juiste actuele basis een taakgerichte branch
- ontwikkel en test op die taakbranch, maar merge vóór productie eerst naar `main`
- deploy uitsluitend vanaf een schone lokale `main` die exact gelijkloopt met `origin/main`; deploy nooit rechtstreeks vanaf een feature- of fixbranch
- gebruik uitsluitend het repositoriespecifieke deployscript; geen losse rsync-, SSH-, Docker- of databasewijzigingen als vervanging van de preflight
- de preflight moet controleren dat de op de VPS geregistreerde Meijendel-productiecommit een voorouder is van de nieuwe `main`, en moet een exclusieve VPS-deploy-lock gebruiken
- deploy één samenhangende release of een expliciet volledig manifest van afhankelijke SQL-, R-, dashboard-, CSV- en Shiny-bestanden; overschrijf geen gedeeld kernbestand los vanuit een andere branch
- wacht na herstart met begrensde retries op Shiny/dashboardgereedheid en voer daarna alle relevante rook- en inhoudscontroles uit
- registreer de nieuwe productiecommit pas na volledig groene nacontrole
- als het deployscript deze beveiligingen nog niet afdwingt, implementeer ze eerst en voer tot die tijd geen nieuwe productiedeploy uit
- gebruik herstelmodus alleen na expliciete bevestiging wanneer productie al defect is; ancestrycontrole, deploy-lock, manifest en volledige nacontrole blijven verplicht
- rond iedere geslaagde productiedeploy af door `/Users/ton/Documents/GitHub/VWG_Project/RELEASE_MANIFEST.yml` bij te werken: lees beide VPS-statebestanden, voeg een nieuwe release toe met exact de geregistreerde `VWG_M`- en `Meijendel`-commits, valideer ancestry en YAML, en commit/push/merge naar `VWG_Project/main`; hergebruik de bestaande commit van een ongewijzigde component en wijzig historische releases nooit
- meld een opdracht pas als volledig gesynchroniseerd wanneer `main == origin/main` in alle drie repositories, alle actieve taakbranches gelijklopen met hun upstream, de drie werkbomen schoon zijn en het productie-release-manifest overeenkomt met beide VPS-statebestanden
- rond imagebuilds en containerwissels pas af nadat alle in die taak gemaakte
  kandidaat-, test-, `previous`- en mislukte containers, tags en images exact
  zijn beoordeeld en na groene nacontrole zijn verwijderd; behoud uitsluitend
  actieve productie en de expliciet gedocumenteerde rollback
- bouw het Shiny-image altijd multi-stage: compilers, headers,
  `linux-libc-dev` en overige `*-dev`-pakketten horen uitsluitend in de
  builder; de runtime bevat alleen aantoonbaar gekoppelde uitvoerbibliotheken
- gebruik voor iedere Shiny-rebuild de vaste kandidaatpoort: verse no-cache
  build met exacte image-ID, 0 `CRITICAL`/0 `HIGH`, geïsoleerde proefcontainer
  op localhostpoort 3839 met productiemounts, package/cache/readinesscontrole,
  automatische rollback en daarna de volledige multi-hostrooktest
- gebruik gestopte containers niet als herstelbewijs: bewaar bewijs in exacte
  image-ID's, scanuitvoer, checksums, back-ups en het release-manifest; iedere
  rollback heeft een doel, laatste test en verwijdercriterium of beoordelingsdatum
- controleer vóór verwijdering altijd containerstatus, imageverwijzingen en
  mounts; bestaande rollbackdata verwijderen blijft een afzonderlijk expliciet
  beoordeelde handeling en een ongerichte Docker-prune is niet toegestaan

Bij communicatie:
- wees direct, feitelijk en beknopt
- behandel de gebruiker primair als vogelteller, voorzitter van de groep
  vogeltellers en systeembeheerder, niet als student of wetenschappelijk
  medewerker
- richt antwoorden op praktische toepasbaarheid, heldere conclusies,
  beheerkeuzes, communicatie en technische uitvoering, met als belangrijk doel
  dat de beheerder de verzamelde vogelgegevens vaker en intensiever gebruikt
- werk alleen op expliciet verzoek of bij strikte noodzaak een uitgebreide
  onderzoeksopzet of voorstellen voor vervolgonderzoek uit, en houd dit dan zo
  beknopt mogelijk
- voeg aan verhalen niet uit eigen beweging een methodologische
  onderzoeksagenda toe
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
- `app.vwg-m.nl` bevat op productie alleen het dashboard en de Shiny-app
- alle grafieken op `app.vwg-m.nl` moeten qua cijfers en opmaak exact overeenkomen met de grafieken in het dashboard; gebruik daarom dezelfde brondata, berekeningslogica, schaal, labels, legenda, kleuren en onzekerheidsweergave
- de ledenadministratie/PWA staat niet meer op de VPS; containers `leden_pwa_web` en `leden_pwa_mysql` horen daar niet te draaien
- toegang tot dashboard, SQL, Shiny en dashboard-output op `app.vwg-m.nl` loopt via Caddy `forward_auth` naar de VWG-M ledenlogin; er is geen PWA-login of magic-link-login op productie
- bij vragen over toegang tot `app.vwg-m.nl`: kijk eerst naar de Caddy `forward_auth`-configuratie en de routes voor dashboard en Shiny, niet naar de verlaten PWA
