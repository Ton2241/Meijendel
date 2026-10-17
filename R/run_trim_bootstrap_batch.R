#!/usr/bin/env Rscript

script_argument <- function(args, name, required = TRUE) {
  hit <- match(name, args)
  if (is.na(hit) || hit == length(args)) {
    if (required) stop("Ontbrekend argument ", name, ".", call. = FALSE)
    return(NULL)
  }
  args[[hit + 1L]]
}

batch_sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  hash <- if (length(output)) sub("[[:space:]].*$", "", output[[1L]]) else ""
  if (!grepl("^[0-9a-f]{64}$", hash)) stop("Batchhash kon niet worden bepaald.", call. = FALSE)
  hash
}

validate_batch_identity <- function(identity) {
  required <- c("run_id", "source_hash", "config_hash", "code_commit", "software_id")
  missing <- setdiff(required, names(identity))
  if (length(missing) || any(!nzchar(vapply(identity[required], as.character, character(1))))) {
    stop("Batchidentiteit is onvolledig.", call. = FALSE)
  }
  invisible(TRUE)
}

run_trim_bootstrap_batch <- function(
    identity,
    replicate_ids,
    output,
    replicate_fn,
    worker_id,
    stop_after = NULL) {
  validate_batch_identity(identity)
  if (!is.function(replicate_fn)) stop("replicate_fn moet een functie zijn.", call. = FALSE)
  replicate_ids <- as.integer(replicate_ids)
  if (!length(replicate_ids) || anyNA(replicate_ids) || anyDuplicated(replicate_ids) || !identical(replicate_ids, seq.int(min(replicate_ids), max(replicate_ids)))) {
    stop("Replicatiebereik moet uniek en aaneengesloten zijn.", call. = FALSE)
  }
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(output, ".partial")
  sidecar <- paste0(output, ".manifest.rds")

  if (file.exists(output)) {
    if (!file.exists(sidecar)) stop("Bestaande batch mist manifest.", call. = FALSE)
    manifest <- readRDS(sidecar)
    if (!identical(batch_sha256_file(output), manifest$output_sha256)) stop("Bestaande batchchecksum wijkt af.", call. = FALSE)
    return(invisible(readRDS(output)))
  }
  state <- if (file.exists(partial)) readRDS(partial) else list(
    identity = identity,
    requested_ids = replicate_ids,
    completed_ids = integer(),
    results = list(),
    errors = list(),
    worker_id = worker_id,
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  if (!identical(state$identity, identity) || !identical(state$requested_ids, replicate_ids)) {
    stop("Partiele batch hoort bij een andere run of replicatiereeks.", call. = FALSE)
  }
  start <- proc.time()[["elapsed"]]
  processed_this_call <- 0L
  for (replicate_id in setdiff(replicate_ids, state$completed_ids)) {
    result <- tryCatch(replicate_fn(replicate_id), error = function(e) e)
    if (inherits(result, "error")) {
      state$errors[[as.character(replicate_id)]] <- conditionMessage(result)
    } else {
      state$results[[as.character(replicate_id)]] <- result
    }
    state$completed_ids <- sort(c(state$completed_ids, replicate_id))
    saveRDS(state, partial, compress = TRUE)
    processed_this_call <- processed_this_call + 1L
    if (!is.null(stop_after) && processed_this_call >= stop_after) stop("Bewuste testonderbreking na checkpoint.", call. = FALSE)
  }
  state$runtime_seconds <- proc.time()[["elapsed"]] - start
  state$peak_memory_mb <- max(gc()[, "max used"]) * 8 / 1024^2
  state$swap_used_bytes <- NA_real_
  state$finished_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  saveRDS(state, partial, compress = TRUE)
  if (!file.rename(partial, output)) stop("Atomische batchpromotie mislukt.", call. = FALSE)
  manifest <- list(
    identity = identity,
    replicate_ids = replicate_ids,
    output_sha256 = batch_sha256_file(output),
    runtime_seconds = state$runtime_seconds,
    peak_memory_mb = state$peak_memory_mb,
    swap_used_bytes = state$swap_used_bytes,
    worker_id = worker_id,
    error_count = length(state$errors)
  )
  saveRDS(manifest, sidecar, compress = TRUE)
  invisible(state)
}

run_trim_bootstrap_batch_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  bundle <- normalizePath(script_argument(args, "--bundle"), mustWork = TRUE)
  from <- as.integer(script_argument(args, "--replicate-from"))
  to <- as.integer(script_argument(args, "--replicate-to"))
  output <- script_argument(args, "--output")
  context <- readRDS(file.path(bundle, "context.rds"))
  identity <- readRDS(file.path(bundle, "identity.rds"))
  repo <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])), ".."), mustWork = TRUE)
  source(file.path(repo, "R", "trim_bootstrap_core.R"), local = TRUE)
  source(file.path(repo, "R", "trim_bridge_core.R"), local = TRUE)
  run_trim_bootstrap_batch(
    identity, seq.int(from, to), output,
    replicate_fn = function(id) run_trim_bootstrap_replicate(context, id),
    worker_id = Sys.info()[["nodename"]]
  )
}

if (sys.nframe() == 0L) run_trim_bootstrap_batch_cli()
