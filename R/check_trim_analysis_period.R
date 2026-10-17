#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_analysis_config.R"))

p25 <- resolve_trim_periods(2025L)
p26 <- resolve_trim_periods(2026L)
stopifnot(identical(p25$post$label, "1984-2025"))
stopifnot(identical(p26$post$label, "1984-2026"))
stopifnot(identical(p26$combined$label, "1958-2026"))
stopifnot(identical(p25$pre$years, 1958:1983))
stopifnot(identical(p26$post$years, 1984:2026))
stopifnot(inherits(try(resolve_trim_periods(1983L), silent = TRUE), "try-error"))
stopifnot(inherits(try(resolve_trim_periods(2026.5), silent = TRUE), "try-error"))

cat("OK: TRIM-perioden en labels volgen het expliciete eindjaar.\n")
