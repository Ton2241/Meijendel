#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "shiny_meijendel", "helpers.R"))

canonical_hash <- trim_selection_hash(
  plots = c("2", "1"), years = 1958:2026,
  species = c("10", "2"), groups = c("eco-100", "eco-200")
)
stopifnot(identical(canonical_hash, trim_selection_hash(
  plots = c("1", "2"), years = 2026:1958,
  species = c("2", "10"), groups = c("eco-200", "eco-100")
)))

results <- list(
  manifest = list(
    run_id = "fixture-2026", analysis_end_year = 2026L,
    planned_replicates = 2000L, publication_status = "publiceerbaar",
    selection_hash = canonical_hash
  ),
  rows = data.frame(
    entity_type = "species", entity_id = "2", period = "1958-2026",
    estimate_pct_per_year = 1.2, ci_low_pct = 0.5, ci_high_pct = 1.9,
    publication_status = "publiceerbaar", run_id = "fixture-2026",
    stringsAsFactors = FALSE
  )
)
results_pending <- results
results_pending$manifest$publication_status <- "validatie_niet_publiceren"

standard <- resolve_trim_uncertainty(selection_hash = canonical_hash, results)
custom <- resolve_trim_uncertainty(selection_hash = "anders", results)
pending <- resolve_trim_uncertainty(selection_hash = canonical_hash, results_pending)
stopifnot(identical(standard$status, "precomputed_formal"))
stopifnot(is.finite(standard$ci_low_pct))
stopifnot(identical(custom$status, "exploratory_no_formal_interval"))
stopifnot(is.na(custom$ci_low_pct), is.na(custom$ci_high_pct))
stopifnot(identical(pending$status, "descriptive_pending_final_run"))

app <- paste(readLines(file.path(repo, "shiny_meijendel", "app.R"), warn = FALSE), collapse = "\n")
stopifnot(grepl("Verkennende selectie; geen formeel bootstrapinterval.", app, fixed = TRUE))
stopifnot(!grepl("run_trim_bootstrap_batch", app, fixed = TRUE))

cat("OK: Shiny gebruikt alleen vooraf berekende intervallen voor de exacte canonieke selectie.\n")
