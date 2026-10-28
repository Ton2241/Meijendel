power_change_terms <- function() {
  c(
    "change_pp", "change_pp_sq", "change_pp:lag15",
    "change_pp_sq:lag15", "change_pp:lag15_sq",
    "change_pp_sq:lag15_sq"
  )
}

delayed_power_contrast <- function(change_pp, lag_years) {
  change_pp <- as.numeric(change_pp)
  lag15 <- as.numeric(lag_years) / 15
  values <- c(
    change_pp, change_pp^2, change_pp * lag15,
    change_pp^2 * lag15, change_pp * lag15^2,
    change_pp^2 * lag15^2
  )
  stats::setNames(values, power_change_terms())
}

target_rate_ratio <- function(target_percent, observed_log_effect) {
  target_percent <- as.numeric(target_percent)
  if (!is.finite(target_percent) || target_percent < 0 || target_percent >= 100) {
    stop("Doeleffect moet tussen 0 en 100 procent liggen.", call. = FALSE)
  }
  if (target_percent == 0) return(1)
  if (!is.finite(observed_log_effect) || observed_log_effect == 0) {
    stop("De richting van het ankereffect is niet bepaald.", call. = FALSE)
  }
  if (observed_log_effect > 0) {
    1 + target_percent / 100
  } else {
    1 - target_percent / 100
  }
}

wilson_interval <- function(successes, trials, confidence = 0.95) {
  successes <- as.numeric(successes)
  trials <- as.numeric(trials)
  if (!is.finite(trials) || trials <= 0 || successes < 0 || successes > trials) {
    return(c(lower95 = NA_real_, upper95 = NA_real_))
  }
  z <- stats::qnorm(1 - (1 - confidence) / 2)
  p <- successes / trials
  denominator <- 1 + z^2 / trials
  centre <- (p + z^2 / (2 * trials)) / denominator
  margin <- z * sqrt(p * (1 - p) / trials + z^2 / (4 * trials^2)) / denominator
  c(lower95 = max(0, centre - margin), upper95 = min(1, centre + margin))
}

power_failure_row <- function(status, reason, target_percent, information_multiplier,
                              simulations) {
  data.frame(
    status = status, reason = reason, target_percent = target_percent,
    information_multiplier = information_multiplier,
    simulations = as.integer(simulations), target_rate_ratio = NA_real_,
    observed_anchor_rate_ratio = NA_real_, coefficient_scale = NA_real_,
    detections = NA_integer_, power = NA_real_, lower95 = NA_real_,
    upper95 = NA_real_, stringsAsFactors = FALSE
  )
}

simulate_delayed_wald_power <- function(
    beta, covariance, contrast, target_percent, information_multiplier = 1,
    simulations = 10000L, alpha = 0.05, seed = 20261028L) {
  terms <- power_change_terms()
  beta <- as.numeric(beta[terms])
  names(beta) <- terms
  contrast <- as.numeric(contrast[terms])
  covariance <- as.matrix(covariance[terms, terms, drop = FALSE])
  simulations <- as.integer(simulations)
  information_multiplier <- as.numeric(information_multiplier)
  target_percent <- as.numeric(target_percent)
  valid <- length(beta) == length(terms) && all(is.finite(beta)) &&
    length(contrast) == length(terms) && all(is.finite(contrast)) &&
    all(dim(covariance) == length(terms)) && all(is.finite(covariance)) &&
    is.finite(information_multiplier) && information_multiplier > 0 &&
    simulations > 0L
  if (!valid) {
    return(power_failure_row(
      "ongeldige_covariantie", "Coëfficiënten, contrast of covariantie zijn niet eindig.",
      target_percent, information_multiplier, simulations
    ))
  }
  covariance <- (covariance + t(covariance)) / 2
  eigenvalues <- tryCatch(
    eigen(covariance, symmetric = TRUE, only.values = TRUE)$values,
    error = function(error) NA_real_
  )
  if (!all(is.finite(eigenvalues)) || min(eigenvalues) <= 0) {
    return(power_failure_row(
      "ongeldige_covariantie", "Covariantie is niet positief definiet.",
      target_percent, information_multiplier, simulations
    ))
  }
  observed_anchor_log <- sum(contrast * beta)
  rate_ratio <- tryCatch(
    target_rate_ratio(target_percent, observed_anchor_log),
    error = function(error) error
  )
  if (inherits(rate_ratio, "error")) {
    return(power_failure_row(
      "ongeldig_ankereffect", conditionMessage(rate_ratio), target_percent,
      information_multiplier, simulations
    ))
  }
  target_log <- log(rate_ratio)
  coefficient_scale <- if (target_percent == 0) 0 else target_log / observed_anchor_log
  true_beta <- beta * coefficient_scale
  simulation_covariance <- covariance / information_multiplier
  set.seed(as.integer(seed))
  estimates <- MASS::mvrnorm(
    n = simulations, mu = true_beta, Sigma = simulation_covariance
  )
  if (simulations == 1L) estimates <- matrix(estimates, nrow = 1L)
  inverse <- solve(simulation_covariance)
  statistic <- rowSums((estimates %*% inverse) * estimates)
  significant <- stats::pchisq(
    statistic, df = length(terms), lower.tail = FALSE
  ) < alpha
  if (target_percent > 0) {
    estimated_anchor <- as.numeric(estimates %*% contrast)
    significant <- significant & sign(estimated_anchor) == sign(target_log)
  }
  detections <- sum(significant)
  interval <- wilson_interval(detections, simulations)
  data.frame(
    status = "geslaagd", reason = "", target_percent = target_percent,
    information_multiplier = information_multiplier, simulations = simulations,
    target_rate_ratio = rate_ratio,
    observed_anchor_rate_ratio = exp(observed_anchor_log),
    coefficient_scale = coefficient_scale, detections = detections,
    power = detections / simulations, lower95 = interval[["lower95"]],
    upper95 = interval[["upper95"]], stringsAsFactors = FALSE
  )
}

translate_information_multiplier <- function(
    information_multiplier, current_plotyears, first_year, last_year,
    current_intervals, plots_per_pq_round) {
  information_multiplier <- as.numeric(information_multiplier)
  period_years <- as.integer(last_year) - as.integer(first_year) + 1L
  annual_plotyears <- as.numeric(current_plotyears) / period_years
  additional_plotyears <- ceiling(
    max(0, information_multiplier - 1) * as.numeric(current_plotyears)
  )
  additional_intervals <- ceiling(
    max(0, information_multiplier - 1) * as.numeric(current_intervals)
  )
  data.frame(
    information_multiplier = information_multiplier,
    additional_plotyears = as.integer(additional_plotyears),
    equivalent_additional_years = as.integer(ceiling(additional_plotyears / annual_plotyears)),
    additional_intervals = as.integer(additional_intervals),
    equivalent_complete_pq_rounds = as.integer(ceiling(
      additional_intervals / as.numeric(plots_per_pq_round)
    )), stringsAsFactors = FALSE
  )
}

select_delayed_power_candidates <- function(summary) {
  required <- c("analysis_id", "response_type", "decision")
  missing <- setdiff(required, names(summary))
  if (length(missing)) {
    stop("Samenvatting mist veld(en): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  unique(as.character(summary$analysis_id[
    summary$response_type == "territoria" &
      summary$decision == "voorspellende_meerwaarde"
  ]))
}

summarise_delayed_candidate_structure <- function(data, team_data) {
  required_data <- c(
    "analysis_id", "gradient", "plot_id", "jaar", "event_id",
    "interval_years", "lag_years", "change_pp", "n_species"
  )
  required_team <- c(
    "plot_id", "jaar", "tellerteam_sleutel", "aantal_tellers",
    "ervaring_plot_mean", "ervaring_elders_mean"
  )
  missing_data <- setdiff(required_data, names(data))
  missing_team <- setdiff(required_team, names(team_data))
  if (length(missing_data) || length(missing_team)) {
    stop(
      "Structuurgegevens missen veld(en): ",
      paste(c(missing_data, missing_team), collapse = ", "), call. = FALSE
    )
  }
  if (anyDuplicated(data[c("plot_id", "jaar")])) {
    stop("Kandidaat bevat dubbele plotjaren.", call. = FALSE)
  }
  team_data <- unique(team_data[required_team])
  if (anyDuplicated(team_data[c("plot_id", "jaar")])) {
    stop("Tellerlaag bevat dubbele plotjaren.", call. = FALSE)
  }
  joined <- merge(data, team_data, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
  intervals <- unique(joined[c("event_id", "interval_years", "change_pp")])
  first_year <- min(joined$jaar)
  last_year <- max(joined$jaar)
  full_grid <- length(unique(joined$plot_id)) * (last_year - first_year + 1L)
  ordered <- joined[order(joined$plot_id, joined$jaar), , drop = FALSE]
  previous_plot <- c(NA, head(ordered$plot_id, -1L))
  previous_year <- c(NA, head(ordered$jaar, -1L))
  previous_team <- c(NA, head(ordered$tellerteam_sleutel, -1L))
  adjacent <- ordered$plot_id == previous_plot & ordered$jaar == previous_year + 1L
  team_changed <- adjacent & !is.na(ordered$tellerteam_sleutel) &
    !is.na(previous_team) & ordered$tellerteam_sleutel != previous_team
  count_range <- function(x, lower, upper) {
    sum(is.finite(x) & x >= lower & x <= upper)
  }
  negative <- intervals$change_pp[is.finite(intervals$change_pp) & intervals$change_pp < 0]
  positive <- intervals$change_pp[is.finite(intervals$change_pp) & intervals$change_pp > 0]
  weighted_negative <- joined$change_pp[is.finite(joined$change_pp) & joined$change_pp < 0]
  weighted_positive <- joined$change_pp[is.finite(joined$change_pp) & joined$change_pp > 0]
  data.frame(
    analysis_id = as.character(joined$analysis_id[[1L]]),
    gradient = as.character(joined$gradient[[1L]]),
    plotyears = nrow(joined), plots = length(unique(joined$plot_id)),
    species_in_group = max(joined$n_species), first_year = first_year,
    last_year = last_year, calendar_years = length(unique(joined$jaar)),
    full_grid_plotyears = full_grid,
    missing_grid_plotyears = full_grid - nrow(joined),
    grid_coverage_pct = 100 * nrow(joined) / full_grid,
    intervals = nrow(intervals),
    interval_1_year = sum(intervals$interval_years == 1L),
    interval_2_years = sum(intervals$interval_years == 2L),
    interval_3_years = sum(intervals$interval_years == 3L),
    interval_4_years = sum(intervals$interval_years == 4L),
    interval_5plus_years = sum(intervals$interval_years >= 5L),
    lag_0 = sum(joined$lag_years == 0L),
    lag_1_3 = count_range(joined$lag_years, 1L, 3L),
    lag_4_7 = count_range(joined$lag_years, 4L, 7L),
    lag_8_14 = count_range(joined$lag_years, 8L, 14L),
    known_teller_plotyears = sum(!is.na(joined$tellerteam_sleutel)),
    teller_or_team_entities = length(unique(joined$tellerteam_sleutel[
      !is.na(joined$tellerteam_sleutel)
    ])),
    single_teller_plotyears = sum(joined$aantal_tellers == 1L, na.rm = TRUE),
    two_teller_plotyears = sum(joined$aantal_tellers == 2L, na.rm = TRUE),
    threeplus_teller_plotyears = sum(joined$aantal_tellers >= 3L, na.rm = TRUE),
    adjacent_plotyear_transitions = sum(adjacent, na.rm = TRUE),
    teller_changes_adjacent = sum(team_changed, na.rm = TRUE),
    median_log1p_plot_experience = stats::median(joined$ervaring_plot_mean, na.rm = TRUE),
    median_log1p_elsewhere_experience = stats::median(joined$ervaring_elders_mean, na.rm = TRUE),
    negative_intervals = length(negative), zero_intervals = sum(intervals$change_pp == 0),
    positive_intervals = length(positive),
    median_negative_interval_change_pp = if (length(negative)) stats::median(negative) else NA_real_,
    median_positive_interval_change_pp = if (length(positive)) stats::median(positive) else NA_real_,
    response_anchor_negative_change_pp = if (length(weighted_negative)) stats::median(weighted_negative) else NA_real_,
    response_anchor_positive_change_pp = if (length(weighted_positive)) stats::median(weighted_positive) else NA_real_,
    stringsAsFactors = FALSE
  )
}
