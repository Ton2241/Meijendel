# Handleiding index.html

Dit bestand is een korte gebruiksaanwijzing voor [bmp\_meijendel\_index.html][1].

De HTML is bedoeld om gegevens uit de database Meijendel zichtbaar en begrijpelijk te maken, ook voor gebruikers zonder veel statistische kennis.

De algemene werkwijze voor Shiny + HTML samen staat in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`

De HTML is vooral een kijk- en controlebestand, niet de plek waar nieuwe TRIM-berekeningen worden gemaakt.

## Tab BMP-Soorten

In `BMP-Soorten` zijn er drie keuzes.

### 1. Territoria

Dit laat de ruwe aantallen territoria per soort of per groep zien.
Bron:
rechtstreeks uit `Meijendel.sql`

### 2. Dichtheid (per km²)

Dit laat aantallen per oppervlakte zien.
De HTML gebruikt hiervoor nu het werkelijke oppervlak uit `plot_jaar_oppervlak`.
Als `plot_jaar_teller` aanwezig is, wordt alleen het bemeten oppervlak meegenomen.
Bron:
`Meijendel.sql`, plus oppervlak uit `plot_jaar_oppervlak` en telling uit `plot_jaar_teller`

### 3. TRIM-index

Dit is de beste keuze als je de langjarige trend van een soort wilt bekijken, vooral bij:

- ontbrekende tellingen
- verschillen in meetinspanning
- de methodebreuk rond 1984

Praktisch:

1. Open de tab `Trend`
2. Kies `TRIM-index`
3. Kies daarna een soort

Dan zie je:

- de TRIM-grafiek
- een korte uitleg zoals `matige afname`, `lichte toename` of `stabiel`

Bron:

- `soortindices_bruikbare_tijdreeks.csv`
- `soorten_trendoverzicht_bruikbare_tijdreeks.csv`
- aanvullend `soortindices_per_jaar.csv` en `soorten_trendoverzicht.csv` voor soorten met `alleen_post_bruikbaar`

Soorten met `alleen_post_bruikbaar` hebben geen bruikbare reeks voor de periode voor 1984.
Het dashboard toont voor die soorten wel de Meijendel-TRIM vanaf het eerste bruikbare post-1984 jaar.
Voor soorten die al in `soortindices_bruikbare_tijdreeks.csv` staan, blijft die volledige reeks leidend.

## Tab Groepen

In `Groepen` zijn er twee keuzes.

### 1. Dichtheid per km2

Dit is de bestaande benadering op basis van dichtheid en GAM-trendlijnen.
Bron:

- `gam_voorspellingen_per_groep.csv`
- `gam_interpretatie_per_groep.csv`

### 2. TRIM

Dit is de groepsindex op basis van TRIM-soortindices.
Gebruik deze keuze als je de ontwikkeling van ecologische vogelgroepen wilt bekijken met dezelfde trendlogica als bij TRIM per soort.
Trendlabels zijn eigen trendduidingen op basis van de TRIM-index; het zijn geen officiële TRIM-classificaties.
Index 100 betekent per soort het eerste analysejaar vanaf het eerste positieve jaar; soorten kunnen dus verschillende basisjaren hebben.

Je ziet:

- een eerste TRIM-MSI grafiek met `Volledige MSI` en `Robuuste MSI`
- een tweede grafiek waarin de volledige Meijendel-TRIM-MSI als GAM met 95%-band wordt vergeleken met een landelijke GAM-lijn zonder band
- een korte uitleg per groep

Bron:

- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`
- eventueel ook `gam_voorspellingen_msi_groepen.csv`
- eventueel ook `gam_interpretatie_msi_groepen.csv`

Bij beide keuzes staan naast de ecologische groepen ook de groepen `Rode Lijst`, `Oranje Lijst` en `Rode en Oranjelijst`.
De `Oranje Lijst` wordt afgeleid uit `soort_richtlijn` met `richtlijn_id = 6`.
Bij elke groep toont het dashboard ook een tekstvak met de vogelsoorten die in de gekozen groep zitten.

De standaardperiode voor de groepengrafieken is `1990-2025`. De gebruiker kan deze periode in het dashboard blijven aanpassen.

## Tab Wintertellingen

De wintergrafiek toont per gekozen vogel een lijn met één punt per winterperiode.

### Periode

Een winterperiode loopt van september tot en met maart.
De labels in de grafiek gebruiken de laatste twee cijfers van de betrokken jaren:

- `00/01`
- `01/02`
- `02/03`

April tot en met augustus worden voor deze grafiek niet meegenomen.

### Berekening per punt

Per vogel en per periode wordt als volgt gerekend:

1. Selecteer alle `dagwaarnemingen_wv` voor september t/m maart.
2. Koppel elke waarneming aan het juiste seizoen via maand en jaar.
3. Sommeer eerst per combinatie `soort + datum + plot`.
4. Zoek het plotoppervlak op in `plot_jaar_oppervlak` voor hetzelfde `plot_id + jaar`.
5. Deel het dag-plottotaal door `oppervlakte_km2`.
6. Sommeer deze oppervlakgecorrigeerde dag-plotwaarden per seizoen.

De y-as is daardoor:

`gesommeerde aantallen per km2`

Deze aanpak voorkomt dat meerdere records op dezelfde dag en in hetzelfde plot eerst los door het oppervlak worden gedeeld. Eerst wordt binnen datum en plot opgeteld, daarna pas gecorrigeerd voor oppervlak.

## Tab Tellers

De HTML gebruikt dan onder andere:

- `tellers`
- `plot_jaar_teller`
- `plots`

## Belangrijk om te onthouden

`Territoria`, `Dichtheid`, `TRIM-index`, `Dichtheid per km2`, `TRIM` en de wintertellinggrafiek zijn niet precies hetzelfde.

Ze beantwoorden verschillende vragen:

- ruwe aantallen
- aantallen per oppervlakte
- trend per soort
- vloeiende groepslijn
- TRIM-gebaseerde groepsindicator
- winteraantallen gecorrigeerd per plotoppervlak en samengevat per september-maartseizoen

Daarom is het goed dat ze in de HTML apart zichtbaar blijven.

Voor een vaste controleset kun je ook kijken in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md`

[1]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
