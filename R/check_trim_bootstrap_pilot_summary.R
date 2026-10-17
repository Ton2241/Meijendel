#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
this_file <- if (length(file_arg)) normalizePath(sub("^--file=", "", file_arg[[1L]])) else normalizePath("R/check_trim_bootstrap_pilot_summary.R")
repo <- dirname(dirname(this_file))

env <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "summarise_trim_bootstrap_pilot.R"), envir = env)

tmp <- tempfile("trim-pilot-summary-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

identity <- list(
  run_id = "pilot-fixture", source_hash = "bron", config_hash = "config",
  code_commit = "commit", software_id = "R-test_rtrim-test"
)

make_result <- function(id, species_value, group_value, species_reason = NA_character_, group_status = "geldig_vaste_samenstelling") {
  list(
    replicate_id = id,
    species = data.frame(
      replicate_id = id, soort_id = 7L, coverage_variant = "volledig_netwerk",
      bridge_variant = "primary_1986_1988", bridge_status = if (is.finite(species_value)) "formele_brug" else "geen_formele_brug",
      bridge_reason = species_reason, estimate_pct_per_year = species_value,
      pre_model = "model3_overdisp", post_model = if (is.finite(species_value)) "model3_overdisp" else NA_character_,
      stringsAsFactors = FALSE
    ),
    groups = data.frame(
      replicate_id = id, entity_id = "eco-100-robuust", coverage_variant = "volledig_netwerk",
      bridge_variant = "primary_1986_1988", estimate_pct_per_year = group_value,
      group_status = group_status, n_years = if (is.finite(group_value)) 68L else 0L,
      stringsAsFactors = FALSE
    )
  )
}

state <- list(
  identity = identity, requested_ids = 1:2, completed_ids = 1:2,
  results = list(
    make_result(1L, 1.5, 0.5),
    make_result(2L, NA_real_, NA_real_, "geen gemeenschappelijke tellingen", "ongeldig_vaste_soort_ontbreekt")
  ),
  errors = list(), worker_id = "test-worker", started_at = "2026-10-17 10:00:00 UTC",
  runtime_seconds = 20, peak_memory_mb = 123, swap_used_bytes = 0,
  swap_growth_bytes = 0,
  finished_at = "2026-10-17 10:00:20 UTC"
)
path <- file.path(tmp, "batch-000001-000002.rds")
saveRDS(state, path)
hash <- sub("[[:space:]].*$", "", system2("shasum", c("-a", "256", path), stdout = TRUE)[[1L]])
saveRDS(list(identity = identity, replicate_ids = 1:2, output_sha256 = hash), paste0(path, ".manifest.rds"))

summary <- env$summarise_trim_bootstrap_pilot(path, expected_ids = 1:2)
stopifnot(summary$run$completed_replicates[[1L]] == 2L)
stopifnot(summary$run$error_count[[1L]] == 0L)
stopifnot(summary$run$runtime_seconds_total[[1L]] == 20)
stopifnot(summary$run$seconds_per_replicate[[1L]] == 10)
stopifnot(summary$run$wall_elapsed_seconds[[1L]] == 20)
stopifnot(summary$run$peak_memory_mb_max[[1L]] == 123)
stopifnot(summary$run$swap_growth_bytes_max[[1L]] == 0)
stopifnot(summary$species$valid_replicates[[1L]] == 1L)
stopifnot(summary$species$valid_fraction[[1L]] == 0.5)
stopifnot(summary$species$publication_gate[[1L]] == "onvoldoende_bootstrap")
stopifnot(summary$species$primary_invalid_reason[[1L]] == "geen gemeenschappelijke tellingen")
stopifnot(summary$species$invalid_reason_counts[[1L]] == "geen gemeenschappelijke tellingen=1")
stopifnot(summary$groups$valid_replicates[[1L]] == 1L)
stopifnot(summary$groups$primary_invalid_reason[[1L]] == "ongeldig_vaste_soort_ontbreekt")
stopifnot(sum(summary$models$count) == 4L)
stopifnot(summary$models$count[summary$models$period == "post" & summary$models$model == "mislukt"] == 1L)

out <- file.path(tmp, "uitvoer")
env$write_trim_bootstrap_pilot_summary(summary, out)
stopifnot(file.exists(file.path(out, "pilot_run.csv")))
stopifnot(file.exists(file.path(out, "pilot_species_validity.csv")))
stopifnot(file.exists(file.path(out, "pilot_group_validity.csv")))
stopifnot(file.exists(file.path(out, "pilot_model_frequencies.csv")))
run_csv <- utils::read.csv(file.path(out, "pilot_run.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(run_csv) == 1L)
stopifnot(run_csv$run_id[[1L]] == "pilot-fixture")

cat("TRIM_BOOTSTRAP_PILOT_SUMMARY=ready\n")
