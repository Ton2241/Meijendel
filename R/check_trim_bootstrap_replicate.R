#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_trend_contract.R"))
source(file.path(repo, "R", "trim_bootstrap_core.R"))
source(file.path(repo, "R", "trim_bridge_core.R"))

clusters <- data.frame(
  plot_id = 1:8,
  bootstrap_cluster_id = 1:8,
  stratum = rep(c("historische_kern", "later_netwerk"), each = 4L),
  primary_bridge_plot = TRUE,
  strict_bridge_plot = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE),
  stringsAsFactors = FALSE
)
grid <- expand.grid(
  soort_id = 1:2,
  bootstrap_cluster_id = 1:8,
  jaar = 1981:1990,
  KEEP.OUT.ATTRS = FALSE
)
grid$plot_id <- grid$bootstrap_cluster_id
grid$geteld <- TRUE
grid$count_adjusted <- 2 + grid$soort_id + (grid$bootstrap_cluster_id %% 3) +
  ifelse(grid$jaar >= 1986, grid$soort_id, 0)

context <- build_bootstrap_context(
  tbls = list(species_matrix = grid),
  cluster_definition = clusters,
  config = list(
    run_seed = 20260920L,
    periods = list(pre = 1981:1983, post = 1984:1990),
    bridge_pre_years = 1981:1983,
    primary_post_years = 1986:1988
  )
)
context$group_definitions <- list(
  list(
    entity_id = "eco-100-robuust",
    mapping = data.frame(soort_id = 1:2),
    variant = "robuust",
    aggregation = "geometrisch"
  ),
  list(
    entity_id = "eco-100-volledig",
    mapping = data.frame(soort_id = 1:2),
    variant = "volledig",
    aggregation = "geometrisch"
  )
)
r1 <- run_trim_bootstrap_replicate(context, 7L)
r2 <- run_trim_bootstrap_replicate(context, 7L)
stopifnot(identical(r1$draw, r2$draw))
stopifnot(identical(r1$species, r2$species))
stopifnot(length(unique(r1$species$draw_hash)) == 1L)
stopifnot(all(c(
  "primary_1986_1988", "alternative_1987_1989", "alternative_1988_1990",
  "strict_all_six", "historical_continuity_1984_1986"
) %in% r1$species$bridge_variant))
primary <- r1$species[
  r1$species$bridge_variant == "primary_1986_1988" &
    r1$species$coverage_variant == "volledig_netwerk",
]
stopifnot(nrow(primary) == 2L)
stopifnot(all(primary$bridge_status == "formele_brug"))
stopifnot(all(primary$post_years == "1986-1988"))
stopifnot(!any(grepl("1984|1985", primary$post_years)))
stopifnot(any(r1$species$coverage_variant == "historische_kern"))
stopifnot(nrow(r1$groups) > 0L)
stopifnot(setequal(unique(r1$groups$entity_id), c("eco-100-robuust", "eco-100-volledig")))
stopifnot(all(is.finite(r1$groups$estimate_pct_per_year)))
stopifnot(all(mapply(
  identical,
  r1$diagnostics$main_site_ids,
  r1$diagnostics$calibration_site_ids,
  USE.NAMES = FALSE
)))

cat("OK: volledige bootstrapreplicatie gebruikt één trekking voor hoofdmodel, brug en historische kern.\n")

# Baseline preparation follows the existing species route, including delayed starts.
delayed <- grid[grid$soort_id == 1 & grid$jaar <= 1985, ]
delayed$count_adjusted[delayed$jaar < 1983] <- 0
prepared <- prepare_trim_period(delayed)
stopifnot(prepared$ok, min(prepared$year_map$jaar) == 1983)
frozen <- fit_first_working_trim_model(delayed, analysis_years = 1981:1985)
stopifnot(identical(frozen$year_map$jaar, 1981:1985))
stopifnot(is.na(combined_pct_trend(c(`1981`=100,`1982`=0),c(`1984`=100),1, required_years=c(1981,1982,1984))))
context$config$coverage_variants <- 'volledig_netwerk'
context$config$bridge_variants <- list(primary_5yr=list(pre_years=1981:1983,post_years=1986:1990),reference_3yr=list(pre_years=1981:1983,post_years=1986:1988))
custom <- build_bootstrap_context(list(species_matrix=grid), clusters, context$config)
custom$group_definitions <- list()
custom$config$calibration_method <- 'window_poisson'
r3 <- run_trim_bootstrap_replicate(custom, 7L)
stopifnot(nrow(r3$species)==4L, setequal(r3$species$bridge_variant,c('primary_5yr','reference_3yr')))
stopifnot(all(c('pre_ok','post_ok','pre_reason','post_reason','result_reason') %in% names(r3$species)))
cat('OK: bevroren modeljaren, nulindices en beide pilotvensters.\n')

# An unavailable original period stays visible and is never redefined.
custom$species_targets <- list()
custom$species_targets[['1']] <- list(pre=list(ok=FALSE,reason='te_weinig_positieve_jaren',years=NULL),post=list(ok=TRUE,years=1984:1990))
r4 <- run_trim_bootstrap_replicate(custom,7L)
unavailable <- r4$species[r4$species$soort_id==1L,]
stopifnot(nrow(unavailable)==2L,all(!unavailable$pre_ok),all(is.na(unavailable$estimate_pct_per_year)),all(unavailable$result_reason=='pre:baseline_te_weinig_positieve_jaren'))
# Exact target years cannot be silently shrunk after loss of all observed cells.
missing_year <- delayed[delayed$jaar!=1984,]
stopifnot(identical(fit_first_working_trim_model(missing_year,analysis_years=1981:1985)$reason,'bevroren_modeljaar_ontbreekt'))
cat('OK: ontbrekend oorspronkelijk model en verloren modeljaren blijven expliciet zichtbaar.\n')
