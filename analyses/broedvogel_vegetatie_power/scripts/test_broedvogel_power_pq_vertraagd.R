args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_power_pq_vertraagd.R"
))

stopifnot(identical(
  power_change_terms(),
  c(
    "change_pp", "change_pp_sq", "change_pp:lag15",
    "change_pp_sq:lag15", "change_pp:lag15_sq",
    "change_pp_sq:lag15_sq"
  )
))

contrast <- delayed_power_contrast(change_pp = -5, lag_years = 15)
stopifnot(
  identical(names(contrast), power_change_terms()),
  isTRUE(all.equal(unname(contrast), c(-5, 25, -5, 25, -5, 25)))
)

stopifnot(
  target_rate_ratio(20, 0.3) == 1.2,
  target_rate_ratio(20, -0.3) == 0.8,
  target_rate_ratio(0, -0.3) == 1
)

beta <- c(
  change_pp = 0.020, change_pp_sq = 0.001,
  `change_pp:lag15` = 0.010, `change_pp_sq:lag15` = 0.0005,
  `change_pp:lag15_sq` = 0.005, `change_pp_sq:lag15_sq` = 0.0002
)
covariance <- diag(rep(0.0004, length(beta)))
dimnames(covariance) <- list(names(beta), names(beta))

null <- simulate_delayed_wald_power(
  beta, covariance, delayed_power_contrast(5, 15), target_percent = 0,
  information_multiplier = 1, simulations = 20000L, seed = 17L
)
weak <- simulate_delayed_wald_power(
  beta, covariance, delayed_power_contrast(5, 15), target_percent = 10,
  information_multiplier = 1, simulations = 5000L, seed = 18L
)
strong <- simulate_delayed_wald_power(
  beta, covariance, delayed_power_contrast(5, 15), target_percent = 40,
  information_multiplier = 1, simulations = 5000L, seed = 19L
)
more_information <- simulate_delayed_wald_power(
  beta, covariance, delayed_power_contrast(5, 15), target_percent = 10,
  information_multiplier = 4, simulations = 5000L, seed = 20L
)
stopifnot(
  null$status == "geslaagd", null$power > 0.04, null$power < 0.06,
  weak$power < strong$power,
  weak$power < more_information$power,
  all(c(null$lower95, null$upper95, strong$power) >= 0),
  all(c(null$lower95, null$upper95, strong$power) <= 1)
)

invalid <- covariance
invalid[1, 1] <- NA_real_
failed <- simulate_delayed_wald_power(
  beta, invalid, delayed_power_contrast(5, 15), target_percent = 20,
  information_multiplier = 1, simulations = 100L, seed = 21L
)
stopifnot(
  failed$status == "ongeldige_covariantie",
  is.na(failed$power), nzchar(failed$reason)
)

translated <- translate_information_multiplier(
  information_multiplier = 1.5, current_plotyears = 650L,
  first_year = 1994L, last_year = 2025L, current_intervals = 362L,
  plots_per_pq_round = 35L
)
stopifnot(
  translated$additional_plotyears == 325L,
  translated$equivalent_additional_years == 16L,
  translated$additional_intervals == 181L,
  translated$equivalent_complete_pq_rounds == 6L
)

summary_fixture <- data.frame(
  analysis_id = c("a", "b", "c", "d"),
  response_type = c("territoria", "territoria", "aanwezigheid", "territoria"),
  decision = c(
    "voorspellende_meerwaarde", "geen_bestendige_voorspellende_meerwaarde",
    "voorspellende_meerwaarde", "voorspellende_meerwaarde"
  ), stringsAsFactors = FALSE
)
selected <- select_delayed_power_candidates(summary_fixture)
stopifnot(identical(selected, c("a", "d")))

candidate_data <- data.frame(
  analysis_id = "a", gradient = "duingrasland_mos_korstmos",
  plot_id = c(1L, 1L, 2L, 2L), jaar = c(2000L, 2001L, 2000L, 2002L),
  event_id = c("1:2000", "1:2000", "2:2000", "2:2002"),
  interval_years = c(2L, 2L, 4L, 1L), lag_years = c(0L, 1L, 0L, 0L),
  change_pp = c(-5, -5, 4, 0), n_species = 12L,
  tellerteam_factor = factor(c("A", "B", "C", "C")),
  stringsAsFactors = FALSE
)
team_data <- data.frame(
  plot_id = candidate_data$plot_id, jaar = candidate_data$jaar,
  tellerteam_sleutel = c("A", "B", "C", "C"),
  aantal_tellers = c(1L, 1L, 2L, 2L),
  ervaring_plot_mean = c(0, log1p(1), 0, log1p(2)),
  ervaring_elders_mean = c(0, 0, log1p(1), log1p(1)),
  stringsAsFactors = FALSE
)
structure <- summarise_delayed_candidate_structure(candidate_data, team_data)
stopifnot(
  structure$plotyears == 4L, structure$plots == 2L,
  structure$full_grid_plotyears == 6L, structure$missing_grid_plotyears == 2L,
  structure$intervals == 3L, structure$lag_0 == 3L, structure$lag_1_3 == 1L,
  structure$single_teller_plotyears == 2L,
  structure$two_teller_plotyears == 2L,
  structure$adjacent_plotyear_transitions == 1L,
  structure$teller_changes_adjacent == 1L,
  structure$negative_intervals == 1L, structure$zero_intervals == 1L,
  structure$positive_intervals == 1L
)

cat("OK: vertraagde PQ-powersimulatie, detectieregel en meetvertaling.\n")
