# Meijendel
> Zie voor de overkoepelende projectarchitectuur, ontwikkelworkflow en projectbrede ontwerpkeuzes ook de repository **VWG\_Project**.

Deze repository bevat de database en analysemiddelen voor de vogelgegevens van Meijendel.

## Projectanker voor nieuwe Codex-draden

Lees bij vervolgwerk eerst deze vijf bestanden:

- `README.md`: ingang voor de Meijendel-repo en actuele projectcontext.
- `ARCHITECTURE.md`: samenhang tussen Meijendel, dashboard, Shiny, FastAPI/Jinja-app, VPS en databases.
- `docs/vps_productie.md`: actuele VPS-componenten, softwareversies,
  MySQL-/Shiny-paden en Docker-retentie.
- `STATUS.md`: actuele status, resterende risico's en aanbevolen vervolgstappen.
- `TODO.md`: openstaande punten en operationele aandachtspunten.
- `DECISIONS.md`: gemaakte keuzes die niet opnieuw moeten worden uitgevonden.

Belangrijkste werkpaden:

- Meijendel-bronproject: `/Users/ton/Documents/GitHub/Meijendel`
- FastAPI/Jinja-site: `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app`
- VPS-app-pad: `/srv/vwgm/vwg-m-linux-app`
- Canonieke SQL op VPS: `/srv/vwgm/data/Meijendel.sql`
- Canonieke gedeelde hostinventaris:
  `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`
- Publieke hoofdhost: `www.vwg-m.nl`.
- `app.vwg-m.nl` verwijst permanent met HTTP 308 naar hetzelfde pad op `www.vwg-m.nl`.

Werk bij nieuwe hoofdopdrachten vanuit een nieuwe draad, maar gebruik deze documenten als werkgeheugen. Start en eindig via `../VWG_Project/scripts/workspace_preflight.sh`; dit controleert vóór fetch of `.git` en gevolgde bestanden werkelijk lokaal beschikbaar zijn. Inspecteer daarna altijd de actuele code en `git status`; neem niet aan dat tijdelijke scripts uit `/private/tmp` nog bestaan. De vaste generatie- en deployscripts voeren dezelfde lokale controle zelf uit. Commit afgeronde wijzigingen standaard met een korte, beschrijvende commitmelding, tenzij expliciet is gevraagd om niet te committen. Als wordt gevraagd een wijziging voor `app.vwg-m.nl` of de VPS-site door te voeren, voer die wijziging zowel lokaal als op de VPS door en controleer de productiepagina of relevante smoke-test na deploy.

Codex start tests, R/Python-generatie en andere opdrachten die tijdelijke
bestanden of caches maken meteen in een lokale uitvoercontext met schrijfbare
macOS-tijdelijke mappen. Een voorafgaande proef in de beperkte sandbox is niet
nodig: `/var/folders/.../T`, `/tmp` en `/var/tmp` kunnen daar onschrijfbaar zijn
en zo een fout veroorzaken voordat de inhoudelijke controle begint. Gebruik
waar beschikbaar altijd het bestaande repositoriespecifieke controle- of
generatiescript.

## Waar begin je?

Als je de repo wilt begrijpen of ermee wilt gaan werken, begin dan in deze volgorde:

1. [`MDs/handboek.md`][1]
2. [`shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`][2]
3. [`shiny_meijendel/CONTROLESET_html_shiny.md`][3]
4. [`shiny_meijendel/README_shiny_meijendel.md`][4]
5. [`MDs/README_bmp_meijendel_index.md`][5]

## Wat staat waar?

### Hoofdbestanden

- [`meijendel.sql`][6]
  De actuele SQL-dump van de database. De tabel `tellers` bevat daarin alleen `id` en de unieke `tellercode`; persoonsgegevens staan uitsluitend in de afgeschermde PostgreSQL-ledenadministratie.
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
- `MDs/wintertellingen_pilot.md`
  Methode, audit, resultaten en besluitregels van de wintertellinganalyse voor alle soorten.
- `MDs/publieksartikel_25_jaar_wintervogels.md`
  Publicatieklaar conceptartikel op basis van de gevalideerde pilotresultaten.

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
- gebruik van jaarlijkse PQ-vegetatiekenmerken als optionele covariaten in GEE, GLMM, NMDS/envfit en occupancy

### HTML-overzicht

De standalone HTML staat in:

- [`bmp_meijendel_index.html`][20]

De HTML bevat momenteel deze hoofdonderdelen:

- `Trend`
- `Plot`
- `MSI`
- `Tellers`
- `Wintertellingen`, met alle geregistreerde soorten, kwaliteitslabels,
  passende model- of beschrijvende reeksen en een apart gemarkeerde ruwe telling

De HTML gebruikt:

- `meijendel.sql` voor ruwe gegevens
- extra CSV-bestanden voor TRIM- en MSI-weergaven

### R-analyses

De R-scripts staan in `R/`.

Belangrijkste scripts:

- [`R/trim_soorten_en_msi_evg.R`][21]
- [`R/trim_sandra_soorten_en_msi_evg.R`][22]
- [`R/analyse_ecologische_groepen.R`][23]
- `R/analyse_wintertellingen_pilot.R`
- `R/check_wintertelling_output.R`

Belangrijkste outputmappen:

- `trim/soorten/`
- `trim_msi_evg/`
- `trim/sandra/`
- `output_ecologische_groepen/`
- `wintertellingen/`

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

1. werk vanuit `meijendel.sql`
2. gebruik Shiny of R voor nieuwe analyses
3. controleer de uitkomsten
4. gebruik de HTML voor overzicht en presentatie
5. leg wijzigingen vast in Git

Voor alleen bekijken:

1. open `bmp_meijendel_index.html`
2. laad `meijendel.sql`
3. laad waar nodig extra CSV-bestanden

Voor nieuwe analyses:

1. start de Shiny-app
2. laad `meijendel.sql`
3. kies kavels en jaren
4. voer de analyse uit
5. controleer de tabs `Soorten`, `Groepen` en `Controle`
6. exporteer zo nodig CSV-bestanden

### Weergegevens: verplicht analysecontract

De tabel `weer` bevat ruwe bronwaarden met een stationsafhankelijke schaal en
mag daarom niet rechtstreeks in analyses worden gebruikt. Gebruik altijd de
view `weer_analyse`, met expliciete eenheden in de kolomnamen: `tg_c`, `tn_c`,
`tx_c`, `rh_mm`, `fg_ms`, `sq_uur`, `pg_hpa` en `ug_pct`.

- station 210 (Valkenburg, tot en met 2 mei 2016): `TG`, `TN`, `TX` en `RH`
  worden met 10 vermenigvuldigd;
- station 215 (Voorschoten, vanaf 3 mei 2016): dezelfde ruwe velden worden
  door 10 gedeeld;
- `rh_spoor` en `sq_spoor` markeren KNMI-code `-1`; de bijbehorende
  analysewaarde is dan nul.

Bij een nieuw station of een gewijzigde import moet eerst het profiel in
`weer_analyse` worden uitgebreid en moeten de weercontroles in
`Integriteit check/Database Validatie Check.sql` groen zijn.

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
- De lokale MySQL-server, `mysql`, `mysqldump` en de VPS-container moeten exact versie 9.7.1 gebruiken. Generatie en deploy blokkeren bij een afwijking.
- Lees voor weeranalyses uitsluitend uit `weer_analyse`, nooit rechtstreeks uit `weer`.
- Voeg aan MySQL `tellers` geen persoonsgegevens toe: alleen `id` en `tellercode` zijn toegestaan. Weergavenamen worden door de website uit PostgreSQL gehaald.
- De PQ-vegetatiebron vormt hierop een expliciete uitzondering: `pq_vegetatie_import`, `pq_vegetatie_pq`, `pq_vegetatie_opname`, `pq_vegetatie_taxon`, `pq_vegetatie_waarneming`, `pq_vegetatie_opname_plot` en `pq_plot_jaar_vegetatie` worden in de levende MySQL-database beheerd. Wijzig deze gegevens niet handmatig in `meijendel.sql`; genereer de dump na databasevalidatie opnieuw.
- De Shiny-app en HTML hebben verschillende rollen: Shiny rekent, HTML presenteert.
- Niet alle documentatie in de repo is even recent; de documenten in `MDs/` zijn nu leidend.
- De worktree hoort buiten een expliciet actieve taak schoon te zijn. Onderzoek iedere vooraf aangetroffen wijziging, rond bedoelde wijzigingen af met commit/push en haal gegenereerde caches of runtime-output uit Git en zet die in `.gitignore`.

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
[6]:	/Users/ton/Documents/GitHub/Meijendel/meijendel.sql
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
