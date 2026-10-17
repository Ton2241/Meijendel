#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
batch_env <- new.env(parent = globalenv())
merge_env <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "run_trim_bootstrap_batch.R"), envir = batch_env)
sys.source(file.path(repo, "R", "merge_trim_bootstrap_batches.R"), envir = merge_env)

root <- tempfile("trim-resume-")
dir.create(root)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
output <- file.path(root, "batch-000001-000005.rds")
identity <- list(
  run_id = "resume-test",
  source_hash = paste(rep("a", 64), collapse = ""),
  config_hash = paste(rep("b", 64), collapse = ""),
  code_commit = paste(rep("c", 40), collapse = ""),
  software_id = "R-test"
)
replicate_fn <- function(replicate_id) data.frame(replicate_id = replicate_id, value = replicate_id^2)

interrupted <- try(batch_env$run_trim_bootstrap_batch(
  identity = identity,
  replicate_ids = 1:5,
  output = output,
  replicate_fn = replicate_fn,
  worker_id = "test-worker",
  stop_after = 3L
), silent = TRUE)
stopifnot(inherits(interrupted, "try-error"))
stopifnot(file.exists(paste0(output, ".partial")))
partial <- readRDS(paste0(output, ".partial"))
stopifnot(identical(partial$completed_ids, 1:3))

batch_env$run_trim_bootstrap_batch(
  identity = identity,
  replicate_ids = 1:5,
  output = output,
  replicate_fn = replicate_fn,
  worker_id = "test-worker"
)
stopifnot(file.exists(output), !file.exists(paste0(output, ".partial")))
complete <- readRDS(output)
stopifnot(identical(complete$completed_ids, 1:5))
stopifnot(identical(unname(vapply(complete$results, function(x) x$replicate_id, integer(1))), 1:5))

merged <- merge_env$merge_trim_bootstrap_batches(c(output), expected_ids = 1:5)
stopifnot(identical(merged$replicate_ids, 1:5))
duplicate <- file.path(root, "batch-copy.rds")
invisible(file.copy(output, duplicate))
invisible(file.copy(paste0(output, ".manifest.rds"), paste0(duplicate, ".manifest.rds")))
overlap <- try(merge_env$merge_trim_bootstrap_batches(c(output, duplicate), expected_ids = 1:5), silent = TRUE)
stopifnot(inherits(overlap, "try-error"))
stopifnot(grepl("overlap|dubbel", as.character(overlap), ignore.case = TRUE))

cat("OK: batches hervatten atomisch en overlap wordt geweigerd.\n")
