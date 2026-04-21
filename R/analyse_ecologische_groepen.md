# MSI-analyse ecologische groepen in R

Dit script leest rechtstreeks de MySQL-dump `Meijendel.sql` in en vervangt de bestaande outputbestanden in `output_ecologische_groepen` door een MSI-gebaseerde analyse van de ecologische vogelgroepen.

De bestandsnamen blijven gelijk, maar de inhoud is nu gebaseerd op de `MSI`:

- `jaarreeksen_dichtheid_per_groep.csv`
  Bevat nu de jaarlijkse `MSI` per groep, plus `n_soorten` en de onderliggende groepsdichtheid.
- `vergelijking_periodes_1958_1983_vs_1984_2025.csv`
  Vergelijkt `MSI`-niveaus tussen beide periodes.
- `doorlopende_index_per_groep.csv`
  Bevat de doorlopende MSI-reeks per groep.
- `trendanalyse_per_groep.csv`
  Trendanalyse over de volledige MSI-reeks met breukterm.
- `trendanalyse_los_per_periode.csv`
  Losse trendanalyse per periode op basis van MSI.
- `vergelijking_trends_tussen_periodes.csv`
  Twee MSI-hellingen naast elkaar per groep.

Nieuwe hulpbestanden:

- `soortindices_voor_msi.csv`
  De soortspecifieke indices waaruit de MSI is opgebouwd.
- `vergelijking_oude_analyse_vs_msi.csv`
  Vergelijking tussen de oude analyse op geaggregeerde groepsdichtheid en de nieuwe MSI-analyse.
- `gam_trendanalyse_per_groep.csv`
  Samenvatting van de GAM-modellen per groep.
- `gam_interpretatie_per_groep.csv`
  Compact advies per groep: lineair voldoende, GAM nuttig of GAM aanbevolen.
- `gam_voorspellingen_per_groep.csv`
  Jaarlijkse waarnemingen, GAM-fit en 95%-banden per groep.

Daarnaast maakt het script een figuur:

- `doorlopende_index_per_groep.png`
- `gam_msi_per_groep.png`

## Wat is hier MSI?

Per soort wordt eerst een jaarlijkse index gemaakt:

- op basis van territoria per km2
- apart gestandaardiseerd vóór en na de methodologische breuk
- vervolgens gebridged rond `1983/1984`

Daarna wordt per ecologische groep per jaar de `MSI` berekend als het geometrisch gemiddelde van de soortindices binnen die groep.

Dat heeft een belangrijk gevolg:

- in de oude analyse telden soorten met veel territoria automatisch zwaarder mee
- in de MSI tellen soorten binnen een groep veel gelijkwaardiger mee

De MSI geeft daardoor eerder een “gemiddelde ontwikkeling van soorten binnen de groep” dan een “ontwikkeling van totale groepsdichtheid”.

## Uitgangspunten

- Ecologische groepen worden afgeleid uit `evg_vogel_landschapgroep`.
- De analyse gebruikt 100-talgroepen: `100`, `200`, `300`, enzovoort.
- Alleen deze kavels worden meegenomen:
  `1a, 1b, 2, 3, 4-5, 6, 7, 8, 9, 10-12-76, 12, 12a, 13, 13s, 14, 15, 16, 16s, 17a`.
- Soorten met `"meeuw"` in de naam worden uitgesloten.
- De methodologische breuk wordt gemodelleerd via aparte standaardisatie vóór en ná `1983`, plus een brugfactor op basis van `1981-1983` versus `1984-1986`.

## Interpretatie

Gebruik voor inhoudelijke conclusies vooral:

- `trend_pre_pct_per_jaar`
- `trend_post_pct_per_jaar`
- `overall_trend_pct_per_jaar`
- `break_level_shift_pct`

Voor de GAM-uitvoer zijn vooral deze velden nuttig:

- `deviance_explained`
- `edf_pre`
- `edf_post`
- `gam_fit_msi`, `gam_fit_lower`, `gam_fit_upper`

Interpretatie van `edf`:

- `edf` dicht bij `1`: bijna lineaire trend
- hogere `edf`: meer kromming in de trend

Belangrijk:

- De MSI zegt iets over de gemiddelde ontwikkeling van soorten binnen een groep.
- De MSI zegt minder direct iets over absolute dichtheid of totale biomassa van de groep.
- Verschillen met de oude analyse zijn informatief: ze laten zien waar dominante soorten eerder het groepsbeeld bepaalden.

## Gebruik in RStudio

Open:

`/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R`

Of voer uit:

```r
source("/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R")
```

Met expliciete paden:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R \
  /Users/ton/Documents/GitHub/Meijendel/Meijendel.sql \
  /Users/ton/Documents/GitHub/Meijendel/output_ecologische_groepen
```

## Wanneer MSI nuttiger is

De MSI is vooral beter als je ecologische groepen wilt vergelijken zonder dat enkele talrijke soorten het resultaat domineren. Voor vragen over totale aantalsontwikkeling van een groep kan de oude som-van-territoria-analyse nog steeds aanvullend nuttig zijn, maar voor groepsbrede soorttrends is MSI meestal verdedigbaarder.

## Wat GAM toevoegt

De lineaire analyse geeft per periode één gemiddelde helling. De GAM-versie voegt daaraan toe:

- niet-lineaire trendvormen
- zichtbaar maken van pieken, dalen en herstel
- een aparte gladde curve vóór en ná de breuk
- onzekerheidsbanden rond de geschatte MSI-trend
