#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Gebruik: check_trim_uncertainty_outputs.R REPO OUTPUT_ROOT", call. = FALSE)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
output_root <- args[[2L]]
source(file.path(repo, "R", "write_trim_uncertainty_outputs.R"))

unlink(output_root, recursive = TRUE, force = TRUE)
trend <- data.frame(
  entity_type = c("species", "group"),
  entity_id = c("1", "eco-100"),
  period = c("1958-2025", "1958-2025"),
  method = c("cluster_bootstrap_common_plot_bridge", "cluster_bootstrap_fixed_group"),
  estimate_pct_per_year = c(1.2, -0.5),
  se_pct = c(0.3, 0.2),
  ci_low_pct = c(0.6, -0.9),
  ci_high_pct = c(1.8, -0.1),
  p_value = c(0.01, 0.03),
  interval_method = c("bca", "bca"),
  planned_replicates = c(500L, 500L),
  valid_replicates = c(500L, 490L),
  valid_fraction = c(1, 0.98),
  publication_status = c("validatie_niet_publiceren", "validatie_niet_publiceren"),
  bridge_variant = c("primary_1986_1988", "primary_1986_1988"),
  bridge_status = c("brugrobuust", "bruggevoelig"),
  coverage_status = c("gebiedsdekkingrobuust", "gebiedsdekkinggevoelig"),
  run_id = c("fixture-run", "fixture-run"),
  stringsAsFactors = FALSE
)
sensitivity <- data.frame(
  entity_type = "species", entity_id = "1", bridge_variant = "alternative_1987_1989",
  estimate_pct_per_year = 1, ci_low_pct = 0.4, ci_high_pct = 1.6,
  envelope_type = "gevoeligheidsenvelop_geen_bi", run_id = "fixture-run"
)
manifest <- list(
  format = "trim-bootstrap-run-manifest-v1",
  run_id = "fixture-run",
  analysis_end_year = 2025L,
  planned_replicates = 500L,
  publication_status = "validatie_niet_publiceren"
)
bundle <- list(
  species_trends = trend[1, ],
  species_bridges = trend[1, ],
  bridge_sensitivity = sensitivity,
  historical_core_sensitivity = transform(sensitivity, bridge_variant = "primary_1986_1988"),
  group_trends = trend[2, ],
  functional_group_trends = transform(trend[2, ], entity_id = "fun-1"),
  sandra_species_trends = transform(trend[1, ], period = "1997-2022", bridge_variant = "niet_van_toepassing"),
  sandra_group_trends = transform(trend[2, ], period = "1997-2022", bridge_variant = "niet_van_toepassing"),
  diagnostics = data.frame(run_id = "fixture-run", key = "valid_fraction", value = "1")
)

write_trim_uncertainty_outputs(bundle, manifest, output_root, mode = "fixture")
required <- c(
  "entity_type", "entity_id", "period", "method", "estimate_pct_per_year",
  "se_pct", "ci_low_pct", "ci_high_pct", "p_value", "interval_method",
  "planned_replicates", "valid_replicates", "valid_fraction",
  "publication_status", "bridge_variant", "bridge_status", "coverage_status",
  "run_id"
)
paths <- c(
  "trim/soorten/soorten_trends_met_onzekerheid.csv",
  "trim_msi_evg/groepstrends_met_onzekerheid.csv",
  "trim_msi_evg/functionele_groepstrends_met_onzekerheid.csv",
  "trim/sandra/soorten/soorten_trends_met_onzekerheid.csv",
  "trim/sandra/trim_msi_evg/groepstrends_met_onzekerheid.csv"
)
for (path in paths) {
  result <- read.csv(file.path(output_root, path), stringsAsFactors = FALSE)
  stopifnot(!length(setdiff(required, names(result))))
  stopifnot(all(result$ci_low_pct <= result$estimate_pct_per_year, na.rm = TRUE))
  stopifnot(all(result$ci_high_pct >= result$estimate_pct_per_year, na.rm = TRUE))
}
bridge <- read.csv(file.path(output_root, "trim/soorten/brugvenstergevoeligheid.csv"), stringsAsFactors = FALSE)
stopifnot(all(bridge$envelope_type == "gevoeligheidsenvelop_geen_bi"))
stopifnot(file.exists(file.path(output_root, "trim/bootstrap/run_manifest.json")))

canonical <- try(write_trim_uncertainty_outputs(bundle, manifest, paste0(output_root, "-canonical"), mode = "canonical"), silent = TRUE)
stopifnot(inherits(canonical, "try-error"))

cat("OK: onzekerheidsuitvoer is atomisch, schemavast en vóór 2026 niet canoniek activeerbaar.\n")
