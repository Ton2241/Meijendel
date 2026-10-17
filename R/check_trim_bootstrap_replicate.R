#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
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
stopifnot(all(mapply(
  identical,
  r1$diagnostics$main_site_ids,
  r1$diagnostics$calibration_site_ids,
  USE.NAMES = FALSE
)))

cat("OK: volledige bootstrapreplicatie gebruikt één trekking voor hoofdmodel, brug en historische kern.\n")
