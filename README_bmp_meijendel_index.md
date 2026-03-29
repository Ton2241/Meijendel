# Handleiding bmp_meijendel_index.html

Dit bestand is een korte gebruiksaanwijzing voor [bmp_meijendel_index.html](/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html).

De HTML is bedoeld om gegevens uit de database Meijendel zichtbaar en begrijpelijk te maken, ook voor gebruikers zonder veel statistische kennis.

## Wat moet je altijd eerst laden?

Laad eerst het SQL-bestand van de database, bijvoorbeeld:

- [meijendel.sql](/Users/ton/Documents/GitHub/Meijendel/meijendel.sql)

Dat doe je in de HTML met de knop `SQL-bestand kiezen` of `Nieuw bestand`.

Zonder dit SQL-bestand werken de tabs `Trend` en `Tellers` niet goed, omdat de HTML daaruit de soorten, kavels, jaren en tellers haalt.

## Tab Trend

In `Trend` zijn er drie keuzes.

### 1. Territoria

Dit laat de ruwe aantallen territoria per soort of per groep zien.

Hiervoor hoef je geen extra csv-bestanden te laden.
Alleen het SQL-bestand is genoeg.

### 2. Dichtheid (per km²)

Dit laat aantallen per oppervlakte zien.
De HTML gebruikt hiervoor nu het werkelijke oppervlak uit `plot_jaar_oppervlak`.
Als `plot_jaar_teller` aanwezig is, wordt alleen het bemeten oppervlak meegenomen.

Hiervoor hoef je ook geen extra csv-bestanden te laden.
Alleen het SQL-bestand is genoeg.

### 3. TRIM-index

Dit is de beste keuze als je de langjarige trend van een soort wilt bekijken, vooral bij:

- ontbrekende tellingen
- verschillen in meetinspanning
- de methodebreuk rond 1984

Voor `TRIM-index` moet je twee csv-bestanden laden:

- [soortindices_bruikbare_tijdreeks.csv](/Users/ton/Documents/GitHub/Meijendel/trim/soorten/soortindices_bruikbare_tijdreeks.csv)
- [soorten_trendoverzicht_bruikbare_tijdreeks.csv](/Users/ton/Documents/GitHub/Meijendel/trim/soorten/soorten_trendoverzicht_bruikbare_tijdreeks.csv)

Praktisch:

1. Open de tab `Trend`
2. Kies `TRIM-index`
3. Laad eerst `soortindices_bruikbare_tijdreeks.csv`
4. Laad daarna `soorten_trendoverzicht_bruikbare_tijdreeks.csv`
5. Kies daarna een soort

Dan zie je:

- de TRIM-grafiek
- een korte uitleg zoals `matige afname`, `lichte toename` of `stabiel`

## Tab MSI

In `MSI` zijn er twee keuzes.

### 1. GAM (dichtheid)

Dit is de bestaande benadering op basis van dichtheid en GAM-trendlijnen.

Daarvoor laad je:

- het bestand met GAM-voorspellingen per groep
- het bestand met GAM-interpretatie per groep

In jouw eerdere werkwijze zijn dat doorgaans:

- `gam_voorspellingen_per_groep.csv`
- `gam_interpretatie_per_groep.csv`

### 2. TRIM-MSI

Dit is de nieuwe MSI op basis van TRIM-soortindices.
Gebruik deze keuze als je de ontwikkeling van ecologische vogelgroepen wilt bekijken met dezelfde trendlogica als bij TRIM per soort.

Voor `TRIM-MSI` laad je:

- [msi_per_groep_per_jaar.csv](/Users/ton/Documents/GitHub/Meijendel/trim_msi_evg/msi_per_groep_per_jaar.csv)
- [trendoverzicht_msi_groepen.csv](/Users/ton/Documents/GitHub/Meijendel/trim_msi_evg/trendoverzicht_msi_groepen.csv)

Praktisch:

1. Open de tab `MSI`
2. Kies `TRIM-MSI`
3. Laad eerst `msi_per_groep_per_jaar.csv`
4. Laad daarna `trendoverzicht_msi_groepen.csv`
5. Kies daarna een ecologische groep

Dan zie je:

- de TRIM-MSI grafiek
- een korte uitleg per groep

## Tab Tellers

Voor `Tellers` hoef je geen extra csv-bestanden te laden.

Hiervoor is alleen het SQL-bestand nodig.
De HTML gebruikt dan onder andere:

- `tellers`
- `plot_jaar_teller`
- `plots`

## Welke keuze gebruik je wanneer?

Gebruik `Territoria` als je de ruwe aantallen wilt zien.

Gebruik `Dichtheid (per km²)` als je eerlijke vergelijking wilt maken tussen jaren of gebieden met verschillende oppervlakken.

Gebruik `TRIM-index` als je de meest bruikbare langjarige trend per soort wilt begrijpen.

Gebruik `GAM (dichtheid)` als je een vloeiende groepsontwikkeling wilt zien op basis van dichtheid.

Gebruik `TRIM-MSI` als je een groepsindicator wilt zien die aansluit op de TRIM-analyse van soorten.

## Belangrijk om te onthouden

`Territoria`, `Dichtheid`, `TRIM-index`, `GAM (dichtheid)` en `TRIM-MSI` zijn niet precies hetzelfde.

Ze beantwoorden verschillende vragen:

- ruwe aantallen
- aantallen per oppervlakte
- trend per soort
- vloeiende groepslijn
- TRIM-gebaseerde groepsindicator

Daarom is het goed dat ze in de HTML apart zichtbaar blijven.
