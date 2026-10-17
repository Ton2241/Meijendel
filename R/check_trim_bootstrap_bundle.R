#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_bootstrap_core.R"))
source(file.path(repo, "R", "trim_bridge_core.R"))
bundle_env <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "build_trim_bootstrap_bundle.R"), envir = bundle_env)

clusters <- data.frame(
  plot_id = 1:6, bootstrap_cluster_id = 1:6,
  stratum = rep(c("historische_kern", "later_netwerk"), each = 3L),
  primary_bridge_plot = TRUE, strict_bridge_plot = c(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE)
)
matrix <- expand.grid(soort_id = 1:2, plot_id = 1:6, jaar = 1981:1990)
matrix$bootstrap_cluster_id <- matrix$plot_id
matrix$geteld <- TRUE
matrix$count_adjusted <- 3 + matrix$soort_id + matrix$plot_id + (matrix$jaar >= 1986)
orphan <- matrix[1L, ]
orphan$plot_id <- orphan$bootstrap_cluster_id <- 99L
orphan$geteld <- FALSE
restricted <- bundle_env$restrict_species_matrix_to_bootstrap_clusters(rbind(matrix, orphan), clusters)
stopifnot(!99L %in% restricted$plot_id)
bad_orphan <- orphan
bad_orphan$geteld <- TRUE
stopifnot(inherits(try(bundle_env$restrict_species_matrix_to_bootstrap_clusters(rbind(matrix, bad_orphan), clusters), silent = TRUE), "try-error"))
context <- build_bootstrap_context(
  list(species_matrix = matrix), clusters,
  list(run_seed = 20260920L, periods = list(pre = 1981:1983, post = 1984:1990), bridge_pre_years = 1981:1983, primary_post_years = 1986:1988)
)
context$group_definitions <- list(list(
  entity_id = "eco-100-robuust", mapping = data.frame(soort_id = 1:2),
  variant = "robuust", aggregation = "geometrisch"
))
identity <- list(
  run_id = "bundle-test", source_hash = paste(rep("a", 64), collapse = ""),
  config_hash = paste(rep("b", 64), collapse = ""),
  code_commit = paste(rep("c", 40), collapse = ""), software_id = "R-test"
)
root <- tempfile("trim-bundle-")
dir.create(root)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
bundle <- file.path(root, "input_bundle")
bundle_env$write_trim_bootstrap_bundle(
  context, identity, bundle,
  metadata = list(analysis_end_year = 2025L, planned_replicates = 50L, publication_status = "pilot_niet_publiceren")
)
stopifnot(file.exists(file.path(bundle, "context.rds")), file.exists(file.path(bundle, "identity.rds")))
manifest <- jsonlite::read_json(file.path(bundle, "bundle_manifest.json"), simplifyVector = TRUE)
stopifnot(manifest$analysis_end_year == 2025L, manifest$planned_replicates == 50L)
stopifnot(identical(manifest$publication_status, "pilot_niet_publiceren"))

fixed <- bundle_env$select_fixed_robust_species(
  list(
    status = data.frame(soort_id = 1:2, analyse_categorie = "brugbare_tijdreeks"),
    indices = data.frame(
      soort_id = c(1, 1, 1, 2, 2), jaar = c(2001:2003, 2001:2002),
      index_gebrugged = c(100, 101, 102, 100, 101)
    )
  ),
  2001:2003
)
stopifnot(identical(fixed, 1L))

output <- file.path(root, "batch-000001-000001.rds")
status <- system2("Rscript", c(
  file.path(repo, "R", "run_trim_bootstrap_batch.R"),
  "--bundle", bundle, "--replicate-from", "1", "--replicate-to", "1", "--output", output
))
stopifnot(status == 0L, file.exists(output))
result <- readRDS(output)$results[["1"]]
stopifnot(nrow(result$species) > 0L, nrow(result$groups) > 0L)

cat("OK: runbundle is atomisch, niet-publicerend en uitvoerbaar voor soorten, brug en groepen.\n")
