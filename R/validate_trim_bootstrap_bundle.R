#!/usr/bin/env Rscript

validate_trim_bootstrap_bundle <- function(bundle, sql_path, requested_replicates) {
  bundle <- normalizePath(bundle, mustWork = TRUE)
  sql_path <- normalizePath(sql_path, mustWork = TRUE)
  manifest_path <- file.path(bundle, "bundle_manifest.json")
  if (!file.exists(manifest_path)) stop("Bundlemanifest ontbreekt.", call. = FALSE)
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  context_path <- file.path(bundle, "context.rds")
  identity_path <- file.path(bundle, "identity.rds")
  if (!identical(bundle_sha256_file(context_path), manifest$context_sha256) ||
      !identical(bundle_sha256_file(identity_path), manifest$identity_sha256)) {
    stop("Runbundle wijkt af van zijn manifest.", call. = FALSE)
  }
  identity <- readRDS(identity_path)
  if (!identical(identity$run_id, manifest$run_id) || !identical(identity$source_hash, manifest$source_hash)) {
    stop("Bundle-identiteit wijkt af van zijn manifest.", call. = FALSE)
  }
  if (as.integer(requested_replicates) > as.integer(manifest$planned_replicates)) {
    stop("Gevraagd replicatieaantal is groter dan het bundelplan.", call. = FALSE)
  }
  if (!identical(bundle_sha256_file(sql_path), manifest$source_hash)) {
    stop("SQL-bronhash wijkt af van de runbundle.", call. = FALSE)
  }
  invisible(manifest)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Gebruik: validate_trim_bootstrap_bundle.R BUNDLE SQL REPLICATES", call. = FALSE)
  script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  source(file.path(dirname(script_file), "build_trim_bootstrap_bundle.R"), local = TRUE)
  validate_trim_bootstrap_bundle(args[[1L]], args[[2L]], as.integer(args[[3L]]))
  cat("BUNDLE_VALIDATION=ready\n")
}
