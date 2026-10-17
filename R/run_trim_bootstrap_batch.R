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

batch_system_swap_used_bytes <- function() {
  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    output <- suppressWarnings(system2("sysctl", c("-n", "vm.swapusage"), stdout = TRUE, stderr = TRUE))
    text <- paste(output, collapse = " ")
    hit <- regexec("used = ([0-9.]+)([KMG])", text, perl = TRUE)
    fields <- regmatches(text, hit)[[1L]]
    if (length(fields) == 3L) {
      multiplier <- c(K = 1024, M = 1024^2, G = 1024^3)[[fields[[3L]]]]
      return(as.numeric(fields[[2L]]) * multiplier)
    }
  }
  if (file.exists("/proc/meminfo")) {
    info <- readLines("/proc/meminfo", warn = FALSE)
    total <- as.numeric(sub("^SwapTotal:[[:space:]]+([0-9]+).*", "\\1", info[grepl("^SwapTotal:", info)]))
    free <- as.numeric(sub("^SwapFree:[[:space:]]+([0-9]+).*", "\\1", info[grepl("^SwapFree:", info)]))
    if (length(total) == 1L && length(free) == 1L && all(is.finite(c(total, free)))) return((total - free) * 1024)
  }
  NA_real_
}

batch_resource_snapshot <- function() {
  list(
    peak_memory_mb = max(gc()[, "max used"]) * 8 / 1024^2,
    swap_used_bytes = batch_system_swap_used_bytes()
  )
}

batch_max_finite <- function(...) {
  values <- as.numeric(unlist(list(...), use.names = FALSE))
  values <- values[is.finite(values)]
  if (length(values)) max(values) else NA_real_
}

run_trim_bootstrap_batch <- function(
    identity,
    replicate_ids,
    output,
    replicate_fn,
    worker_id,
    stop_after = NULL,
    resource_fn = batch_resource_snapshot) {
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
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    runtime_seconds = 0
  )
  if (!identical(state$identity, identity) || !identical(state$requested_ids, replicate_ids)) {
    stop("Partiele batch hoort bij een andere run of replicatiereeks.", call. = FALSE)
  }
  base_runtime <- as.numeric(state$runtime_seconds %||% 0)
  start <- proc.time()[["elapsed"]]
  initial_resources <- resource_fn()
  if (is.null(state$swap_start_bytes)) state$swap_start_bytes <- as.numeric(initial_resources$swap_used_bytes %||% NA_real_)
  state$peak_memory_mb <- batch_max_finite(state$peak_memory_mb, initial_resources$peak_memory_mb)
  state$swap_used_bytes <- batch_max_finite(state$swap_used_bytes, initial_resources$swap_used_bytes)
  processed_this_call <- 0L
  for (replicate_id in setdiff(replicate_ids, state$completed_ids)) {
    result <- tryCatch(replicate_fn(replicate_id), error = function(e) e)
    if (inherits(result, "error")) {
      state$errors[[as.character(replicate_id)]] <- conditionMessage(result)
    } else {
      state$results[[as.character(replicate_id)]] <- result
    }
    state$completed_ids <- sort(c(state$completed_ids, replicate_id))
    resources <- resource_fn()
    state$runtime_seconds <- base_runtime + proc.time()[["elapsed"]] - start
    state$peak_memory_mb <- batch_max_finite(state$peak_memory_mb, resources$peak_memory_mb)
    state$swap_used_bytes <- batch_max_finite(state$swap_used_bytes, resources$swap_used_bytes)
    state$swap_growth_bytes <- if (all(is.finite(c(state$swap_start_bytes, state$swap_used_bytes)))) {
      max(0, state$swap_used_bytes - state$swap_start_bytes)
    } else NA_real_
    saveRDS(state, partial, compress = TRUE)
    processed_this_call <- processed_this_call + 1L
    if (!is.null(stop_after) && processed_this_call >= stop_after) stop("Bewuste testonderbreking na checkpoint.", call. = FALSE)
  }
  state$runtime_seconds <- base_runtime + proc.time()[["elapsed"]] - start
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
    swap_growth_bytes = state$swap_growth_bytes,
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
  validation_env <- new.env(parent = globalenv())
  sys.source(file.path(repo, "R", "build_trim_bootstrap_bundle.R"), envir = validation_env)
  sys.source(file.path(repo, "R", "validate_trim_bootstrap_bundle.R"), envir = validation_env)
  validation_env$validate_trim_bootstrap_engine(bundle, repo)
  source(file.path(repo, "R", "trim_bootstrap_core.R"), local = TRUE)
  source(file.path(repo, "R", "trim_bridge_core.R"), local = TRUE)
  run_trim_bootstrap_batch(
    identity, seq.int(from, to), output,
    replicate_fn = function(id) run_trim_bootstrap_replicate(context, id),
    worker_id = Sys.info()[["nodename"]]
  )
}

if (sys.nframe() == 0L) run_trim_bootstrap_batch_cli()
