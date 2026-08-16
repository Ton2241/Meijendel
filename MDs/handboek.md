# Handboek Meijendel-database

Dit handboek is bedoeld voor een gebruiker die inhoudelijk met de Meijendel-database wil werken.

Het doel van dit handboek is:

- uitleggen wat er in de database zit
- uitleggen waarvoor de verschillende bestanden en hulpmiddelen dienen
- uitleggen in welke volgorde je werkt
- duidelijk maken welke controles je altijd moet doen

Dit handboek vervangt niet alle losse documenten in de repository, maar brengt de belangrijkste informatie samen in één logisch verhaal.

## 1. Wat is de Meijendel-database?

De database Meijendel bevat vogelgegevens uit het duingebied Meijendel, tussen Scheveningen, Den Haag, Wassenaar, de Wassenaarse Slag en de zee.

De kern van de database bestaat uit:

- vogelsoorten
- plots en kavels
- territoria per plot en jaar
- dagbezoeken en dagwaarnemingen voor BMP en WV
- oppervlakte per plot en jaar
- tellers per plot en jaar
- ecologische vogelgroepen
- aanvullende gegevens zoals habitat, maatregelen, richtlijnen, recreatie en ruimtelijke omgeving

De repository bevat een MySQL-dump van de database, in SQL-vorm.

Belangrijke hoofdtabellen zijn:

- `soorten`
- `plots`
- `plot_jaar_oppervlak`
- `plot_jaar_teller`
- `territoria`
- `dagbezoeken_bmp`
- `dagwaarnemingen_bmp`
- `dagbezoeken_wv`
- `dagwaarnemingen_wv`
- `evg_vogelgroepen`
- `evg_vogel_landschapgroep`

Praktisch betekent dit:

- `plots` zegt waar de gebieden liggen
- `soorten` zegt om welke vogels het gaat
- `territoria` bevat de aantallen per plot en jaar
- `dagbezoeken_bmp` bevat gegevens per BMP-veldbezoek
- `dagwaarnemingen_bmp` bevat losse BMP-waarnemingen per soort, datum en locatie
- `dagbezoeken_wv` bevat gegevens per WV-bezoek
- `dagwaarnemingen_wv` bevat losse WV-waarnemingen per soort, datum en locatie
- `plot_jaar_oppervlak` is nodig om dichtheden te berekenen
- `plot_jaar_teller` laat zien of een plot in een jaar echt is geteld

### 1.1 Hoe gebruik je `plots.in_gebruik`?

In `plots` staat het veld `in_gebruik`.

Werkafspraak:

- `in_gebruik = 1`: het plot is actief en hoort standaard mee te doen in HTML, Shiny en gewone gebruikersviews
- `in_gebruik = 0`: het plot blijft historisch in de database bestaan, maar hoort standaard niet meer in keuzelijsten, overzichten en reguliere analyses

Gebruik daarom deze regel:

- gebruikersgerichte views, HTML en Shiny: filter standaard op actieve plots
- import-, controle- en integriteitsqueries: filter meestal niet op `in_gebruik`, omdat je daar juist ook niet-actieve of afwijkende koppelingen wilt kunnen zien

Praktisch SQL-patroon:

```sql
JOIN plots p ON ... AND p.in_gebruik = 1
```

of, als je vanuit `plots` start:

```sql
FROM plots p
WHERE p.in_gebruik = 1
```

## 2. Hoe is de repository opgebouwd?

Je werkt in de repository `Ton2241/Meijendel`.

Belangrijke onderdelen daarin zijn:

- `meijendel.sql`: de eigenlijke database-export
- `bmp_meijendel_index.html`: de standalone HTML voor overzicht en presentatie
- `shiny_meijendel/app.R`: de Shiny-app voor nieuwe selecties en analyses
- `trim/` en `trim_msi_evg/`: output van TRIM-analyses
- `trim/sandra/`: aparte Sandra-variant van de TRIM-analyse
- `output_ecologische_groepen/`: output van MSI- en GAM-analyses van ecologische groepen
- `Recreatie/` en `Ruimtelijke data/`: uitbreiding met recreatie- en omgevingsgegevens

## 3. Welke hulpmiddelen gebruik je waarvoor?

In dit project gebruik je niet één programma voor alles.

### 3.1 De SQL-dump

De SQL-dump is de bron.

Gebruik de dump:

- om de database-inhoud vast te leggen
- om gegevens opnieuw in te lezen
- als basis voor analyses in R, Shiny en HTML

#### Weerdata

Gebruik de ruwe tabel `weer` nooit rechtstreeks voor een analyse. De schaal van
`TG`, `TN`, `TX` en `RH` verschilt per station:

- Valkenburg (station 210, tot en met 2 mei 2016): vermenigvuldigen met 10;
- Voorschoten (station 215, vanaf 3 mei 2016): delen door 10.

De verplichte interface is `weer_analyse`. De eenheid staat daar in de
kolomnaam, bijvoorbeeld `tg_c`, `rh_mm`, `fg_ms` en `pg_hpa`. De vlaggen
`rh_spoor` en `sq_spoor` onderscheiden KNMI-spoorwaarden van een gemeten nul.
Voer na een weerimport of wijziging altijd uit:

```bash
deploy/check_weer_contract.sh meijendel.sql
```

De controle blokkeert onbekende stations, een ontbrekende view, rechtstreekse
ruwe weerqueries in de analysemap, een verkeerde schaal rond de stationsbreuk
en fysisch onwaarschijnlijke genormaliseerde waarden.

### 3.2 De Shiny-app

De Shiny-app gebruik je als je nieuwe selecties wilt doorrekenen.

Gebruik de Shiny-app voor:

- selectie van kavels
- keuze van begin- en eindjaar
- nieuwe TRIM-analyse per soort
- nieuwe MSI-analyse per ecologische groep
- controle van analysebasis en modelstatus
- export van analyse-uitkomsten naar CSV

Kort:

- Shiny = rekenen en controleren

### 3.3 De standalone HTML

De HTML gebruik je om gegevens overzichtelijk te bekijken en te presenteren.

Gebruik de HTML voor:

- ruwe aantallen territoria
- plotoverzicht per plot en jaar
- dichtheden per km2
- TRIM-index per soort
- GAM- en TRIM-MSI per ecologische groep
- telleroverzicht

Kort:

- HTML = bekijken en uitleggen

### 3.4 R en RStudio

R gebruik je voor zwaardere analyses die niet direct in de HTML of Shiny-app plaatsvinden.

Voorbeelden:

- TRIM-analyse per soort
- MSI-analyse per ecologische groep
- Sandra-variant
- vergelijking tussen periodes
- GAM-trendanalyse

### 3.5 QGIS

QGIS gebruik je voor ruimtelijke analyses die buiten MySQL worden uitgevoerd.

Voorbeelden:

- hoogte per plot
- stikstof per plot
- landgebruik per plot
- recreatieve afstanden per plot
- afstand tot paden
- padlengte per hectare
- afstand tot parkeerplaatsen
- afstand tot hoofdtoegangen

## 4. Wat is de normale werkvolgorde?

De eenvoudigste en veiligste werkvolgorde is:

1. werk vanuit een actuele SQL-dump
2. laad of controleer de database
3. voer een analyse uit in Shiny of R
4. controleer de uitkomst
5. gebruik daarna de HTML voor overzicht en presentatie
6. leg wijzigingen vast in Git

Als je alleen resultaten wilt bekijken:

1. open `bmp_meijendel_index.html`
2. laad `meijendel.sql`
3. laad waar nodig extra CSV-bestanden
4. bekijk de uitkomsten

Als je nieuwe soort- of groepsanalyses wilt maken:

1. start de Shiny-app
2. laad `meijendel.sql`
3. kies kavels
4. kies begin- en eindjaar
5. klik op `Analyse uitvoeren`
6. controleer de tabs `Soorten`, `Groepen` en `Controle`
7. exporteer desgewenst de CSV-bestanden
8. gebruik daarna de HTML om de resultaten overzichtelijk te bekijken

## 5. Hoe start je de Shiny-app?

De app staat in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R`

Benodigde R-packages zijn:

- `shiny`
- `rtrim`
- `mgcv`
- `bslib`

Starten in R of RStudio:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp(host = "127.0.0.1", port = 3867)
```

Of via het startscript:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
```

Daarna open je:

- `http://127.0.0.1:3867`

Er is ook een Tailscale-startscript voor gebruik binnen je tailnet.

## 6. Wat kun je in de Shiny-app doen?

De app bevat vier tabbladen:

- `Selectie`
- `Soorten`
- `Groepen`
- `Controle`

### 6.1 Selectie

Hier kies je:

- de kavels
- de periode

De app laat daarna de samenvatting van de selectie zien.

### 6.2 Soorten

Hier bekijk je:

- de TRIM-index per soort
- een GAM-lijn over de indexreeks
- trenduitleg per soort

### 6.3 Groepen

Hier bekijk je:

- de MSI per ecologische groep
- een GAM-lijn over de groepsreeks
- trenduitleg per groep
- welke soorten in de groep zitten

### 6.4 Controle

Hier controleer je:

- dekking per kavel
- oppervlak per jaar
- modelstatus van soorten

Dit tabblad is belangrijk. Gebruik het niet als bijzaak, maar als controlepunt vóór je conclusies trekt.

## 7. Welke bestanden exporteert de Shiny-app?

De Shiny-app maakt onder andere deze bestanden:

| Bestand                               | Betekenis                                           |
| ------------------------------------- | --------------------------------------------------- |
| `meijendel_shiny_soorttrends_...csv`  | trendoverzicht per soort                            |
| `meijendel_shiny_soortindices_...csv` | jaarlijkse TRIM-index per soort                     |
| `meijendel_shiny_groepstrends_...csv` | trendoverzicht per groep                            |
| `meijendel_shiny_groep_msi_...csv`    | MSI per groep per jaar                              |
| `meijendel_shiny_analysebasis_...csv` | controlebestand voor selectie, telling en oppervlak |
| `meijendel_shiny_modelstatus_...csv`  | modelstatus per soort                               |

Deze bestanden zijn bedoeld voor:

- controle
- vergelijking
- archivering

## 8. Hoe verbeter je de Shiny-app veilig?

Werk aan de Shiny-app altijd in deze volgorde:

1. pas lokaal de bestanden in `shiny_meijendel/` aan
2. test de app eerst lokaal
3. controleer of de wijziging echt werkt
4. upload daarna pas opnieuw naar `shinyapps.io`

Praktisch betekent dit:

- verbeter eerst lokaal `app.R`, `helpers.R` of andere bestanden in `shiny_meijendel/`
- start daarna de app lokaal
- controleer of de wijziging werkt
- deploy pas daarna opnieuw de hele app-map

Gebruik dus niet als eerste stap `deployApp()`.
Eerst lokaal verbeteren en testen is veiliger en voorkomt dat je een kapotte versie online zet.

### 8.1 Lokaal testen van de Shiny-app

Lokaal starten:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp(host = "127.0.0.1", port = 3867)
```

Of via het startscript:

```bash
/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/start_shiny_local.sh
```

Controleer daarna in je browser:

- start de app zonder foutmelding
- werkt `SQL laden`
- werken je nieuwe of aangepaste onderdelen

### 8.2 Opnieuw uploaden naar shinyapps.io

Als de lokale test goed is, upload je de nieuwe versie met:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
source("deploy_shinyapps.R")
```

Belangrijk:

- de deploy gebruikt altijd `/Users/ton/Documents/GitHub/Meijendel/meijendel.sql` als bron
- voor `shinyapps.io` wordt tijdelijk een bundle gemaakt met die root-SQL
- houd dus geen aparte `meijendel.sql` meer in `shiny_meijendel/`
- wacht na `deployApp()` tot de melding `Successfully deployed` verschijnt
- controleer daarna de live app in de browser

De live app is te benaderen via:

- `https://mbsk.shinyapps.io/shiny_meijendel/`
## 9. Hoe gebruik je de HTML?

De HTML staat in:

- `/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html`

De HTML kent vier hoofdonderdelen:

- `Trend`
- `Plot`
- `MSI`
- `Tellers`

### 8.1 Trend

In `Trend` zijn drie keuzes mogelijk:

#### Territoria

Dit zijn ruwe aantallen territoria.

Gebruik dit als je simpel wilt zien hoeveel territoria er in een jaar zijn vastgelegd.

Bron:

- rechtstreeks uit `meijendel.sql`

#### Dichtheid (per km2)

Dit zijn aantallen omgerekend naar oppervlak.

Gebruik dit als je jaren of gebieden eerlijker wilt vergelijken, vooral als plots in grootte verschillen.

Bron:

- `meijendel.sql`
- `plot_jaar_oppervlak`
- `plot_jaar_teller`

#### TRIM-index

Dit is de beste keuze voor langjarige trendduiding van soorten, vooral als:

- tellingen ontbreken
- meetinspanning wisselt
- de methodebreuk rond 1984 een rol speelt

Bron:

- `soortindices_bruikbare_tijdreeks.csv`
- `soorten_trendoverzicht_bruikbare_tijdreeks.csv`

### 8.2 MSI

In `MSI` zijn twee keuzes mogelijk:

#### GAM (dichtheid)

Een vloeiende groepsontwikkeling op basis van dichtheid.

Bron:

- `gam_voorspellingen_per_groep.csv`
- `gam_interpretatie_per_groep.csv`

#### TRIM-MSI

Een groepsindicator op basis van TRIM-soortindices.

Bron:

- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`
- eventueel `gam_voorspellingen_msi_groepen.csv`
- eventueel `gam_interpretatie_msi_groepen.csv`

### 8.3 Plot

In `Plot` kun je per gekozen plot en per gekozen jaar een samenvatting bekijken.

Deze tab is bedoeld als plotoverzicht.

Je kunt daar onder andere zien:

- plotnaam en `plot_id`
- toegankelijkheidsstatus voor recreanten
- een link naar de kaart
- oppervlakte
- AHN
- stikstof
- afstand tot pad
- padlengte per hectare
- afstand tot parkeerplaats
- afstand tot hoofdtoegang
- top 3 habitattypen
- landgebruik
- beheer en maatregel
- een vogelblok met vogelinformatie voor het gekozen jaar

De informatie in deze tab komt uit meerdere tabellen, onder andere:

- `plots`
- `plot_jaar_oppervlak`
- `plot_jaar_ahn_dtm`
- `plot_jaar_stikstof`
- `plot_jaar_landgebruik`
- `plot_jaar_infra`
- `plot_jaar_toegankelijkheid`
- `plot_jaar_habitat`
- `plot_jaar_maatregel`
- `territoria`

Praktisch is deze tab vooral nuttig als je voor één plot tegelijk wilt begrijpen:

- hoe het plot er qua omgeving uitziet
- welke ruimtelijke gegevens bekend zijn
- welke recreatieve kenmerken bekend zijn
- welke beheerinformatie erbij hoort
- hoe dat zich verhoudt tot de vogelgegevens

### 8.4 Tellers

De HTML kan ook tellers tonen op basis van:

- `tellers`
- `plot_jaar_teller`
- `plots`

## 10. Wat is TRIM en waarom gebruik je het?

TRIM is een analysemethode voor tellingen over de tijd.

In dit project gebruik je TRIM vooral om soorttrends te berekenen op een manier die beter omgaat met:

- ontbrekende tellingen
- wisselende meetinspanning
- een methodologische breuk rond 1984

Belangrijk om te begrijpen:

- `territoria` is niet hetzelfde als `TRIM-index`
- `dichtheid` is niet hetzelfde als `TRIM-index`

Ze beantwoorden verschillende vragen.

## 11. Hoe werkt de hoofd-TRIM-analyse?

De hoofd-TRIM-analyse leest rechtstreeks `meijendel.sql` in en maakt nieuwe output in:

- `trim/soorten`
- `trim_msi_evg`

De analyse doet in grote lijnen dit:

1. leest de kern-tabellen in
2. bouwt per `plot x jaar` een analysebasis op
3. gebruikt voor `1958-1972` alleen de historische kernkavels
4. behandelt niet-getelde plotjaren als `NA`
5. behandelt wel-getelde maar niet-waargenomen soorten als `0`
6. corrigeert pragmatisch voor veranderend plotoppervlak
7. draait per soort een TRIM-model vóór `1984`
8. draait per soort een tweede TRIM-model vanaf `1984`
9. verbindt beide reeksen met een brugfactor
10. berekent daarna per ecologische 100-groep een MSI

Dit is nodig omdat `rtrim` een tijdsafhankelijke covariaat zoals `post84` niet eenvoudig in één model accepteert.

Daarom is gekozen voor:

- aparte reeksen vóór en na de breuk
- daarna gecontroleerd bruggen

Belangrijke outputbestanden voor soorten zijn:

- `analysebasis_plot_jaar.csv`
- `soorten_modelstatus.csv`
- `soortindices_per_jaar.csv`
- `soorten_trendoverzicht.csv`
- `soorten_brugfactoren.csv`

Belangrijke outputbestanden voor groepen zijn:

- `groepssamenstelling_100tal.csv`
- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`

## 11. Wat is de Sandra-variant?

Naast de lange TRIM-reeks is er een aparte, strikte Sandra-variant.

Deze variant:

- gebruikt alleen `1997-2022`
- gebruikt alleen 25 vooraf vastgelegde Sandra-plots
- laat de bestaande lange analyse ongemoeid
- gebruikt dezelfde verbeterde TRIM-logica
- berekent daarna ook een MSI per ecologische 100-groep

De soortselectie is hier ruimer dan in Sandra’s artikel:

- alle soorten met minstens één territorium in deze 25 plots en periode worden eerst meegenomen
- pas daarna wordt gekeken voor welke soorten het TRIM-model werkelijk bruikbaar is

Deze variant is nuttig als je de huidige analyse wilt vergelijken met Sandra’s selectie en tijdsvenster.

## 12. Wat is MSI en waarom gebruik je het?

MSI betekent hier:

- per soort eerst een jaarlijkse index maken
- daarna per ecologische groep per jaar het geometrisch gemiddelde van die soortindices nemen

Dat heeft een belangrijk gevolg:

- in een gewone groepssom wegen algemene soorten vaak zwaar
- in MSI tellen soorten binnen een groep veel gelijkwaardiger mee

Dus:

- MSI zegt meer over de gemiddelde ontwikkeling van soorten binnen een groep
- MSI zegt minder direct iets over de totale groepsdichtheid of biomassa

## 13. Wat voegt GAM toe?

De lineaire analyses geven één gemiddelde helling per periode.

De GAM-analyse voegt toe:

- niet-lineaire trendvormen
- zichtbare pieken en dalen
- herstel of kromming in trends
- onzekerheidsbanden rond de geschatte lijn

Let bij GAM vooral op:

- `deviance_explained`
- `edf_pre`
- `edf_post`
- `gam_fit_*`

Interpretatie:

- `edf` dicht bij `1` betekent bijna lineair
- hogere `edf` betekent meer kromming

## 14. Hoe controleer je of een analyse betrouwbaar is?

Doe altijd deze controles:

### Controle 1: laden

Controleer of:

- `meijendel.sql` zonder fout laadt
- de kavellijst verschijnt
- de jaarkeuze verschijnt

### Controle 2: korte selectie

Controleer met een kleine, bekende selectie of:

- de analyse zonder foutmelding draait
- de samenvatting logisch is
- dekking per kavel zichtbaar is
- geteld oppervlak per jaar zichtbaar is

### Controle 3: soortcontrole

Controleer of:

- je een soort kunt kiezen
- de grafiek verschijnt
- de TRIM-index logisch over de jaren verandert
- de GAM-lijn logisch aansluit
- de tabel trenduitleg en analysecategorie toont

### Controle 4: groepscontrole

Controleer of:

- je een groep kunt kiezen
- de MSI-grafiek verschijnt
- de GAM-lijn logisch aansluit
- de groepstabel logisch oogt
- de tabel met soorten in de groep gevuld is

### Controle 5: randgeval

Controleer ook een lastige selectie, bijvoorbeeld:

- weinig kavels
- korte periode
- weinig soorten

De app moet dan nog steeds een begrijpelijke uitkomst of duidelijke melding geven.

## 15. Hoe importeer je jaarlijks nieuwe territoria?

De import van nieuwe vogelterritoria gebeurt in principe één keer per jaar.

### Stap 1: maak altijd eerst een backup

Voer dit uit zonder uitzondering.

In TablePlus:

1. verbind met de database
2. kies `File > Export > SQL Dump`
3. sla de backup op als `meijendel_backup_JJJJMMDD.sql`

### Stap 2: laad de bronbestanden in de werktabellen

De belangrijkste werktabellen zijn:

- `import_waarnemingen_breed`
- `import_waarnemingen_lang`

Controleer daarna of die tabellen gevuld zijn.

### Stap 3: verwerk de data naar productietabellen

Daarna verwerk je de data door naar de echte tabellen.

Controleer na elke belangrijke stap het aantal rijen.

### Stap 4: controleer referentiële integriteit

Controleer of:

- alle `euring_code`-waarden bestaan in `soorten`
- alle `plot_id`-waarden bestaan in `plots`

Ontbrekende soorten of plots moet je eerst oplossen.

### Stap 5: maak de werktabellen pas leeg als alles klopt

Pas na succesvolle verwerking en controle mag je de werktabellen leegmaken.

### Stap 6: leg de import vast in Git

Daarna:

1. exporteer het bijgewerkte schema of de dump
2. sla dat op in de repository
3. commit en push de wijziging

Belangrijk:

Het document over deze procedure bevat nog enkele open plekken met `[AANVULLEN]`. Gebruik die importprocedure dus als raamwerk, maar ga er niet vanuit dat elk detail al volledig is uitgewerkt.

## 16. Wat zijn dagbezoeken en dagwaarnemingen?

Naast de jaarlijkse territoria bevat de database ook dagwaarnemingen.

Dat is een belangrijk verschil:

- `territoria` geeft de samengevatte uitkomst per plot en jaar
- `dagwaarnemingen_bmp` en `dagwaarnemingen_wv` bewaren losse waarnemingen per bezoek, soort en datum

Daarmee kun je later veel preciezer terugkijken:

- welke soorten op welke dag zijn gezien
- hoeveel exemplaren zijn genoteerd
- welke broedcode is gebruikt
- of een waarneming binnen of buiten het plot viel
- waar de waarneming ruimtelijk lag

De belangrijkste tabellen hiervoor zijn:

- `bronnen`
- `dagbezoeken_bmp`
- `dagwaarnemingen_bmp`
- `dagbezoeken_wv`
- `dagwaarnemingen_wv`

### 16.1 `bronnen`

Deze tabel legt vast uit welke bron een bezoek of waarneming afkomstig is.

Dat is nodig om later te kunnen onderscheiden:

- uit welk systeem een record kwam
- welke importbron is gebruikt

### 16.2 `dagbezoeken_bmp`

`dagbezoeken_bmp` bevat de gegevens per BMP-veldbezoek.

Daarin staat onder andere:

- `bezoek_id`
- `plot_id`
- `jaar`
- `bezoek_datum`
- begin- en eindtijd
- bezoekduur
- of het een deelbezoek was
- of de omstandigheden gunstig waren
- aantallen soorten en records
- de bron van het bezoek

Praktisch is dit de tabel die één concreet BMP-bezoek aan een plot beschrijft.

### 16.3 `dagwaarnemingen_bmp`

`dagwaarnemingen_bmp` bevat de losse waarnemingen die bij zo'n BMP-bezoek horen.

Daarin staat onder andere:

- aan welk bezoek de waarneming hangt
- voor welk plot en jaar de waarneming geldt
- welke soort is gezien
- op welke dag de waarneming viel
- het aantal
- de broedcode
- eventueel geslacht en opmerking
- of de waarneming in het plot viel
- de coördinaten en geometrie
- de bron van de waarneming

Belangrijk:

- elke BMP-dagwaarneming hoort bij een bestaand `dagbezoeken_bmp`
- elke BMP-dagwaarneming hoort ook bij een bestaand `plot_id`, `jaar` en `soort_id`
- `bron_waarneming_id` voorkomt dubbele bronrecords

### 16.4 `dagbezoeken_wv`

`dagbezoeken_wv` bevat de gegevens per watervogeltelling bezoek.

Deze tabel lijkt op `dagbezoeken_bmp`, maar bevat extra WV-specifieke context:

- `telling_id`
- `tellingtype`
- `telomschrijving`
- `waterstand`
- `sneeuw`
- `ijs`

Praktisch is dit de bezoekentabel voor WV met extra informatie over type telling en omstandigheden.

### 16.5 `dagwaarnemingen_wv`

`dagwaarnemingen_wv` bevat de losse waarnemingen die bij een WV-bezoek horen.

De opzet lijkt sterk op `dagwaarnemingen_bmp`, maar deze tabel hoort via `bezoek_id` bij `dagbezoeken_wv`.

Belangrijk:

- elke WV-dagwaarneming hoort bij een bestaand `dagbezoeken_wv`
- elke WV-dagwaarneming hoort ook bij een bestaand `plot_id`, `jaar` en `soort_id`
- ook hier voorkomt `bron_waarneming_id` dubbele bronrecords

### 16.6 Waarom dit nuttig is

Je kunt nu niet alleen meer werken met:

- samenvattingen per plot en jaar

maar ook met:

- losse BMP-waarnemingen per dag
- losse WV-waarnemingen per dag
- bezoekinformatie per meettype
- preciezere bronherkomst
- ruimtelijke waarnemingspunten

Voor een beginner is de belangrijkste praktische les:

- gebruik `territoria` voor overzicht en jaaranalyses
- gebruik `dagwaarnemingen` als je detailinformatie per bezoek of per losse waarneming nodig hebt

## 16A. Hoe worden NDFF/FFV-waarnemingen toegevoegd?

NDFF-waarnemingen zijn een aanvullende externe bron. Zij worden niet opgenomen
in `territoria`, `dagwaarnemingen_bmp`, `dagwaarnemingen_wv` of de
PQ-vegetatietabellen. Daardoor blijven de eigen gestandaardiseerde tellingen en
de externe aanwezigheidssignalen methodisch gescheiden.

### Downloadafspraken

- sla de soortgroep Vogels over;
- gebruik als vaste periode 1 januari 1950 tot en met 31 december 2025;
- download losse `Waarnemingen`, niet alleen de geaggregeerde `Soortenlijst`;
- gebruik `GeoPackage RD` zodat de oorspronkelijke NDFF-vlakgeometrie behouden
  blijft en direct aansluit op EPSG:28992 van de Meijendel-kavels;
- selecteer in een export alle gewenste niet-vogelgroepen tegelijk als het
  recordaantal dit toelaat; de export hoeft dus niet per latere hoofd- of
  databasetabel te worden aangevraagd;
- combineer een beperkt aantal kilometerhokken per aanvraag en houd als
  operationele streefgrens maximaal circa 80.000 waarnemingen aan, ruim onder de
  FFV-grens van 100.000;
- splits eerst op kilometerhokken en alleen waar nodig daarnaast op een of meer
  soortgroepen;
- bewaar het ongewijzigde bronbestand met downloadmoment, selectieperiode,
  kilometerhokken, FFV-peildatum, SHA-256 en standaardbronvermelding.

De eerdere Amfibieën-proef met eindjaar 2026 blijft uitsluitend een
schema- en kwaliteitsproef. Neem die niet op in de definitieve geïntegreerde
dataset; vraag de betreffende selectie opnieuw aan met einddatum 31 december
2025.

Iedere oorspronkelijke FFV-soortgroep krijgt een eigen waarnemingstabel. De
naamconventie is `ndff_<soortgroep>`, waarbij het FFV-label reproduceerbaar naar
een ASCII-naam in `snake_case` wordt genormaliseerd. Voorbeelden zijn
`ndff_kreeftachtigen`, `ndff_kranswieren_wieren_algen`,
`ndff_korstmossen` en `ndff_amfibieen`. Deze tabellen zijn functioneel
vergelijkbaar met `territoria`, maar bevatten losse externe NDFF-waarnemingen en
geen territoria of gestandaardiseerde tellingen. De oorspronkelijke
FFV-soortgroep wordt altijd ongewijzigd als bronwaarde bewaard.

Gebruik Nederlandse soortnamen niet als unieke sleutel; taxoncodes of stabiele
bronidentificaties gaan voor, met de wetenschappelijke naam als controleveld.
De voorkeur is om taxa in de bestaande tabel `soorten` te registreren, maar
alleen als die tabel veilig generiek kan worden gemaakt. Zij is nu vogelgericht
en vereist voor iedere rij een unieke `euring_code`. Toets daarom eerst alle
foreign keys, imports, queries, dashboard- en Shiny-afhankelijkheden zonder de
levende database te wijzigen. Als veilig hergebruik niet aantoonbaar is, gebruik
dan een afzonderlijke NDFF-taxontabel en koppel die expliciet aan `soorten` voor
reeds aanwezige taxa.

### Eerst compleet downloaden, daarna integreren

Rond eerst de volledige reeks aanvragen af. Maak daarna twee reproduceerbare
producten:

1. een geïntegreerde stagingdataset met alle ontvangen niet-vogelrecords tot en
   met 31 december 2025, na verwijdering van exportoverlap;
2. een database-importselectie met alleen de records die aan de vastgelegde
   ruimtelijke toelatingsregels voor de SOVON-plots voldoen.

Ontdubbel primair op `Identiteit`, maar bevestig eerst met een kleine
overlappende herdownload dat deze bronwaarde tussen leveringen stabiel blijft.
Als dat niet zo is, gebruik dan een conservatieve samengestelde vergelijking van
onder andere soort, periode, bronhouder, protocol, aantal en genormaliseerde
geometrie, gevolgd door controle van twijfelgevallen. Voeg niet samen op alleen
soort, datum of geometrie: dat kan echte afzonderlijke waarnemingen verwijderen.

Bewaar alle oorspronkelijke GeoPackages ongewijzigd met hun SHA-256. De
geïntegreerde stagingdataset vervangt de bronbestanden dus niet.

### Raming van het aantal aanvragen

De 55 kavelpolygonen uit de actuele lokale shapefile raken 34 verschillende
1x1-kilometerhokken. Een FFV-peiling op 15 augustus 2026 gaf voor de gehele
periode 1950-2026:

- hok 83-461: 209.898 waarnemingen totaal, waarvan 135.243 vogels en dus 74.655
  niet-vogelwaarnemingen;
- hok 84-462: 142.854 waarnemingen totaal, waarvan 110.208 vogels en dus 32.646
  niet-vogelwaarnemingen.

De oorspronkelijke raming van **circa 20 tot 25 aanvragen** ging ervan uit dat
alle niet-vogelgroepen samen konden worden geselecteerd. Controle in FFV-versie
1.3.2 op 15 augustus 2026 wees uit dat het downloadvenster alleen alle
soortgroepen samen of één afzonderlijke FFV-soortgroep aanbiedt. `Alle
soortgroepen` bevat ook Vogels en overschrijdt in drukke hokken de grens van
100.000. De definitieve reeks moet daarom per FFV-soortgroep worden aangevraagd,
verdeeld over maximaal twaalf 1x1-kilometerhokken en waar nodig verder gesplitst
om onder circa 80.000 te blijven. De raming van 23 is vervallen; leid het actuele
aantal af uit de werkelijk benodigde soortgroep-bundels. Met 26 niet-vogelgroepen
en drie ruimtelijke bundels is de voorlopige basisraming 78 unieke aanvragen,
vóór eventuele extra splitsingen van omvangrijke selecties. FFV staat maximaal
vijf aanvragen per voortschrijdend uur toe.

Per 16 augustus 2026 zijn Eencelligen, Geleedpotigen (overig), Insecten
(overig) en Kevers voor alle 34 hokken afgedekt en gevalideerd. De op die dag
ontvangen nieuwe GeoPackages bevatten 585 en 698 records voor Insecten (overig)
bundels 2 en 3, en 3.765, 2.653 en 2.275 records voor Kevers bundels 1, 2 en 3.
Alle vijf hebben de laag `waarnemingen`; de tellingen komen exact overeen met
de vooraf gecontroleerde FFV-resultaten. De SHA-256-controlesommen zijn:

- Insecten (overig) bundel 2: `3065324c8ad42f24e161a0360f3aedd403966954f2bc01a48dea9e947bc87740`;
- Insecten (overig) bundel 3: `cd494a1881fbebf7a9a4789dbba6dff62f771de989b8f8c49341da5caf30fd47`;
- Kevers bundel 1: `88e03860e921a201e3d13456deb061402b8ead563b8d8f1752986feb63e056fc`;
- Kevers bundel 2: `52ffb2b05b3cf2b4b9b7eeff69ef7602de4dca63fb5bebe4db0bf5233ced48af`;
- Kevers bundel 3: `c8a42315233c08fb140a582240ad3bf1933d007520050f61f5d0799c2d2647bd`.

De daaropvolgende ronde op 16 augustus 2026 dekte Amfibieën volledig en
Dagvlinders voor bundels 1 en 2. De vijf GeoPackages hebben eveneens de laag
`waarnemingen` en bevatten respectievelijk 7.283, 3.584, 3.412, 45.010 en
76.799 records. De SHA-256-controlesommen zijn:

- Amfibieën bundel 1: `3bb2542c9366a4d36bfb7d20316ab97d4c4736ec77e49449662f81bd2abfb230`;
- Amfibieën bundel 2: `53e4cae22002b08706a295ee6ee8ad9125eee30a7c9b2351b76f5e7cc24740ff`;
- Amfibieën bundel 3: `7b162dd123d238a7f48215207b7d567199f2bf0235e78539b9d037852c2e0e91`;
- Dagvlinders bundel 1: `19a0991c2243ee38f65770315e468ae82a7a7d2fb5b7da8f8086ce5615c55f22`;
- Dagvlinders bundel 2: `7a32f5e55e045ab935f3c72a0c1605074d82dc21d636c1847c8414d85c9fe806`.

De volgende ronde op 16 augustus 2026 dekte Dagvlinders bundel 3 en
Korstmossen volledig, plus Kranswieren, wieren en algen bundel 1. De vijf
GeoPackages hebben de laag `waarnemingen`, CRS EPSG:28992 en bevatten
respectievelijk 14.437, 11.720, 8.740, 10.823 en 227 records. De tellingen komen
exact overeen met de vooraf gecontroleerde FFV-resultaten. De
SHA-256-controlesommen zijn:

- Dagvlinders bundel 3: `42b3cf5ff62a7e26f00546bee05596bb94746242a68835a35c09cdf79d961634`;
- Korstmossen bundel 1: `b27f678b1ecb961fcddb8ef28adada32b8f567198869053bee812c9d9fb8b0ee`;
- Korstmossen bundel 2: `7697e7df7facb2979e4879f5a82b07855713a6361f1836614b931f03951a09d2`;
- Korstmossen bundel 3: `ac58d8b6c31c4f99c4bf958973fe16e6a225423f57cda6a78e0f44fc7953e22a`;
- Kranswieren, wieren en algen bundel 1: `1d5ef92ed1bf90f36ebbfc6976c205fda1a33cdf8eea75ac45c0b38f641ccd55`.

De daaropvolgende ronde op 16 augustus 2026 voltooide Kranswieren, wieren en
algen met bundels 2 en 3 en dekte Kreeftachtigen volledig. De vijf
GeoPackages hebben de laag `waarnemingen`, CRS EPSG:28992 en bevatten
respectievelijk 224, 145, 1.183, 776 en 372 records. De tellingen komen exact
overeen met de vooraf gecontroleerde FFV-resultaten. De
SHA-256-controlesommen zijn:

- Kranswieren, wieren en algen bundel 2: `8e48dc0fc5190eeb55d2e2366562453943eef6f19218d494aab81ce44180e041`;
- Kranswieren, wieren en algen bundel 3: `1fb7975af262d1b6593f51e9f78ac00c09c002654f0f56fec1a1c190eb4b5e65`;
- Kreeftachtigen bundel 1: `7678685c284f609bbb1b7661457064bbd6f2700e862ac02897e525ecf4895837`;
- Kreeftachtigen bundel 2: `a7c5b6b28ba9a32485bff7ac1f892d3a4124010b8cbe68d5254387ff88fe6f32`;
- Kreeftachtigen bundel 3: `934be675d8680f0e9904fb075a9b7f8646abadedeefeb88cef030523cd0ffb95`.

De daaropvolgende ronde op 16 augustus 2026 dekte Libellen volledig. De drie
GeoPackages hebben de laag `waarnemingen`, CRS EPSG:28992 en bevatten
respectievelijk 14.239, 7.873 en 12.277 records. De selectie-URL's in Gmail
komen exact overeen met de drie vaste hokkenbundels. De SHA-256-controlesommen
zijn:

- Libellen bundel 1: `bc165d7308415fed15c5be5e3306ca749f916655950e0b76813115d6ca570a27`;
- Libellen bundel 2: `f26b0ce7aef112d1443af03bc6bd1a2ea5bdbce5f82207cff49872e23d6b5858`;
- Libellen bundel 3: `17c27e4174f25936972d0646eb0329d4b4b018c915665ed678039786d4782bee`.

De ronde van 16 augustus 2026 tussen 15:05 en 15:10 uur lokale tijd benutte
alle vijf beschikbare aanvragen. Microvlinders is volledig afgedekt. De drie
GeoPackages hebben de laag `waarnemingen`, CRS EPSG:28992 en bevatten
respectievelijk 6.295, 7.796 en 9.609 records. De selectie-URL's in Gmail komen
exact overeen met de drie vaste hokkenbundels. De SHA-256-controlesommen zijn:

- Microvlinders bundel 1: `961f7da54888c231a409da6182b928fca8fa3d8806a680a0bc03678c7cbf2b93`;
- Microvlinders bundel 2: `ee240b11ee492aaf0a0e95bec725f0904380faab377c2cf767b0e3b63f1b7175`;
- Microvlinders bundel 3: `0115ac8bd8bb0f40fc5539639fa0dd59ccc044dd5e3cce9b2dc548d0bb22fcb1`.

De twee resterende plaatsen in die ronde zijn gebruikt voor Mossen bundels 1
en 2. Ook deze GeoPackages hebben de laag `waarnemingen` en CRS EPSG:28992; ze
bevatten respectievelijk 11.922 en 11.916 records. De selectie-URL's in Gmail
komen exact overeen met de eerste twee vaste hokkenbundels. De
SHA-256-controlesommen zijn:

- Mossen bundel 1: `d5521f4a55f5de4eea00970f51cb9d8b4f6826a292be459fc2f8596162569842`;
- Mossen bundel 2: `815ff4a1c04cfa1fe1e5b986ad16fe0519b501490266c9fe65db33bb872aac57`.

De volgende ronde op 16 augustus 2026 tussen 16:35 en 16:40 uur lokale tijd
benutte opnieuw alle vijf beschikbare aanvragen. Mossen bundel 3 bevat 10.459
records, waardoor Mossen volledig is afgedekt. Nachtvlinders is met drie
GeoPackages van respectievelijk 22.599, 23.228 en 29.147 records eveneens
volledig afgedekt. Ongewervelden (overig) bundel 1 bevat 938 records. Alle vijf
bestanden hebben de laag `waarnemingen`, CRS EPSG:28992 en een selectie-URL die
exact overeenkomt met de aangevraagde hokkenbundel. De
SHA-256-controlesommen zijn:

- Mossen bundel 3: `86e5171a46561f44e747dc42b240f028672116f3992665c9dac4dba8f851cb83`;
- Nachtvlinders bundel 1: `538038b37e5fae0e6c761e9bbafaf4bdd2fdd16a2b6667a0371ca9eb7abe2c3f`;
- Nachtvlinders bundel 2: `8fc7f4c72da77411feaa87ef172c86987d68f864dc3952e61ca7b0e4073e1098`;
- Nachtvlinders bundel 3: `f39e8a738a8c36ac75f04defc14e9a21d467c0e0a3a326e765ac8b5563039033`;
- Ongewervelden (overig) bundel 1: `c693439320f3c44a0f94dcf3a18454438945c03caeaa6f91a84c3ef0b6b31f99`.

De ronde van 16 augustus 2026 tussen 17:53 en 17:57 uur lokale tijd dekte
Ongewervelden (overig) en Reptielen volledig af. Ongewervelden (overig)
bundels 2 en 3 bevatten respectievelijk 691 en 302 records. Reptielen bundels
1, 2 en 3 bevatten respectievelijk 1.528, 1.585 en 874 records. Alle vijf
bestanden hebben de laag `waarnemingen`, CRS EPSG:28992 en een selectie-URL die
exact overeenkomt met de aangevraagde hokkenbundel. De
SHA-256-controlesommen zijn:

- Ongewervelden (overig) bundel 2: `5ae74dea1087abddbfa3511c1015a2315d902f964aa97c1e9cf9e2df8c8609a5`;
- Ongewervelden (overig) bundel 3: `fdd598dde6f44d91aaf98836c451d1eca3234d642341dc084e6f8fb8169d7df5`;
- Reptielen bundel 1: `c6ae0c63e6e413ed56cdd90ca0837a48cae2d692b6e2c2450a0f72cd3a855d58`;
- Reptielen bundel 2: `0cec8456a98bf2b7e0959afd519a4e1417875ca58302a796c5a88d35047df26f`;
- Reptielen bundel 3: `fe7188851cd5320be3d74b976a964ac244e83861e2c2b98bf80b0cb1b3c073be`.

De eerstvolgende vrijvallende uurreeks begint met Schimmels bundels 1, 2 en 3
en wordt, als de gecontroleerde resultaataantallen dit toelaten, aangevuld met
Snavelinsecten bundels 1 en 2. Ieder vrijvallend uur wordt tot maximaal vijf
unieke aanvragen benut.

Door vertraagde e-mailbevestigingen zijn eerder Eencelligen-bundel 2,
Geleedpotigen-bundel 3 en Insecten-bundel 1 dubbel geleverd. De paren hebben
respectievelijk 57, 75 en 702 records en binnen ieder paar exact dezelfde
`Identiteit`-waarden. Behandel deze leveringen als exportoverlap en niet als
afzonderlijke waarnemingssets. Controleer na iedere verzending zowel de
pagina-status als Gmail voordat een aanvraag wordt herhaald.

### Relatie met kavels

Het doel is dat iedere NDFF-waarneming net als territoria en dagwaarnemingen via
`plot_id` in analyses per Meijendel-kavel kan worden gebruikt. NDFF-locaties zijn
echter vaak vlakken en kunnen meerdere kavels raken. Daarom geldt:

1. bewaar altijd de oorspronkelijke geometrie, de ruwe FFV-vervagingswaarde,
   een afzonderlijke vervagingsstatus en het vervagingsniveau;
2. bereken de koppeling reproduceerbaar tegen de versie van de
   Meijendel-plotpolygonen die bij de import is vastgelegd;
3. bewaar iedere geraakte `plot_id` in een koppeltabel met ruimtelijke methode,
   overlapoppervlak en waar mogelijk overlapaandeel;
4. wijs een waarneming alleen rechtstreeks aan een enkel plot toe als de
   geometrie dat eenduidig ondersteunt;
5. presenteer een vervaagd kilometerhok nooit als een exacte vindplaats.

Pas daarna de ruimtelijke toelating toe tegen één vastgelegde versie van de
SOVON-plotlaag:

- geen intersectie met een SOVON-plot: niet opnemen in de database; registreer
  de uitsluitingsreden en aantallen wel in de importaudit;
- één voldoende precieze, eenduidige plotintersectie: kandidaat voor directe
  `plot_id`-koppeling;
- meerdere plotintersecties, grote tel-/zoekpolygonen of 1 km/5 km-vervaging:
  bewaar hoogstens als onzeker kandidaatrecord met alle geraakte plots en
  overlapmaten, maar gebruik het standaard niet als aanwezigheid per plot;
- leg versie en SHA van de gebruikte SOVON-plotlaag vast, zodat de selectie
  reproduceerbaar kan worden herhaald.

Deze aanpak verwijdert waarnemingen buiten de plots uit de database, maar een
geometrische intersectie alleen lost de onzekerheid van vervaagde of grote
polygonen niet op. Daarvoor blijft de ruimtelijke kwaliteitsklasse noodzakelijk.

### Voorgestelde databasestructuur voor ruimtelijke zekerheid

Gebruik een gedeelde technische kern en houd de biologische waarnemingen per
oorspronkelijke FFV-soortgroep gescheiden:

- `ndff_import`: één rij per ontvangen GeoPackage met bestandsnaam, SHA-256,
  aanvraagfilters, periode, FFV-peildatum, bronvermelding en recordtellingen;
- `ndff_waarneming_register`: één globale `ndff_id` per ontdubbeld bronrecord,
  met `Identiteit`, oorspronkelijke FFV-soortgroep en toegewezen hoofdgroep;
- `ndff_import_record`: veel-op-veelherkomst tussen `import_id` en `ndff_id`, met
  het oorspronkelijke record-/FID-nummer, zodat zichtbaar blijft in welke
  GeoPackages hetzelfde record voorkwam;
- `ndff_<soortgroep>`: de biologische en temporele velden per oorspronkelijke
  FFV-soortgroep, bijvoorbeeld `ndff_amfibieen`, met `ndff_id` als foreign key
  naar het register;
- `ndff_waarneming_geometrie`: één canonieke brongeometrie per `ndff_id` in
  EPSG:28992, met oppervlakte en de berekende ruimtelijke hoofdklasse;
- `ndff_waarneming_plot`: uitsluitend ruimtelijk voldoende betrouwbare relaties
  tussen `ndff_id` en `plot_id`, met methode, overlapoppervlak, overlapaandeel en
  versie van de SOVON-plotlaag;
- `ndff_vervaagde_waarneming`: aparte één-op-éénuitbreiding voor 1 km-, 5 km- en
  eventuele andere vervagingsniveaus, met vervagingsniveau, reden voor zover
  aangeleverd en het toegestane gebruik `alleen_grove_schaal`;
- `ndff_gebiedswaarneming`: aparte één-op-éénuitbreiding voor niet-vervaagde,
  maar niet eenduidig aan één plot toe te wijzen bronpolygonen;
- `ndff_onzekere_plot_overlap`: optionele kandidaatkoppelingen voor vervaagde en
  gebiedswaarnemingen, met overlapmaten en expliciet
  `is_aanwezigheid_per_plot = 0`.

De vervaagde en gebiedstabellen bevatten geen tweede kopie van soort, datum,
bronhouder of geometrie: die blijven respectievelijk in de hoofdgroeptabel en
`ndff_waarneming_geometrie`. De uitzonderingslagen bevatten alleen aanvullende
ruimtelijke status en kwaliteitskenmerken. Daarmee blijven categorieën apart
analyseerbaar zonder dezelfde bronwaarneming dubbel op te slaan.

Classificeer iedere ontdubbelde waarneming in deze volgorde:

1. `Vervaging` gevuld: registreer in `ndff_vervaagde_waarneming`; maak geen
   reguliere plotkoppeling;
2. niet vervaagd en geen intersectie met de SOVON-plotunie: niet importeren en
   alleen als telling per uitsluitingsreden in de importaudit opnemen;
3. niet vervaagd en volledig/eenduidig binnen één plot: reguliere koppeling in
   `ndff_waarneming_plot` met methode `binnen_een_plot`;
4. niet vervaagd en meerdere of gedeeltelijke plotintersecties: bereken
   geometrieoppervlak, aantal plots, centroidplot, totaal overlapaandeel en het
   hoogste overlapaandeel per plot;
5. alleen na validatie van een nog vast te stellen dominante-overlapregel mag
   zo'n record een reguliere plotkoppeling krijgen; anders registreer het in
   `ndff_gebiedswaarneming` en hoogstens in
   `ndff_onzekere_plot_overlap`.

Stel de dominante-overlapdrempel niet vooraf willekeurig vast. Toets bijvoorbeeld
een startvoorstel van 90% overlap plus centroid in hetzelfde plot op de volledige
geïntegreerde dataset en controleer grensgevallen visueel. Geometrieoppervlak moet
worden beoordeeld ten opzichte van de plotgrootte en bronmethode; een vaste
oppervlaktedrempel voor alle soortgroepen is niet verdedigbaar.

Voor de 558 niet-vervaagde geometrieën uit de Amfibieën-proef die buiten hok
83-461 doorlopen geldt daarom: dit feit alleen zegt niet dat ze onbruikbaar zijn.
Het hok was de zoekselectie. De records worden op bovenstaande regels getoetst;
eenduidige geometrieën krijgen een plotkoppeling, ambigue of grote polygonen gaan
naar `ndff_gebiedswaarneming`, en geometrieën zonder SOVON-plotintersectie worden
niet geïmporteerd.

Deze koppeling maakt selectie per kavel mogelijk, maar verandert een losse
NDFF-waarneming niet in een gestandaardiseerde telling. Niet waargenomen of niet
gemeld blijft onbekend en wordt niet als nul opgeslagen.

### Beslisfase voor vervaging en waarnemingsmethode

Neem het definitieve besluit over vervaagde waarnemingen pas nadat alle
GeoPackages zijn ontvangen, gevalideerd, geïntegreerd en ontdubbeld. Beoordeel
dan niet alleen het vervagingspercentage, maar per soortgroep, soort en tijdvak:

- de verdeling tussen niet vervaagd, 1 km, 5 km en eventuele andere niveaus;
- `Protocol`, `Telonderwerp`, `Schaal (telmethode)`, `Determinatiemethode`,
  `Zoek- of vangmethode`, `Bronhouder` en ruimtelijke nauwkeurigheid;
- ontbrekende methodevelden en veranderingen in bron, protocol of methode door
  de tijd;
- of de gegevens aantoonbaar eenmalige losse meldingen, periodieke maar
  niet-gestandaardiseerde waarnemingen of structurele protocolreeksen zijn;
- welke analyse op grond daarvan verantwoord is: alleen regionale aanwezigheid,
  beschrijvende frequentie, plotkoppeling of een eventueel gestandaardiseerde
  tijdreeks.

Herhaling alleen bewijst geen structurele monitoring: daarvoor zijn een
herhaalbaar protocol, bekende ruimtelijke dekking en informatie over
waarnemingsinspanning nodig. Beoordeel de kwaliteit van waarnemers of
determinaties alleen als de levering expliciete kwaliteits-, validatie- of
expertisegegevens bevat. Als die ontbreken, registreer de kwaliteit als
`niet_beoordeelbaar` en maak geen afgeleide rangschikking op basis van aantallen
of zeldzaamheid. Leg het uiteindelijke inclusie-, uitsluitings- of
beperkingsbesluit per analysetype reproduceerbaar vast vóór database-import.

### Importvolgorde

1. rond alle aanvragen voor 1950 tot en met 2025 af;
2. valideer ieder bestand, laag, CRS, velden en recordaantal;
3. registreer alle bronbestanden en SHA-waarden;
4. bouw de geïntegreerde stagingdataset en ontdubbel controleerbaar;
5. valideer taxon- en categorie-mapping;
6. analyseer vervaging, methode, methodewisselingen en onderzoeksstructuur en
   leg het definitieve gebruiksbesluit per analysetype vast;
7. bereken plotintersecties en ruimtelijke kwaliteitsklassen;
8. sluit records zonder SOVON-plotintersectie uit en registreer de uitsluiting;
9. laad pas daarna de goedgekeurde records in de tabellen per FFV-soortgroep en
   plotkoppeltabel;
10. publiceer of analyseer pas na integriteitscontroles.

## 17. Hoe werkt ruimtelijke data koppelen aan plots?

Het uitgangspunt is:

- volledige raster- of vectorbestanden blijven buiten MySQL
- in MySQL sla je alleen samengevatte waarden per plot en jaar op

Voorbeelden:

- gemiddelde hoogte
- stikstofdepositie
- landgebruik per klasse

### Werkwijze

Werk in vaste volgorde:

1. AHN
2. Stikstof
3. Landgebruik

Begin dus niet meteen met alles tegelijk.

### Belangrijke regel

Controleer steeds:

- dat lagen in `EPSG:28992` staan
- dat je het juiste jaar van de plotgrenzen gebruikt
- dat elk `plot_id + jaar` ook bestaat in `plot_jaar_oppervlak`

### Eerste proef

Voer eerst alleen AHN uit:

1. juiste plotlaag kiezen
2. AHN-bestand laden
3. zonal statistics uitvoeren
4. CSV exporteren
5. importeren in `plot_jaar_ahn_dtm`

Stop daarna en controleer eerst het resultaat.

## 18. Hoe zit recreatie en infrastructuur in het model?

Voor recreatie en infrastructuur zijn twee soorten gegevens onderscheiden:

### 17.1 Numerieke variabelen

Die gaan in `plot_jaar_infra`.

Voorgestelde variabelen zijn:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`

### 17.2 Toegankelijkheidsstatus

Die hoort in een aparte tabel:

- `plot_jaar_toegankelijkheid`

Mogelijke waarden:

- `afgesloten`
- `beperkt`
- `vrij`

Reden:

- dit is een status en geen meetgetal

Voor gedeeltelijke toegankelijkheid bestaat daarnaast:

- `plot_jaar_toegankelijkheid_deel`

Die tabel gebruik je als een plot niet volledig `afgesloten`, `beperkt` of `vrij` is.

Daar leg je per deel vast:

- welk deel het is
- welke status daar geldt
- welk percentage van het plot het betreft
- welk hek, raster of andere barrière relevant is
- eventueel de geometrie van dat deel

### 17.3 Bezoekersdruk

Bezoekersdruk uit het Dunea-rapport hoort voorlopig niet direct in `plot_jaar_infra`.

Reden:

- die bron werkt met gebieden, telpunten en parkeerlocaties
- niet met directe plotwaarden

## 19. Welke bronnen gebruik je voor recreatie?

### BGT

Gebruik voor:

- paden
- wegen
- geometrische controle

### OpenStreetMap

Gebruik voor:

- parkeerplaatsen
- voorzieningen
- aanvullende infrastructuur

### Handmatige lijst

Gebruik voor:

- hoofdtoegangen

### Dunea-rapport 2022

Gebruik niet rechtstreeks voor plotafstanden.

Gebruik dit rapport wel later voor een aparte bezoekersdruklaag.

## 20. Hoe verwerk je recreatiedata uit BGT en OSM?

De basisregel is:

- bereken eerst de ruimtelijke uitkomsten buiten MySQL
- importeer daarna alleen de samenvatting per `plot_id` en `jaar`

Doelbestand:

- `Recreatie/plot_jaar_infra_recreatie_import.csv`

Het bijbehorende script berekent:

- afstand tot dichtstbijzijnd pad
- padlengte binnen plot per hectare
- afstand tot dichtstbijzijnde parkeerplaats
- afstand tot dichtstbijzijnde hoofdtoegang

Controleer daarna altijd:

- heeft elk plot de verwachte variabelen?
- zijn alle afstanden groter dan of gelijk aan 0?
- is `padlengte_m_per_ha` logisch?
- bestaan alle `plot_id + jaar` combinaties in `plot_jaar_oppervlak`?

Daarna pas importeer je de output in MySQL.

## 21. Wat zijn de importbestanden voor recreatie?

Er zijn twee hoofdimportbestanden:

### `plot_jaar_infra_recreatie_import.csv`

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `variabele`
- `waarde`

Toegestane variabelen:

- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`

### `plot_jaar_toegankelijkheid_import.csv`

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `status_code`
- `opmerking`

Toegestane statuscodes:

- `afgesloten`
- `beperkt`
- `vrij`

Belangrijk:

Elke rij moet verwijzen naar een bestaande combinatie van `plot_id` en `jaar` in `plot_jaar_oppervlak`.

Anders krijg je een foreign key-fout.

### `plot_jaar_toegankelijkheid_deel_import.csv`

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `deel_label`
- `status_code`
- `aandeel_pct`
- `barriere_type`
- `geom_wkt`
- `opmerking`

Gebruik dit bestand voor plots met meerdere toegankelijkheidsdelen.

### `plot_jaar_maatregel_import.csv`

Kolommen:

- `plot_id`
- `jaar`
- `bron`
- `maatregel_id`
- `intensiteit_code`
- `uitvoerder_of_diersoort`
- `deel_label`
- `dekking_pct`
- `opmerking`

Gebruik dit bestand voor beheermaatregelen per plot en jaar.

Belangrijk:

- `maatregel_id` verwijst naar `maatregelen`
- `Begrazing` specificeer je hier verder met:
  - `intensiteit_code`
  - `uitvoerder_of_diersoort`
- hiermee kun je onderscheid maken tussen bijvoorbeeld extensieve en intensieve begrazing en tussen schapen, runderen of paarden

## 22. Wat is de bezoekersdruklaag?

Voor bezoekersdruk uit het Dunea-rapport is een apart model ontworpen.

De drie voorgestelde tabellen zijn:

- `bezoekersdruk_locatie`
- `bezoekersdruk_meting`
- `plot_bezoekersdruk_koppeling`

Waarom apart?

- het rapport bevat vooral telpunten, parkeerlocaties en gebiedsgegevens
- de koppeling naar `plot_id` is niet automatisch gegeven

Praktische regel:

- afstands- en padvariabelen mogen direct per plot
- bezoekersdruk uit rapport nog niet

## 23. Belangrijke uitzondering: afstand tot hoofdtoegang

Voor een aantal plots is de gewone berekening van `afstand_hoofdtoegang_m` niet goed genoeg.

Daar geldt een uitzonderingsregel:

1. eerst afstand van de dichtstbijzijnde hoofdtoegang tot een vast tussenpunt
2. daarna afstand van dat tussenpunt tot het plot

De formule is dus:

`afstand_hoofdtoegang_m = afstand(hoofdingang, tussenpunt) + afstand(tussenpunt, plot)`

Deze regel geldt voor 16 specifieke plots, waaronder:

- `75`
- `10-12-76`
- `8`
- `7`
- `6`
- `4-5`
- `61`
- `62`
- `71`
- `72`
- `73`
- `74`
- `12a`

Belangrijk:

Als je later `plot_jaar_infra` opnieuw volledig vult vanuit een ouder importbestand of een oude berekening, kunnen deze handmatig gecorrigeerde waarden worden overschreven.

Daarom moet deze uitzondering in toekomstige herberekeningen worden meegenomen.

## 23A. Hoe wordt het PQ-vegetatiemeetnet gebruikt?

De aangeleverde vegetatiegegevens worden rechtstreeks in de levende MySQL-database `Meijendel` beheerd. Bewerk of plak deze brondata niet handmatig in `meijendel.sql`.

De genormaliseerde tabellen zijn:

- `pq_vegetatie_import`: versie, SHA-256, voorlopige/definitieve status en tellingen per ontvangen bronbestand
- `pq_vegetatie_pq`: vaste identiteit en meetperiode per PQ, gekoppeld aan de importbatch
- `pq_vegetatie_opname`: één regel per opname, inclusief datum en historische RD-geometrie; een afwijkende nieuw aangeleverde bodemcode blijft apart staan tot PZH deze bevestigt
- `pq_vegetatie_taxon`: aangeleverde `SRTNUM` plus soortenlijstversie en de Nederlandse/Latijnse bronnaam; officiële taxoncodes blijven apart en mogen pas na broncontrole worden ingevuld
- `pq_vegetatie_waarneming`: taxon, abundantie, ruwe `PLABED`-code en aangeleverde indicatorvelden per opname
- `pq_vegetatie_opname_plot`: reproduceerbare koppeling van iedere historische opname aan een Avimap-kavel
- `pq_plot_jaar_vegetatie`: veilige analysekorrel `plot_id + jaar`

De afgeleide plot-jaartabel bevat uitsluitend jaren waarin werkelijk PQ's zijn opgenomen. Er wordt niet geïnterpoleerd. De hoofdvariabelen zijn:

- aantal PQ's en opnamen
- totaal aantal aangetroffen taxa in het plot-jaar
- gemiddelde soortenrijkdom per PQ
- gemiddelde som van bedekkingspercentages per PQ
- gemiddelde Shannon-index per PQ
- dekkingskwaliteit op basis van het aantal PQ's

Soortenrijkdom en Shannon gebruiken `SRTNUM` als stabiele identiteit. De export van 17 juli 2026 is voorlopig zolang PZH en CBS de historische meetnetdata controleren. `PLABED` wordt uitsluitend als ruwe broncode bewaard; de bedekkingssom blijft gebaseerd op `ABUNDANTP`. Trofie-, vocht- en zuurindicatoren worden niet als covariaat gebruikt zolang de bronvelden niet door PZH/CBS zijn bevestigd.

GEE, GLMM, NMDS/envfit en occupancy mogen deze waarden als optionele covariaten gebruiken. Toon bij iedere interpretatie ook het aantal PQ's of de dekkingskwaliteit. De publieke website gebruikt uitsluitend `website_plot_vegetatie_jaar`; ruwe taxa, PQ-nummers en coördinaten blijven intern.

## 24. Wat zijn de belangrijkste praktische regels?

Houd deze regels aan:

1. Maak altijd eerst een backup vóór import of grote wijziging.
2. Werk in kleine stappen en controleer na elke stap.
3. Trek geen conclusies uit een analyse die je nog niet in `Controle` hebt nagekeken.
4. Gebruik Shiny om te rekenen, HTML om te bekijken.
5. Gebruik MSI voor groepsontwikkeling, niet als directe maat voor totale aantallen.
6. Sla in MySQL alleen samengevatte ruimtelijke waarden op, niet hele bronlagen.
7. Koppel alleen gegevens direct aan plots als die koppeling verdedigbaar is.
8. Leg wijzigingen vast in Git.

## 25. Waar moet je extra voorzichtig mee zijn?

Extra aandacht is nodig bij:

- ontbrekende tellingen
- veranderend plotoppervlak
- de methodebreuk rond 1984
- soorten met zwakke of onstabiele TRIM-modellen
- recreatiegegevens die niet direct per plot beschikbaar zijn
- handmatige uitzonderingen zoals de afstand tot hoofdtoegang

## 26. Welke bestanden zijn het belangrijkst om mee te beginnen?

Als je opnieuw instapt in het project, begin dan met:

1. `handboek.md`
2. `README.md`
3. `EINDHANDLEIDING_html_en_shiny.md`
4. `README_shiny_meijendel.md`
5. `README_bmp_meijendel_index.md`
6. `CONTROLESET_html_shiny.md`

Als je daarna een specifiek onderwerp wilt uitwerken, ga dan pas naar:

- `R/trim_soorten_en_msi_evg.md`
- `R/trim_sandra_soorten_en_msi_evg.md`
- `R/analyse_ecologische_groepen.md`
- `import_procedure_territoria.md`
- de documenten in `Recreatie/`
- de documenten in `Ruimtelijke data/`

## 27. Samenvatting in één zin

De Meijendel-database is een inhoudelijk rijke vogel- en omgevingsdatabase waarbij je de SQL-dump als bron gebruikt, de Shiny-app voor nieuwe analyses, de HTML voor overzicht en presentatie, en QGIS plus aanvullende scripts voor ruimtelijke en recreatieve uitbreidingen.
