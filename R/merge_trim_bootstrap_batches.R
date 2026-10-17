#!/usr/bin/env Rscript

merge_trim_bootstrap_batches <- function(paths, expected_ids) {
  if (!length(paths)) stop("Geen batchbestanden aangeleverd.", call. = FALSE)
  batches <- lapply(paths, function(path) {
    sidecar <- paste0(path, ".manifest.rds")
    if (!file.exists(path) || !file.exists(sidecar)) stop("Batch of batchmanifest ontbreekt: ", path, ".", call. = FALSE)
    manifest <- readRDS(sidecar)
    output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
    hash <- sub("[[:space:]].*$", "", output[[1L]])
    if (!identical(hash, manifest$output_sha256)) stop("Batchchecksum wijkt af: ", path, ".", call. = FALSE)
    list(path = path, manifest = manifest, state = readRDS(path))
  })
  identity <- batches[[1L]]$manifest$identity
  if (any(!vapply(batches, function(x) identical(x$manifest$identity, identity), logical(1)))) {
    stop("Batchidentiteiten verschillen.", call. = FALSE)
  }
  ids <- unlist(lapply(batches, function(x) x$manifest$replicate_ids), use.names = FALSE)
  if (anyDuplicated(ids)) stop("Replicatie-overlap of dubbele replicatie-ID aangetroffen.", call. = FALSE)
  expected_ids <- as.integer(expected_ids)
  if (!identical(sort(ids), sort(expected_ids)) || !identical(sort(expected_ids), seq.int(min(expected_ids), max(expected_ids)))) {
    stop("Replicatie-ID's ontbreken of zijn niet aaneengesloten.", call. = FALSE)
  }
  results <- unlist(lapply(batches, function(x) x$state$results), recursive = FALSE)
  names(results) <- NULL
  order_idx <- order(vapply(results, function(x) as.integer(x$replicate_id), integer(1)))
  list(identity = identity, replicate_ids = sort(ids), results = results[order_idx])
}
