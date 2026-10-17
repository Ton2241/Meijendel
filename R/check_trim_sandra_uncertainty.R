#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("Gebruik: check_trim_sandra_uncertainty.R REPO [SQL]", call. = FALSE)
repo <- normalizePath(args[[1L]], mustWork = TRUE)
source(file.path(repo, "R", "trim_bootstrap_core.R"))
source(file.path(repo, "R", "trim_sandra_soorten_en_msi_evg.R"), local = TRUE)

trends <- read.csv(file.path(repo, "trim", "sandra", "soorten", "soorten_trendoverzicht.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(trends) == 110L)
stopifnot(all(trends$periode == "1997-2022"))
stopifnot(all(trends$trend_methode[trends$trend_formaliteit == "formeel"] == "rtrim::overall(imputed); volledige variantie-covariantiematrix"))

config <- build_sandra_bootstrap_config()
stopifnot(identical(config$bridge, FALSE))
stopifnot(identical(config$period, c(1997L, 2022L)))
stopifnot(identical(config$species_method, "rtrim_overall_imputed_vcov"))
stopifnot(setequal(config$group_variants, c("volledig", "robuust")))

clusters <- data.frame(
  plot_id = 1:4,
  bootstrap_cluster_id = 1:4,
  stratum = rep(c("historische_kern", "later_netwerk"), each = 2L),
  primary_bridge_plot = FALSE,
  strict_bridge_plot = FALSE
)
grid <- expand.grid(soort_id = 1:2, bootstrap_cluster_id = 1:4, jaar = 1997:2001)
grid$plot_id <- grid$bootstrap_cluster_id
grid$geteld <- TRUE
grid$count_adjusted <- 1 + grid$soort_id + grid$bootstrap_cluster_id + grid$jaar - 1997
context <- list(species_matrix = grid, clusters = clusters, config = modifyList(config, list(run_seed = 11L)))
result <- run_unbridged_bootstrap_replicate(context, 1L)
stopifnot(nrow(result$species) == 2L)
stopifnot(!any(grepl("bridge|brug", names(result$species), ignore.case = TRUE)))
stopifnot(all(c("replicate_id", "soort_id", "estimate_pct_per_year", "model_status", "draw_hash") %in% names(result$species)))

cat("OK: Sandra houdt 110 formele soorttrends en hergebruikt de clusterbootstrap zonder brug.\n")
