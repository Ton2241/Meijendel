# TRIM-bootstraponzekerheid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publiceer formele onzekerheid voor afzonderlijke TRIM-perioden, de gebrugde soorttrend 1958–2025 en ecologische en functionele MSI-groepen, met een reproduceerbare gestratificeerde clusterbootstrap die lokaal en optioneel op NAS/VPS in controleerbare batches draait.

**Architecture:** De bestaande TRIM-batchscripts worden sourcebaar gemaakt zonder hun CLI-gedrag te veranderen. Een nieuwe zuivere bootstrapkern trekt volledige plotclusters binnen vaste strata, voert per replicatie de bestaande soort-, brug- en groepsketen uit en schrijft atomische batchartefacten. De iMac coördineert en valideert alle batches; NAS en productie-VPS zijn optionele workers die nooit canonieke uitvoer schrijven en alleen na een groene capaciteitstest worden geactiveerd.

**Tech Stack:** R 4.6.1, `rtrim` 2.3.1, base R-tests met `stopifnot`, shellcontracttests, JSON via `jsonlite`, Git, Docker voor Linux-workers, SSH/rsync voor optionele NAS/VPS-workers.

**Spec:** `docs/superpowers/specs/2026-09-20-trim-bootstrap-onzekerheid-design.md`

## Global Constraints

- De bronset Meijendel bevat 55 plots en 3.159 plot-jaarregels over 1958–2025; iedere gegevensuitspraak noemt verzameling, aantal en periode.
- De afzonderlijke soortperioden 1958–1983 en 1984–2025 blijven primair en gebruiken `rtrim::overall(..., which = "imputed")`.
- De soorttrend 1958–2025 heet altijd `gecombineerde trend via brugfactor`; presenteer hem nooit als één doorlopend TRIM-model.
- Trek volledige plotgeschiedenissen met teruglegging binnen vaste strata; trek geen jaren, indexwaarden of soorten afzonderlijk.
- Gebruik binnen een replicatie exact dezelfde clustertrekking voor alle soorten en groepen.
- De primaire robuuste groep heeft vaste soortensamenstelling; een ontbrekende vaste groepssoort maakt die groepsreplicatie ongeldig.
- Gebruik minimaal 2.000 replicaties; verleng alleen volgens het vastgelegde stabiliteitscriterium, tot maximaal 5.000.
- Draai geen bootstrap in een interactieve website- of Shiny-request.
- De iMac is coördinator en referentie. NAS/VPS zijn optioneel, schrijven alleen batchresultaten en worden niet automatisch geactiveerd.
- De volledige 2.000-run blijft lokaal uitvoerbaar; NAS/VPS staan standaard uit en vereisen na een read-only proef afzonderlijk expliciet akkoord.
- Normaal functioneren van NAS en VPS gaat altijd vóór rekensnelheid; veiligheidsgrenzen worden nooit voor doorlooptijd versoepeld.
- De productie-VPS gebruikt een aparte container en uitvoermap; raak actieve Shiny- en MySQL-containers niet aan.
- Houd credentials, lokale workerconfiguratie, ruwe replicaties, caches en runtime-output buiten Git.
- Werk testgestuurd: schrijf en observeer eerst de bedoelde testfout, implementeer daarna minimaal en draai vervolgens de gerichte én relevante bestaande tests.
- Voer begin- en eindpreflight uit; commit logisch afgeronde taken en deploy pas na integratie in schone actuele `main` volgens de projectworkflow.

## Review Focus

- **Plotduplicatie:** twee trekkingen van hetzelfde bronplot moeten twee unieke TRIM-site-ID's opleveren; Task 4 test dit expliciet.
- **Vaste groepssamenstelling:** uitval van één primaire groepssoort mag geen kleiner ogenschijnlijk geldig MSI opleveren; Task 6 test dat de replicatie ongeldig wordt.
- **Hervatten en dubbelen:** een afgebroken of dubbel aangeleverde batch mag geen replicatie tweemaal meetellen; Task 8 test atomische hervatting en overlapafwijzing.
- **Heterogene workers:** dezelfde replicaties op macOS en Linux moeten discrete velden exact en numerieke velden binnen `1e-8` reproduceren; Task 9 test de workerpariteit.
- **Productieveiligheid en preëmptie:** een VPS-worker mag niet starten bij deploylock, onvoldoende reservegeheugen of ongezonde Shiny/MySQL-status en een externe worker mag na swapgroei of verslechterde health geen volgende replicatie starten; Task 9 test deze blokkades.

---

### Task 1: Canonieke regressiebaseline uit één bronrun

**Files:**
- Create: `R/trim_run_manifest.R`
- Create: `R/check_trim_source_output_contract.R`
- Create: `scripts/test_trim_source_output_contract.sh`
- Modify: `.gitignore`
- Modify: `R/trim_soorten_en_msi_evg.md`
- Modify: `R/trim_sandra_soorten_en_msi_evg.md`

**Interfaces:**
- Consumes: één expliciet SQL-pad, Git-commit, R- en packageversies en de bestaande TRIM-outputmappen.
- Produces: `trim/run_manifest.json` met bronhash en uitvoerchecksums; een contractcontrole die gemengde bron- en outputruns weigert.

- [ ] **Step 1: Schrijf de falende bron/outputcontracttest**

Maak `scripts/test_trim_source_output_contract.sh` met een tijdelijke SQL-fixture, twee kleine uitvoerbestanden en een manifest met opzettelijk verkeerde SQL-hash:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/trim-contract.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf 'bron-a\n' > "$work/meijendel.sql"
printf 'x,y\n1,2\n' > "$work/out/result.csv"
Rscript "$repo/R/trim_run_manifest.R" create \
  --sql "$work/meijendel.sql" --output "$work/out" \
  --manifest "$work/run_manifest.json" --run-id test-run
printf 'bron-b\n' > "$work/meijendel.sql"
if Rscript "$repo/R/check_trim_source_output_contract.R" \
  "$work/meijendel.sql" "$work/out" "$work/run_manifest.json"; then
  echo 'Contract had gewijzigde SQL moeten weigeren.' >&2
  exit 1
fi
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `bash scripts/test_trim_source_output_contract.sh`

Expected: FAIL omdat `R/trim_run_manifest.R` nog ontbreekt.

- [ ] **Step 3: Implementeer manifest en contractcontrole minimaal**

Implementeer in `R/trim_run_manifest.R` de functies:

```r
sha256_file <- function(path) character(1)
hash_output_tree <- function(path) data.frame(path = character(), sha256 = character())
build_trim_run_manifest <- function(sql_path, output_dir, run_id, git_commit) list()
write_trim_run_manifest <- function(manifest, path) invisible(path)
```

Gebruik `system2("shasum", c("-a", "256", path), stdout = TRUE)` op macOS en
`sha256sum` als fallback. Sorteer relatieve bestandspaden vóór hashing. De
controle weigert ontbrekende bestanden, gewijzigde bronhash, gewijzigde
uitvoerchecksum of een leeg run-ID.

- [ ] **Step 4: Voeg runtimepaden aan `.gitignore` toe**

Voeg uitsluitend deze patronen toe:

```gitignore
trim/bootstrap_runs/
trim/bootstrap_workers.csv
trim/**/*.partial
```

- [ ] **Step 5: Draai test en bestaande lichte baselinecontroles**

Run:

```bash
bash scripts/test_trim_source_output_contract.sh
scripts/test_shiny_reproducibility.sh
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
```

Expected: alle groen.

- [ ] **Step 6: Bouw SQL en bestaande TRIM/dashboardoutput uit één bronrun**

Gebruik één vastgelegd lokaal SQL-pad. Genereer eerst naar een tijdelijke map,
maak het manifest, controleer aantallen voor de bronset 1958–2025 en vervang de
gevolgde output alleen wanneer alle contract- en pariteitstests groen zijn.

Run:

```bash
Rscript R/trim_soorten_en_msi_evg.R /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-baseline/trim/soorten" "$TMPDIR/trim-baseline/trim_msi_evg"
Rscript R/build_groepen_grafieken_dashboard_csv.R \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-baseline/groepen_grafieken"
```

Controleer exact: 55 plots, 3.159 plot-jaarregels, 159 soortstatusregels, 137
soorten met indices en 95 brugbare soorten. Als deze aantallen door een
gedocumenteerde broncorrectie zijn gewijzigd, stop en leg het verschil voor
voordat gevolgde output wordt vervangen.

- [ ] **Step 7: Commit de baselinecontractwijziging**

```bash
git add .gitignore R/trim_run_manifest.R R/check_trim_source_output_contract.R \
  scripts/test_trim_source_output_contract.sh R/trim_soorten_en_msi_evg.md \
  R/trim_sandra_soorten_en_msi_evg.md trim trim_msi_evg groepen_grafieken
git commit -m "Borg bron en uitvoer van TRIM-runs"
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

### Task 3: Formele trends voor afzonderlijke TRIM-perioden

**Files:**
- Create: `R/trim_uncertainty_core.R`
- Create: `R/check_trim_overall_trends.R`
- Modify: `R/trim_soorten_en_msi_evg.R`
- Modify: `R/trim_sandra_soorten_en_msi_evg.R`

**Interfaces:**
- Consumes: een geslaagde `fit_trim_model()`-uitkomst en periodelabel.
- Produces: `extract_trim_overall(fit_obj, period_label)` met additieve helling, multiplicatieve helling, SE, 95%-BI, p-waarde en procent per jaar.

- [ ] **Step 1: Schrijf een falende synthetische overall-test**

Maak een klein telpaneel met zes jaren, vier sites, één stijgende soort en één
stabiele soort. Pas `rtrim::trim()` toe en eis:

```r
up <- extract_trim_overall(up_fit, "1984-1989")
flat <- extract_trim_overall(flat_fit, "1984-1989")
stopifnot(up$trend_pct_per_year > 0)
stopifnot(up$ci_low_pct < up$trend_pct_per_year)
stopifnot(up$ci_high_pct > up$trend_pct_per_year)
stopifnot(is.finite(up$se_pct), is.finite(up$p_value))
stopifnot(abs(flat$trend_pct_per_year) < 1e-8)
stopifnot(identical(up$method, "rtrim_overall_imputed_vcov"))
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_overall_trends.R .`

Expected: FAIL omdat `extract_trim_overall()` ontbreekt.

- [ ] **Step 3: Implementeer `extract_trim_overall()`**

Gebruik `rtrim::overall(fit_obj$model, which = "imputed")`. Lees de
slope-regel, bereken:

```r
trend_pct <- 100 * (exp(beta) - 1)
se_pct <- 100 * exp(beta) * se_beta
critical <- qt(0.975, df = overall$J - 2L)
ci_low_pct <- 100 * (exp(beta - critical * se_beta) - 1)
ci_high_pct <- 100 * (exp(beta + critical * se_beta) - 1)
```

Weiger `J < 3`, niet-eindige waarden en een ontbrekende slope met een
gestructureerde status in plaats van een ongerichte fout.

- [ ] **Step 4: Vervang alleen de formele periodetrends**

Gebruik `extract_trim_overall()` voor `trend_pre_*`, `trend_post_*` en de
Sandra-soorttrend. Behoud de huidige gebrugde `overall_trend_*` voorlopig als
beschrijvende puntschatting met methodecode
`loglineair_op_gebrugde_trim_indices_zonder_interval`.

- [ ] **Step 5: Verifieer tests en uitvoerschema**

Run:

```bash
Rscript R/check_trim_overall_trends.R .
Rscript R/trim_soorten_en_msi_evg.R /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-overall/soorten" "$TMPDIR/trim-overall/groepen"
Rscript R/trim_sandra_soorten_en_msi_evg.R /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  "$TMPDIR/trim-overall/sandra-soorten" "$TMPDIR/trim-overall/sandra-groepen"
```

Controleer dat iedere geslaagde soortperiode SE, ondergrens, bovengrens,
p-waarde, periode en methode bevat.

- [ ] **Step 6: Commit**

```bash
git add R/trim_uncertainty_core.R R/check_trim_overall_trends.R \
  R/trim_soorten_en_msi_evg.R R/trim_sandra_soorten_en_msi_evg.R
git commit -m "Voeg formele TRIM-periodetrends toe"
```

### Task 4: Plotlineage, strata en reproduceerbare clustertrekking

**Files:**
- Create: `R/trim_bootstrap_core.R`
- Create: `R/audit_trim_bootstrap_clusters.R`
- Create: `R/check_trim_bootstrap_sampling.R`
- Create: `trim/bootstrap/cluster_definition.csv`

**Interfaces:**
- Consumes: analysebasis met `plot_id`, `kavel_nummer`, jaar en historische-kernstatus.
- Produces: gevalideerde clusterdefinitie en `make_stratified_cluster_draw(clusters, replicate_id, run_seed)`.

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
- clusterjaren buiten 1958–2025;
- lege historische of latere strata.

Schrijf `trim/bootstrap/cluster_definition.csv` met
`plot_id,bootstrap_cluster_id,stratum,eerst_jaar,laatst_jaar,reden`. Gebruik
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

Expected: 55 bronplots over 1958–2025, geen ongeclassificeerde clusters en
gelijke aantallen per stratum vóór en na iedere trekking.

- [ ] **Step 6: Commit**

```bash
git add R/trim_bootstrap_core.R R/audit_trim_bootstrap_clusters.R \
  R/check_trim_bootstrap_sampling.R trim/bootstrap/cluster_definition.csv
git commit -m "Leg gestratificeerde plotbootstrap vast"
```

### Task 5: Eén volledige bootstrapreplicatie

**Files:**
- Modify: `R/trim_bootstrap_core.R`
- Create: `R/check_trim_bootstrap_replicate.R`

**Interfaces:**
- Consumes: vooraf opgebouwde analysecontext, clustertrekking en replicatie-ID.
- Produces: `run_trim_bootstrap_replicate(context, replicate_id)` met soort-, brug-, groep- en diagnostiekregels.

- [ ] **Step 1: Schrijf een falende end-to-endtest op synthetische data**

De fixture bevat twee strata, vier plots per stratum, twee soorten en acht jaren
aan weerszijden van een kunstmatige modelbreuk. Eis:

```r
r <- run_trim_bootstrap_replicate(context, 11L)
stopifnot(identical(unique(r$species$replicate_id), 11L))
stopifnot(nrow(r$bridge) == 2L)
stopifnot(all(is.finite(r$bridge$bridge_factor)))
stopifnot(nrow(r$groups) >= 1L)
stopifnot(length(unique(r$diagnostics$draw_hash)) == 1L)
```

- [ ] **Step 2: Voer de test uit en verifieer RED**

Run: `Rscript R/check_trim_bootstrap_replicate.R .`

Expected: FAIL omdat de replicatiefunctie ontbreekt.

- [ ] **Step 3: Implementeer context en replicatieketen**

Definieer:

```r
build_bootstrap_context <- function(tbls, cluster_definition, config) list()
fit_first_working_trim_model <- function(df, configs) list()
run_trim_bootstrap_replicate <- function(context, replicate_id) list()
```

Parse brondata en bouw onveranderlijke mappings eenmaal in de context. Gebruik
de bestaande vier modelconfiguraties in dezelfde volgorde, maar stop na de
eerste geslaagde fit. Registreer iedere poging, waarschuwing en fout. Bereken de
brugfactor per replicatie opnieuw en gebruik de bestaande loglineaire schatter
voor 1958–2025.

- [ ] **Step 4: Verifieer determinisme en gedeelde trekking**

Voer replicatie 11 tweemaal uit en vergelijk alle gegevensframes na sortering.
Eis identieke discrete velden en numerieke verschillen kleiner dan `1e-12` op
dezelfde machine. Controleer dat beide soorten dezelfde `draw_hash` hebben.

- [ ] **Step 5: Commit**

```bash
git add R/trim_bootstrap_core.R R/check_trim_bootstrap_replicate.R
git commit -m "Bereken volledige TRIM-bootstrapreplicatie"
```

### Task 6: Vaste robuuste groepen en volledige gevoeligheidsvariant

**Files:**
- Modify: `R/trim_bootstrap_core.R`
- Create: `R/check_trim_bootstrap_groups.R`

**Interfaces:**
- Consumes: oorspronkelijke selectie, groepsmapping en replicatiesoortindices.
- Produces: primaire robuuste groepstrends met vaste samenstelling en volledige gevoeligheidstrends met werkelijk soortenaantal.

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
stilzwijgend tot een ander primair estimand worden hergeschaald.

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
- Consumes: analysecontext, oorspronkelijke puntschatting en geldige bootstrapwaarden.
- Produces: clusterjackknifewaarden, standaardfout, percentile- en BCa-interval, empirische p-waarde, geldigheids- en stabiliteitsstatus.

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
```

Gebruik de eindige-steekproefcorrectie uit de spec. Val terug op percentile bij
niet-eindige BCa-acceleratie en leg de reden vast. Publiceer geen formeel
interval onder 95% geldige replicaties.

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
  "publication_status", "run_id"
)
stopifnot(!length(setdiff(required, names(result))))
stopifnot(all(result$ci_low_pct <= result$estimate_pct_per_year, na.rm = TRUE))
stopifnot(all(result$ci_high_pct >= result$estimate_pct_per_year, na.rm = TRUE))
```

- [ ] **Step 2: Voer test uit en verifieer RED**

Run: `Rscript R/check_trim_uncertainty_outputs.R . "$TMPDIR/trim-output-fixture"`

Expected: FAIL omdat writer of bestanden ontbreken.

- [ ] **Step 3: Implementeer atomische publicatiewriter**

Schrijf eerst naar een tijdelijke publicatiemap. Controleer schema, unieke
sleutels, perioden, eindige grenzen, status/intervalconsistentie en run-ID.
Vervang de canonieke bestanden pas na een volledig groen contract.

- [ ] **Step 4: Documenteer methode en actualisatiecommand**

Documenteer 1958–1983, 1984–2025 en 1958–2025 afzonderlijk; leg uit dat de
laatste een gecombineerde brugtrendschatter is. Vermeld voor de Sandra-set exact
110 soorten en 1997–2022.

- [ ] **Step 5: Verifieer en commit**

```bash
Rscript R/check_trim_uncertainty_outputs.R . trim
git add R/write_trim_uncertainty_outputs.R R/check_trim_uncertainty_outputs.R \
  R/trim_soorten_en_msi_evg.R R/trim_sandra_soorten_en_msi_evg.R \
  R/trim_soorten_en_msi_evg.md R/trim_sandra_soorten_en_msi_evg.md trim trim_msi_evg
git commit -m "Publiceer TRIM- en bootstraponzekerheid"
```

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

- labels `1958–1983`, `1984–2025` en `1958–2025`;
- onder- en bovengrens;
- tekst `Gecombineerde trend via een geschatte brugfactor; geen enkel doorlopend TRIM-model.`;
- robuuste groepsvariant vóór volledige gevoeligheidsvariant;
- geen intervalweergave bij `onvoldoende_bootstrap`.

- [ ] **Step 3: Voer test uit en verifieer RED**

Run: `Rscript R/check_trim_uncertainty_presentation.R .`

Expected: FAIL omdat de presentatie nog geen onzekerheidsvelden gebruikt.

- [ ] **Step 4: Implementeer presentatie minimaal**

Voeg compacte trendregels en tooltips toe. Toon methode, geldig aantal
replicaties en rekendatum. Gebruik geen betrouwbaarheidslint voor jaarindices in
deze fase; de spec sluit simultane jaarlijkse banden uit.

- [ ] **Step 5: Genereer en verifieer**

Run:

```bash
Rscript R/build_groepen_grafieken_dashboard_csv.R \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql groepen_grafieken
Rscript R/check_trim_uncertainty_presentation.R .
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
```

Voer daarnaast een visuele desktop- en mobiele controle uit van soorten,
groepen en methodetoelichting.

- [ ] **Step 6: Commit**

```bash
git add R/build_groepen_grafieken_dashboard_csv.R \
  R/check_dashboard_website_parity.R R/check_trim_uncertainty_presentation.R \
  bmp_meijendel_index.html groepen_grafieken
git commit -m "Toon formele trendonzekerheid in dashboard"
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
stopifnot(identical(standard$status, "precomputed_formal"))
stopifnot(is.finite(standard$ci_low_pct))
stopifnot(identical(custom$status, "exploratory_no_formal_interval"))
stopifnot(is.na(custom$ci_low_pct), is.na(custom$ci_high_pct))
```

- [ ] **Step 2: Voer test uit en verifieer RED**

Run: `Rscript R/check_shiny_trim_uncertainty_contract.R .`

Expected: FAIL omdat resolver en selectiehash ontbreken.

- [ ] **Step 3: Implementeer selectiehash en resolver**

Hash exacte plot-, jaar-, soort- en groepsselecties. Alleen een exacte match met
het runmanifest krijgt vooraf berekende intervallen. Iedere afwijking toont:
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

### Task 14: Pilot 50, validatie 500 en productierun 2.000+

**Files:**
- Modify: `trim/bootstrap/run_manifest.json`
- Modify: `trim/bootstrap/diagnostiek.csv`
- Modify: `STATUS.md`
- Modify: `TODO.md`
- Modify: `DECISIONS.md`
- Modify: `ARCHITECTURE.md`

**Interfaces:**
- Consumes: volledig geteste lokale en eventueel geactiveerde workerketen.
- Produces: feitelijke prestatiegegevens, geldige formele intervallen en actuele projectdocumentatie.

- [ ] **Step 1: Draai de lokale pilot van 50 replicaties**

Gebruik batches van 5, één worker en een vaste seed. Registreer totale tijd,
seconden per replicatie, piekgeheugen, swap, foutpercentage per soort/groep en
hervatbaarheid. Vergelijk de eerste twee replicaties met een tweede lokale run.

- [ ] **Step 2: Beslis op meetwaarden over NAS/VPS-activering**

Bereken workergeheugenlimiet als 125% van de pilotpiek. Activeer alleen workers
waar na die limiet de vereiste reserve overblijft. Leg per host `enabled` plus
reden vast; geen geschiktheid betekent geen externe berekening.

- [ ] **Step 3: Draai validatie met 500 replicaties**

Controleer:

- minimaal 95% geldige replicaties per te publiceren schatter;
- lokale/externe numerieke pariteit `<= 1e-8`;
- BCa versus percentile;
- model- en fallbackfrequenties;
- vaste primaire groepssamenstelling;
- gevoeligheid van volledige groepen;
- reproduceerbaarheid na hervatten.

Stop en corrigeer de implementatie wanneer een formele schatter onder 95%
geldig blijft; schaal niet door naar 2.000 om een structureel probleem te
verbergen.

- [ ] **Step 4: Draai minimaal 2.000 replicaties**

Wijs niet-overlappende bereiken toe aan alle groen geactiveerde workers. De
iMac mergeert, valideert en berekent jackknife/BCa. Beoordeel na 2.000 en iedere
volgende 500 de vastgelegde stabiliteitsregel. Stop uiterlijk bij 5.000 en
publiceer `interval_niet_gestabiliseerd` waar nodig.

- [ ] **Step 5: Genereer alle canonieke outputs opnieuw**

Maak soort-, brug-, ecologische, functionele en Sandra-uitvoer vanuit exact
hetzelfde run-ID. Draai alle uitvoer-, presentatie- en pariteitstests.

- [ ] **Step 6: Werk projectdocumentatie bij met feitelijke resultaten**

Leg vast:

- bronset met aantal, periode en hash;
- werkelijk aantal replicaties;
- gebruikte workers en hun gemeten bijdrage;
- totale en per-workerdoorlooptijd;
- geheugen en swap;
- geldige percentages en fallbacks;
- intervalmethode en eventuele uitzonderingen;
- jaarlijkse actualisatieroute.

- [ ] **Step 7: Volledige eindverificatie**

Run minimaal:

```bash
scripts/test_shiny_reproducibility.sh
bash scripts/test_trim_source_output_contract.sh
Rscript R/check_trim_scripts_sourceable.R .
Rscript R/check_trim_overall_trends.R .
Rscript R/check_trim_bootstrap_sampling.R .
Rscript R/check_trim_bootstrap_replicate.R .
Rscript R/check_trim_bootstrap_groups.R .
Rscript R/check_trim_bootstrap_summary.R .
Rscript R/check_trim_bootstrap_resume.R .
bash scripts/test_trim_bootstrap_workers.sh
Rscript R/check_trim_sandra_uncertainty.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql
Rscript R/check_trim_uncertainty_outputs.R . trim
Rscript R/check_trim_uncertainty_presentation.R .
Rscript R/check_shiny_trim_uncertainty_contract.R .
Rscript R/check_dashboard_website_parity.R . groepen_grafieken
Rscript R/check_shiny_dashboard_parity.R . \
  /Users/ton/Documents/GitHub/Meijendel/meijendel.sql \
  trim_msi_evg/msi_per_groep_per_jaar.csv 1958 2025
git diff --check
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
```

- [ ] **Step 8: Commit de gevalideerde resultaten en documentatie**

```bash
git add trim trim_msi_evg groepen_grafieken bmp_meijendel_index.html \
  STATUS.md TODO.md DECISIONS.md ARCHITECTURE.md
git commit -m "Publiceer gevalideerde TRIM-bootstrapintervallen"
```

### Task 15: Review, integratie en productiepublicatie

**Files:**
- Modify: `RELEASE_MANIFEST.yml` volgens de projectreleaseprocedure
- Modify: overige releasebewijsbestanden die de preflight vereist

**Interfaces:**
- Consumes: volledig groene featurebranch met gereproduceerde output.
- Produces: gereviewde integratie in actuele `main`, gecontroleerde deploy en productie-evidence.

- [ ] **Step 1: Laat de volledige branch onafhankelijk reviewen**

Review statistische estimands, vaste groepssamenstelling, workerveiligheid,
uitvoercontracten en alle UI-consumenten. Los bevindingen testgestuurd op.

- [ ] **Step 2: Integreer uitsluitend op schone actuele `main`**

Voer projectpreflight uit, actualiseer refs, verifieer ancestry en integreer
volgens de geldende repositoryworkflow. Draai daarna de volledige testset
opnieuw op `main`.

- [ ] **Step 3: Voer volledige deploypreflight uit**

Gebruik uitsluitend het repositoriespecifieke deployscript. Laat de preflight
de SQL-hash, publicatiebestanden, Shiny/dashboard-pariteit, containerstatus en
productiecommit controleren.

- [ ] **Step 4: Deploy en controleer productie**

Controleer website, dashboard en Shiny voor:

- beide primaire perioden;
- aanvullende gebrugde trend en kwalificatietekst;
- robuuste en volledige groepsvarianten;
- standaardselectie met formeel interval;
- maatwerkselectie zonder misleidend interval;
- ongewijzigde bestaande filters, grafieken en toelichtingen.

- [ ] **Step 5: Registreer release en voer eindpreflight uit**

Werk het release-manifest pas bij na volledig groene nacontrole. Verwijder geen
branch, worktree, rollbackimage of bootstrapbewijs zonder afzonderlijke
beoordeling en expliciete toestemming waar de projectregels dat vereisen.
