# TRIM-bootstraponzekerheid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw en valideer formele onzekerheid voor afzonderlijke TRIM-perioden, de empirisch gebrugde soorttrend en ecologische en functionele MSI-groepen, met een eerste productierun over 1958–2026 zodra broedseizoen 2026 compleet en gevalideerd is.

**Architecture:** De bestaande TRIM-batchscripts worden sourcebaar gemaakt zonder hun CLI-gedrag te veranderen. Een nieuwe zuivere bootstrapkern trekt volledige plotclusters binnen vaste strata en schat per replicatie beide TRIM-perioden, een hulp-TRIM op gemeenschappelijke brugplots, de empirische brug, de verplichte gevoeligheidsvarianten en de groepen. De iMac coördineert en valideert alle batches; NAS en productie-VPS zijn optionele workers die nooit canonieke uitvoer schrijven en alleen na een groene capaciteitstest en afzonderlijk akkoord worden geactiveerd.

**Tech Stack:** R 4.6.1, `rtrim` 2.3.1, base R-tests met `stopifnot`, shellcontracttests, JSON via `jsonlite`, Git, Docker voor Linux-workers, SSH/rsync voor optionele NAS/VPS-workers.

**Spec:** `docs/superpowers/specs/2026-09-20-trim-bootstrap-onzekerheid-design.md`

## Global Constraints

- De ontwikkelbaseline van 7 oktober 2026 bevat 53 plots met oppervlaktejaren, 52 ooit getelde plots, 3.053 plot-jaarregels, 156 soorten in de statuslaag, 135 soorten met indices en 93 soorten met twee bruikbare perioden over 1958–2025; iedere gegevensuitspraak noemt verzameling, aantal en periode.
- De afzonderlijke soortperioden 1958–1983 en 1984–2025 blijven primair en gebruiken `rtrim::overall(..., which = "imputed")`.
- De soorttrend 1958–2025 heet altijd `gecombineerde trend via brugfactor`; presenteer hem nooit als één doorlopend TRIM-model.
- Gebruik voor de primaire brug 1981–1983 en 1986–1988; gebruik 1984 en 1985 niet als kalibratiejaren.
- Schat de niveauverhouding met een hulp-TRIM op de 33 plots die in beide ankervensters vertegenwoordigd zijn; gebruik de 20 in alle zes jaren getelde plots als strikte gevoeligheidsvariant.
- Bereken ook 1987–1989, 1988–1990, de historische continuiteitsbrug 1984–1986 en een vaste historische-kernvariant; label hun totale bereik als gevoeligheidsenvelop, niet als 95%-interval.
- Trek volledige plotgeschiedenissen met teruglegging binnen vaste strata; trek geen jaren, indexwaarden of soorten afzonderlijk.
- Gebruik binnen een replicatie exact dezelfde clustertrekking voor alle soorten en groepen.
- De primaire robuuste groep heeft vaste soortensamenstelling; een ontbrekende vaste groepssoort maakt die groepsreplicatie ongeldig.
- Gebruik nu 50 pilotreplicaties en daarna 500 validatiereplicaties. Start 2.000–5.000 productiereplicaties pas na opname en validatie van 2026.
- Draai geen bootstrap in een interactieve website- of Shiny-request.
- De iMac is coördinator en referentie. NAS/VPS zijn optioneel, schrijven alleen batchresultaten en worden niet automatisch geactiveerd.
- De volledige 2.000-run blijft lokaal uitvoerbaar; NAS/VPS staan standaard uit en vereisen na een read-only proef afzonderlijk expliciet akkoord.
- Normaal functioneren van NAS en VPS gaat altijd vóór rekensnelheid; veiligheidsgrenzen worden nooit voor doorlooptijd versoepeld.
- De productie-VPS gebruikt een aparte container en uitvoermap; raak actieve Shiny- en MySQL-containers niet aan.
- Houd credentials, lokale workerconfiguratie, ruwe replicaties, caches en runtime-output buiten Git.
- Werk testgestuurd: schrijf en observeer eerst de bedoelde testfout, implementeer daarna minimaal en draai vervolgens de gerichte én relevante bestaande tests.
- Voer begin- en eindpreflight uit en commit logisch afgeronde taken. Publicatie naar de VPS vereist na de 2026-productierun afzonderlijk expliciet akkoord.

## Review Focus

- **Brugidentiteit:** dezelfde getrokken plotkopieën en multipliciteiten moeten in hoofd-TRIM, hulp-TRIM, soorttrend en groeps-MSI terechtkomen; Tasks 4 en 5 testen dit expliciet.
- **Overgangsjaren:** 1984 en 1985 mogen wel geldige post-1984-modeldata blijven, maar nooit in de primaire brugkalibratie belanden; Task 5 test dit expliciet.
- **Vaste groepssamenstelling:** uitval van één primaire groepssoort mag geen kleiner ogenschijnlijk geldig MSI opleveren; Task 6 test dat de replicatie ongeldig wordt.
- **Hervatten en dubbelen:** een afgebroken of dubbel aangeleverde batch mag geen replicatie tweemaal meetellen; Task 8 test atomische hervatting en overlapafwijzing.
- **Structurele gevoeligheid:** een richtings- of nulgrensverschil tussen brugvarianten of de historische-kernvariant moet status `bruggevoelig` respectievelijk `gebiedsdekkinggevoelig` opleveren; Task 7 test beide statussen.
- **Productieveiligheid:** optionele externe workers blijven uit, tenzij capaciteit, numerieke pariteit en servicehealth aantoonbaar groen zijn en Ton daarna afzonderlijk akkoord geeft; Task 9 test de blokkades zonder echte NAS/VPS-activering.

---

### Task 1: Canonieke regressiebaseline en reproduceerbare brugjaaraudit

**Files:**
- Create: `R/trim_run_manifest.R`
- Create: `R/check_trim_source_output_contract.R`
- Create: `R/audit_trim_bridge_windows.R`
- Create: `R/check_trim_bridge_audit.R`
- Create: `scripts/test_trim_source_output_contract.sh`
- Modify: `.gitignore`
- Modify: `R/trim_soorten_en_msi_evg.md`

**Interfaces:**
- Consumes: één expliciet SQL-pad, Git-commit, R- en packageversies en de bestaande TRIM-outputmappen.
- Produces: `trim/bootstrap/run_manifest.json`, een bron/outputcontract en `audit_trim_bridge_windows(tbls, basis, windows)` met jaarlijkse dekking, vensterdekking en plotoverlap.

- [ ] **Step 1: Schrijf de falende bron/outputcontract- en brugjaaraudittests**

De manifesttest wijzigt na manifestcreatie de SQL-fixture en eist afwijzing.
De brugfixture bevat zes plots over 1981–1988 en eist exact:

```r
audit <- audit_trim_bridge_windows(tbls, basis, list(pre = 1981:1983, primary = 1986:1988))
stopifnot(audit$windows$unique_plots[audit$windows$window == "pre"] == 4L)
stopifnot(audit$overlap$any_year == 3L)
stopifnot(audit$overlap$all_six_years == 2L)
stopifnot(!any(audit$primary_post_years %in% c(1984L, 1985L)))
```

- [ ] **Step 2: Voer beide tests uit en verifieer RED**

Run:

```bash
bash scripts/test_trim_source_output_contract.sh
Rscript R/check_trim_bridge_audit.R .
```

Expected: FAIL omdat manifest- en auditfuncties ontbreken.

- [ ] **Step 3: Implementeer manifest, contract en brugjaaraudit**

Definieer:

```r
sha256_file <- function(path) character(1)
build_trim_run_manifest <- function(sql_path, output_dir, run_id, git_commit) list()
audit_trim_bridge_windows <- function(tbls, basis, windows) list()
derive_bridge_plot_sets <- function(basis, pre_years, post_years) list()
```

`derive_bridge_plot_sets()` levert voor 1981–1983 en 1986–1988 de plots met
ten minste één geteld jaar in ieder venster en afzonderlijk de plots die alle
zes jaren zijn geteld. De audit gebruikt exact de Natura 2000-, oppervlakte-
en geteld-poort uit `prepare_analysis_basis()`.

- [ ] **Step 4: Voeg uitsluitend runtimepaden toe aan `.gitignore`**

Negeer `trim/bootstrap_runs/`, `trim/bootstrap_workers.csv` en
`trim/**/*.partial`.

- [ ] **Step 5: Verifieer de ontwikkelbaseline zonder een nieuwe zware dump te maken**

Controleer op de gevolgde bronset 1958–2025 exact 53 plots met
oppervlaktejaren, 52 ooit getelde plots, 3.053 plot-jaarregels, 156 soorten in
de statuslaag, 135 soorten met indices, 93 soorten met twee perioden, 18
ecologische en 24 functionele trendregels. Controleer voor de brug 43 unieke
preplots, 37 unieke primaire postplots, 33 gemeenschappelijke plots en 20
volledig getelde plots. Een nieuwe dump, cachebouw of gevolgde uitvoer is geen
onderdeel van deze stap.

- [ ] **Step 6: Draai contract- en bestaande lichte baselinecontroles**

Run:

```bash
bash scripts/test_trim_source_output_contract.sh
Rscript R/check_trim_bridge_audit.R .
scripts/test_shiny_reproducibility.sh
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
```

- [ ] **Step 7: Commit**

```bash
git add .gitignore R/trim_run_manifest.R R/check_trim_source_output_contract.R \
  R/audit_trim_bridge_windows.R R/check_trim_bridge_audit.R \
  scripts/test_trim_source_output_contract.sh R/trim_soorten_en_msi_evg.md
git commit -m "Borg TRIM-bronrun en brugjaaraudit"
```

### Task 2: Maak de bestaande batchscripts veilig sourcebaar

**Files:**
- Modify: `R/trim_soorten_en_msi_evg.R`
- Modify: `R/trim_sandra_soorten_en_msi_evg.R`
- Create: `R/check_trim_scripts_sourceable.R`

**Interfaces:**
- Consumes: bestaande functies en ongewijzigde CLI-argumenten.
- Produces: `trim_main(args)` en `trim_sandra_main(args)`; `source()` definieert functies zonder analyse of bestandswrites te starten.

- [ ] **Step 1: Schrijf de falende sourceabilitytest**

```r
repo <- normalizePath(commandArgs(trailingOnly = TRUE)[1], mustWork = TRUE)
before <- list.files(tempdir(), all.files = TRUE)
source(file.path(repo, "R", "trim_soorten_en_msi_evg.R"), local = .GlobalEnv)
stopifnot(exists("trim_main", mode = "function"))
stopifnot(identical(before, list.files(tempdir(), all.files = TRUE)))
source(file.path(repo, "R", "trim_sandra_soorten_en_msi_evg.R"), local = .GlobalEnv)
stopifnot(exists("trim_sandra_main", mode = "function"))
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_scripts_sourceable.R .`

Expected: FAIL omdat `trim_main` ontbreekt en het script direct uitvoert.

- [ ] **Step 3: Wikkel alleen de uitvoerende onderkant in functies**

Behoud bestaande functienamen. Verplaats argumentafhandeling, directorycreatie,
parsing, analyse en writes naar `trim_main(args)` en
`trim_sandra_main(args)`. Voeg onderaan toe:

```r
if (sys.nframe() == 0L) {
  trim_main(commandArgs(trailingOnly = TRUE))
}
```

Gebruik voor Sandra dezelfde constructie met `trim_sandra_main`.

- [ ] **Step 4: Verifieer sourceability en CLI-pariteit**

Run:

```bash
Rscript R/check_trim_scripts_sourceable.R .
Rscript R/trim_soorten_en_msi_evg.R /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-cli/soorten" "$TMPDIR/trim-cli/groepen"
diff -qr "$TMPDIR/trim-cli/soorten" trim/soorten
diff -qr "$TMPDIR/trim-cli/groepen" trim_msi_evg
```

Expected: sourceability groen; inhoudelijk gelijke CSV's, afgezien van bewust
toegevoegde runmetadata.

- [ ] **Step 5: Commit**

```bash
git add R/trim_soorten_en_msi_evg.R R/trim_sandra_soorten_en_msi_evg.R \
  R/check_trim_scripts_sourceable.R
git commit -m "Maak TRIM-batchfuncties herbruikbaar"
```

### Task 3: Behoud het bestaande formele trendcontract en parametriseer het eindjaar

**Files:**
- Create: `R/trim_analysis_config.R`
- Create: `R/check_trim_analysis_period.R`
- Modify: `R/trim_soorten_en_msi_evg.R`
- Modify: `R/check_trim_species_output_contract.R`

**Interfaces:**
- Consumes: expliciet analyse-eindjaar; de al bestaande `trim_overall_contract()` uit `R/trim_trend_contract.R`.
- Produces: `resolve_trim_periods(end_year)` met perioden en labels voor hoofdmodel, gecombineerde trend en presentatie.

- [ ] **Step 1: Bevestig eerst de bestaande formele periodetrends**

Run:

```bash
Rscript R/test_trim_trend_contract.R
Rscript R/check_trim_species_output_contract.R .
```

Expected: beide groen; `rtrim::overall(imputed)` levert al schatting, SE,
95%-interval en p-waarde voor de afzonderlijke perioden. Wijzig dit contract
niet opnieuw.

- [ ] **Step 2: Schrijf de falende eindjaartest**

```r
p25 <- resolve_trim_periods(2025L)
p26 <- resolve_trim_periods(2026L)
stopifnot(identical(p25$post$label, "1984-2025"))
stopifnot(identical(p26$post$label, "1984-2026"))
stopifnot(identical(p26$combined$label, "1958-2026"))
stopifnot(inherits(try(resolve_trim_periods(1983L), silent = TRUE), "try-error"))
```

- [ ] **Step 3: Implementeer `resolve_trim_periods(end_year)` en verwijder functionele hardcodering**

De huidige standaard blijft expliciet 2025. De pilot krijgt `end_year = 2025`;
de productierun krijgt pas na validatie expliciet `end_year = 2026`. Leid
labels, filters, manifestvelden en contracttests uit dezelfde configuratie af.

- [ ] **Step 4: Verifieer 2025-regressie en 2026-fixture**

Run:

```bash
Rscript R/check_trim_analysis_period.R .
Rscript R/test_trim_trend_contract.R
Rscript R/check_trim_species_output_contract.R .
```

- [ ] **Step 5: Commit**

```bash
git add R/trim_analysis_config.R R/check_trim_analysis_period.R \
  R/trim_soorten_en_msi_evg.R R/check_trim_species_output_contract.R
git commit -m "Parametriseer eindjaar van TRIM-analyse"
```

### Task 4: Plotlineage, strata en reproduceerbare clustertrekking

**Files:**
- Create: `R/trim_bootstrap_core.R`
- Create: `R/audit_trim_bootstrap_clusters.R`
- Create: `R/check_trim_bootstrap_sampling.R`
- Create: `trim/bootstrap/cluster_definition.csv`

**Interfaces:**
- Consumes: analysebasis met `plot_id`, `kavel_nummer`, jaar en historische-kernstatus plus de vaste primaire en strikte brugplotsets uit Task 1.
- Produces: gevalideerde clusterdefinitie en `make_stratified_cluster_draw(clusters, replicate_id, run_seed)`; iedere getrokken broncluster bewaart zijn brugplotstatus.

- [ ] **Step 1: Schrijf falende tests voor stratificatie en duplicatie**

Gebruik zes synthetische clusters, drie per stratum. Eis voor replicatie 17:

```r
d1 <- make_stratified_cluster_draw(clusters, 17L, 20260920L)
d2 <- make_stratified_cluster_draw(clusters, 17L, 20260920L)
stopifnot(identical(d1, d2))
stopifnot(table(d1$stratum)[["historische_kern"]] == 3L)
stopifnot(table(d1$stratum)[["later_netwerk"]] == 3L)
stopifnot(!anyDuplicated(d1$bootstrap_site_id))
stopifnot(anyDuplicated(d1$source_cluster_id) > 0L)
stopifnot(identical(d1$primary_bridge_plot, clusters$primary_bridge_plot[match(d1$source_cluster_id, clusters$bootstrap_cluster_id)]))
```

Zoek voor de duplicatietest deterministisch het eerste replicatienummer tussen
1 en 100 met minstens één dubbel getrokken broncluster.

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_bootstrap_sampling.R .`

Expected: FAIL omdat de bootstrapkern ontbreekt.

- [ ] **Step 3: Implementeer deterministische RNG en trekking**

Definieer:

```r
replicate_seed <- function(run_seed, replicate_id) integer(7)
make_stratified_cluster_draw <- function(clusters, replicate_id, run_seed) data.frame()
apply_cluster_draw <- function(data, draw, cluster_col = "bootstrap_cluster_id") data.frame()
```

Gebruik `RNGkind("L'Ecuyer-CMRG")`; leid iedere replicatiestream uitsluitend af
van `run_seed` en `replicate_id`. `apply_cluster_draw()` kopieert de volledige
clusterhistorie en vervangt `plot_id` door het unieke synthetische site-ID.

- [ ] **Step 4: Bouw en controleer de echte clusterdefinitie**

Laat `audit_trim_bootstrap_clusters.R` controleren op:

- één stratum per cluster;
- overlappende of niet-aaneengesloten plotidentiteiten;
- dezelfde genormaliseerde kavelnaam onder meerdere `plot_id`'s;
- clusterjaren buiten het geconfigureerde analysebereik;
- lege historische of latere strata.

Schrijf `trim/bootstrap/cluster_definition.csv` met
`plot_id,bootstrap_cluster_id,stratum,eerst_jaar,laatst_jaar,primary_bridge_plot,strict_bridge_plot,reden`. Gebruik
`plot_id` als cluster-ID alleen waar de audit geen lineageconflict vindt. Een
conflict blokkeert verdere uitvoering totdat de mapping inhoudelijk is
vastgelegd.

- [ ] **Step 5: Verifieer de echte bronset**

Run:

```bash
Rscript R/audit_trim_bootstrap_clusters.R \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  trim/bootstrap/cluster_definition.csv
Rscript R/check_trim_bootstrap_sampling.R .
```

Expected op de ontwikkelbaseline 1958–2025: 52 ooit getelde bronplots, geen
ongeclassificeerde clusters, 33 primaire brugplots, 20 strikte brugplots en
gelijke aantallen per stratum vóór en na iedere trekking.

- [ ] **Step 6: Commit**

```bash
git add R/trim_bootstrap_core.R R/audit_trim_bootstrap_clusters.R \
  R/check_trim_bootstrap_sampling.R trim/bootstrap/cluster_definition.csv
git commit -m "Leg gestratificeerde plotbootstrap vast"
```

### Task 5: Empirische brug en één volledige bootstrapreplicatie

**Files:**
- Modify: `R/trim_bootstrap_core.R`
- Create: `R/trim_bridge_core.R`
- Create: `R/check_trim_bridge_core.R`
- Create: `R/check_trim_bootstrap_replicate.R`

**Interfaces:**
- Consumes: vooraf opgebouwde analysecontext, clustertrekking, vaste brugplotsets en replicatie-ID.
- Produces: `fit_bridge_calibration_trim()`, `compute_empirical_bridge()` en `run_trim_bootstrap_replicate()` met soort-, brugvariant-, groep- en diagnostiekregels.

- [ ] **Step 1: Schrijf falende tests voor de empirische brug**

Gebruik synthetische pre- en postindices en hulp-TRIM-totalen. Eis exact:

```r
b <- compute_empirical_bridge(
  pre_index = c(`1981` = 180, `1982` = 200, `1983` = 220),
  post_index = c(`1986` = 90, `1987` = 100, `1988` = 110),
  calibration_totals = c(`1981` = 40, `1982` = 50, `1983` = 60,
                         `1986` = 20, `1987` = 25, `1988` = 30)
)
stopifnot(all.equal(b$level_ratio, 0.5))
stopifnot(all.equal(b$bridge_factor, 1.0))
stopifnot(identical(b$method, "common_plot_trim_1981_1983_to_1986_1988"))
```

Voeg negatieve tests toe: 1984 of 1985 in `post_years` is voor de primaire
configuratie een fout; een mislukt hulp-TRIM of een niet-positief ankertotaal
levert status `geen_formele_brug` en nooit factor `1` als fallback.

- [ ] **Step 2: Voer de brugtest uit en verifieer RED**

Run: `Rscript R/check_trim_bridge_core.R .`

Expected: FAIL omdat `R/trim_bridge_core.R` ontbreekt.

- [ ] **Step 3: Implementeer hulp-TRIM en brugvarianten**

Definieer:

```r
fit_bridge_calibration_trim <- function(species_df, draw, plot_ids, pre_years, post_years) list()
compute_empirical_bridge <- function(pre_index, post_index, calibration_totals, pre_years = 1981:1983, post_years = 1986:1988) list()
compute_bridge_variants <- function(species_df, pre_index, post_index, draw, config) data.frame()
```

De hulp-TRIM gebruikt dezelfde synthetische sites en multipliciteiten als de
hoofdmodellen, model 3 met overdispersie en zonder seriële correlatie. Maak de
primaire variant 1986–1988, alternatieven 1987–1989 en 1988–1990, de strikte
20-plotvariant en de historische continuiteitscomparator 1984–1986.

- [ ] **Step 4: Schrijf de falende end-to-end-replicatietest**

De fixture bevat twee strata, acht plots, twee soorten, de ankerjaren en
overgangsjaren. Eis één gedeelde `draw_hash`, geldige primaire brugregels, alle
verplichte varianten, uitsluiting van 1984–1985 uit de primaire kalibratie en
een afzonderlijke historische-kernuitkomst.

- [ ] **Step 5: Implementeer context en volledige replicatieketen**

Definieer:

```r
build_bootstrap_context <- function(tbls, cluster_definition, config) list()
fit_first_working_trim_model <- function(df, configs) list()
run_trim_bootstrap_replicate <- function(context, replicate_id) list()
```

Stop na de eerste geslaagde hoofdmodelconfiguratie, maar registreer poging,
waarschuwing en fout. Herbereken per replicatie beide hoofd-TRIM-modellen,
hulp-TRIM, brugvarianten, gecombineerde soorttrend en historische-kernvariant.

- [ ] **Step 6: Verifieer determinisme en gedeelde trekking**

Run:

```bash
Rscript R/check_trim_bridge_core.R .
Rscript R/check_trim_bootstrap_replicate.R .
```

Voer dezelfde replicatie tweemaal uit. Eis identieke discrete velden,
numerieke verschillen kleiner dan `1e-12` en dezelfde synthetische site-ID's in
hoofdmodel en hulp-TRIM.

- [ ] **Step 7: Commit**

```bash
git add R/trim_bootstrap_core.R R/trim_bridge_core.R \
  R/check_trim_bridge_core.R R/check_trim_bootstrap_replicate.R
git commit -m "Voeg empirische TRIM-brug aan bootstrap toe"
```

### Task 6: Vaste robuuste groepen en volledige gevoeligheidsvariant

**Files:**
- Modify: `R/trim_bootstrap_core.R`
- Create: `R/check_trim_bootstrap_groups.R`

**Interfaces:**
- Consumes: oorspronkelijke selectie, groepsmapping en replicatiesoortindices per brug- en gebiedsvariant.
- Produces: primaire robuuste groepstrends met vaste samenstelling, volledige gevoeligheidstrends met werkelijk soortenaantal en dezelfde brug-/gebiedsvariantcodes als de soorten.

- [ ] **Step 1: Schrijf de falende groepsuitvaltest**

Maak een groep met drie vast geselecteerde soorten en verwijder in de
replicatie-output één soort. Eis:

```r
robust <- aggregate_bootstrap_group(indices_missing_one, fixed_group, "robuust")
full <- aggregate_bootstrap_group(indices_missing_one, fixed_group, "volledig")
stopifnot(identical(robust$status, "ongeldig_vaste_soort_ontbreekt"))
stopifnot(nrow(robust$series) == 0L)
stopifnot(identical(full$status, "geldig_wisselende_samenstelling"))
stopifnot(all(full$series$n_soorten == 2L))
stopifnot(setequal(unique(result$bridge_variant), required_bridge_variants))
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_bootstrap_groups.R .`

Expected: FAIL op ontbrekende `aggregate_bootstrap_group()`.

- [ ] **Step 3: Implementeer ecologische en functionele aggregatie**

Definieer aparte zuivere functies voor geometrisch, binair en gewogen
gemiddelde. Bewaar per jaar `n_soorten`, verwachte soorten, ontbrekende soorten
en som van gewichten. Een vaste primaire groepsreplicatie is alleen geldig als
alle vereiste soorten voor de geschatte periode aanwezig zijn.

- [ ] **Step 4: Verifieer alle varianten**

Test negen ecologische groepen en zes functionele groepen in binaire en gewogen
vorm, met `volledig` en `robuust`. Controleer dat gewichten niet na uitval
stilzwijgend tot een ander primair estimand worden hergeschaald. Controleer dat
iedere groep dezelfde brugvariant en gebiedsvariant gebruikt als alle
onderliggende soortindices binnen die replicatie.

- [ ] **Step 5: Commit**

```bash
git add R/trim_bootstrap_core.R R/check_trim_bootstrap_groups.R
git commit -m "Borg vaste samenstelling van bootstrapgroepen"
```

### Task 7: Bootstrapintervallen, p-waarden en stabiliteit

**Files:**
- Create: `R/trim_bootstrap_summary.R`
- Create: `R/run_trim_cluster_jackknife.R`
- Create: `R/check_trim_bootstrap_summary.R`

**Interfaces:**
- Consumes: analysecontext, oorspronkelijke puntschatting en geldige bootstrapwaarden per primaire, brug- en gebiedsvariant.
- Produces: clusterjackknifewaarden, standaardfout, percentile- en BCa-interval, empirische p-waarde, geldigheids- en stabiliteitsstatus plus `summarise_structural_sensitivity()`.

- [ ] **Step 1: Schrijf falende tests voor samenvatting en grenzen**

Test minimaal:

```r
s <- summarise_bootstrap_estimate(theta_hat = 1, boot = seq(-1, 3, length.out = 2000), jack = c(.8, .9, 1.1, 1.2), planned = 2000L)
stopifnot(s$valid_replicates == 2000L)
stopifnot(s$ci_low < s$estimate, s$ci_high > s$estimate)
stopifnot(s$interval_method %in% c("bca", "percentile_fallback"))
stopifnot(s$p_value >= 0, s$p_value <= 1)

bad <- summarise_bootstrap_estimate(1, c(rep(1, 1899), rep(NA, 101)), c(.9, 1.1), 2000L)
stopifnot(identical(bad$publication_status, "onvoldoende_bootstrap"))

sens <- summarise_structural_sensitivity(primary, alternatives, historical_core)
stopifnot(identical(sens$bridge_status, "bruggevoelig"))
stopifnot(identical(sens$coverage_status, "gebiedsdekkinggevoelig"))
stopifnot(identical(sens$envelope_type, "gevoeligheidsenvelop_geen_bi"))
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_bootstrap_summary.R .`

Expected: FAIL omdat de samenvattingsmodule ontbreekt.

- [ ] **Step 3: Implementeer percentile, BCa en empirische p**

Definieer:

```r
bca_interval <- function(theta_hat, boot, jack, conf = 0.95) numeric(2)
empirical_two_sided_p <- function(values, null = 0) numeric(1)
summarise_bootstrap_estimate <- function(theta_hat, boot, jack, planned) data.frame()
check_interval_stability <- function(previous, current) logical(1)
summarise_structural_sensitivity <- function(primary, bridge_variants, historical_core) data.frame()
```

Gebruik de eindige-steekproefcorrectie uit de spec. Val terug op percentile bij
niet-eindige BCa-acceleratie en leg de reden vast. Publiceer geen formeel
interval onder 95% geldige replicaties.
`summarise_structural_sensitivity()` vergelijkt richting en de vraag of het
interval nul omvat. De minimum- en maximumgrens over varianten worden nooit als
95%-interval benoemd.

- [ ] **Step 4: Test stabiliteitsregel exact**

Eis `TRUE` alleen wanneer beide grenzen minder veranderen dan 0,10
procentpunt/jaar én minder dan 5% van de actuele intervalbreedte. Test de
grenswaarden 0,099/0,049 en 0,100/0,050 afzonderlijk.

- [ ] **Step 5: Implementeer en test de clusterjackknife**

Definieer in `R/run_trim_cluster_jackknife.R`:

```r
run_trim_cluster_jackknife <- function(context) data.frame()
```

Laat voor ieder oorspronkelijk `bootstrap_cluster_id` precies één volledige
analyse weg, met behoud van de overige vaste selecties. Bewaar
`omitted_cluster_id`, stratum, entiteit, periode, schatting en foutstatus. Voeg
aan `R/check_trim_bootstrap_summary.R` een fixture met zes clusters toe en eis
zes unieke weglatingen, geen willekeurige trekking en identieke uitkomst bij
herhaling.

- [ ] **Step 6: Commit**

```bash
git add R/trim_bootstrap_summary.R R/run_trim_cluster_jackknife.R \
  R/check_trim_bootstrap_summary.R
git commit -m "Vat bootstraponzekerheid reproduceerbaar samen"
```

### Task 8: Lokale batchrunner, checkpoints en hervatten

**Files:**
- Create: `R/run_trim_bootstrap_batch.R`
- Create: `R/merge_trim_bootstrap_batches.R`
- Create: `R/check_trim_bootstrap_resume.R`
- Create: `scripts/run_trim_bootstrap_local.sh`

**Interfaces:**
- Consumes: runbundle, inclusief manifest, configuratie en uniek replicatiebereik.
- Produces: atomisch batchbestand plus batchmanifest; gevalideerde, niet-overlappende merge.

- [ ] **Step 1: Schrijf de falende hervat- en overlaptest**

Laat een testjob replicaties 1–5 uitvoeren, na replicatie 3 bewust stoppen en
daarna hervatten. Eis dat iedere replicatie exact eenmaal voorkomt. Kopieer
vervolgens batch 1–5 onder een tweede naam en eis dat merge faalt op overlap.

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_bootstrap_resume.R .`

Expected: FAIL omdat batchrunner en merger ontbreken.

- [ ] **Step 3: Implementeer atomische batches**

CLI-contract:

```text
Rscript R/run_trim_bootstrap_batch.R \
  --bundle RUN_DIR/input_bundle \
  --replicate-from 1 --replicate-to 25 \
  --output RUN_DIR/batches/batch-000001-000025.rds
```

Schrijf eerst `.partial`, voer `saveRDS()` en checksumcontrole uit en hernoem
daarna atomisch. Het manifest bevat run-ID, exacte replicatie-ID's, hashes,
runtime, piekgeheugen, swap, worker-ID en foutaantallen.

- [ ] **Step 4: Implementeer hervatten en mergevalidatie**

De runner slaat reeds complete replicaties over na checksumcontrole. De merger
weigert ontbrekende, dubbele, overlappende of niet-aaneengesloten IDs en iedere
hash- of softwareafwijking.

- [ ] **Step 5: Verifieer test en lokale rookrun**

Run:

```bash
Rscript R/check_trim_bootstrap_resume.R .
scripts/run_trim_bootstrap_local.sh --replicates 2 --batch-size 1 \
  --sql /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  --run-root "$TMPDIR/trim-bootstrap-smoke"
```

- [ ] **Step 6: Commit**

```bash
git add R/run_trim_bootstrap_batch.R R/merge_trim_bootstrap_batches.R \
  R/check_trim_bootstrap_resume.R scripts/run_trim_bootstrap_local.sh
git commit -m "Voeg hervatbare lokale bootstrapbatches toe"
```

### Task 9: Optionele NAS- en productie-VPS-workers

**Files:**
- Create: `scripts/probe_trim_bootstrap_worker.sh`
- Create: `scripts/run_trim_bootstrap_worker.sh`
- Create: `scripts/dispatch_trim_bootstrap_batches.sh`
- Create: `scripts/test_trim_bootstrap_workers.sh`
- Create: `trim/bootstrap_workers.example.csv`

**Interfaces:**
- Consumes: lokaal niet-gevolgd `trim/bootstrap_workers.csv` en een gevalideerd runbundle.
- Produces: capaciteitrapporten, veilig gedispatchte batches en teruggehaalde batchartefacten; geen publicatie-output.

- [ ] **Step 1: Schrijf falende workercontracttests**

Gebruik fake commando's en tijdelijke statusbestanden; maak geen echte
NAS/VPS-verbinding. Test:

- ontbrekende bronhash blokkeert;
- actieve `production.lock` blokkeert de VPS;
- ongezonde Shiny- of MySQL-status blokkeert de VPS;
- vrij geheugen kleiner dan `worker_limit + reserve` blokkeert;
- voldoende capaciteit levert status `eligible`;
- overlappende batchtoewijzingen worden vóór dispatch geweigerd.

Run: `bash scripts/test_trim_bootstrap_workers.sh`

Expected: FAIL omdat de workerscripts ontbreken.

- [ ] **Step 2: Definieer het workerconfiguratiecontract**

Maak `trim/bootstrap_workers.example.csv`:

```csv
worker_id,backend,ssh_target,remote_root,max_workers,enabled,role
imac,local,,,1,true,compute
nas,ssh,,,1,false,storage_or_compute
vps,ssh,ton@45.87.43.90,/srv/vwgm/bootstrap,1,false,compute
```

Het echte `trim/bootstrap_workers.csv` blijft genegeerd. Een lege `ssh_target`
of `remote_root` bij een ingeschakelde SSH-worker is een harde fout.

- [ ] **Step 3: Implementeer read-only capabilityprobe**

`probe_trim_bootstrap_worker.sh` rapporteert machineleesbaar:

```text
worker_id|architecture|cpu_count|memory_free_bytes|swap_used_bytes|load_1m|disk_free_bytes|docker_available|eligible|reason
```

Voor NAS controleert de probe daarnaast of back-up, scrub of SMART-test actief
is. Voor VPS controleert hij productie-lock, afzonderlijke bootstraplock,
containerstatus van `shiny_meijendel` en `meijendel-mysql`, lokale HTTP-health
en beschikbare productie-reserve. De probe verandert niets.

- [ ] **Step 4: Implementeer de geïsoleerde worker**

Gebruik lokaal `Rscript`. Gebruik op Linux-workers een apart tijdelijk
Dockerproces met het in het runbundle vastgelegde image-ID:

```bash
docker run --rm --read-only --cpus 0.5 --cpu-shares 128 --pids-limit 256 \
  --memory "$memory_limit" --memory-swap "$memory_limit" \
  --mount "type=bind,src=$input_dir,dst=/work/input,readonly" \
  --mount "type=bind,src=$output_dir,dst=/work/output" \
  "$image_id" Rscript /work/input/R/run_trim_bootstrap_batch.R "$@"
```

Bereken `memory_limit` als 125% van het gemeten pilotpiekgebruik. Start niet
wanneer daarna minder dan 1 GB NAS-reserve of 2 GB VPS-reserve overblijft.
Gebruik `nice -n 15` en waar beschikbaar `ionice -c 3`; start nooit een tweede
worker. Herhaal load-, geheugen-, swap-, schijf- en servicechecks vóór iedere
replicatie en vergelijk na iedere replicatie swap en servicehealth met de
nulmeting. Bij verslechtering stopt de worker vóór de volgende replicatie.

- [ ] **Step 5: Implementeer dispatch zonder langdurige deploylock**

De VPS-worker maakt atomair `/srv/vwgm/bootstrap/bootstrap.lock` aan, maar
controleert vóór iedere replicatie dat
`/srv/vwgm/deploy-state/production.lock` afwezig is. Hij leest die bestaande
productielock alleen, wijzigt geen deployscript of productieguard en houdt de
productiedeploylock niet vast. Bij een nieuw aangetroffen deploylock pauzeert
dispatch vóór de volgende replicatie. Alleen de iMac wijst bereiken toe en
haalt complete bestanden via checksumvergelijking terug.

- [ ] **Step 6: Test lokale simulatie en cross-workerpariteit**

Laat twee lokale fake workers dezelfde replicaties 1–2 uitvoeren vanuit exact
hetzelfde bundle. Eis exacte discrete gelijkheid en maximale numerieke afwijking
`<= 1e-8`. Activeer NAS/VPS nog niet.

- [ ] **Step 7: Voer afzonderlijke read-only capaciteitsproeven uit**

Pas na expliciete bevestiging voor het feitelijke NAS-pad en de workerconfig:

```bash
scripts/probe_trim_bootstrap_worker.sh --worker nas \
  --config trim/bootstrap_workers.csv
scripts/probe_trim_bootstrap_worker.sh --worker vps \
  --config trim/bootstrap_workers.csv
```

Leg CPU, vrij geheugen, swap, opslag, Docker/imagebeschikbaarheid en actieve
taken vast. Rapporteer ook Shiny/MySQL-responstijd vóór en na de proefreplicatie.
Vraag daarna afzonderlijk expliciet akkoord voordat `enabled = true` wordt
gezet. Een niet-geschikte NAS blijft uitsluitend checkpointopslag; een
niet-geschikte VPS blijft geheel uitgeschakeld.

- [ ] **Step 8: Draai per geschikte externe worker één gelijkheidsbatch**

Gebruik exact dezelfde twee replicatie-ID's als lokaal. Activeer een worker
voor productie pas na groene hash-, schema- en numerieke vergelijking, een
ongewijzigde Shiny/MySQL-healthcheck en afzonderlijk expliciet akkoord van de
gebruiker. Zonder dat akkoord blijft de lokale run doorgaan.

- [ ] **Step 9: Commit code en voorbeeldconfiguratie**

```bash
git add scripts/probe_trim_bootstrap_worker.sh \
  scripts/run_trim_bootstrap_worker.sh scripts/dispatch_trim_bootstrap_batches.sh \
  scripts/test_trim_bootstrap_workers.sh trim/bootstrap_workers.example.csv
git commit -m "Voeg veilige optionele bootstrapworkers toe"
```

### Task 10: Sandra-soorten en -groepen

**Files:**
- Modify: `R/trim_sandra_soorten_en_msi_evg.R`
- Modify: `R/trim_bootstrap_core.R`
- Create: `R/check_trim_sandra_uncertainty.R`

**Interfaces:**
- Consumes: 110 geselecteerde Sandra-soorten over 1997–2022.
- Produces: `overall()`-soortintervallen en clusterbootstrapintervallen voor Sandra-groepen zonder brugstap.

- [ ] **Step 1: Schrijf de falende Sandra-contracttest**

Eis 110 selectieregels voor 1997–2022, geen brugvelden in de
replicatieketen, `rtrim_overall_imputed_vcov` voor geslaagde soorttrends en
bootstrapvelden voor beide groepsvarianten.

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_sandra_uncertainty.R . /Users/ton/Documents/GitHub/Meijendel/meijendel.sql`

Expected: FAIL omdat de nieuwe onzekerheidsuitvoer ontbreekt.

- [ ] **Step 3: Hergebruik bootstrapkern zonder brug**

Voeg configuratie `bridge = FALSE`, `period = c(1997L, 2022L)` toe. Hergebruik
dezelfde cluster-, batch-, interval- en geldigheidslogica. Maak geen tweede
fork van de bootstrapengine.

- [ ] **Step 4: Verifieer en commit**

```bash
Rscript R/check_trim_sandra_uncertainty.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql
git add R/trim_sandra_soorten_en_msi_evg.R R/trim_bootstrap_core.R \
  R/check_trim_sandra_uncertainty.R
git commit -m "Voeg formele Sandra-onzekerheid toe"
```

### Task 11: Publicatiebestanden en schema-contract

**Files:**
- Create: `R/write_trim_uncertainty_outputs.R`
- Create: `R/check_trim_uncertainty_outputs.R`
- Modify: `R/trim_soorten_en_msi_evg.R`
- Modify: `R/trim_sandra_soorten_en_msi_evg.R`
- Modify: `R/trim_soorten_en_msi_evg.md`
- Modify: `R/trim_sandra_soorten_en_msi_evg.md`

**Interfaces:**
- Consumes: oorspronkelijke puntschattingen, bootstrap- en jackknifesamenvattingen en runmanifest.
- Produces: de in de spec genoemde compacte CSV's, diagnostiek en `trim/bootstrap/run_manifest.json`.

- [ ] **Step 1: Schrijf de falende uitvoercontracttest**

Eis per trendbestand minimaal:

```r
required <- c(
  "entity_type", "entity_id", "period", "method", "estimate_pct_per_year",
  "se_pct", "ci_low_pct", "ci_high_pct", "p_value", "interval_method",
  "planned_replicates", "valid_replicates", "valid_fraction",
  "publication_status", "bridge_variant", "bridge_status", "coverage_status",
  "run_id"
)
stopifnot(!length(setdiff(required, names(result))))
stopifnot(all(result$ci_low_pct <= result$estimate_pct_per_year, na.rm = TRUE))
stopifnot(all(result$ci_high_pct >= result$estimate_pct_per_year, na.rm = TRUE))
```

- [ ] **Step 2: Voer test uit en verifieer RED**

Run: `Rscript R/check_trim_uncertainty_outputs.R . "$TMPDIR/trim-output-fixture"`

Expected: FAIL omdat writer of bestanden ontbreken.

- [ ] **Step 3: Implementeer atomische publicatiewriter**

Schrijf eerst naar een tijdelijke publicatiemap. Schrijf afzonderlijk
`brugvenstergevoeligheid.csv` en `historische_kerngevoeligheid.csv`. Controleer
schema, unieke sleutels, perioden, eindige grenzen,
status/intervalconsistentie, gevoeligheidsenveloplabel en run-ID.
Vervang de canonieke bestanden pas na een volledig groen contract.

- [ ] **Step 4: Documenteer methode en actualisatiecommand**

Documenteer 1958–1983, 1984–actueel eindjaar en 1958–actueel eindjaar
afzonderlijk. Leg uit dat de laatste een gecombineerde gemeenschappelijke-
plotbrugtrendschatter is, dat 1984–1985 niet kalibreren en dat de
gevoeligheidsenvelop geen betrouwbaarheidsinterval is. Vermeld voor de
Sandra-set exact 110 geselecteerde soorten over 1997–2022.

- [ ] **Step 5: Verifieer en commit**

```bash
Rscript R/check_trim_uncertainty_outputs.R . "$TMPDIR/trim-output-fixture"
git add R/write_trim_uncertainty_outputs.R R/check_trim_uncertainty_outputs.R \
  R/trim_soorten_en_msi_evg.R R/trim_sandra_soorten_en_msi_evg.R \
  R/trim_soorten_en_msi_evg.md R/trim_sandra_soorten_en_msi_evg.md
git commit -m "Definieer TRIM-bootstrapuitvoer"
```

Schrijf in deze fase geen 50- of 500-replicatieresultaat naar de canonieke
publicatiebestanden; alleen een latere geldige 2.000+-run over 1958–2026 mag
die bestanden activeren.

### Task 12: Website en dashboard

**Files:**
- Modify: `R/build_groepen_grafieken_dashboard_csv.R`
- Modify: `R/check_dashboard_website_parity.R`
- Modify: `bmp_meijendel_index.html`
- Create: `R/check_trim_uncertainty_presentation.R`

**Interfaces:**
- Consumes: vooraf berekende onzekerheids-CSV's.
- Produces: primaire periodetrends, aanvullende gecombineerde trend en robuuste groepsintervallen met vaste kwalificatietekst.

- [ ] **Step 1: Lokaliseer alle consumenten vóór wijziging**

Run:

```bash
rg -n "overall_trend_pct_per_jaar|trend_pre_pct_per_jaar|trend_post_pct_per_jaar|trendoverzicht_msi|soorten_trendoverzicht" R bmp_meijendel_index.html groepen_grafieken
```

Leg de gevonden generator en outputvelden in de test vast; wijzig geen
handgegenereerde HTML zonder bijbehorende generatorwijziging.

- [ ] **Step 2: Schrijf de falende presentatietest**

Eis in gegenereerde data/HTML:

- periodevelden afgeleid van het runmanifest, met in de ontwikkelfixture
  `1958–1983`, `1984–2025` en `1958–2025`;
- onder- en bovengrens;
- tekst `Gecombineerde trend via een geschatte gemeenschappelijke-plotbrug van 1981–1983 naar 1986–1988; geen enkel doorlopend TRIM-model.`;
- zichtbare kwalificatie bij `bruggevoelig` en `gebiedsdekkinggevoelig`;
- label `gevoeligheidsenvelop; geen 95%-betrouwbaarheidsinterval`;
- robuuste groepsvariant vóór volledige gevoeligheidsvariant;
- geen intervalweergave bij `onvoldoende_bootstrap`;
- bytegelijk behoud van de huidige beschrijvende presentatie wanneer nog geen
  definitieve 2026-bootstrapbestanden aanwezig zijn.

- [ ] **Step 3: Voer test uit en verifieer RED**

Run: `Rscript R/check_trim_uncertainty_presentation.R .`

Expected: FAIL omdat de presentatie nog geen onzekerheidsvelden gebruikt.

- [ ] **Step 4: Implementeer presentatie minimaal**

Voeg compacte trendregels en tooltips toe. Toon methode, geldig aantal
replicaties en rekendatum. Gebruik geen betrouwbaarheidslint voor jaarindices in
deze fase; de spec sluit simultane jaarlijkse banden uit. Activeer nieuwe
velden uitsluitend wanneer runmanifest en uitvoercontract beide status
`publiceerbaar` hebben; anders blijft de bestaande presentatie intact.

- [ ] **Step 5: Genereer en verifieer**

Run:

```bash
Rscript R/build_groepen_grafieken_dashboard_csv.R \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-dashboard-fixture"
Rscript R/check_trim_uncertainty_presentation.R .
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
```

Voer daarnaast een visuele desktop- en mobiele controle uit van soorten,
groepen en methodetoelichting.

- [ ] **Step 6: Commit**

```bash
git add R/build_groepen_grafieken_dashboard_csv.R \
  R/check_dashboard_website_parity.R R/check_trim_uncertainty_presentation.R \
  bmp_meijendel_index.html
git commit -m "Bereid formele trendonzekerheid in dashboard voor"
```

### Task 13: Shiny gebruikt alleen vooraf berekende standaardintervallen

**Files:**
- Modify: `shiny_meijendel/helpers.R`
- Modify: `shiny_meijendel/app.R`
- Modify: `shiny_meijendel/README_shiny_meijendel.md`
- Modify: `R/check_shiny_dashboard_parity.R`
- Create: `R/check_shiny_trim_uncertainty_contract.R`

**Interfaces:**
- Consumes: canonieke onzekerheidsbestanden voor de ongewijzigde standaardselectie.
- Produces: standaardintervallen in Shiny; expliciet verkennend label zonder interval bij aangepaste selectie.

- [ ] **Step 1: Schrijf de falende Shiny-contracttest**

Eis:

```r
standard <- resolve_trim_uncertainty(selection_hash = canonical_hash, results)
custom <- resolve_trim_uncertainty(selection_hash = "anders", results)
pending <- resolve_trim_uncertainty(selection_hash = canonical_hash, results_pending)
stopifnot(identical(standard$status, "precomputed_formal"))
stopifnot(is.finite(standard$ci_low_pct))
stopifnot(identical(custom$status, "exploratory_no_formal_interval"))
stopifnot(is.na(custom$ci_low_pct), is.na(custom$ci_high_pct))
stopifnot(identical(pending$status, "descriptive_pending_final_run"))
```

- [ ] **Step 2: Voer test uit en verifieer RED**

Run: `Rscript R/check_shiny_trim_uncertainty_contract.R .`

Expected: FAIL omdat resolver en selectiehash ontbreken.

- [ ] **Step 3: Implementeer selectiehash en resolver**

Hash exacte plot-, jaar-, soort- en groepsselecties. Alleen een exacte match met
een publiceerbaar runmanifest krijgt vooraf berekende intervallen. Een nog niet
definitieve run behoudt de bestaande beschrijvende presentatie. Iedere echte
selectieafwijking toont:
`Verkennende selectie; geen formeel bootstrapinterval.` Start nergens vanuit
Shiny een bootstrapproces.

- [ ] **Step 4: Verifieer regressie en pariteit**

Run:

```bash
Rscript R/check_shiny_trim_uncertainty_contract.R .
Rscript R/check_shiny_dashboard_parity.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  trim_msi_evg/msi_per_groep_per_jaar.csv 1958 2025
```

Controleer visueel standaard- en maatwerkselectie. Geen bestaande tab, grafiek,
filter of toelichting mag verdwijnen.

- [ ] **Step 5: Commit**

```bash
git add shiny_meijendel/helpers.R shiny_meijendel/app.R \
  shiny_meijendel/README_shiny_meijendel.md \
  R/check_shiny_dashboard_parity.R R/check_shiny_trim_uncertainty_contract.R
git commit -m "Gebruik vooraf berekende onzekerheid in Shiny"
```

### Task 14: Pilot 50 en validatie 500 vóór broedseizoen 2026

**Files:**
- Modify: `trim/bootstrap/run_manifest.json`
- Modify: `trim/bootstrap/diagnostiek.csv`
- Modify: `STATUS.md`
- Modify: `TODO.md`
- Modify: `DECISIONS.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.md`
- Modify: `docs/MEIJENDEL_BRONREGISTER.docx`

**Interfaces:**
- Consumes: volledig geteste lokale keten en de ontwikkelbronset 1958–2025.
- Produces: feitelijke prestatie-, uitval- en gevoeligheidsgegevens, een gevalideerde maar nog niet gepubliceerde bootstrapketen en actuele projectdocumentatie.

- [x] **Step 1: Draai de lokale pilot van 50 replicaties**

Gebruik batches van 5, één worker en een vaste seed. Registreer totale tijd,
seconden per replicatie, piekgeheugen, swap, foutpercentage per soort/groep en
hervatbaarheid. Vergelijk de eerste twee replicaties met een tweede lokale run.

- [x] **Step 2: Beoordeel op meetwaarden of externe workers later zinvol kunnen zijn**

Bereken workergeheugenlimiet als 125% van de pilotpiek. Maak alleen een
read-only geschiktheidsrapport wanneer Ton vooraf het NAS-pad of de VPS-probe
afzonderlijk goedkeurt. Activeer in deze taak geen NAS- of VPS-worker.

- [ ] **Step 3: Draai validatie met 500 replicaties**

Niet gestart op 17 oktober 2026. De 50-pilot leverde voor slechts 5 van 21
primaire vaste groepsschatters minimaal 95% geldige replicaties; een eerste
rookreplicatie na correctie van de formele soortpoort leverde 7 van 21 geldige
vaste groepen. Volgens de stopregel is eerst een expliciet methodisch besluit
en daarna een nieuwe 50-pilot nodig.

Controleer:

- minimaal 95% geldige replicaties per kandidaat-schatter;
- BCa versus percentile;
- model- en fallbackfrequenties;
- vaste primaire groepssamenstelling;
- bruggevoeligheid, strikte 20-plotvariant en historische-kerngevoeligheid;
- reproduceerbaarheid na hervatten.

Stop en corrigeer de implementatie wanneer een kandidaat-schatter onder 95%
geldig blijft. Een structureel ongeldige schatter wordt niet door meer
replicaties geldig gemaakt.

- [ ] **Step 4: Controleer de structurele gevoeligheid en leg de 2026-gate vast**

Vergelijk primaire brug, beide alternatieve postvensters, de strikte
20-plotvariant, de historische comparator en de vaste historische-kernvariant.
Leg per soort en groep de gevoeligheidsstatus vast. Markeer de keten daarna als
`gereed_voor_productierun_na_2026`; start geen 2.000-run op 1958–2025.

- [x] **Step 5: Werk methode- en bronregistratie bij**

Werk `STATUS.md`, `TODO.md`, `DECISIONS.md`, `ARCHITECTURE.md` en het leidende
bronregister bij met de getelde dataset, aantallen, periode, brugkeuze,
structurele beperking en 2026-gate. Actualiseer daarna ook
`docs/MEIJENDEL_BRONREGISTER.docx`, render hem met het bestaande projectscript
en controleer alle pagina's visueel.

- [x] **Step 6: Leg feitelijke pilot- en validatieresultaten vast**

Leg vast:

- bronset met aantal, periode en hash;
- werkelijk aantal replicaties;
- uitsluitend lokaal gebruikte worker en eventuele niet-uitgevoerde externe
  opties;
- totale en lokale doorlooptijd;
- geheugen en swap;
- geldige percentages en fallbacks;
- intervalmethode en eventuele uitzonderingen;
- jaarlijkse actualisatieroute en de harde stop vóór 2026.

- [ ] **Step 7: Volledige eindverificatie**

Gebruik voor deze stap een taakgebonden, niet-gevolgde validatiemap als
`VALIDATION_ROOT`; schrijf geen pilot- of 500-run naar de canonieke
publicatiepaden.

Run minimaal:

```bash
scripts/test_shiny_reproducibility.sh
bash scripts/test_trim_source_output_contract.sh
Rscript R/check_trim_scripts_sourceable.R .
Rscript R/test_trim_trend_contract.R
Rscript R/check_trim_analysis_period.R .
Rscript R/check_trim_bridge_audit.R .
Rscript R/check_trim_bridge_core.R .
Rscript R/check_trim_bootstrap_sampling.R .
Rscript R/check_trim_bootstrap_replicate.R .
Rscript R/check_trim_bootstrap_groups.R .
Rscript R/check_trim_bootstrap_summary.R .
Rscript R/check_trim_bootstrap_resume.R .
bash scripts/test_trim_bootstrap_workers.sh
Rscript R/check_trim_sandra_uncertainty.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql
Rscript R/check_trim_uncertainty_outputs.R . "$VALIDATION_ROOT/publication-fixture"
Rscript R/check_trim_uncertainty_presentation.R .
Rscript R/check_shiny_trim_uncertainty_contract.R .
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
Rscript R/check_shiny_dashboard_parity.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  trim_msi_evg/msi_per_groep_per_jaar.csv 1958 2025
scripts/render_docx_local.sh docs/MEIJENDEL_BRONREGISTER.md \
  docs/MEIJENDEL_BRONREGISTER.docx
git diff --check
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
```

- [ ] **Step 8: Commit de gevalideerde engine, pilotdiagnostiek en documentatie**

```bash
git add trim/bootstrap STATUS.md TODO.md DECISIONS.md ARCHITECTURE.md \
  docs/MEIJENDEL_BRONREGISTER.md docs/MEIJENDEL_BRONREGISTER.docx
git commit -m "Valideer TRIM-bootstrapketen vóór cijfers 2026"
```

### Task 15: Review en integratie van de voorbereide bootstrapketen

**Files:**
- Modify: geen productie- of releasebestanden in deze fase

**Interfaces:**
- Consumes: volledig groene featurebranch met engine, tests, pilot, validatie en gedocumenteerde 2026-gate.
- Produces: gereviewde integratie in actuele `main`; geen 2.000-run, geen gewijzigde canonieke onzekerheidsoutput en geen VPS-publicatie.

- [ ] **Step 1: Laat de volledige branch onafhankelijk reviewen**

Review statistische estimands, empirische brugformule, vaste
groepssamenstelling, structurele gevoeligheidsstatussen, hervatbaarheid,
workerveiligheid, uitvoercontracten en terugwaartse compatibiliteit van alle
UI-consumenten. Los bevindingen testgestuurd op.

- [ ] **Step 2: Integreer uitsluitend op schone actuele `main`**

Voer projectpreflight uit, actualiseer refs, verifieer ancestry en integreer
volgens de geldende repositoryworkflow. Draai daarna de volledige testset
opnieuw op `main`.

- [ ] **Step 3: Verifieer dat de huidige productiepresentatie ongewijzigd blijft**

Zonder definitieve 2026-run mogen website, dashboard en Shiny geen
bootstrapinterval tonen. Ontbrekende definitieve bestanden moeten veilig
terugvallen op de huidige primaire periodetrends en beschrijvende gecombineerde
trend. Test dit expliciet op `main`.

- [ ] **Step 4: Leg de afzonderlijke vervolgfase na ontvangst van 2026 vast**

De vervolgfase omvat pas na complete en gevalideerde cijfers over 2026:

- afzonderlijk akkoord voor een nieuwe dump uit de levende lokale database en
  de zware afgeleide keten;
- herijking van aantallen, vaste soortenpopulatie en groepssamenstelling;
- minimaal 2.000 en zo nodig maximaal 5.000 replicaties;
- generatie van canonieke publicatiebestanden en volledige pariteitstests;
- afzonderlijk expliciet akkoord voor VPS-publicatie en pas daarna bijwerking
  van `VWG_Project/RELEASE_MANIFEST.yml`.

- [ ] **Step 5: Voer eindpreflight uit en push geïntegreerde main**

Eis `main == origin/main` in alle drie repositories en een schone werkboom.
Verwijder geen branch, worktree of pilotbewijs zonder afzonderlijke beoordeling.
