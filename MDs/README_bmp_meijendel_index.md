# Handleiding index.html

Dit bestand is een korte gebruiksaanwijzing voor [bmp\_meijendel\_index.html][1].

De HTML is bedoeld om gegevens uit de database Meijendel zichtbaar en begrijpelijk te maken, ook voor gebruikers zonder veel statistische kennis.

De algemene werkwijze voor Shiny + HTML samen staat in:

- `/Users/ton/Documents/GitHub/Meijendel/EINDHANDLEIDING_html_en_shiny.md`

De HTML is vooral een kijk- en controlebestand, niet de plek waar nieuwe TRIM-berekeningen worden gemaakt.

## Tab Trend

In `Trend` zijn er drie keuzes.

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

## Tab MSI

In `MSI` zijn er twee keuzes.

### 1. GAM (dichtheid)

Dit is de bestaande benadering op basis van dichtheid en GAM-trendlijnen.
Bron:

- `gam_voorspellingen_per_groep.csv`
- `gam_interpretatie_per_groep.csv`

### 2. TRIM-MSI

Dit is de MSI op basis van TRIM-soortindices.
Gebruik deze keuze als je de ontwikkeling van ecologische vogelgroepen wilt bekijken met dezelfde trendlogica als bij TRIM per soort.

Je ziet:

- de TRIM-MSI grafiek
- een korte uitleg per groep

Bron:

- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`
- eventueel ook `gam_voorspellingen_msi_groepen.csv`
- eventueel ook `gam_interpretatie_msi_groepen.csv`

## Tab Tellers

De HTML gebruikt dan onder andere:

- `tellers`
- `plot_jaar_teller`
- `plots`

## Belangrijk om te onthouden

`Territoria`, `Dichtheid`, `TRIM-index`, `GAM (dichtheid)` en `TRIM-MSI` zijn niet precies hetzelfde.

Ze beantwoorden verschillende vragen:

- ruwe aantallen
- aantallen per oppervlakte
- trend per soort
- vloeiende groepslijn
- TRIM-gebaseerde groepsindicator

Daarom is het goed dat ze in de HTML apart zichtbaar blijven.

Voor een vaste controleset kun je ook kijken in:

- `/Users/ton/Documents/GitHub/Meijendel/CONTROLESET_html_shiny.md`

[1]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
