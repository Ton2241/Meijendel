# Trendanalyse ecologische groepen in R

Dit script leest rechtstreeks de MySQL-dump `20260324.sql` in en maakt vier outputbestanden:

- `jaarreeksen_dichtheid_per_groep.csv`
- `vergelijking_periodes_1958_1983_vs_1984_2025.csv`
- `doorlopende_index_per_groep.csv`
- `trendanalyse_per_groep.csv`
- `trendanalyse_los_per_periode.csv`
- `vergelijking_trends_tussen_periodes.csv`

Daarnaast maakt het een figuur:

- `doorlopende_index_per_groep.png`

## Uitgangspunten

- Ecologische groepen worden afgeleid uit `evg_vogel_landschapgroep`.
- De analyse gebruikt 100-talgroepen: `100`, `200`, `300`, enzovoort.
- Alleen de kavels uit de bestaande trendquery worden meegenomen:
  `1a, 1b, 2, 3, 4-5, 6, 7, 8, 9, 10-12-76, 12, 12a, 13, 13s, 14, 15, 16, 16s, 17a`.
- Soorten met `"meeuw"` in de naam worden uitgesloten, net als in de bestaande SQL-view.
- Jaarlijkse dichtheid wordt berekend als:
  `som territoria per groep / getelde km2 in dat jaar`.

## Vergelijking van de twee periodes

Het script maakt een tabel met per groep:

- gemiddelde dichtheid in `1958-1983`
- gemiddelde dichtheid in `1984-2025`
- procentueel verschil tussen beide periodes
- een `bridge_factor` op basis van `1981-1983` versus `1984-1986`

Die `bridge_factor` is vooral bedoeld om de methodologische breuk te kwantificeren.
Een grote afwijking van `1` wijst op een duidelijke sprong rond de breuk.

Daarnaast maakt het script een expliciete losse trendanalyse per periode:

- `trendanalyse_los_per_periode.csv`
  Hier staat per groep én per periode de geschatte jaarlijkse procentuele trend.
- `vergelijking_trends_tussen_periodes.csv`
  Hier staan de twee hellingen naast elkaar, plus het verschil tussen beide.

Dit is de veiligste tabel als je `1958-1983` en `1984-2025` apart wilt interpreteren.

## Doorlopende trendanalyse

Voor iedere groep worden eerst binnen beide periodes losse indices gemaakt met gemiddelde = `100`.
Daarna wordt de tweede periode geschaald met de `bridge_factor`, zodat een doorlopende index over `1958-2025` ontstaat.

Het script past daarna twee lineaire modellen toe:

1. `log(density_per_km2 + 0.1) ~ jaar_c + post_break + jaar_na_break`
2. `log(index_spliced + 0.1) ~ jaar`

Interpretatie:

- `pre_trend_pct_per_jaar`: gemiddelde jaarlijkse verandering voor `1958-1983`
- `post_trend_pct_per_jaar`: gemiddelde jaarlijkse verandering voor `1984-2025`
- `overall_trend_pct_per_jaar`: gemiddelde jaarlijkse verandering over de doorlopende, geschaalde index
- `break_level_shift_pct`: geschatte niveausprong direct na de breuk
- `p_slope_change`: toets of de helling na de breuk verschilt van die ervoor

## Gebruik in RStudio

Open in RStudio:

`/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R`

Of voer uit in de terminal:

```r
source("/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R")
```

Met expliciete paden:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R \
  /Users/ton/Documents/GitHub/Meijendel/20260324.sql \
  /Users/ton/Documents/GitHub/Meijendel/output_ecologische_groepen
```

## Advies voor interpretatie

- Vergelijk `pct_change_post_pre` niet als puur ecologische verandering; een deel kan uit de methodebreuk komen.
- Gebruik `break_level_shift_pct` om de breuk zichtbaar te maken.
- Gebruik `overall_trend_pct_per_jaar` alleen in combinatie met de geschaalde index.
- Gebruik voor inhoudelijke conclusies bij voorkeur `trend_pre_pct_per_jaar` en `trend_post_pct_per_jaar`.
- Als je publiceerbare analyses wilt maken, is een vervolgstap met `GAM`, `GLM` of `TRIM`-achtige modellen zinvol, maar deze basisversie is direct uitvoerbaar zonder extra R-packages.
