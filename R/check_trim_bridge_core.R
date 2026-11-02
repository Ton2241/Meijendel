#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_bridge_core.R"))

b <- compute_empirical_bridge(
  pre_index = c(`1981` = 180, `1982` = 200, `1983` = 220),
  post_index = c(`1986` = 90, `1987` = 100, `1988` = 110),
  calibration_totals = c(`1981` = 40, `1982` = 50, `1983` = 60,
                         `1986` = 20, `1987` = 25, `1988` = 30)
)
stopifnot(isTRUE(all.equal(b$level_ratio, 0.5)))
stopifnot(isTRUE(all.equal(b$bridge_factor, 1.0)))
stopifnot(identical(b$method, "common_plot_trim_1981_1983_to_1986_1988"))
stopifnot(identical(b$status, "formele_brug"))

transition <- try(compute_empirical_bridge(
  pre_index = c(`1981` = 100, `1982` = 100, `1983` = 100),
  post_index = c(`1984` = 100, `1985` = 100, `1986` = 100),
  calibration_totals = c(`1981` = 10, `1982` = 10, `1983` = 10,
                         `1984` = 10, `1985` = 10, `1986` = 10),
  post_years = 1984:1986
), silent = TRUE)
stopifnot(inherits(transition, "try-error"))

bad <- compute_empirical_bridge(
  pre_index = c(`1981` = 100, `1982` = 100, `1983` = 100),
  post_index = c(`1986` = 100, `1987` = 100, `1988` = 100),
  calibration_totals = c(`1981` = 10, `1982` = 10, `1983` = 10,
                         `1986` = 0, `1987` = 0, `1988` = 0)
)
stopifnot(identical(bad$status, "geen_formele_brug"))
stopifnot(is.na(bad$bridge_factor))

failed <- compute_empirical_bridge(
  pre_index = c(`1981` = 100, `1982` = 100, `1983` = 100),
  post_index = c(`1986` = 100, `1987` = 100, `1988` = 100),
  calibration_totals = NULL
)
stopifnot(identical(failed$status, "geen_formele_brug"))
stopifnot(is.na(failed$bridge_factor))

# Een echte nul telt mee in het gemiddelde van een volledig venster.
zero_year <- compute_empirical_bridge(
  c(`1981`=100, `1982`=100, `1983`=100),
  c(`1986`=100, `1987`=100, `1988`=100),
  c(`1981`=10, `1982`=10, `1983`=10, `1986`=0, `1987`=10, `1988`=10)
)
stopifnot(isTRUE(all.equal(zero_year$level_ratio, 2/3)))
for (bad_value in c(NA_real_, Inf, -1)) {
  incomplete <- compute_empirical_bridge(
    c(`1981`=100, `1982`=100, `1983`=100),
    c(`1986`=100, `1987`=100, `1988`=100),
    c(`1981`=10, `1982`=10, `1983`=10, `1986`=bad_value, `1987`=10, `1988`=10)
  )
  stopifnot(identical(incomplete$status, "geen_formele_brug"))
}
missing_year <- compute_empirical_bridge(
  c(`1981`=100, `1982`=100, `1983`=100),
  c(`1986`=100, `1987`=100, `1988`=100),
  c(`1981`=10, `1982`=10, `1983`=10, `1987`=10, `1988`=10)
)
stopifnot(identical(missing_year$status, "geen_formele_brug"))

cat("OK: empirische brug gebruikt 1981-1983 naar 1986-1988 zonder fallbackfactor.\n")

# Twee vensterniveaus: nullen blijven deel van telling en telinspanning.
source(file.path(repo, "R", "trim_bootstrap_core.R"))
window_data <- expand.grid(bootstrap_cluster_id = 1:2, jaar = c(1981:1983, 1986:1988))
window_data$geteld <- TRUE
window_data$count_adjusted <- 10 * window_data$bootstrap_cluster_id * ifelse(window_data$jaar < 1984, 1, 0.5)
window_data$count_adjusted[window_data$jaar %in% c(1981, 1986)] <- 0
identity_draw <- data.frame(source_cluster_id=1:2, bootstrap_site_id=101:102, draw_position=1:2)
window_fit <- fit_bridge_calibration_window(window_data, identity_draw, 1:2, 1981:1983, 1986:1988)
stopifnot(isTRUE(window_fit$ok))
stopifnot(isTRUE(all.equal(unname(window_fit$totals[["1986"]]/window_fit$totals[["1981"]]), 0.5, tolerance=1e-8)))
# Ontbrekend bezoek is geen nul: ongelijke blootstelling wordt gecorrigeerd.
unequal <- window_data
unequal$count_adjusted <- 10 * unequal$bootstrap_cluster_id * ifelse(unequal$jaar < 1984, 1, 0.5)
unequal$geteld[unequal$bootstrap_cluster_id==2 & unequal$jaar==1981] <- FALSE
unequal$count_adjusted[!unequal$geteld] <- NA_real_
unequal_fit <- fit_bridge_calibration_window(unequal, identity_draw, 1:2, 1981:1983, 1986:1988)
stopifnot(isTRUE(unequal_fit$ok))
stopifnot(isTRUE(all.equal(unname(unequal_fit$totals[["1986"]]/unequal_fit$totals[["1981"]]), 0.5, tolerance=1e-8)))
empty_window <- window_data
empty_window$count_adjusted[empty_window$jaar >= 1986] <- 0
stopifnot(!fit_bridge_calibration_window(empty_window, identity_draw, 1:2, 1981:1983, 1986:1988)$ok)
missing_window_year <- window_data
missing_window_year$geteld[missing_window_year$jaar==1987] <- FALSE
stopifnot(!fit_bridge_calibration_window(missing_window_year, identity_draw, 1:2, 1981:1983, 1986:1988)$ok)
negative_window <- window_data
negative_window$count_adjusted[1] <- -1
stopifnot(!fit_bridge_calibration_window(negative_window, identity_draw, 1:2, 1981:1983, 1986:1988)$ok)
# De venstermethode is expliciet; de jaarlijkse comparator blijft beschikbaar.
variant_config <- list(bridge_variants=list(primary=list(plot_ids=1:2,pre_years=1981:1983,post_years=1986:1988)), calibration_method="window_poisson")
variant_fit <- compute_bridge_variants(window_data, stats::setNames(rep(100,3),1981:1983), stats::setNames(rep(100,3),1986:1988), identity_draw, variant_config)
stopifnot(identical(variant_fit$calibration_method, "window_poisson"))
stopifnot(isTRUE(all.equal(variant_fit$bridge_factor,0.5,tolerance=1e-8)))
cat("OK: vensterkalibratie behoudt nullen en corrigeert ongelijke telinspanning.\n")

# Een eenzijdig bezochte site mag geen ontbrekend jaar van de gebruikte
# tweezijdige sites verhullen. Nulsites met echte bezoeken tellen wel mee.
covered_elsewhere <- window_data
covered_elsewhere$geteld <- with(covered_elsewhere, (bootstrap_cluster_id==1 & jaar!=1983) | (bootstrap_cluster_id==2 & jaar==1983))
covered_elsewhere$count_adjusted[!covered_elsewhere$geteld] <- NA_real_
coverage_fit <- fit_bridge_calibration_window(covered_elsewhere,identity_draw,1:2,1981:1983,1986:1988)
stopifnot(!coverage_fit$ok)
stopifnot(identical(coverage_fit$reason,"onvolledige_ankercellen_gepaarde_sites"))
