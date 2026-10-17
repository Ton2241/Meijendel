#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "audit_trim_bridge_windows.R"))

all_six <- function(plot_id) {
  data.frame(plot_id = plot_id, jaar = c(1981:1983, 1986:1988), geteld = TRUE)
}
basis <- rbind(
  all_six(1L),
  all_six(2L),
  data.frame(plot_id = 3L, jaar = c(1981L, 1986L), geteld = TRUE),
  data.frame(plot_id = 4L, jaar = 1982L, geteld = TRUE),
  data.frame(plot_id = 5L, jaar = 1987L, geteld = TRUE),
  data.frame(plot_id = 6L, jaar = 1988L, geteld = TRUE)
)
basis$oppervlakte_km2 <- 1
basis$in_analyse <- TRUE

audit <- audit_trim_bridge_windows(
  tbls = list(),
  basis = basis,
  windows = list(pre = 1981:1983, primary = 1986:1988)
)
stopifnot(audit$windows$unique_plots[audit$windows$window == "pre"] == 4L)
stopifnot(audit$overlap$any_year == 3L)
stopifnot(audit$overlap$all_six_years == 2L)
stopifnot(!any(audit$primary_post_years %in% c(1984L, 1985L)))

sets <- derive_bridge_plot_sets(basis, 1981:1983, 1986:1988)
stopifnot(identical(sets$common_any_year, 1:3))
stopifnot(identical(sets$common_all_years, 1:2))

cat("OK: brugjaaraudit telt vensters en gemeenschappelijke plots correct.\n")
