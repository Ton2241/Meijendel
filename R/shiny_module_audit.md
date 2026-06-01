# Audit Shiny-modules: actuele implementatie

Datum: 2026-06-01

Repo-referentie:

- huidige `HEAD`: `4f54c91`
- audit is geactualiseerd op basis van de werkboom op 2026-06-01; let op dat `app.R`, `helpers.R` en dit document lokale, nog niet gecommitte wijzigingen kunnen bevatten.

Bronnen:

- `shiny_meijendel/app.R`
- `shiny_meijendel/helpers.R`

Doel van dit document: reconstrueren hoe de huidige Shiny-app werkt. De nadruk ligt op implementatie, invoerdata, UI-keuzes, modelcode, defaults, diagnostiek en interpretatierisico's. Dit document beschrijft dus niet primair de ecologische uitkomsten.

## 0. Gedeelde uitgangspunten

### SQL en tabelbasis

De app leest de Meijendel SQL-export in en bouwt daaruit R-tabellen. Voor de meeste analyses zijn vooral deze tabellen relevant:

- `plots`
- `plot_jaar_oppervlak`
- `plot_jaar_teller`
- `territoria`
- `soorten`
- `evg_vogelgroepen`
- `evg_vogel_landschapgroep`
- `richtlijnen`
- `soort_richtlijn`
- `soorten_kenmerken`
- `soorten_kenmerken_datadictionary`
- `soorten_kenmerken_hoofdcategorien`
- `plot_jaar_ahn_dtm`
- `plot_jaar_stikstof`
- `plot_jaar_infra`
- habitat-/covariaattabellen
- `dagbezoeken_bmp`
- `dagwaarnemingen_bmp`

### Echte nullen en ontbrekende waarnemingen

De centrale regel is:

```text
niet geteld = NA
wel geteld, geen territorium = 0
wel geteld, territorium vastgesteld = positief aantal
```

Voor getelde plot-jaren worden ontbrekende soort-territoria dus echte nullen. Voor niet-getelde plot-jaren wordt geen nul ingevuld. Dit is essentieel voor alle modules.

### Responsmaat

De meeste modules gebruiken `territoria_per_km2`. Bij tellingmodellen zoals GEE en GLMM wordt feitelijk gemodelleerd met:

```r
count ~ ... + offset(log_area)
```

Daarmee is de respons inhoudelijk territoria per oppervlakte-eenheid, maar statistisch blijft het model een telmodel op aantallen met oppervlakte-offset.

### Community-matrix

NMDS, RDA, PLS, SEM en Beta-Diversity gebruiken dezelfde community-basis direct. Changepoint gebruikt deze basis voor jaarlijkse tellingen en kan daarnaast TRIM-indexen of MSI-reeksen opbouwen. Occupancy gebruikt deze basis voor soortselectie en metadata, maar combineert die met dagbezoeken en dagwaarnemingen.

```r
build_community_matrix_subset(
  tbls, selected_kavels, year_from, year_to,
  selection_type, selection_value
)
```

Deze functie:

1. bouwt getelde plot-jaren via `prepare_analysis_basis_subset()`;
2. houdt alleen getelde plot-jaren over;
3. selecteert soorten op basis van alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk;
4. bouwt een soortmatrix met `build_species_matrix_subset()`;
5. gebruikt `territoria_per_km2`;
6. maakt een matrix:

```r
xtabs(territoria_per_km2 ~ sample_id + soort_id, data = species_matrix)
```

Daarbij is:

- rij = `sample_id`, opgebouwd als `plot_id_jaar`;
- kolom = `soort_id`;
- waarde = `territoria_per_km2`;
- echte nullen blijven 0;
- niet-getelde plot-jaren komen niet in de matrix;
- rijen en kolommen die overal 0 zijn worden verwijderd.

De gedeelde metadata bevat onder andere:

- `plot_id`
- `kavel_nummer`
- `jaar`
- `oppervlakte_km2`
- `totaal_territoria_per_km2`
- `totaal_territoria`
- `soortenrijkdom`
- `year_c`
- `ahn_mean`
- `stikstof_mean`
- `afstand_pad_m`

Belangrijk: de community-modules werken op een `plotjaar x soort` matrix, niet op `soort x jaar`, `soort x plot` of TRIM-indices.

### Transformaties

De gedeelde transformatiefunctie is:

```r
nmds_transform_matrix(
  comm,
  transform = c("hellinger", "presence_absence", "log1p", "raw")
)
```

Implementatie:

```r
raw              -> comm
presence_absence -> ifelse(comm > 0, 1, 0)
log1p            -> log1p(comm)
hellinger        -> vegan::decostand(comm, method = "hellinger")
```

Deze transformaties worden gebruikt door NMDS, RDA en PLS. Beta-Diversity gebruikt expliciet presence/absence met Sorensen.

## 1. TRIM

### Implementatie

Belangrijkste functies:

```r
analyse_subset()
analyse_species_subset()
fit_trim_model()
collect_index()
```

Package:

```r
rtrim
```

Modelaanroep:

```r
rtrim::trim(
  df_fit,
  model = cfg$model,
  overdisp = cfg$overdisp,
  serialcor = cfg$serialcor,
  autodelete = TRUE,
  conv_crit = 1e-5,
  max_iter = 400
)
```

De app probeert modellen in vaste volgorde:

1. `model3_overdisp`
2. `model3_overdisp_serialcor`
3. `model3_basis`
4. `model2_basis`

Dit is een voorkeursvolgorde, geen AIC-selectie. Het eerste werkende model wordt gekozen.

### Invoerdata

TRIM gebruikt soort-plot-jaar tellingen uit de territoriadataset. Voor getelde plot-jaren zonder territorium wordt 0 gebruikt. Niet-getelde plot-jaren blijven buiten de bruikbare modeldata.

De app gebruikt `count_adjusted`, inclusief de bestaande brugjaarlogica voor vergelijkbaarheid tussen pre-1984 en post-1984.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- soorten;
- vogelgroepen;
- Rode/Oranje Lijst.

Output:

- selectieoverzicht;
- soortgrafiek;
- groepsgrafiek;
- richtlijn-/Rode-Oranje-Lijstgrafiek;
- waarschuwing bij geselecteerde soort wanneer niet het voorkeursmodel maar een fallback-model is gebruikt;
- tabellen met trends, indexen en status;
- R-script export.

### Auditpunten

- Sterk punt: TRIM is passend voor telreeksen met ontbrekende waarnemingen.
- Let op: trendlabels in de app zijn eigen trendduidingen op basis van indexen, geen officiële TRIM-classificaties.
- Let op: modelkeuze is deterministisch via voorkeursvolgorde. Als een fallback-model wordt gebruikt verandert de modelinterpretatie; de UI toont dit nu als waarschuwing bij de geselecteerde soort.
- Let op: TRIM werkt op tellingen; interpretatie van index 100 is het eerste analysejaar vanaf het eerste positieve jaar.

## 2. LAMBDA

### Implementatie

Belangrijkste functies:

```r
analyse_lambda_subset()
analyse_lambda_species_subset()
analyse_lambda_groups_subset()
analyse_lambda_richtlijnen_subset()
bereken_lambda_jaarreeks()
```

Lambda wordt berekend als:

```r
lambda = N[t] / N[t-1]
log_lambda = log(lambda)
```

Alleen opeenvolgende jaren met positieve waarden leveren een lambda op.

### Perioden

De app gebruikt drie T0-perioden:

```r
1959-1972  T0 = 1959
1973-1983  T0 = 1973
1984-heden T0 = 1984
```

### Invoerdata

LAMBDA gebruikt geaggregeerde soort-jaar waarden uit getelde plot-jaren. Echte nullen worden gebruikt bij geschiktheidsbeoordeling, maar jaar-op-jaar verandering wordt alleen berekend tussen opeenvolgende positieve waarden.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- berekening voor soorten;
- berekening voor vogelgroepen;
- berekening voor Rode/Oranje Lijst.

Output:

- soortresultaten;
- groepsresultaten;
- richtlijnresultaten;
- dekking per kavel;
- LAMBDA-status soorten, inclusief `status_reden`;
- R-script export.

### Auditpunten

- Sterk punt: transparante jaar-op-jaar verandering.
- Let op: een soort levert geen bruikbare lambda op zonder minimaal twee opeenvolgende jaren met positieve waarden; voor stabiele beoordeling zijn meerdere opeenvolgende positieve jaarparen nodig.
- Let op: LAMBDA is geen modelmatige correctie voor detectie of ontbrekende waarden.
- Voor rapportage moet duidelijk blijven dat de grafiek percentageveranderingen toont, geen T0-index.

## 3. GEE

### Implementatie

Belangrijkste functies:

```r
run_gee_subset()
run_gee_screening_subset()
run_gee_trait_screening()
```

Packages:

```r
geepack
broom
```

Reguliere modelaanroep:

```r
geepack::geeglm(
  formula = count ~ covariaten + offset(log_area),
  family = poisson(link = "log"),
  id = plot_id,
  corstr = gee_corstr,
  control = geepack::geese.control(maxit = 20, epsilon = 1e-04),
  data = dat_model
)
```

Kenmerkenanalyse:

```r
count ~ year_c + trait_present + year_c:trait_present + offset(log_area)
```

met:

```r
id = cluster_id
```

waar `cluster_id = plot_id x soort_id`.

### Invoerdata

GEE gebruikt:

- `count` als territoriumaantal;
- `offset(log_area)` voor oppervlaktecorrectie;
- getelde plot-jaren;
- echte nullen voor getelde plot-jaren zonder territorium;
- `NA` voor niet-getelde plot-jaren;
- covariaten zoals jaar, stikstof, toegankelijkheid, AHN, afstand tot pad en habitatvariabelen.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- reguliere analyse of kenmerkenanalyse;
- analyse-niveau: soort, vogelgroep, Rode/Oranje Lijst;
- correlatiestructuur:
  - `ar1`
  - `exchangeable`
  - `independence`
  - `unstructured`
- vaste covariaten;
- AHN-covariaten;
- infra-covariaten;
- habitatcovariaten;
- screening GEE.

Default:

- correlatiestructuur = `ar1`;
- standaardcovariaten = `stikstof_mean` en `toegankelijkheid_status`.

### Output

De gebruiker ziet:

- IRR-grafiek met 95%-betrouwbaarheidsinterval;
- coefficiententabel;
- overdispersie-diagnose:
- gemiddelde;
- variantie;
- variantie/gemiddelde;
- interpretatie;
- advies.
- telinspanning/detectie;
- VIF-multicollineariteit;
- gebruikte kavels;
- gebruikte plot-jaren;
- R-script export.

### Auditpunten

- Sterk punt: GEE past bij herhaalde metingen per plot.
- Sterk punt: AR1 is ecologisch plausibel voor jaarlijkse reeksen.
- Let op: GEE gebruikt Poisson. Bij variantie/gemiddelde groter dan 1,5 moet Poisson voorzichtig worden geïnterpreteerd en met GLMM Negative Binomial worden vergeleken. Bij variantie/gemiddelde groter dan 2 verdient GLMM Negative Binomial of een ander alternatief voor Poisson de voorkeur.
- Let op: `unstructured` kan te zwaar of instabiel zijn bij grote selecties.
- Let op: kenmerkenanalyse is een screening over kenmerken, geen causaal eindmodel.

## 4. GLMM

### Implementatie

Belangrijkste functies:

```r
run_glmm_subset()
run_glmm_trait_screening()
```

Package:

```r
glmmTMB
```

Reguliere modelaanroep:

```r
glmmTMB::glmmTMB(
  count ~ covariaten + offset(log_area) + random_effects,
  family = poisson(link = "log") of nbinom2(link = "log"),
  data = dat_model,
  control = glmmTMB::glmmTMBControl(
    optCtrl = list(iter.max = 500, eval.max = 500)
  )
)
```

Beschikbare random-effect structuren in de reguliere analyse:

```r
(1 | plot_id_factor)
(1 | plot_id_factor) + (1 | jaar_factor)
(year_c | plot_id_factor)
```

Kenmerkenanalyse:

```r
count ~ year_c + trait_present + year_c:trait_present +
  offset(log_area) + (1 | plot_id_factor) + (1 | soort_id_factor)
```

### Invoerdata

GLMM gebruikt dezelfde reguliere datalaag als GEE:

- `count`;
- `offset(log_area)`;
- territoria per km2 als inhoudelijke respons;
- echte nullen voor getelde plot-jaren;
- `NA` voor niet-getelde plot-jaren.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- reguliere analyse of kenmerkenanalyse;
- analyse-niveau: soort, vogelgroep, Rode/Oranje Lijst;
- verdeling:
  - Poisson;
  - Negative Binomial (`nbinom2`);
- random effects:
  - plot-intercept;
  - plot + jaar-intercept;
  - jaar-slope per plot;
- vaste covariaten;
- AHN-covariaten;
- infra-covariaten;
- habitatcovariaten.

Default:

```r
glmm_family = "nbinom2"
```

### Output

De gebruiker ziet:

- IRR-grafiek;
- coefficiententabel;
- overdispersie-diagnose;
- GLMM-diagnostiek:
  - ICC-benadering;
  - marginale R2-benadering;
  - conditionele R2-benadering;
  - VIF;
  - automatische waarschuwingen;
- random-effect variantieplot;
- telinspanning/detectie;
- gebruikte kavels;
- gebruikte plot-jaren;
- R-script export.

### Auditpunten

- Sterk punt: Negative Binomial is beschikbaar en vaak beter bij overdispersie.
- Sterk punt: random intercept voor plot houdt rekening met plotverschillen.
- Sterk punt: jaar als random effect en jaar-slope per plot zijn nu als opties beschikbaar.
- Sterk punt: ICC, marginale/conditionele R2, VIF en random-effect variantie zijn nu zichtbaar.
- Let op: ICC en R2 zijn benaderingen voor telmodellen met log-link.
- Let op: random slope voor jaar vraagt relatief veel data en kan instabiel of singular worden bij kleine selecties.
- Let op: kenmerkenanalyse is screening; p-waarden worden BH-gecorrigeerd, maar interpretatie blijft exploratief.
- Let op: bij grote selecties zijn tijdslimieten en maximale datagroottes ingebouwd.

## 5. Occupancy

### Implementatie

Belangrijkste functie:

```r
run_occupancy_subset()
```

Package:

```r
unmarked
```

Modelaanroep:

```r
unmarked::unmarkedFrameOccu(
  y = y,
  siteCovs = site_cov_data,
  obsCovs = obs_covs_arg
)

unmarked::occu(
  as.formula(paste0("~ ", det_formula, " ~ ", site_formula)),
  data = umf
)
```

Dit is single-season occupancy per plot-jaar. De module gebruikt nog geen dynamische occupancy met `unmarked::colext()`; kolonisatie en extinctie tussen jaren worden dus niet gemodelleerd.

### Invoerdata

Occupancy gebruikt als enige module expliciet:

- `dagbezoeken_bmp`;
- `dagwaarnemingen_bmp`.

De responsmatrix `y` is:

```text
rij = plot-jaar
kolom = bezoek binnen seizoen
waarde = 1 detectie, 0 geen detectie, NA geen bezoekpositie
```

Alleen plot-jaren met minimaal het ingestelde aantal bezoeken worden gebruikt.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- soortselectie: alle soorten, vogelgroep, Rode/Oranje Lijst, vogelkenmerk;
- minimaal aantal bezoeken per plot-jaar: 2, 3 of 4;
- detectiecovariaten:
  - dag in seizoen;
  - bezoekduur;
  - gunstig bezoek.
- sitecovariaten:
  - jaar;
  - stikstof;
  - AHN hoogte;
  - afstand tot pad.

Default:

- minimaal 2 bezoeken;
- alle drie detectiecovariaten geselecteerd.
- sitecovariaat = jaar.

### Output

De gebruiker ziet:

- jaarlijkse naive detectie-occupancy;
- coefficienten voor occupancy- en detectiecomponent;
- diagnostiek;
- gebruikte plot-jaren;
- telinspanning/detectie;
- R-script export.

### Auditpunten

- Sterk punt: dit is detectiegecorrigeerde occupancy, niet alleen territorium-occupancy.
- Sterk punt: dagbezoeken worden als herhaalde detectiemomenten gebruikt.
- Sterk punt: sitecovariaten zijn nu selecteerbaar in de occupancy-formule.
- Let op: dagwaarnemingen zijn vanaf 2009 relevant; oudere perioden zijn waarschijnlijk beperkt of niet bruikbaar.
- Let op: habitat- of beheer-covariaten op occupancy-niveau ontbreken nog.
- Let op: dit is geen dynamische occupancy; jaarlijkse kolonisatie en extinctie worden nog niet geschat.
- Let op: bij soortgroepen betekent detectie: detectie van ten minste een soort uit de selectie tijdens een bezoek.

## 6. NMDS

### Implementatie

Belangrijkste functie:

```r
run_nmds_subset()
```

Package:

```r
vegan
```

Hoofdfunctie:

```r
vegan::metaMDS(
  comm_transformed,
  distance = distance,
  k = dimensions,
  trymax = trymax,
  autotransform = FALSE,
  trace = FALSE
)
```

Extra diagnostiek:

```r
vegan::envfit(
  fit,
  env_meta[, usable_envfit_vars],
  permutations = 999,
  na.rm = TRUE
)
```

Envfit-variabelen:

- `year_c`
- `stikstof_mean`
- `ahn_mean`
- `afstand_pad_m`

Defaults:

```r
transform = "hellinger"
distance = "bray"
dimensions = 2
trymax = 30
```

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk;
- transformatie: Hellinger, presence/absence, log1p, ruw;
- afstandsmaat: Bray-Curtis, Jaccard, Euclidean;
- dimensies: 2D of 3D.
- tijdstrajecten per kavel tonen: aan/uit.

### Output

De gebruiker ziet:

- NMDS-plot;
- stresswaarde in titel;
- optionele tijdstrajecten per kavel met lijnen en pijlen door opeenvolgende jaren;
- site-scores;
- soort-scores;
- envfit-tabel;
- Shepard-diagram;
- gebruikte plot-jaren;
- telinspanning/detectie;
- CSV downloads;
- R-script export.

### Auditpunten

- Sterk punt: passend als exploratieve community-ordinatie.
- Sterk punt: envfit maakt verbanden met omgevingsvariabelen zichtbaar.
- Sterk punt: tijdstrajecten maken verschuivingen binnen kavels expliciet zichtbaar.
- Let op: envfit is associatief en geen causale toets.
- Let op: Jaccard hoort inhoudelijk vooral bij presence/absence; met Hellinger is interpretatie minder zuiver.

## 7. RDA

### Implementatie

Belangrijkste functie:

```r
run_rda_subset()
```

Package:

```r
vegan
```

Hoofdfunctie:

```r
vegan::rda(
  comm ~ year_c + stikstof_mean + ahn_mean + afstand_pad_m,
  data = meta
)
```

Partial RDA:

```r
vegan::rda(
  comm ~ stikstof_mean + ahn_mean + afstand_pad_m + Condition(year_c),
  data = meta
)
```

Diagnostiek:

```r
vegan::anova.cca(fit, permutations = 999)
vegan::anova.cca(fit, by = "axis", permutations = 999)
vegan::anova.cca(fit, by = "term", permutations = 999)
vegan::vif.cca(fit)
```

Default:

```r
transform = "hellinger"
```

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk;
- transformatie: Hellinger, presence/absence, log1p, ruw;
- Partial RDA:
  - geen conditionering;
  - conditioneer voor jaar.

### Output

De gebruiker ziet:

- RDA-plot met sites en pijlen voor constraints;
- hoofdresultaat: constraint-scores;
- diagnostiek: permutatietests en VIF;
- gebruikte plot-jaren;
- telinspanning/detectie;
- R-script export.

### Auditpunten

- Sterk punt: RDA is nuttig voor verklaarde variatie in soortensamenstelling.
- Sterk punt: permutatietests en VIF zijn nu zichtbaar.
- Sterk punt: Partial RDA met `Condition(year_c)` kan temporele trend wegfilteren.
- Let op: RDA veronderstelt lineaire respons in de getransformeerde matrix.
- Let op: collineariteit blijft een inhoudelijk aandachtspunt; hoge VIF vraagt covariaatreductie.

## 8. PLS

### Implementatie

Belangrijkste functie:

```r
run_pls_subset()
```

Package:

```r
pls
```

Hoofdfunctie:

```r
pls::plsr(
  Y ~ X,
  ncomp = ncomp,
  validation = "LOO",
  method = "kernelpls",
  scale = FALSE
)
```

Vooraf:

- `X` = geschaalde omgevingsvariabelen;
- `Y` = geschaalde community-matrix;
- standaardtransformatie community = Hellinger.

Beschikbare X-variabelen:

- `year_c`
- `stikstof_mean`
- `ahn_mean`
- `afstand_pad_m`

Extra diagnostiek:

- VIP-scores;
- RMSEP via leave-one-out crossvalidatie;
- componentinterpretatie op basis van dominante X-loadings per component.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk;
- transformatie: Hellinger, presence/absence, log1p, ruw;
- aantal componenten: 1 t/m 4.

Default:

```r
transform = "hellinger"
ncomp = 2
```

### Output

De gebruiker ziet:

- PLS-scoreplot;
- tekstblok dat RMSEP en VIP inhoudelijk scheidt;
- hoofdresultaat: VIP-scores;
- diagnostiek: RMSEP per aantal componenten en dominante variabelen per component;
- gebruikte plot-jaren;
- telinspanning/detectie;
- R-script export.

### Auditpunten

- Sterk punt: PLS is bruikbaar bij samenhangende covariaten.
- Sterk punt: VIP en RMSEP maken modelbeoordeling beter.
- Sterk punt: dominante loadings per component helpen bij voorzichtige ecologische interpretatie.
- Let op: PLS is primair predictief/exploratief; causale interpretatie is zwak.
- Let op: componentinterpretatie is geen automatisch ecologisch label.
- Let op: LOOCV kan optimistisch of instabiel zijn bij kleine selecties.

## 9. Changepoint

### Implementatie

Belangrijkste functie:

```r
run_changepoint_subset()
```

Package:

```r
changepoint
```

Beschikbare methoden:

1. Niveauverandering:

```r
changepoint::cpt.mean(
  annual$waarde,
  method = "PELT",
  penalty = penalty,
  class = TRUE
)
```

Daarnaast berekent de app handmatig de beste enkele knip op basis van RSS voor links/rechts-gemiddelden.

2. Trendbreuk:

```r
lm(waarde ~ jaar + post_knip, data = annual)
```

waar:

```r
post_knip = pmax(0, jaar - knipjaar)
```

De beste knip is de knip met de laagste RSS.

3. Meerdere niveau-omslagpunten:

```r
changepoint::cpt.mean(
  annual$waarde,
  method = "PELT",
  penalty = penalty,
  minseglen = 3,
  class = TRUE
)
```

Extra diagnostiek:

```r
changepoint::cpt.mean(..., penalty = "AIC")
changepoint::cpt.mean(..., penalty = "BIC")
changepoint::cpt.mean(..., penalty = "SIC")
changepoint::cpt.mean(..., penalty = "MBIC")
```

Voor niveauverandering en trendbreuk berekent de app daarnaast een indicatief onzekerheidsvenster rond het omslagjaar. Dat venster bestaat uit kandidaatknippen met een AIC-achtige score binnen 2 punten van de beste kandidaat. Dit is een praktische diagnose, geen formeel betrouwbaarheidsinterval.

### Invoerdata

Changepoint kan drie invoerbronnen gebruiken:

- jaarlijkse tellingen uit `cd$meta`;
- gemiddelde TRIM-indexen (`index_100`) van de geselecteerde soorten;
- MSI als geometrisch gemiddelde van TRIM-indexen van de geselecteerde soorten.

Bij jaarlijkse tellingen kan de gebruiker kiezen tussen `totaal_territoria_per_km2` en `soortenrijkdom`. Bij TRIM-indexen en MSI wordt de reeks intern eerst uit TRIM-indexen opgebouwd.

De app houdt per jaar ook `n_plot_jaren` bij. Dat is nodig omdat een changepoint in een jaargemiddelde reeks mede kan ontstaan door wisselende plotdekking.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk;
- invoerbron:
  - jaarlijkse tellingen;
  - TRIM-indexen;
  - MSI;
- reeks:
  - totaal territoria per km2;
  - soortenrijkdom;
- methode:
  - niveauverandering;
  - trendbreuk;
  - meerdere niveau-omslagpunten PELT;
- PELT-penalty: MBIC, BIC, SIC of AIC.

### Output

De gebruiker ziet:

- tijdreeksplot;
- verticale lijn bij knipjaar;
- bij trendbreuk ook gefitte trendregel;
- aantal gebruikte plot-jaren per jaar op een tweede as;
- kandidaat-knippen;
- indicatief onzekerheidsvenster rond het omslagjaar voor enkelvoudige niveau- en trendbreuk;
- penaltygevoeligheid voor AIC, BIC, SIC en MBIC;
- diagnostiek/samenvatting;
- gebruikte jaren;
- R-script export.

### Auditpunten

- Sterk punt: onderscheid tussen niveauverandering en trendbreuk is nu expliciet.
- Sterk punt: meerdere niveau-omslagpunten via PELT zijn nu beschikbaar.
- Sterk punt: TRIM-indexen en MSI kunnen nu als invoerbron worden gebruikt.
- Sterk punt: penaltygevoeligheid en een indicatief onzekerheidsvenster zijn nu zichtbaar.
- Let op: trendbreuk blijft beperkt tot een beste enkele knip.
- Let op: TRIM-indexen en MSI vereisen dat de app intern TRIM-modellen fit; dit is zwaarder dan jaarlijkse tellingen.
- Let op: de jaarlijkse aggregatie kan plotdekkingseffecten maskeren. Als het aantal getelde plots per jaar sterk varieert, is de jaargemiddelde reeks niet homogeen. Minder dan vijf plot-jaren in een jaar is een praktische ondergrens waaronder interpretatie voorzichtig moet zijn.
- Let op: changepoint zegt niets over oorzaak; koppeling aan beheer/gebeurtenissen blijft interpretatief.

## 10. SEM

### Implementatie

Belangrijkste functie:

```r
run_sem_subset()
```

Package:

```r
lavaan
```

Modelopbouw:

```r
soortenrijkdom ~ beschikbare_predictoren
log1p_totaal_territoria_per_km2 ~ soortenrijkdom + beschikbare_predictoren
stikstof_mean ~ year_c   # alleen als beide beschikbaar zijn
```

Fit:

```r
lavaan::sem(
  model,
  data = sem_dat,
  missing = "fiml",
  fixed.x = FALSE
)
```

Vooraf:

- complete cases op de basisvariabelen;
- numerieke variabelen worden geschaald;
- respons `totaal_territoria_per_km2` wordt `log1p` getransformeerd.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk.

De SEM-tab toont daarnaast een uitgeschakelde modeltemplate-keuze:

- verkennende SEM;
- `Begrazing -> Struweel -> doelsoort`;
- `Begrazing -> doelsoort`;
- direct + indirect model.

Alle hypothese-templates behalve de verkennende SEM zijn nog niet actief, omdat begrazing per plot-jaar en struweel/vegetatiestructuur per plot-jaar nog ontbreken.

### Output

De gebruiker ziet:

- staafgrafiek met padcoefficienten;
- padtabel;
- diagnostiek met fitmaten:
  - chi-kwadraat;
  - df;
  - p-value;
  - CFI;
  - RMSEA;
  - SRMR;
- gebruikte plot-jaren;
- R-script export met prominente disclaimer.

De tab benoemt alvast de beoogde toekomstige output voor hypothesegedreven SEM:

- directe effecten;
- indirecte effecten;
- totaal effect;
- gestandaardiseerde effecten;
- fitmaten;
- modelvergelijking;
- padendiagram.

### Auditpunten

- Sterk punt: bruikbaar als SEM-verkenning.
- Sterk punt: hypothese-templates zijn zichtbaar voorbereid zonder ze inhoudelijk al te activeren.
- Let op: dit is nog geen hypothesegedreven SEM.
- Let op: modelstructuur is hard-coded.
- Let op: hypothesetoetsing met begrazing en struweel is pas verantwoord nadat deze data per plot-jaar beschikbaar zijn.
- Let op: zolang de modelstructuur hard-coded is, mag deze module niet worden gebruikt voor causale rapportage. Causale interpretatie is pas verantwoord met vooraf geformuleerde ecologische hypothesen en een expliciet gekozen SEM-model. De UI en R-script export tonen hiervoor een disclaimer.

## 11. Beta-Diversity

### Implementatie

Belangrijkste functie:

```r
run_betadiversity_subset()
```

Package:

```r
betapart
```

Hoofdfunctie:

```r
comm_pa <- ifelse(cd$community_matrix > 0, 1, 0)
betapart::beta.pair(comm_pa, index.family = "sorensen")
```

De app gebruikt dus expliciet presence/absence en Sorensen.

### Invoerdata

Beta-Diversity gebruikt:

- `plotjaar x soort`;
- presence/absence;
- getelde plot-jaren;
- echte nullen als afwezigheid;
- niet-getelde plot-jaren buiten de analyse.

### UI-keuzes

Gebruiker kan kiezen:

- kavels;
- jaren;
- alle soorten, vogelgroep, Rode/Oranje Lijst of vogelkenmerk.

Er zijn geen dropdowns meer voor transformatie of afstandsmaat. De methode staat vast op:

```text
Sorensen presence/absence
```

### Output

De gebruiker ziet:

- jaarlijkse beta-diversity;
- Sorensen totaal;
- turnover;
- nestedness;
- diagnostiek met methode en gemiddelde waarden;
- gebruikte plot-jaren;
- telinspanning/detectie;
- R-script export.

### Auditpunten

- Sterk punt: Sorensen presence/absence is methodologisch passend voor soortencompositie.
- Sterk punt: misleidende UI-keuzes zijn verwijderd.
- Let op: jaarlijkse gemiddelden zijn afhankelijk van het aantal beschikbare plot-jaren. Minder dan vijf plot-jaren in een jaar is een praktische ondergrens waaronder de jaarlijkse beta-diversity onbetrouwbaar wordt.
- Let op: abundantie-informatie wordt bewust genegeerd. Een toekomstige Bray-Curtis variant op abundantie kan zinvol zijn, maar moet als aparte methode worden aangeboden omdat de interpretatie verschilt van Sorensen presence/absence.

## 12. Gedeelde code-export

De app kan per module een R-script downloaden via `write_analysis_export_script()` en `attach_analysis_export_script()`. De export bevat:

- gebruikte functie;
- functieargumenten;
- packageversies;
- R-versie;
- datasetverwijzing;
- reproduceerbare analysecalls.

Dit is belangrijk voor audit, reproduceerbaarheid en later gebruik in rapportage.

## 13. Gedeelde diagnostiek

Voor GEE en GLMM is overdispersie zichtbaar via:

```r
count_overdispersion_diagnostic()
```

De tabel bevat:

- gemiddelde;
- variantie;
- variantie/gemiddelde;
- interpretatie;
- advies.

Voor community-modules is daarnaast telinspanning/detectie toegevoegd via:

```r
add_detection_effort_to_analysis()
```

Daarin wordt informatie uit dagbezoeken en dagwaarnemingen gebruikt waar beschikbaar.

## 14. Samenvattende beoordeling per module

| Module | Status | Belangrijkste risico |
|---|---|---|
| TRIM | bruikbaar voor trendindices | eigen trendlabels, modelvolgorde geen AIC-selectie |
| LAMBDA | bruikbaar voor jaar-op-jaar verandering | gevoelig voor nullen en gaten |
| GEE | bruikbaar voor verklarende analyse | Poisson is tekortkoming bij variantie/gemiddelde > 1,5-2 |
| GLMM | bruikbaar, inclusief Negative Binomial | modelcomplexiteit en convergentie |
| Occupancy | detectiegecorrigeerd single-season vanaf dagbezoeken | geen dynamische occupancy, vooral vanaf 2009 |
| NMDS | goed als exploratieve ordinatie | geen causaliteit |
| RDA | bruikbaar met permutatietests en VIF | lineaire aannames, collineariteit |
| PLS | bruikbaar bij veel/samenhangende covariaten | exploratief/predictief, geen causaliteit |
| Changepoint | bruikbaar voor niveau-, trendbreuk en multi-PELT | formele onzekerheid en modelvergelijking blijven beperkt |
| SEM | verkennend, hypothese-templates voorbereid | hypothesemodellen nog niet actief |
| Beta-Diversity | methodologisch helder | presence/absence negeert aantallen |

## 15. Prioriteiten voor verdere verbetering

1. Activeer de SEM-hypothese-templates pas wanneer begrazing, struweel/vegetatiestructuur en doelsoortrespons per plot-jaar beschikbaar zijn.
2. Breid Occupancy uit met habitat- en beheercovariaten op site-niveau en overweeg daarna een aparte dynamische occupancy-module met `unmarked::colext()`.
3. Versterk Changepoint met formele onzekerheidsintervallen en expliciete modelvergelijking tussen niveauknip, trendbreuk en multi-PELT.
4. Overweeg bij RDA extra conditionering, bijvoorbeeld `Condition(plot_id)` of periodecorrecties, als de onderzoeksvraag daarom vraagt.
5. Overweeg een aparte Beta-Diversity optie voor Bray-Curtis op abundantie, gescheiden van de huidige Sorensen presence/absence analyse.
