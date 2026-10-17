#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_uncertainty_presentation.R"))

dashboard <- paste(readLines(file.path(repo, "bmp_meijendel_index.html"), warn = FALSE), collapse = "\n")
required_text <- c(
  "Gecombineerde trend via een geschatte gemeenschappelijke-plotbrug van 1981–1983 naar 1986–1988; geen enkel doorlopend TRIM-model.",
  "gevoeligheidsenvelop; geen 95%-betrouwbaarheidsinterval",
  "bruggevoelig", "gebiedsdekkinggevoelig", "valid_replicates", "calculated_at"
)
stopifnot(all(vapply(required_text, grepl, logical(1), x = dashboard, fixed = TRUE)))

empty_root <- tempfile("trim-dashboard-empty-")
dir.create(empty_root)
pending <- load_trim_uncertainty_for_presentation(empty_root)
stopifnot(identical(pending$status, "descriptive_pending_final_run"))

rows <- data.frame(
  entity_type = "group",
  entity_id = c("eco-100-volledig", "eco-100-robuust", "eco-100-onvoldoende"),
  period = "1958-2026",
  method = "cluster_bootstrap_fixed_group",
  estimate_pct_per_year = c(0.8, 0.7, 0.6),
  se_pct = c(0.2, 0.2, NA), ci_low_pct = c(0.4, 0.3, NA), ci_high_pct = c(1.2, 1.1, NA),
  p_value = c(0.01, 0.02, NA), interval_method = c("bca", "bca", NA),
  planned_replicates = 2000L, valid_replicates = c(1990L, 1980L, 1800L),
  valid_fraction = c(0.995, 0.99, 0.9),
  publication_status = c("publiceerbaar", "publiceerbaar", "onvoldoende_bootstrap"),
  bridge_variant = "primary_1986_1988", bridge_status = "bruggevoelig",
  coverage_status = "gebiedsdekkinggevoelig", run_id = "fixture-2026",
  stringsAsFactors = FALSE
)
presented <- prepare_trim_uncertainty_rows(rows)
stopifnot(grepl("robuust", presented$entity_id[[1L]], fixed = TRUE))
stopifnot(is.na(presented$display_ci[[3L]]))
stopifnot(identical(presented$period[[1L]], "1958-2026"))

cat("OK: website/dashboard activeren alleen definitieve 2026-onzekerheid en bewaren anders de beschrijvende presentatie.\n")
