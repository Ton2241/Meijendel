args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_vegetatiesamenstelling.R"
))

stopifnot(identical(primary_composition_model_lags(), 0L))
stopifnot(identical(composition_coverage_lags(), 0:15))

coverage_fixture <- list(
  data = data.frame(
    row_id = c("1:10:2015", "2:10:2015"),
    plot_id = c(10L, 10L),
    jaar = c(2015L, 2015L),
    soort_id = c(1L, 2L),
    stringsAsFactors = FALSE
  ),
  row_hash = "fixture-hash",
  lag_years = 15L
)
coverage_fixture_row <- coverage_row("compositie", "lag15", coverage_fixture)
stopifnot(identical(coverage_fixture_row$lag_years, 15L))
old_workers <- Sys.getenv("MEIJENDEL_MODEL_WORKERS", unset = NA_character_)
Sys.setenv(MEIJENDEL_MODEL_WORKERS = "2")
stopifnot(identical(validation_worker_count(), 1L))
if (is.na(old_workers)) Sys.unsetenv("MEIJENDEL_MODEL_WORKERS") else Sys.setenv(MEIJENDEL_MODEL_WORKERS = old_workers)

failed_model <- list(diagnostics = list(error = "foutmelding"))
stopifnot(identical(validation_model_failure_message(failed_model), "foutmelding"))
failed_hessian <- list(warnings = character(), diagnostics = list(error = NULL, pdHess = FALSE))
stopifnot(identical(
  validation_model_failure_message(failed_hessian),
  "Hessiaan niet positief-definiet"
))
failed_warning <- list(
  warnings = "Model convergence problem; non-positive-definite",
  diagnostics = list(error = NULL, pdHess = TRUE)
)
stopifnot(grepl(
  "Model convergence problem",
  validation_model_failure_message(failed_warning),
  fixed = TRUE
))
reported_metadata <- add_reporting_commit(
  list(git_commit = "model-commit"), "rapportage-commit"
)
stopifnot(identical(reported_metadata$git_commit, "model-commit"))
stopifnot(identical(reported_metadata$reporting_commit, "rapportage-commit"))
stopifnot(isTRUE(model_pair_comparison_validity(list(
  basis = list(status = "geslaagd"), vegetatie = list(status = "geslaagd")
))))
stopifnot(!model_pair_comparison_validity(list(
  basis = list(status = "modeluitval"), vegetatie = list(status = "geslaagd")
)))

validation <- data.frame(
  validatie = rep(c("ruimte", "tijd"), each = 4),
  fold_id = paste0("f", 1:8),
  blok = rep(c("compositie", "ipi"), 4),
  n = 100L,
  delta_mean_log_score = c(.1, -.1, .2, 0, .3, .1, -.2, .2),
  delta_mae = c(.2, -.2, .3, 0, .4, .2, -.1, .1),
  delta_rmse = c(.3, -.3, .4, 0, .5, .3, -.2, .2),
  stringsAsFactors = FALSE
)
summary <- summarise_block_validation(validation)
stopifnot(nrow(summary) == 4L)
stopifnot(all(summary$aantal_blokken == 2L))
stopifnot(all(summary$aandeel_betere_logscore >= 0 & summary$aandeel_betere_logscore <= 1))

landcover <- data.frame(
  plot_id = rep(1:2, each = 2),
  jaar = rep(c(2001L, 2022L), 2),
  struik_aandeel = .1,
  bos_aandeel = .2,
  boomgroep_aandeel = .1,
  laag_aandeel = .3,
  riet_aandeel = .05,
  zand_aandeel = .05,
  water_aandeel = .2
)
landcover <- add_landcover_derived_features(landcover)
stopifnot(all(landcover$open_aandeel == .35))
stopifnot(all(landcover$houtig_aandeel == .4))

decision <- decide_height_followup(data.frame(
  blok = c("compositie", "ipi", "landbedekking"),
  validatie = "ruimte",
  delta_logscore_gem = c(.02, -.01, .03),
  aandeel_betere_logscore = c(.8, .4, .8)
))
stopifnot(decision$status == "gerichte_hoogteproef_aanbevolen")
stopifnot(grepl("AHN", decision$advies, fixed = TRUE))
stopifnot(grepl("gerichte proef", decision$advies, fixed = TRUE))

cat("OK: vegetatiesamenstellingspijplijncontracten\n")
