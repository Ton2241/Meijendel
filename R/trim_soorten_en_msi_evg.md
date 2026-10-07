# TRIM-analyse soorten en MSI-ecologische vogelgroepen

Dit script leest rechtstreeks `meijendel.sql` in en maakt twee nieuwe outputmappen:

- `trim/soorten`
- `trim_msi_evg`

## Wat het script doet

1. Het leest onder meer `plots`, `plot_analyse_scope`, `plot_jaar_oppervlak`, `plot_jaar_teller`, `territoria`, `bronnen`, `sovon_bmp_plotjaar`, `soorten`, `evg_vogelgroepen` en `evg_vogel_landschapgroep` en past standaard de scope `meijendel_natura2000` toe.
2. Het bouwt per `plot x jaar` een analysebasis op.
3. Het gebruikt voor `1958-1972` alleen de historische kernkavels.
4. Een expliciete SOVON-nul blijft `0`; een lege SOVON-cel blijft `NA`. In een geteld `jrvslg_m`-plotjaar wordt het ontbreken van een soort uit de jaarverslagsoortpool als `afgeleide_jaarverslagnul` behandeld. Een formeel afgekeurd SOVON-plotjaar levert voor SOVON `NA`, terwijl een aanwezige onafhankelijke niet-SOVON-regel geldig blijft.
5. Het corrigeert tellingen pragmatisch voor veranderend plotoppervlak door elk plotjaar terug te rekenen naar de mediane plotoppervlakte van dat plot.
6. Het draait per soort een `TRIM`-model vóór `1984` en een tweede `TRIM`-model vanaf `1984`.
7. Het verbindt beide indexreeksen met een brugfactor op basis van `1981-1983` versus `1984-1986`.
8. Het berekent daarna per ecologische 100-groep een `MSI` als geometrisch gemiddelde van de soortindices.
9. Het berekent voor de zes functionele vogelgroepen altijd binair en gewogen
   (`1,0` primair; `0,5` secundair), zowel volledig als robuust.
10. Het voert per functionele groep en analysevariant een
    leave-one-species-out-trendcontrole uit.

M66 en M91 vallen standaard buiten de analyse. Alleen een uitdrukkelijke
uitvoering met bijvoorbeeld
`MEIJENDEL_INCLUDE_OUT_OF_SCOPE_PLOTS=M66,M91` voegt beide kavels toe.

De op 7 oktober 2026 herberekende standaarduitvoer over 1958–2025 bevat 156
soorten met minimaal één geaccepteerd positief territorium binnen de scope, 135
soorten met ten minste één bruikbare TRIM-indexreeks en 93 soorten met een
brugbare reeks in beide modelperioden. Letterlijke SOVON-nullen vullen de
meetmatrix van zo'n soort aan, maar maken een soort zonder positieve waarneming
niet zelfstandig tot analysekandidaat. Lege SOVON-cellen blijven `NA`;
ontbrekende jaarverslagcellen volgen de hieronder beschreven bronregel. M66 en
M91 en de formeel afgekeurde SOVON-plotjaren zijn conform hun status buiten de
standaardberekening gehouden.

## Nulbesluit van 6 oktober 2026, uitgevoerd 7 oktober 2026

SOVON Helpdesk heeft bevestigd dat in de officiële Excel-downloads `0` een
harde nul is en een lege cel betekent dat de soort niet is onderzocht. De
huidige TRIM-code behandelt de SOVON-gegevens dus correct: alleen de letterlijke
SOVON-nul wordt nul en de lege cel blijft `NA`.

Voor de zelfstandige jaarverslagbron `jrvslg_m` geldt voortaan de volgende
analyseaanname. Omdat de tellers alle vogelsoorten telden, bestaat de soortpool
uit iedere soort met ten minste één geaccepteerd positief `jrvslg_m`-resultaat
in de volledige jaarverslagreeks 1958-2025. Haar ontbreken in een geteld
jaarverslagplot geldt als afgeleide nul; voorkomen elders in hetzelfde
kalenderjaar is geen voorwaarde.

De actuele standaardanalyse over 52 Natura 2000-plots bevat binnen 662 getelde
`jrvslg_m`-plotjaren en een soortpool van 128 soorten 66.116 afgeleide nullen:
60.387 in 1958-1983 en 5.729 in 1984-2025. Na selectie op eerste positieve jaar
en actieve plots worden 15.921 daarvan werkelijk als modelinvoer gebruikt:
14.149 in 1958-1983 en 1.772 in 1984-2025. De afgeleide waarden blijven in de
analysematrix herkenbaar via analysebron, nulstatus en bewijsgrond en worden
niet als bronwaarde in `territoria` opgeslagen.

De vergelijking met de uitvoer van 4 oktober staat per soort in
`trim/soorten/gevolgen_afgeleide_jaarverslagnullen_per_soort.csv`. Van de 156
soorten hebben 28 geen afgeleide jaarverslagnul, negen wel afgeleide nullen maar
geen wijziging in de trenduitvoer, 118 gewijzigde trendwaarden en één een
gewijzigde modelstatus. Kuifleeuwerik verloor de post-1984-reeks en is daardoor
niet langer brugbaar.

## Trendcontract `trim-trend-v2`

De afzonderlijke soortperioden zijn de primaire trendresultaten. Per werkend
TRIM-model berekent `rtrim::overall(..., which = "imputed")` de jaarlijkse
trend met de volledige variantie-covariantiematrix. De uitvoer bevat per
periode minimaal de procentuele verandering per jaar, standaardfout, 95%-BI,
p-waarde, periode, model en methode. Deze formele berekening is alleen geldig
voor aaneengesloten kalenderjaren; een ontbrekend model of een jaarhiaat krijgt
een expliciete niet-formele status.

De gebrugde reeks `1958-2025` combineert de modellen `1958-1983` en
`1984-2025` met een geschatte brugfactor. Zolang deze volledige keten niet
wordt gebootstrapt, is de samengevatte langetermijntrend uitsluitend
beschrijvend. Zij krijgt dus geen formele standaardfout, 95%-BI, p-waarde of
trendklasse. De groeps-MSI's zijn om dezelfde reden beschrijvend; hun
jaarwaarden en samenstellingsdiagnostiek blijven wel beschikbaar.

## Waarom geen `post84` als TRIM-covariaat?

De `rtrim`-module accepteert covariaten alleen als site-kenmerk en niet als tijdsafhankelijke variabele per site-jaar. Daarom kan een indicator als `post84` niet rechtstreeks in één TRIM-model worden opgenomen.

Daarom gebruikt dit script een verdedigbare alternatieve aanpak:

- aparte TRIM-reeksen vóór en na de methodebreuk
- daarna gecontroleerd bruggen van beide reeksen

## Uitvoer in `trim/soorten`

- `analysebasis_plot_jaar.csv`
- `soorten_modelstatus.csv`
- `soortindices_per_jaar.csv`
- `soorten_trendoverzicht.csv`
- `soorten_brugfactoren.csv`
- `gevolgen_afgeleide_jaarverslagnullen_per_soort.csv`

## Uitvoer in `trim_msi_evg`

- `groepssamenstelling_100tal.csv`
- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`
- `functionele_groepssamenstelling.csv`
- `functionele_msi_per_groep_per_jaar.csv`
- `functionele_trendoverzicht_msi_groepen.csv`
- `functionele_loso_trendgevoeligheid.csv`

## Script uitvoeren

In Terminal:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R
```

Met expliciete paden:

```sh
Rscript /Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  /Users/ton/Documents/GitHub/Meijendel/trim/soorten \
  /Users/ton/Documents/GitHub/Meijendel/trim_msi_evg
```

## Belangrijke methodologische notitie

De oppervlakte-correctie is hier een praktische benadering, omdat `rtrim` geen eenvoudige tijdsafhankelijke offset voor wisselende plotoppervlakken biedt. De uitkomsten zijn daarom bruikbaar als eerste verdedigbare trendanalyse, maar verdienen ecologische controle bij soorten waarvan kavels sterk in oppervlak veranderden.
