#!/usr/bin/env Rscript

pilot_bind_rows <- function(items) {
  items <- Filter(function(x) is.data.frame(x) && nrow(x), items)
  if (!length(items)) return(data.frame())
  do.call(rbind, items)
}

pilot_primary_reason <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(values)]
  if (!length(values)) return(NA_character_)
  counts <- sort(table(values), decreasing = TRUE)
  names(counts)[[1L]]
}

pilot_reason_counts <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(values)]
  if (!length(values)) return(NA_character_)
  counts <- sort(table(values), decreasing = TRUE)
  paste(paste(names(counts), as.integer(counts), sep = "="), collapse = ";")
}

pilot_validity_table <- function(data, keys, reason_col, planned) {
  required <- c("replicate_id", keys, "estimate_pct_per_year", reason_col)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Pilotregels missen kolommen: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  duplicate_key <- do.call(paste, c(data[c("replicate_id", keys)], sep = "\r"))
  if (anyDuplicated(duplicate_key)) stop("Een pilotschatter komt dubbel voor binnen een replicatie.", call. = FALSE)

  group_key <- do.call(paste, c(data[keys], sep = "\r"))
  pieces <- split(data, group_key, drop = TRUE)
  rows <- lapply(pieces, function(piece) {
    valid <- is.finite(piece$estimate_pct_per_year)
    key_values <- piece[1L, keys, drop = FALSE]
    key_values$planned_replicates <- as.integer(planned)
    key_values$observed_replicates <- nrow(piece)
    key_values$valid_replicates <- sum(valid)
    key_values$valid_fraction <- sum(valid) / planned
    key_values$publication_gate <- if (key_values$valid_fraction >= 0.95) "voldoet_aan_95_procent" else "onvoldoende_bootstrap"
    key_values$primary_invalid_reason <- pilot_primary_reason(piece[[reason_col]][!valid])
    key_values$invalid_reason_counts <- pilot_reason_counts(piece[[reason_col]][!valid])
    key_values
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[do.call(order, out[keys]), , drop = FALSE]
}

pilot_model_frequencies <- function(species) {
  required <- c("replicate_id", "soort_id", "coverage_variant", "pre_model", "post_model")
  missing <- setdiff(required, names(species))
  if (length(missing)) stop("Pilotsoortregels missen modelkolommen: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  base <- unique(species[required])
  pre <- data.frame(
    coverage_variant = base$coverage_variant, period = "pre", model = base$pre_model,
    stringsAsFactors = FALSE
  )
  post <- data.frame(
    coverage_variant = base$coverage_variant, period = "post", model = base$post_model,
    stringsAsFactors = FALSE
  )
  long <- rbind(pre, post)
  long$model[is.na(long$model) | !nzchar(long$model)] <- "mislukt"
  counts <- aggregate(
    rep(1L, nrow(long)),
    list(coverage_variant = long$coverage_variant, period = long$period, model = long$model),
    sum
  )
  names(counts)[[4L]] <- "count"
  totals <- aggregate(count ~ coverage_variant + period, counts, sum)
  names(totals)[[3L]] <- "total"
  counts <- merge(counts, totals, by = c("coverage_variant", "period"), all.x = TRUE)
  counts$fraction <- counts$count / counts$total
  counts[order(counts$coverage_variant, counts$period, counts$model), , drop = FALSE]
}

summarise_trim_bootstrap_pilot <- function(paths, expected_ids) {
  paths <- sort(normalizePath(paths, mustWork = TRUE))
  merge_env <- new.env(parent = globalenv())
  repo <- dirname(dirname(normalizePath(sys.frame(1)$ofile %||% "R/summarise_trim_bootstrap_pilot.R", mustWork = FALSE)))
  merge_file <- file.path(repo, "R", "merge_trim_bootstrap_batches.R")
  if (!file.exists(merge_file)) merge_file <- file.path("R", "merge_trim_bootstrap_batches.R")
  sys.source(merge_file, envir = merge_env)
  merged <- merge_env$merge_trim_bootstrap_batches(paths, expected_ids = expected_ids)
  states <- lapply(paths, readRDS)
  results <- merged$results
  species <- pilot_bind_rows(lapply(results, `[[`, "species"))
  groups <- pilot_bind_rows(lapply(results, `[[`, "groups"))
  planned <- length(expected_ids)
  completed <- length(merged$replicate_ids)
  runtimes <- vapply(states, function(x) as.numeric(x$runtime_seconds %||% NA_real_), numeric(1))
  peaks <- vapply(states, function(x) as.numeric(x$peak_memory_mb %||% NA_real_), numeric(1))
  swaps <- vapply(states, function(x) as.numeric(x$swap_used_bytes %||% NA_real_), numeric(1))
  error_count <- sum(vapply(states, function(x) length(x$errors %||% list()), integer(1)))
  identity <- merged$identity
  started_at <- vapply(states, function(x) as.character(x$started_at %||% NA_character_), character(1))
  finished_at <- vapply(states, function(x) as.character(x$finished_at %||% NA_character_), character(1))
  start_time <- suppressWarnings(as.POSIXct(started_at, tz = "UTC"))
  finish_time <- suppressWarnings(as.POSIXct(finished_at, tz = "UTC"))
  wall_elapsed <- if (any(!is.na(start_time)) && any(!is.na(finish_time))) {
    as.numeric(difftime(max(finish_time, na.rm = TRUE), min(start_time, na.rm = TRUE), units = "secs"))
  } else NA_real_

  run <- data.frame(
    run_id = identity$run_id,
    source_hash = identity$source_hash,
    config_hash = identity$config_hash,
    code_commit = identity$code_commit,
    software_id = identity$software_id,
    planned_replicates = planned,
    completed_replicates = completed,
    batch_count = length(paths),
    worker_ids = paste(sort(unique(vapply(states, function(x) as.character(x$worker_id %||% NA_character_), character(1)))), collapse = ";"),
    started_at_utc = if (any(!is.na(start_time))) format(min(start_time, na.rm = TRUE), tz = "UTC", usetz = TRUE) else NA_character_,
    finished_at_utc = if (any(!is.na(finish_time))) format(max(finish_time, na.rm = TRUE), tz = "UTC", usetz = TRUE) else NA_character_,
    wall_elapsed_seconds = wall_elapsed,
    runtime_seconds_total = sum(runtimes, na.rm = TRUE),
    seconds_per_replicate = sum(runtimes, na.rm = TRUE) / completed,
    peak_memory_mb_max = if (any(is.finite(peaks))) max(peaks, na.rm = TRUE) else NA_real_,
    swap_used_bytes_max = if (any(is.finite(swaps))) max(swaps, na.rm = TRUE) else NA_real_,
    error_count = error_count,
    stringsAsFactors = FALSE
  )

  list(
    run = run,
    species = pilot_validity_table(
      species,
      c("soort_id", "coverage_variant", "bridge_variant"),
      "bridge_reason", planned
    ),
    groups = pilot_validity_table(
      groups,
      c("entity_id", "coverage_variant", "bridge_variant"),
      "group_status", planned
    ),
    models = pilot_model_frequencies(species)
  )
}

write_trim_bootstrap_pilot_summary <- function(summary, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  files <- c(
    run = "pilot_run.csv",
    species = "pilot_species_validity.csv",
    groups = "pilot_group_validity.csv",
    models = "pilot_model_frequencies.csv"
  )
  for (name in names(files)) {
    target <- file.path(output_dir, files[[name]])
    temporary <- tempfile(paste0(".", files[[name]], "."), tmpdir = output_dir)
    utils::write.csv(summary[[name]], temporary, row.names = FALSE, na = "")
    if (!file.rename(temporary, target)) stop("Kan pilotuitvoer niet atomisch schrijven: ", target, ".", call. = FALSE)
  }
  invisible(file.path(output_dir, unname(files)))
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3L) stop("Gebruik: summarise_trim_bootstrap_pilot.R OUTPUT_DIR EXPECTED_N BATCH...", call. = FALSE)
  output_dir <- args[[1L]]
  expected_n <- as.integer(args[[2L]])
  if (!is.finite(expected_n) || expected_n < 1L) stop("EXPECTED_N moet positief zijn.", call. = FALSE)
  summary <- summarise_trim_bootstrap_pilot(args[-c(1L, 2L)], seq_len(expected_n))
  write_trim_bootstrap_pilot_summary(summary, output_dir)
  cat("TRIM_BOOTSTRAP_PILOT_SUMMARY=ready\n")
}
