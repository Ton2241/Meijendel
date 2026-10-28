args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_power_pq_vertraagd.R"
))

terms <- power_change_terms()
beta <- stats::setNames(c(0.02, 0.001, 0.01, 0.0005, 0.005, 0.0002), terms)
covariance <- diag(rep(0.0004, length(terms)))
dimnames(covariance) <- list(terms, terms)
data <- data.frame(
  change_pp = c(rep(-5, 20), rep(4, 20)), lag_years = rep(0:4, 8),
  stringsAsFactors = FALSE
)

scenarios <- build_candidate_power_scenarios(
  analysis_id = "test", beta = beta, covariance = covariance, data = data,
  historical_effects = c(0, 20), future_effects = 20,
  information_multipliers = c(1, 2), simulations = 1000L, seed = 100L
)
stopifnot(
  nrow(scenarios) == 10L,
  setequal(scenarios$direction, c("afname", "toename")),
  setequal(scenarios$scenario_type, c(
    "historische_detectiegrens", "toekomstig_meetvolume", "waargenomen_modelschaal"
  )),
  all(scenarios$analysis_id == "test"),
  all(scenarios$anchor_lag_years == 4L),
  all(scenarios$status == "geslaagd")
)
scenarios$lower95[scenarios$scenario_type == "toekomstig_meetvolume"] <- 0.9

structure <- data.frame(
  analysis_id = c("test", "andere_kandidaat"),
  plotyears = c(40L, 50L), plots = c(2L, 5L), intervals = c(20L, 30L),
  first_year = c(2000L, 2000L), last_year = c(2019L, 2019L),
  stringsAsFactors = FALSE
)
thresholds <- summarise_power_requirements(
  scenarios, structure, target_power = 0.8
)
stopifnot(
  nrow(thresholds$historical) == 2L,
  nrow(thresholds$future) == 2L,
  all(c(
    "minimum_detectable_percent", "observed_model_percent",
    "observed_model_power"
  ) %in% names(thresholds$historical)),
  all(c(
    "required_information_multiplier", "additional_plotyears",
    "equivalent_additional_years", "additional_intervals",
    "equivalent_complete_pq_rounds"
  ) %in% names(thresholds$future))
)

cat("OK: runner voor historische en toekomstige PQ-power.\n")
