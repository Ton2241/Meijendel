# TRIM-analyse soorten en MSI-ecologische vogelgroepen

Dit script leest rechtstreeks `Meijendel.sql` in en maakt twee nieuwe outputmappen:

- `trim/soorten`
- `trim_msi_evg`

## Wat het script doet

1. Het leest de tabellen `plots`, `plot_jaar_oppervlak`, `plot_jaar_teller`, `territoria`, `soorten`, `evg_vogelgroepen` en `evg_vogel_landschapgroep`.
2. Het bouwt per `plot x jaar` een analysebasis op.
3. Het gebruikt voor `1958-1972` alleen de historische kernkavels.
4. Het behandelt niet-getelde plotjaren als `NA` en wel-getelde maar niet-waargenomen soorten als `0`.
5. Het corrigeert tellingen pragmatisch voor veranderend plotoppervlak door elk plotjaar terug te rekenen naar de mediane plotoppervlakte van dat plot.
6. Het draait per soort een `TRIM`-model vóór `1984` en een tweede `TRIM`-model vanaf `1984`.
7. Het verbindt beide indexreeksen met een brugfactor op basis van `1981-1983` versus `1984-1986`.
8. Het berekent daarna per ecologische 100-groep een `MSI` als geometrisch gemiddelde van de soortindices.

## Waarom geen `post84` als TRIM-covariaat?

De `rtrim`-module accepteert covariaten alleen als site-kenmerk en niet als tijdsafhankelijke variabele per site-jaar. Daarom kan een indicator als `post84` niet rechtstreeks op de door jou voorgestelde manier in één TRIM-model worden opgenomen.

Daarom gebruikt dit script een verdedigbare alternatieve aanpak:

- aparte TRIM-reeksen vóór en na de methodebreuk
- daarna gecontroleerd bruggen van beide reeksen

## Uitvoer in `trim/soorten`

- `analysebasis_plot_jaar.csv`
- `soorten_modelstatus.csv`
- `soortindices_per_jaar.csv`
- `soorten_trendoverzicht.csv`
- `soorten_brugfactoren.csv`

## Uitvoer in `trim_msi_evg`

- `groepssamenstelling_100tal.csv`
- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`

## Script uitvoeren

In Terminal:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R
```

Met expliciete paden:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R \
  /Users/ton/Documents/GitHub/Meijendel/Meijendel.sql \
  /Users/ton/Documents/GitHub/Meijendel/trim/soorten \
  /Users/ton/Documents/GitHub/Meijendel/trim_msi_evg
```

## Belangrijke methodologische notitie

De oppervlakte-correctie is hier een praktische benadering, omdat `rtrim` geen eenvoudige tijdsafhankelijke offset voor wisselende plotoppervlakken biedt. De uitkomsten zijn daarom bruikbaar als eerste verdedigbare trendanalyse, maar verdienen ecologische controle bij soorten waarvan kavels sterk in oppervlak veranderden.
