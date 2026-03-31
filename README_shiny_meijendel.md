# Shiny-app Meijendel

Dit is een eerste werkende Shiny-opzet voor vrije TRIM-selecties op kavels.

De app staat in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R`

## Wat deze eerste versie kan

- kavels kiezen
- een begin- en eindjaar kiezen
- per soort een nieuwe TRIM-analyse draaien
- per ecologische groep een nieuwe MSI berekenen
- de resultaten direct tonen in dezelfde app

Tabbladen:

- `Selectie`
- `Soorten`
- `Groepen`
- `Controle`

## Nodige packages

Voor deze app zijn in elk geval nodig:

- `shiny`
- `rtrim`

## Starten

Open R of RStudio en voer uit:

```r
setwd("/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel")
shiny::runApp()
```

## Belangrijke beperking van deze eerste versie

Deze versie is vooral bedoeld als eerste werkmodel.

Er zit nog niet in:

- kaartweergave van kavels
- opslaan van resultaten naar csv
- meerdere lijnen tegelijk in de soortgrafiek
- onzekerheidsbanden in de grafieken
- caching van eerdere berekeningen

Maar methodisch doet deze versie wel al wat nodig is:

- opnieuw rekenen voor de gekozen kavels
- correcte `0` voor wel geteld maar niet aanwezig
- lege waarde voor niet geteld
- TRIM per soort
- MSI per ecologische groep
