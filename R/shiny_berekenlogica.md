# Shiny-berekenlogica

Dit document beschrijft de inhoudelijke berekenroutines van de Shiny-app in:

- [app.R](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/app.R)
- [helpers.R](/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/helpers.R)

Belangrijk:

- de echte broncode staat nu in `shiny_meijendel/helpers.R`
- `app.R` bevat vooral interface, selectie, grafieken en exports
- de inhoudelijke berekeningen zitten vrijwel volledig in `helpers.R`

Dit document is bedoeld om met een statisticus te delen voor commentaar op aannames, drempels en opbouw.

## Hoofdstructuur

De Shiny-app heeft nu drie inhoudelijke analysepaden:

1. `TRIM`
2. `LAMBDA`
3. `G.E.E.`

`G.E.E.` is nu als eerste werkende versie aanwezig op soortniveau en groepsniveau.

Voor de verdere uitwerking geldt deze ontwerpregel:

- `G.E.E.` wordt niet gebouwd als extra trendmodule
- `G.E.E.` wordt gebouwd als verklarende analysemodule voor effecten van beheer, recreatie, habitat, weer en andere covariaten op herhaalde plotmetingen

## Ingelezen tabellen uit `Meijendel.sql`

De app leest via `parse_meijendel_tables()` de volgende tabellen in:

- `plots`
- `soorten`
- `plot_jaar_oppervlak`
- `plot_jaar_teller`
- `territoria`
- `evg_vogelgroepen`
- `evg_vogel_landschapgroep`
- `habitattypen`
- `plot_jaar_habitat`
- `plot_jaar_ahn_dtm`
- `plot_jaar_stikstof`
- `plot_jaar_infra`
- `plot_jaar_toegankelijkheid`

De parser leest `INSERT`-blokken rechtstreeks uit `Meijendel.sql` en zet die om naar dataframes.

## Analysebasis

De functie `prepare_analysis_basis_subset()` bouwt per selectie van kavels en jaren een basis op van `plot x jaar`.

Belangrijke stappen:

1. filteren op gekozen kavels en jaren
2. bepalen of een plot-jaar als `geteld` geldt op basis van:
   - `plot_jaar_teller`
   - of aanwezigheid in `territoria`
3. berekenen van een `referentie_oppervlakte_km2` per plot als mediaan
4. berekenen van een `oppervlakte_factor`:

`referentie_oppervlakte_km2 / oppervlakte_km2`

Daarmee worden tellingen pragmatisch teruggeschaald naar een vaste plotoppervlakte.

## Soortselectie

De functie `build_species_selection_subset()` bepaalt welke soorten in de huidige selectie voorkomen.

Een soort komt in de selectie als:

- in de gekozen kavels en jaren minstens één positief territorium voorkomt

Uitkomst:

- `in_selectie = TRUE/FALSE`
- `selectie_reden`

## Soortmatrix

De functie `build_species_matrix_subset()` maakt een matrix van:

- soort
- plot
- jaar

Belangrijke interpretatie:

- wel geteld maar geen territorium: `0`
- niet geteld: `NA`

Daarnaast wordt per cel berekend:

- `count_raw`
- `count_adjusted = count_raw * oppervlakte_factor`

## TRIM-logica

De TRIM-berekeningen lopen via:

- `prepare_trim_period()`
- `fit_trim_model()`
- `collect_index()`
- `analyse_species_subset()`
- `analyse_groups_subset()`
- `analyse_subset()`

### Opzet

Per soort:

1. alleen getelde cellen met geldige waarden worden gebruikt
2. jaren zonder positieve jaarwaarde vallen af
3. alleen actieve plots blijven over
4. daarna wordt een `rtrim::trim()`-model geschat

De app probeert meerdere modelconfiguraties, van eenvoudiger naar robuuster.

### Uitkomst per soort

- `trim_index`
- `trim_se`
- `index_100`
- trend in `% per jaar`
- trendduiding
- modelstatus en eventuele waarschuwingen

### MSI per ecologische vogelgroep

De groepsanalyse gebruikt de TRIM-indexen per soort.

Stap:

1. `index_100` per soort naar log-schaal
2. gemiddelde log-index per `groep_100 x jaar`
3. exponent terug naar schaal van de `MSI`

Dat is dus een geometrisch gemiddelde van soortindices.

## GAM-logica

De functie `fit_gam_curve()` maakt gladde curves voor visualisatie.

Opzet:

- `mgcv::gam(log(y) ~ s(jaar, k = ...))`
- alleen bij voldoende datapunten
- uitkomst:
  - `fit`
  - `lower`
  - `upper`

De GAM wordt in de app alleen gebruikt als gladde visualisatie boven op:

- TRIM-indexreeksen
- MSI-reeksen

De GAM is dus nu geen aparte analysemodule, maar een visualisatie- en trendhulpmiddel.

## LAMBDA-logica

De LAMBDA-berekeningen lopen via:

- `classificeer_lambda_status()`
- `bereken_lambda_jaarreeks()`
- `analyse_lambda_species_subset()`
- `analyse_lambda_groups_subset()`
- `analyse_lambda_subset()`

### Methodologische basis

De LAMBDA-aanpak volgt het document:

- [Brugjaren en T0 reeksen.md](/Users/ton/Documents/GitHub/Meijendel/R/Brugjaren%20en%20T0%20reeksen.md)

Belangrijk:

- `1958` wordt genegeerd
- de methodebreuk in `1984` wordt in `LAMBDA` niet gemodelleerd
- er worden twee aparte deelreeksen gebruikt:
  - `1959-1983`
  - `1984-heden`

### T0-opzet

Per deelreeks wordt een `T0-index` opgebouwd.

Voorkeurs-T0:

- `1959` voor `1959-1983`
- `1984` voor `1984-heden`

Fallback:

- als dat voorkeursjaar in de selectie ontbreekt of waarde `0` heeft
- dan wordt het eerste positieve jaar in die deelreeks gebruikt

Dat gebruikte jaar wordt opgeslagen in:

- `t0_jaar`

### Jaar-op-jaar verandering

Per deelreeks wordt `lambda` alleen berekend als twee opeenvolgende jaren beide:

- aanwezig
- geteld
- positief

Dus:

- geen imputatie
- geen berekening over gaten heen

Uitkomst per jaar:

- `lambda`
- `log_lambda`
- `t0_index`

### Selectiecriteria voor T0-soortanalyse

Een soort wordt voorlopig als `ongeschikt_voor_T0` gemarkeerd als een van de volgende situaties optreedt:

- minder dan `10` geldige jaren
- minder dan `8` geldige opeenvolgende jaarparen
- `nul_aandeel > 50%`
- minder dan `5` positieve jaren

Een soort is `geschikt_voor_T0_MSI` als bovendien geldt:

- minimaal `12` geldige jaren
- minimaal `10` geldige opeenvolgende jaarparen
- `nul_aandeel <= 33%`
- aanwezigheid in zowel pre- als post-`1984`

Overige soorten worden:

- `geschikt_voor_T0_soortanalyse`

### LAMBDA per ecologische vogelgroep

Voor groepsniveau gebruikt de app niet alleen de technische selectie uit de sessie, maar ook de gecureerde whitelist:

- [evg_selctie_T0soort_T0msi.csv](/Users/ton/Documents/GitHub/Meijendel/R/evg_selctie_T0soort_T0msi.csv)

Daarbij geldt:

- alleen soorten met `t0_msi_eindselectie == TRUE` gaan door naar groepsniveau

Daarna wordt per groep:

1. log van soort-`t0_index` genomen
2. gemiddeld per `groep_100 x jaar x periode`
3. exponent terug naar groeps-`t0_index`
4. opnieuw `lambda` en `log_lambda` berekend op groepsniveau

## Waarom kan een soort `ongeschikt_voor_T0` zijn en toch een grafiek hebben?

Dat is een bewuste ontwerpkeuze in de app.

De status zegt:

- de soort is niet robuust genoeg voor T0-selectie

## G.E.E.-logica

De G.E.E.-berekeningen lopen via:

- `gee_covariate_specs()`
- `build_gee_dataset()`
- `run_gee_subset()`

### Methodologische positie

`G.E.E.` wordt in deze app niet gebruikt als extra trendmodule.

De functie is:

- verklarende analyse op soortniveau
- verklarende analyse op groepsniveau
- met herhaalde metingen per `plot_id`
- waarbij `plot_id` de cluster-id is

### Eerste werkende versie

De eerste versie werkt per gekozen analyse-eenheid met:

- responsvariabele: `territoria`
- linkfunctie: `log`
- familie: `Poisson`
- offset: `log(oppervlakte_km2)`
- cluster: `plot_id`

De gebruiker kiest eerst:

- `Soort`
- `Ecologische Vogelgroep`

Bij soortniveau:

- respons = som territoria van één gekozen soort per `plot_id + jaar`

Bij groepsniveau:

- soorten worden via `evg_vogel_landschapgroep` gekoppeld aan `groep_100`
- respons = som territoria van alle soorten binnen één gekozen ecologische vogelgroep per `plot_id + jaar`

De groepsrespons is dus een geaggregeerde groepssom, geen MSI en geen TRIM-index.

De formule bevat altijd:

- `year_c` als controlevariabele voor tijd

en daarnaast een door de gebruiker gekozen subset van covariaten.

De app begrenst de `G.E.E.`-fit operationeel:

- `maxit = 20`
- `epsilon = 1e-04`
- een elapsed time limit van `20` seconden
- een voorcontrole op te zware combinaties van correlatiestructuur, aantal plots en aantal jaren per plot

Als de fit daar overheen gaat, stopt de app met een expliciete foutmelding in plaats van eindeloos door te rekenen.

### Gebruikte covariaten in versie 1

Deze versie gebruikt alleen covariaten die nu al betrouwbaar in de database aanwezig zijn:

- `ahn_mean`
- `ahn_sd`
- `stikstof_mean`
- `afstand_pad_m`
- `padlengte_m_per_ha`
- `afstand_parkeerplaats_m`
- `afstand_hoofdtoegang_m`
- `toegankelijkheid_status`
- geselecteerde habitat-aandelen uit `plot_jaar_habitat`

Nog niet meegenomen in deze eerste versie:

- beheermaatregelen
- deeltoegankelijkheid
- weeraggregaties
- landgebruikssamenstellingen als afzonderlijke modeltermen

### Covariaatkoppeling

Per `plot_id + jaar` wordt eerst een G.E.E.-dataset opgebouwd.

Daarbij geldt:

- territoria worden geaggregeerd per `plot_id + jaar`
- wel geteld maar geen territorium = `0`
- niet geteld = `NA`
- `ahn_mean`, `stikstof_mean` en infra-waarden worden gekoppeld op dichtstbijzijnde beschikbare jaarwaarde per plot
- `toegankelijkheid_status` gebruikt de laatst bekende status op of vóór het gekozen jaar
- habitatcovariaten worden gekoppeld als aandeel per geselecteerd habitattype in `plot_jaar_habitat`

### Modeluitvoer

De app toont in versie 1:

- een samenvatting van de selectie
- een coefficiententabel
- `IRR`-waarden (`Incident Rate Ratio`)
- een effectplot met `IRR` en `95%`-interval
- de gebruikte modeldataset als controle-export
- een melding als gekozen covariaten in de actuele selectie vervallen door constante waarden of lineaire afhankelijkheid

### Statistische aandachtspunten voor review

Een statisticus zou in deze eerste G.E.E.-versie vooral moeten beoordelen:

- of `Poisson + log(offset(area))` passend is
- of `year_c` altijd als controlevariabele moet blijven staan
- welke correlatiestructuur (`exchangeable`, `ar1`, `independence`, `unstructured`) hier inhoudelijk het meest verdedigbaar is
- of nearest-year koppeling van ruimtelijke covariaten acceptabel is
- of in een volgende stap negatieve binomiale of zero-inflation varianten nodig zijn
- of een ruwe groepssom op EVG-niveau inhoudelijk de juiste respons is, of dat later een andere groepsrespons gewenst is
- of het automatisch laten vervallen van constante of lineair afhankelijke covariaten statistisch de gewenste werkwijze is

De grafiek zegt:

- er bestaat wel een berekenbare deelreeks met geldige `t0_index`

Dus:

- `ongeschikt_voor_T0` sluit tonen niet uit
- het sluit vooral opname in de formele T0-selectie of T0-MSI uit

In de app wordt daarom een toelichting boven de grafiek getoond voor zulke soorten.

## Huidige outputs in de Shiny-app

### TRIM

- selectie-overzicht
- soortgrafieken
- groepgrafieken
- trendtabellen
- controle-overzichten
- CSV-exports

### LAMBDA

- selectie-overzicht
- soortgrafieken met T0-index per deelreeks
- groepsgrafieken met T0-index per groep
- status- en controletabellen
- CSV-exports

## Statistische aandachtspunten voor review

Voor commentaar van een statisticus zijn vooral deze punten relevant:

1. oppervlakte-correctie via mediane plotoppervlakte
2. keuze om `1958` volledig uit `LAMBDA` te verwijderen
3. keuze voor harde T0-splitsing op `1959` en `1984`
4. fallback naar eerste positieve jaar als `T0`
5. gebruik van `lambda` en `log_lambda` zonder imputatie over gaten
6. huidige drempels voor opname in `T0-soortanalyse` en `T0-MSI`
7. combinatie van technische selectie en ecologische whitelist voor groepsniveau
8. interpretatie van soorten die wel getoond worden maar `ongeschikt_voor_T0` zijn

## Belangrijke projectnotitie

Als later wordt besloten de Shiny-berekenlogica ook als zelfstandig R-script in de map `R` op te nemen, dan is het beter om:

- óf de logica te verplaatsen naar één gedeeld bronbestand
- óf `helpers.R` vanuit zo'n script te hergebruiken

Niet wenselijk is:

- dezelfde berekenlogica op twee plaatsen los onderhouden

Dat zou snel tot inconsistenties leiden tussen:

- Shiny-app
- losse analyse-scripts
- documentatie
