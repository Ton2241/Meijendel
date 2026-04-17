# TRIM-analyse Sandra-variant

Dit script maakt een nieuwe, strikte Sandra-variant naast de bestaande lange TRIM-reeks.

Het script:

- gebruikt alleen de periode `1997-2022`
- gebruikt alleen de 25 Sandra-plots
- laat de bestaande lange output in `trim/soorten` en `trim_msi_evg` ongemoeid
- behandelt niet-getelde plotjaren als `NA`
- behandelt wel-getelde maar niet-waargenomen soorten als `0`
- gebruikt dezelfde verbeterde TRIM-logica als de lange analyse: eerst een volledig model, daarna automatisch eenvoudigere modellen als dat nodig is
- berekent daarna een MSI per ecologische 100-groep

## Plotselectie

Deze Sandra-variant gebruikt:

`1a, 1b, 3, 4-5, 6, 7, 8, 10-12-76, 12a, 13, 13s, 14, 15, 16, 17a, 17b, 45, 54a, 62, 71, 72, 73, 74, 75, 83`

## Soortselectie

De soortselectie is nu bewust ruimer dan in Sandra’s artikel:

- alle soorten worden meegenomen die in deze 25 plots en in `1997-2022` minstens één keer territoria hebben
- de MSI wordt daarna alleen opgebouwd uit soorten waarvoor het TRIM-model ook echt een bruikbare jaarindex oplevert

De feitelijke selectie wordt weggeschreven naar:

- `trim/sandra/soorten/soorten_selectie_sandra.csv`

## Uitvoer

Soorten:

- `trim/sandra/soorten/analysebasis_plot_jaar.csv`
- `trim/sandra/soorten/soorten_selectie_sandra.csv`
- `trim/sandra/soorten/soorten_modelstatus.csv`
- `trim/sandra/soorten/soorten_status_samenvatting.csv`
- `trim/sandra/soorten/soortindices_per_jaar.csv`
- `trim/sandra/soorten/soorten_trendoverzicht.csv`

Groepen:

- `trim/sandra/trim_msi_evg/groepssamenstelling_100tal.csv`
- `trim/sandra/trim_msi_evg/msi_per_groep_per_jaar.csv`
- `trim/sandra/trim_msi_evg/trendoverzicht_msi_groepen.csv`

## Uitvoeren

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.R
```

Met expliciete paden:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_sandra_soorten_en_msi_evg.R \
  /Users/ton/Documents/GitHub/Meijendel/Meijendel.sql \
  /Users/ton/Documents/GitHub/Meijendel/trim/sandra/soorten \
  /Users/ton/Documents/GitHub/Meijendel/trim/sandra/trim_msi_evg
```
