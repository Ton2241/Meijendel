# Meijendel

Deze repository bevat de database en analysemiddelen voor de vogelgegevens van Meijendel.

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
2. [`MDs/EINDHANDLEIDING_html_en_shiny.md`][2]
3. [`MDs/CONTROLESET_html_shiny.md`][3]
4. [`MDs/README_shiny_meijendel.md`][4]
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
- [`MDs/EINDHANDLEIDING_html_en_shiny.md`][10]
  Korte werkwijze voor HTML en Shiny.
- [`MDs/CONTROLESET_html_shiny.md`][11]
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
- De worktree kan lokale, nog niet gecommitte wijzigingen bevatten. Controleer `git status` voordat je bestanden overschrijft of commit.

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
[2]:	/Users/ton/Documents/GitHub/Meijendel/MDs/EINDHANDLEIDING_html_en_shiny.md
[3]:	/Users/ton/Documents/GitHub/Meijendel/MDs/CONTROLESET_html_shiny.md
[4]:	/Users/ton/Documents/GitHub/Meijendel/MDs/README_shiny_meijendel.md
[5]:	/Users/ton/Documents/GitHub/Meijendel/MDs/README_bmp_meijendel_index.md
[6]:	/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql
[7]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
[8]:	/Users/ton/Documents/GitHub/Meijendel/README.md
[9]:	/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md
[10]:	/Users/ton/Documents/GitHub/Meijendel/MDs/EINDHANDLEIDING_html_en_shiny.md
[11]:	/Users/ton/Documents/GitHub/Meijendel/MDs/CONTROLESET_html_shiny.md
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
