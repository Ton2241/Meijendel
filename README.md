# Meijendel
> Zie voor de overkoepelende projectarchitectuur, ontwikkelworkflow en projectbrede ontwerpkeuzes ook de repository **VWG\_Project**.

Deze repository bevat de database en analysemiddelen voor de vogelgegevens van Meijendel.

## Projectanker voor nieuwe Codex-draden

Lees bij vervolgwerk eerst deze vier bestanden:

- `README.md`: ingang voor de Meijendel-repo en actuele projectcontext.
- `ARCHITECTURE.md`: samenhang tussen Meijendel, dashboard, Shiny, FastAPI/Jinja-app, VPS en databases.
- `TODO.md`: openstaande punten en operationele aandachtspunten.
- `DECISIONS.md`: gemaakte keuzes die niet opnieuw moeten worden uitgevonden.

Belangrijkste werkpaden:

- Meijendel-bronproject: `/Users/ton/Documents/GitHub/Meijendel`
- FastAPI/Jinja-site: `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`
- VPS-app-pad: `/srv/vwgm/vwg-m-linux-app`
- Canonieke SQL op VPS: `/srv/vwgm/data/Meijendel.sql`
- Publieke host nu: `app.vwg-m.nl`
- Voorbereide hoofdhost na DNS-cutover: `www.vwg-m.nl`, met `app.vwg-m.nl` als alias.

Werk bij nieuwe hoofdopdrachten vanuit een nieuwe draad, maar gebruik deze documenten als werkgeheugen. Inspecteer daarna altijd de actuele code en `git status`; neem niet aan dat tijdelijke scripts uit `/private/tmp` nog bestaan. Commit afgeronde wijzigingen standaard met een korte, beschrijvende commitmelding, tenzij expliciet is gevraagd om niet te committen. Als wordt gevraagd een wijziging voor `app.vwg-m.nl` of de VPS-site door te voeren, voer die wijziging zowel lokaal als op de VPS door en controleer de productiepagina of relevante smoke-test na deploy.

## Actuele status app.vwg-m.nl op 2026-06-30

Uitgevoerd voor nieuws/CMS:

- nieuwseditor en preview overlappen niet meer
- afbeeldingen uploaden in nieuwsberichten werkt en schrijft naar de CMS-mediamap
- publiceren van nieuwsitems werkt weer
- nieuwstitels staan weer correct in nieuws- en startpaginalijsten
- startpagina en nieuwspagina sorteren nieuwsitems op nieuwste item bovenaan
- `/nieuws/index.asp` toont per item alleen een korte tekstsamenvatting; afbeeldingen aan het begin van een bericht worden in het overzicht overgeslagen en het volledige bericht staat achter `Lees verder`

Gewijzigde sitebestanden in `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`:

- `app/static/site.css`
- `app/templates/base.html`
- `app/queries.py`
- `app/templates/home.html`
- `app/templates/news_archive.html`
- `app/templates/news_index.html`
- `app/main.py`
- `deploy/README_DEPLOY.md`
- `docs/herstelrunbook.md`
- `handleiding_beheer.md`
- `scripts/backup_baremetal_vps.py`
- `deploy/systemd/vwg-m-archive-ocr.service`
- `deploy/systemd/vwg-m-archive-ocr.timer`
- `scripts/reindex_member_archive_ocr.py`

Resterende risico's: er is nog geen volledige geautomatiseerde ingelogde test voor nieuws maken, afbeeldingen uploaden en publiceren; `app/static/uploads/cms` is runtime-data en mag bij brede deploys niet worden verwijderd; de archief/OCR-service en timer moeten nog apart gecontroleerd worden voordat die als productie-actief worden beschouwd.

Aanbevolen volgende stap: voer een ingelogde redactietest uit met een nieuw nieuwsbericht inclusief afbeelding en controleer startpagina, `/nieuws/index.asp` en de detailpagina.

Uitgevoerd voor leden/contentbeheer:

- leden met een actuele BMP- of winterkavelkoppeling in het lopende jaar krijgen beperkte toegang tot `Contentbeheer`
- gewone leden zien binnen Contentbeheer alleen `Kavels` en alleen hun eigen actuele kavels
- niveau 4 en 5 blijven alle contentbeheeronderdelen zien
- de ledenpagina toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie

Gewijzigde sitebestanden in `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`:

- `app/main.py`
- `app/queries.py`
- `app/templates/member.html`
- `handleiding_beheer.md`

Resterende risico's: er is nog geen volledige ingelogde browsertest met een gewoon niveau-1 telleraccount voor kaveltekst bewerken/publiceren; PTT-routeteksten zijn nog niet onderdeel van deze module.

Aanbevolen volgende stap: test met een gewoon telleraccount dat alleen de eigen kavel(s) zichtbaar zijn, dat een kaveltekst kan worden aangepast en dat de publieke kavelpagina daarna de wijziging toont.

Uitgevoerd voor Vogelrichtlijn/groepen:

- dashboard `Groepen > Lijsten` toont nu naast Rode Lijst, Oranje Lijst en Rode en Oranjelijst ook `Vogelrichtlijn`
- dashboard `Groepen` ondersteunt `Vogelrichtlijn` voor `Dichtheid per km2` en `TRIM`
- dashboard `Kenmerken` heeft een samengevoegde tegel `Lijsten` met Rode Lijst, Oranje Lijst en Vogelrichtlijn per soort
- de groepengrafiek-output bevat chart-id `vogelrichtlijn`
- publieke site toont `Vogelrichtlijn` als knop en subpagina onder `Rode, Oranje en Vogelrichtlijn lijst groepen`
- de vaste pagina `Vogelrichtlijn` is beschikbaar in `Contentbeheer > Vaste Pagina's > Groepen`

Gewijzigde Meijendel-bestanden:

- `bmp_meijendel_index.html`
- `R/build_groepen_grafieken_dashboard_csv.R`
- `groepen_grafieken/gam_dashboard_groepen.csv`
- `groepen_grafieken/groep_dichtheid.csv`
- `groepen_grafieken/groep_soorten.csv`
- `meijendel.sql`

Gewijzigde sitebestanden in `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`:

- `app/main.py`
- `handleiding_beheer.md`

Resterende risico's: er is nog geen ingelogde CMS-browsertest waarin de vaste pagina `Vogelrichtlijn` als concept wordt aangepast en gepubliceerd; de algemene smoke-test controleert de nieuwe `/groepen/vogelrichtlijn.asp` route en SVG-route nog niet expliciet.

Aanbevolen volgende stap: breid `scripts/smoke_vps.sh` uit met controles voor `/groepen/vogelrichtlijn.asp` en `/groepen/grafiek/vogelrichtlijn.svg`, en test een kleine Contentbeheer-publicatie voor de vaste pagina `Vogelrichtlijn`.

Uitgevoerd voor soortpagina's/vogelkenmerken:

- publieke vogelsoortdetailpagina's hebben in het kopblok nu compacte ankerknoppen `Beschrijving`, `Voorkomen` en, indien beschikbaar, `Kenmerken`
- `Vogelkenmerken` verschijnt alleen bij soorten met gekoppelde Meijendel-kenmerkdata
- het kenmerkenblok toont eerst lijsten en daarna hoofdgroepkenmerken als doorlopende tekst, zonder technische codes zoals veldnamen of primair/secundair-labels
- bestaande `Beschrijving`- en `Voorkomen`-teksten blijven uit de website/CMS-bron komen en worden niet overschreven

Gewijzigde sitebestanden in `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`:

- `app/queries.py`
- `app/templates/species_detail.html`
- `app/static/site.css`
- `handleiding_beheer.md`

Gewijzigde Meijendel-bestanden: geen; de website gebruikt bestaande Meijendel-data voor soortkoppeling, lijsten en kenmerken.

Resterende risico's: de productiepagina voor Boomleeuwerik en de algemene VPS-smoke-test zijn gecontroleerd, maar er is nog geen brede visuele controle voor soorten met lange namen, soorten zonder kenmerken en mobiele/tabletweergave. De smoke-test heeft nog geen expliciete assert op het nieuwe `Vogelkenmerken`-blok.

Aanbevolen volgende stap: voeg aan `scripts/smoke_vps.sh` checks toe voor een soort met kenmerken en een soort zonder kenmerken, en doe een korte mobiele/tabletcontrole van de kopknoppen.

De kern van het project bestaat uit:

- een MySQL- of MariaDB-dump van de database in `Meijendel.sql`
- een standalone HTML-overzicht in `bmp_meijendel_index.html`
- een Shiny-app in `shiny_meijendel/`
- R-scripts voor TRIM-, MSI- en GAM-analyses in `R/`
- SQL-views en importbestanden
- gesplitste dagtabellen voor BMP en WV
- ruimtelijke en recreatieve uitbreidingen in `Ruimtelijke data/` en `Recreatie/`

## Waar begin je?

Als je de repo wilt begrijpen of ermee wilt gaan werken, begin dan in deze volgorde:

1. [`MDs/handboek.md`][1]
2. [`shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`][2]
3. [`shiny_meijendel/CONTROLESET_html_shiny.md`][3]
4. [`shiny_meijendel/README_shiny_meijendel.md`][4]
5. [`MDs/README_bmp_meijendel_index.md`][5]

## Wat staat waar?

### Hoofdbestanden

- [`Meijendel.sql`][6]
  De actuele SQL-dump van de database.
- [`bmp_meijendel_index.html`][7]
  Standalone HTML voor overzicht, controle en presentatie.
- [`README.md`][8]
  Korte projectingang.

### Documentatie

Projectdocumentatie staat vooral in `MDs/`, met scriptspecifieke documentatie in `R/`.

Belangrijke bestanden zijn:

- [`MDs/handboek.md`][9]
  Doorlopend handboek voor gebruik van de database.
- [`shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`][10]
  Korte werkwijze voor HTML en Shiny.
- [`shiny_meijendel/CONTROLESET_html_shiny.md`][11]
  Vaste controlelijst voor gebruik en wijzigingen.
- [`R/trim_soorten_en_msi_evg.md`][12]
  Uitleg van de hoofd-TRIM-analyse.
- [`R/trim_sandra_soorten_en_msi_evg.md`][13]
  Uitleg van de Sandra-variant.
- [`R/analyse_ecologische_groepen.md`][14]
  Uitleg van de MSI- en GAM-analyse voor ecologische groepen.
- [`MDs/import_procedure_territoria.md`][15]
  Jaarlijkse importprocedure voor territoria.

### Shiny-app

De Shiny-app staat in `shiny_meijendel/`.

Belangrijkste bestanden:

- [`shiny_meijendel/app.R`][16]
- [`shiny_meijendel/helpers.R`][17]
- [`shiny_meijendel/start_shiny_local.sh`][18]
- [`shiny_meijendel/start_shiny_tailscale.sh`][19]

De app is bedoeld voor:

- selectie van kavels
- keuze van periode
- TRIM-analyse per soort
- MSI-analyse per ecologische groep
- controle van analysebasis en modelstatus
- export van resultaten naar CSV

### HTML-overzicht

De standalone HTML staat in:

- [`bmp_meijendel_index.html`][20]

De HTML bevat momenteel deze hoofdonderdelen:

- `Trend`
- `Plot`
- `MSI`
- `Tellers`

De HTML gebruikt:

- `Meijendel.sql` voor ruwe gegevens
- extra CSV-bestanden voor TRIM- en MSI-weergaven

### R-analyses

De R-scripts staan in `R/`.

Belangrijkste scripts:

- [`R/trim_soorten_en_msi_evg.R`][21]
- [`R/trim_sandra_soorten_en_msi_evg.R`][22]
- [`R/analyse_ecologische_groepen.R`][23]

Belangrijkste outputmappen:

- `trim/soorten/`
- `trim_msi_evg/`
- `trim/sandra/`
- `output_ecologische_groepen/`

### SQL-views en hulpmiddelen

De repository bevat veel SQL-bestanden voor:

- analyses per soort
- analyses per plot
- trends
- habitat
- tellers
- richtlijnen
- kernopgaven
- controle en validatie

Belangrijke mappen:

- `Views - soorten/`
- `Views - trends/`
- `Views - plots/`
- `Views - tellers/`
- `Views - Habitat/`
- `Integriteit check/`

### Ruimtelijke en recreatieve data

Ruimtelijke uitbreidingen staan in:

- `Ruimtelijke data/`
- `Recreatie/`

Daarin staan onder andere:

- import-SQL voor AHN, stikstof en landgebruik
- Python-scripts voor ruimtelijke samenvattingen per plot
- bronbestanden uit BGT en OSM
- importbestanden voor recreatie en toegankelijkheid
- documentatie over bezoekersdruk en recreatieve infrastructuur

## Wat is de normale werkvolgorde?

De praktische volgorde is:

1. werk vanuit `Meijendel.sql`
2. gebruik Shiny of R voor nieuwe analyses
3. controleer de uitkomsten
4. gebruik de HTML voor overzicht en presentatie
5. leg wijzigingen vast in Git

Voor alleen bekijken:

1. open `bmp_meijendel_index.html`
2. laad `Meijendel.sql`
3. laad waar nodig extra CSV-bestanden

Voor nieuwe analyses:

1. start de Shiny-app
2. laad `Meijendel.sql`
3. kies kavels en jaren
4. voer de analyse uit
5. controleer de tabs `Soorten`, `Groepen` en `Controle`
6. exporteer zo nodig CSV-bestanden

## Shiny starten

In R of RStudio:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp(host = "127.0.0.1", port = 3867)
```

Of via Terminal:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
```

## Belangrijke aandachtspunten

- De SQL-dump is de bron. Werk zorgvuldig als je die wijzigt.
- De Shiny-app en HTML hebben verschillende rollen: Shiny rekent, HTML presenteert.
- Niet alle documentatie in de repo is even recent; de documenten in `MDs/` zijn nu leidend.
- De worktree kan lokale, nog niet gecommitte wijzigingen bevatten. Controleer `git status` voordat je bestanden overschrijft of commit; commit afgeronde wijzigingen standaard na verificatie.

## Samenvatting

Deze repository is geen losse SQL-dump meer, maar een complete werkomgeving rond de Meijendel-database:

- database
- documentatie
- analyses
- visualisaties
- ruimtelijke uitbreidingen
- import- en controlehulpmiddelen

Voor dagelijks gebruik is [`MDs/handboek.md`][24] nu het beste startpunt.

[1]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
[2]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md
[3]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md
[4]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/README_shiny_meijendel.md
[5]:	/Users/ton/Documents/GitHub/Meijendel/MDs/README_bmp_meijendel_index.md
[6]:	/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql
[7]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
[8]:	/Users/ton/Documents/GitHub/Meijendel/README.md
[9]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
[10]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md
[11]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md
[12]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.md
[13]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.md
[14]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.md
[15]:	/Users/ton/Documents/GitHub/Meijendel/MDs/import_procedure_territoria.md
[16]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R
[17]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/helpers.R
[18]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
[19]:	/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_tailscale.sh
[20]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
[21]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R
[22]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.R
[23]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R
[24]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md