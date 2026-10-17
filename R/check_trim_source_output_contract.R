#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
source(file.path(repo, "R", "trim_run_manifest.R"))

root <- tempfile("trim-manifest-test-")
dir.create(root)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

sql_path <- file.path(root, "meijendel.sql")
output_dir <- file.path(root, "output")
dir.create(output_dir)
writeLines("CREATE TABLE test (id INT);", sql_path)
writeLines("resultaat", file.path(output_dir, "result.csv"))

manifest <- build_trim_run_manifest(
  sql_path = sql_path,
  output_dir = output_dir,
  run_id = "test-run-1",
  git_commit = paste(rep("a", 40L), collapse = "")
)
stopifnot(identical(manifest$format, "trim-bootstrap-run-manifest-v1"))
stopifnot(identical(manifest$run_id, "test-run-1"))
stopifnot(validate_trim_run_manifest(manifest, sql_path, output_dir))

writeLines(c("CREATE TABLE test (id INT);", "INSERT INTO test VALUES (1);"), sql_path)
changed <- try(validate_trim_run_manifest(manifest, sql_path, output_dir), silent = TRUE)
stopifnot(inherits(changed, "try-error"))
stopifnot(grepl("bronhash", as.character(changed), ignore.case = TRUE))

cat("OK: TRIM-bron- en uitvoercontract bewaakt hashes.\n")
