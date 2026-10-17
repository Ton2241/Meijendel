#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_bootstrap_core.R"))

stopifnot(normalize_kavel_identity(" 4-5 ") == "4-5")
stopifnot(normalize_kavel_identity("M45") == "45")
stopifnot(normalize_kavel_identity("4-5") != normalize_kavel_identity("45"))

clusters <- data.frame(
  bootstrap_cluster_id = 1:6,
  stratum = rep(c("historische_kern", "later_netwerk"), each = 3L),
  primary_bridge_plot = c(TRUE, TRUE, FALSE, TRUE, FALSE, FALSE),
  strict_bridge_plot = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

d1 <- make_stratified_cluster_draw(clusters, 17L, 20260920L)
d2 <- make_stratified_cluster_draw(clusters, 17L, 20260920L)
stopifnot(identical(d1, d2))
stopifnot(table(d1$stratum)[["historische_kern"]] == 3L)
stopifnot(table(d1$stratum)[["later_netwerk"]] == 3L)
stopifnot(!anyDuplicated(d1$bootstrap_site_id))
stopifnot(identical(
  d1$primary_bridge_plot,
  clusters$primary_bridge_plot[match(d1$source_cluster_id, clusters$bootstrap_cluster_id)]
))

first_duplicate <- NA_integer_
for (replicate_id in 1:100) {
  draw <- make_stratified_cluster_draw(clusters, replicate_id, 20260920L)
  if (anyDuplicated(draw$source_cluster_id) > 0L) {
    first_duplicate <- replicate_id
    break
  }
}
stopifnot(is.finite(first_duplicate))
draw <- make_stratified_cluster_draw(clusters, first_duplicate, 20260920L)
stopifnot(anyDuplicated(draw$source_cluster_id) > 0L)

history <- expand.grid(bootstrap_cluster_id = 1:6, jaar = 2001:2002)
history$plot_id <- history$bootstrap_cluster_id
history$value <- history$bootstrap_cluster_id * 10 + history$jaar
sampled <- apply_cluster_draw(history, draw)
stopifnot(nrow(sampled) == nrow(draw) * 2L)
stopifnot(!any(is.na(sampled$bootstrap_site_id)))
stopifnot(identical(sort(unique(sampled$plot_id)), sort(unique(draw$bootstrap_site_id))))

cat("OK: gestratificeerde clustertrekking is reproduceerbaar en bewaart multipliciteit.\n")
