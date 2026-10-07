# TRIM-analyse Sandra-variant

Dit script maakt een nieuwe, strikte Sandra-variant naast de bestaande lange TRIM-reeks.

Het script:

- gebruikt alleen de periode `1997-2022`
- gebruikt alleen de 25 Sandra-plots
- laat de bestaande lange output in `trim/soorten` en `trim_msi_evg` ongemoeid
- houdt een expliciete SOVON-nul als `0` en een lege SOVON-cel als `NA`
- gebruikt de gedeelde `jrvslg_m`-nulregel; binnen deze selectie ontstaan daaruit geen afgeleide nullen
- zet SOVON-uitkomsten van formeel afgekeurde plotjaren op `NA`, maar behoudt aanwezige onafhankelijke niet-SOVON-regels
- gebruikt dezelfde verbeterde TRIM-logica als de lange analyse: eerst een volledig model, daarna automatisch eenvoudigere modellen als dat nodig is
- berekent daarna een MSI per ecologische 100-groep

Vooraf past het script de centrale scope `meijendel_natura2000` toe. M66 en
M91 vallen daardoor standaard buiten iedere variant, ook als een toekomstige
plotlijst een van beide zou noemen. Alleen een uitdrukkelijke uitvoering met
`MEIJENDEL_INCLUDE_OUT_OF_SCOPE_PLOTS` kan daarvan afwijken.

De op 4 oktober 2026 herberekende standaarduitvoer bevat binnen de 25
Sandra-plots en 1997–2022 132 soorten met minimaal één positief territorium.
Daarvan leveren 110 soorten een formele TRIM-trend. Letterlijke nulregels tellen
mee in de modellen, maar selecteren een soort niet zonder positief territorium.

Het nulbesluit van 6 oktober 2026 verandert deze Sandra-variant niet. Binnen de
25 Sandra-plots en 1997-2022 bevat de huidige database geen plotjaar met bron
`jrvslg_m`. Er ontstaan in deze selectie dus geen afgeleide
jaarverslagnullen. De letterlijke SOVON-nullen blijven `0` en lege SOVON-cellen
blijven `NA`.

## Trendcontract `trim-trend-v2`

De soorttrend over `1997-2022` wordt rechtstreeks uit het werkende TRIM-model
berekend met `rtrim::overall(..., which = "imputed")`. Daardoor worden de
standaardfout, het 95%-betrouwbaarheidsinterval en de p-waarde afgeleid uit de
volledige variantie-covariantiematrix van de geschatte jaarindices. De formele
uitvoer vermeldt ook periode, methode, model en eventuele fallbackreden.

Een ontbrekend model of een niet-aaneengesloten kalenderreeks krijgt geen
formele onzekerheidsvelden. De MSI per ecologische groep blijft beschrijvend:
de onzekerheid over de onderliggende soorten wordt in deze release niet naar
de groepstrend doorgevoerd.

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
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  /Users/ton/Documents/GitHub/Meijendel/trim/sandra/soorten \
  /Users/ton/Documents/GitHub/Meijendel/trim/sandra/trim_msi_evg
```
