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

## 2. Hoe is de repository opgebouwd?

Je werkt in de repository `Ton2241/Meijendel`.

Belangrijke onderdelen daarin zijn:

- `Meijendel.sql`: de eigenlijke database-export
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
2. laad `Meijendel.sql`
3. laad waar nodig extra CSV-bestanden
4. bekijk de uitkomsten

Als je nieuwe soort- of groepsanalyses wilt maken:

1. start de Shiny-app
2. laad `Meijendel.sql`
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

## 8. Hoe gebruik je de HTML?

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

- rechtstreeks uit `Meijendel.sql`

#### Dichtheid (per km2)

Dit zijn aantallen omgerekend naar oppervlak.

Gebruik dit als je jaren of gebieden eerlijker wilt vergelijken, vooral als plots in grootte verschillen.

Bron:

- `Meijendel.sql`
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

## 9. Wat is TRIM en waarom gebruik je het?

TRIM is een analysemethode voor tellingen over de tijd.

In dit project gebruik je TRIM vooral om soorttrends te berekenen op een manier die beter omgaat met:

- ontbrekende tellingen
- wisselende meetinspanning
- een methodologische breuk rond 1984

Belangrijk om te begrijpen:

- `territoria` is niet hetzelfde als `TRIM-index`
- `dichtheid` is niet hetzelfde als `TRIM-index`

Ze beantwoorden verschillende vragen.

## 10. Hoe werkt de hoofd-TRIM-analyse?

De hoofd-TRIM-analyse leest rechtstreeks `Meijendel.sql` in en maakt nieuwe output in:

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

- `Meijendel.sql` zonder fout laadt
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

- `README_trim_analyse.md`
- `README_trim_sandra_analyse.md`
- `README_ecologische_groepen.md`
- `import_procedure_territoria.md`
- de documenten in `Recreatie/`
- de documenten in `Ruimtelijke data/`

## 27. Samenvatting in één zin

De Meijendel-database is een inhoudelijk rijke vogel- en omgevingsdatabase waarbij je de SQL-dump als bron gebruikt, de Shiny-app voor nieuwe analyses, de HTML voor overzicht en presentatie, en QGIS plus aanvullende scripts voor ruimtelijke en recreatieve uitbreidingen.
