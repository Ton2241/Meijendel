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

1. [`MDs/handboek.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md)
2. [`MDs/EINDHANDLEIDING_html_en_shiny.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/EINDHANDLEIDING_html_en_shiny.md)
3. [`MDs/CONTROLESET_html_shiny.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/CONTROLESET_html_shiny.md)
4. [`MDs/README_shiny_meijendel.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/README_shiny_meijendel.md)
5. [`MDs/README_bmp_meijendel_index.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/README_bmp_meijendel_index.md)

## Wat staat waar?

### Hoofdbestanden

- [`Meijendel.sql`](/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql)
  De actuele SQL-dump van de database.
- [`bmp_meijendel_index.html`](/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html)
  Standalone HTML voor overzicht, controle en presentatie.
- [`README.md`](/Users/ton/Documents/GitHub/Meijendel/README.md)
  Korte projectingang.

### Documentatie

Alle actieve projectdocumentatie staat in `MDs/`.

Belangrijke bestanden daar zijn:

- [`MDs/handboek.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md)
  Doorlopend handboek voor gebruik van de database.
- [`MDs/EINDHANDLEIDING_html_en_shiny.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/EINDHANDLEIDING_html_en_shiny.md)
  Korte werkwijze voor HTML en Shiny.
- [`MDs/CONTROLESET_html_shiny.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/CONTROLESET_html_shiny.md)
  Vaste controlelijst voor gebruik en wijzigingen.
- [`MDs/README_trim_analyse.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/README_trim_analyse.md)
  Uitleg van de hoofd-TRIM-analyse.
- [`MDs/README_trim_sandra_analyse.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/README_trim_sandra_analyse.md)
  Uitleg van de Sandra-variant.
- [`MDs/README_ecologische_groepen.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/README_ecologische_groepen.md)
  Uitleg van de MSI- en GAM-analyse voor ecologische groepen.
- [`MDs/import_procedure_territoria.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/import_procedure_territoria.md)
  Jaarlijkse importprocedure voor territoria.

### Dagbezoeken en dagwaarnemingen

De database gebruikt nu een gesplitst model voor daggegevens:

- `dagbezoeken_bmp`
- `dagwaarnemingen_bmp`
- `dagbezoeken_wv`
- `dagwaarnemingen_wv`

Praktisch betekent dit:

- BMP-daggegevens staan los van WV-daggegevens
- beide reeksen hebben hun eigen bezoekentabel en waarnemingentabel
- beide reeksen blijven gekoppeld aan `plots`, `plot_jaar_oppervlak`, `soorten` en `bronnen`

In `dagbezoeken_wv` is bovendien extra WV-specifieke context aanwezig, zoals:

- `telling_id`
- `tellingtype`
- `telomschrijving`
- `waterstand`
- `sneeuw`
- `ijs`

### Shiny-app

De Shiny-app staat in `shiny_meijendel/`.

Belangrijkste bestanden:

- [`shiny_meijendel/app.R`](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R)
- [`shiny_meijendel/helpers.R`](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/helpers.R)
- [`shiny_meijendel/start_shiny_local.sh`](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh)
- [`shiny_meijendel/start_shiny_tailscale.sh`](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_tailscale.sh)

De app is bedoeld voor:

- selectie van kavels
- keuze van periode
- TRIM-analyse per soort
- MSI-analyse per ecologische groep
- controle van analysebasis en modelstatus
- export van resultaten naar CSV

### HTML-overzicht

De standalone HTML staat in:

- [`bmp_meijendel_index.html`](/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html)

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

- [`R/trim_soorten_en_msi_evg.R`](/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R)
- [`R/trim_sandra_soorten_en_msi_evg.R`](/Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.R)
- [`R/analyse_ecologische_groepen.R`](/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R)

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

Voor dagelijks gebruik is [`MDs/handboek.md`](/Users/ton/Documents/GitHub/Meijendel/MDs/handboek.md) nu het beste startpunt.
