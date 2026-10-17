empirical_two_sided_p <- function(values, null = 0) {
  values <- values[is.finite(values)]
  if (!length(values)) return(NA_real_)
  n <- length(values)
  min(1, 2 * min(
    (1 + sum(values <= null)) / (n + 1),
    (1 + sum(values >= null)) / (n + 1)
  ))
}

bca_interval <- function(theta_hat, boot, jack, conf = 0.95) {
  boot <- boot[is.finite(boot)]
  jack <- jack[is.finite(jack)]
  if (!is.finite(theta_hat) || length(boot) < 2L || length(jack) < 3L) stop("Onvoldoende waarden voor BCa.", call. = FALSE)
  prop_less <- (sum(boot < theta_hat) + 0.5 * sum(boot == theta_hat)) / length(boot)
  prop_less <- min(max(prop_less, 1 / (2 * length(boot))), 1 - 1 / (2 * length(boot)))
  z0 <- stats::qnorm(prop_less)
  centered <- mean(jack) - jack
  denominator <- 6 * sum(centered^2)^(3 / 2)
  if (!is.finite(denominator) || denominator <= 0) stop("Niet-eindige BCa-acceleratie.", call. = FALSE)
  acceleration <- sum(centered^3) / denominator
  if (!is.finite(acceleration)) stop("Niet-eindige BCa-acceleratie.", call. = FALSE)
  alpha <- (1 - conf) / 2
  z_alpha <- stats::qnorm(c(alpha, 1 - alpha))
  adjusted <- stats::pnorm(z0 + (z0 + z_alpha) / (1 - acceleration * (z0 + z_alpha)))
  if (any(!is.finite(adjusted)) || any(adjusted <= 0 | adjusted >= 1) || adjusted[[1L]] >= adjusted[[2L]]) {
    stop("Ongeldige BCa-percentielen.", call. = FALSE)
  }
  unname(stats::quantile(boot, adjusted, names = FALSE, type = 7))
}

summarise_bootstrap_estimate <- function(theta_hat, boot, jack, planned) {
  planned <- as.integer(planned)
  valid <- boot[is.finite(boot)]
  valid_n <- length(valid)
  valid_fraction <- if (planned > 0L) valid_n / planned else NA_real_
  if (!is.finite(valid_fraction) || valid_fraction < 0.95) {
    return(data.frame(
      estimate = theta_hat, se = NA_real_, ci_low = NA_real_, ci_high = NA_real_, p_value = NA_real_,
      interval_method = NA_character_, interval_reason = "minder_dan_95_procent_geldig",
      planned_replicates = planned, valid_replicates = valid_n, valid_fraction = valid_fraction,
      publication_status = "onvoldoende_bootstrap", stringsAsFactors = FALSE
    ))
  }
  percentile <- unname(stats::quantile(valid, c(0.025, 0.975), names = FALSE, type = 7))
  bca <- tryCatch(bca_interval(theta_hat, valid, jack), error = function(e) e)
  if (inherits(bca, "error")) {
    interval <- percentile
    method <- "percentile_fallback"
    reason <- conditionMessage(bca)
  } else {
    interval <- bca
    method <- "bca"
    reason <- NA_character_
  }
  data.frame(
    estimate = theta_hat,
    se = stats::sd(valid),
    ci_low = interval[[1L]],
    ci_high = interval[[2L]],
    p_value = empirical_two_sided_p(valid),
    interval_method = method,
    interval_reason = reason,
    planned_replicates = planned,
    valid_replicates = valid_n,
    valid_fraction = valid_fraction,
    publication_status = "publiceerbaar",
    stringsAsFactors = FALSE
  )
}

check_interval_stability <- function(previous, current) {
  previous <- as.numeric(previous)
  current <- as.numeric(current)
  if (length(previous) != 2L || length(current) != 2L || any(!is.finite(c(previous, current)))) return(FALSE)
  width <- current[[2L]] - current[[1L]]
  if (!is.finite(width) || width <= 0) return(FALSE)
  changes <- abs(current - previous)
  all(changes < 0.10 & changes < 0.05 * width)
}

interval_includes_zero <- function(df) is.finite(df$ci_low) & is.finite(df$ci_high) & df$ci_low <= 0 & df$ci_high >= 0

summarise_structural_sensitivity <- function(primary, bridge_variants, historical_core) {
  primary_direction <- sign(primary$estimate[[1L]])
  primary_zero <- interval_includes_zero(primary)[[1L]]
  bridge_sensitive <- any(sign(bridge_variants$estimate) != primary_direction, na.rm = TRUE) ||
    any(interval_includes_zero(bridge_variants) != primary_zero, na.rm = TRUE)
  coverage_sensitive <- sign(historical_core$estimate[[1L]]) != primary_direction ||
    interval_includes_zero(historical_core)[[1L]] != primary_zero
  all_intervals <- rbind(primary[, c("ci_low", "ci_high")], bridge_variants[, c("ci_low", "ci_high")], historical_core[, c("ci_low", "ci_high")])
  data.frame(
    bridge_status = if (bridge_sensitive) "bruggevoelig" else "brugrobuust",
    coverage_status = if (coverage_sensitive) "gebiedsdekkinggevoelig" else "gebiedsdekkingrobuust",
    envelope_low = min(all_intervals$ci_low, na.rm = TRUE),
    envelope_high = max(all_intervals$ci_high, na.rm = TRUE),
    envelope_type = "gevoeligheidsenvelop_geen_bi",
    stringsAsFactors = FALSE
  )
}
