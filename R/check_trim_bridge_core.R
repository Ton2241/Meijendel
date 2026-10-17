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

cat("OK: empirische brug gebruikt 1981-1983 naar 1986-1988 zonder fallbackfactor.\n")
