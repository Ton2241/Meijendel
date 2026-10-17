#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_bootstrap_summary.R"))
source(file.path(repo, "R", "run_trim_cluster_jackknife.R"))

s <- summarise_bootstrap_estimate(
  theta_hat = 1,
  boot = seq(-1, 3, length.out = 2000),
  jack = c(.8, .9, 1.1, 1.2),
  planned = 2000L
)
stopifnot(s$valid_replicates == 2000L)
stopifnot(s$ci_low < s$estimate, s$ci_high > s$estimate)
stopifnot(s$interval_method %in% c("bca", "percentile_fallback"))
stopifnot(s$p_value >= 0, s$p_value <= 1)

bad <- summarise_bootstrap_estimate(1, c(rep(1, 1899), rep(NA, 101)), c(.9, 1.1), 2000L)
stopifnot(identical(bad$publication_status, "onvoldoende_bootstrap"))
stopifnot(is.na(bad$ci_low), is.na(bad$ci_high), is.na(bad$p_value))

primary <- data.frame(estimate = 1, ci_low = 0.2, ci_high = 1.8)
alternatives <- data.frame(
  estimate = c(-0.5, 0.8), ci_low = c(-1.2, -0.1), ci_high = c(-0.1, 1.7)
)
historical_core <- data.frame(estimate = -0.2, ci_low = -0.8, ci_high = -0.05)
sens <- summarise_structural_sensitivity(primary, alternatives, historical_core)
stopifnot(identical(sens$bridge_status, "bruggevoelig"))
stopifnot(identical(sens$coverage_status, "gebiedsdekkinggevoelig"))
stopifnot(identical(sens$envelope_type, "gevoeligheidsenvelop_geen_bi"))
stopifnot(sens$envelope_low == -1.2, sens$envelope_high == 1.8)

stopifnot(check_interval_stability(c(-1, 1), c(-0.901, 1.099)))
stopifnot(!check_interval_stability(c(-1, 1), c(-0.9, 1.1)))
stopifnot(check_interval_stability(c(-0.5, 0.5), c(-0.451, 0.549)))
stopifnot(!check_interval_stability(c(-0.5, 0.5), c(-0.45, 0.55)))

clusters <- data.frame(
  bootstrap_cluster_id = 1:6,
  stratum = rep(c("historische_kern", "later_netwerk"), each = 3L)
)
context <- list(
  clusters = clusters,
  jackknife_estimator = function(context_without_cluster, omitted_cluster_id) {
    data.frame(
      entity_type = "species",
      entity_id = 1L,
      period = "1958-2025",
      estimate = mean(context_without_cluster$clusters$bootstrap_cluster_id),
      error_status = NA_character_,
      stringsAsFactors = FALSE
    )
  }
)
j1 <- run_trim_cluster_jackknife(context)
j2 <- run_trim_cluster_jackknife(context)
stopifnot(identical(j1, j2))
stopifnot(nrow(j1) == 6L)
stopifnot(identical(sort(unique(j1$omitted_cluster_id)), 1:6))
stopifnot(all(j1$stratum %in% c("historische_kern", "later_netwerk")))

cat("OK: bootstrapintervallen, gevoeligheid, stabiliteit en clusterjackknife voldoen aan contract.\n")
