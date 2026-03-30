# Handleiding index.html

Dit bestand is een korte gebruiksaanwijzing voor [bmp\_meijendel\_index.html][1].

De HTML is bedoeld om gegevens uit de database Meijendel zichtbaar en begrijpelijk te maken, ook voor gebruikers zonder veel statistische kennis.

## Tab Trend

In `Trend` zijn er drie keuzes.

### 1. Territoria

Dit laat de ruwe aantallen territoria per soort of per groep zien.

### 2. Dichtheid (per km²)

Dit laat aantallen per oppervlakte zien.
De HTML gebruikt hiervoor nu het werkelijke oppervlak uit `plot_jaar_oppervlak`.
Als `plot_jaar_teller` aanwezig is, wordt alleen het bemeten oppervlak meegenomen.

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

## Tab MSI

In `MSI` zijn er twee keuzes.

### 1. GAM (dichtheid)

Dit is de bestaande benadering op basis van dichtheid en GAM-trendlijnen.
### 2. TRIM-MSI

Dit is de MSI op basis van TRIM-soortindices.
Gebruik deze keuze als je de ontwikkeling van ecologische vogelgroepen wilt bekijken met dezelfde trendlogica als bij TRIM per soort.

Je ziet:

- de TRIM-MSI grafiek
- een korte uitleg per groep

## Tab Tellers

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

[1]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html