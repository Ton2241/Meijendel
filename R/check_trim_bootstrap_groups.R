#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_bootstrap_core.R"))

required_bridge_variants <- c(
  "primary_1986_1988", "alternative_1987_1989", "alternative_1988_1990",
  "strict_all_six", "historical_continuity_1984_1986"
)
fixed_group <- data.frame(
  group_id = "g1",
  soort_id = 1:3,
  binary_membership = 1,
  membership_weight = c(1, 0.5, 1),
  stringsAsFactors = FALSE
)
indices_missing_one <- expand.grid(
  soort_id = 1:2,
  jaar = 2001:2003,
  bridge_variant = required_bridge_variants,
  coverage_variant = "volledig_netwerk",
  KEEP.OUT.ATTRS = FALSE
)
indices_missing_one$index_value <- 100 + indices_missing_one$soort_id * 10 + indices_missing_one$jaar - 2001

robust <- aggregate_bootstrap_group(indices_missing_one, fixed_group, "robuust")
full <- aggregate_bootstrap_group(indices_missing_one, fixed_group, "volledig")
stopifnot(identical(robust$status, "ongeldig_vaste_soort_ontbreekt"))
stopifnot(nrow(robust$series) == 0L)
stopifnot(identical(full$status, "geldig_wisselende_samenstelling"))
stopifnot(all(full$series$n_soorten == 2L))
stopifnot(setequal(unique(full$series$bridge_variant), required_bridge_variants))
stopifnot(all(full$series$verwachte_soorten == 3L))
stopifnot(all(full$series$ontbrekende_soorten == "3"))

complete <- rbind(
  indices_missing_one,
  transform(indices_missing_one[indices_missing_one$soort_id == 1L, ], soort_id = 3L, index_value = 130)
)
weighted <- aggregate_bootstrap_group(complete, fixed_group, "robuust", aggregation = "gewogen")
stopifnot(identical(weighted$status, "geldig_vaste_samenstelling"))
stopifnot(all(weighted$series$n_soorten == 3L))
stopifnot(all(abs(weighted$series$som_gewichten - 2.5) < 1e-12))

binary <- aggregate_bootstrap_group(complete, fixed_group, "robuust", aggregation = "binair")
geometric <- aggregate_bootstrap_group(complete, fixed_group, "robuust", aggregation = "geometrisch")
stopifnot(all(is.finite(binary$series$group_index)))
stopifnot(all(is.finite(geometric$series$group_index)))
stopifnot(setequal(unique(binary$series$coverage_variant), "volledig_netwerk"))

ecological_checks <- lapply(1:9, function(group_id) {
  mapping <- transform(fixed_group, group_id = paste0("eco-", group_id))
  aggregate_bootstrap_group(complete, mapping, "robuust", "geometrisch")
})
stopifnot(length(ecological_checks) == 9L)
stopifnot(all(vapply(ecological_checks, function(x) identical(x$status, "geldig_vaste_samenstelling"), logical(1))))

functional_checks <- unlist(lapply(1:6, function(group_id) {
  mapping <- transform(fixed_group, group_id = paste0("fun-", group_id))
  lapply(c("binair", "gewogen"), function(mode) {
    list(
      volledig = aggregate_bootstrap_group(complete, mapping, "volledig", mode),
      robuust = aggregate_bootstrap_group(complete, mapping, "robuust", mode)
    )
  })
}), recursive = FALSE)
stopifnot(length(functional_checks) == 12L)
stopifnot(all(vapply(functional_checks, function(x) {
  identical(x$volledig$status, "geldig_wisselende_samenstelling") &&
    identical(x$robuust$status, "geldig_vaste_samenstelling")
}, logical(1))))

cat("OK: vaste groepen vallen volledig uit en volledige groepen bewaren samenstellingsdiagnostiek.\n")
