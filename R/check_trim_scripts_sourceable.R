#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", mustWork = TRUE)
root <- tempfile("trim-sourceable-")
dir.create(root)
on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

source_without_execution <- function(path, main_name) {
  env <- new.env(parent = globalenv())
  env$commandArgs <- function(trailingOnly = FALSE) {
    if (trailingOnly) {
      return(c(
        file.path(root, "missing.sql"),
        file.path(root, paste0(main_name, "-species")),
        file.path(root, paste0(main_name, "-groups"))
      ))
    }
    paste0("--file=", path)
  }
  before <- list.files(root, all.files = TRUE, recursive = TRUE)
  sys.source(path, envir = env)
  after <- list.files(root, all.files = TRUE, recursive = TRUE)
  stopifnot(exists(main_name, envir = env, mode = "function", inherits = FALSE))
  stopifnot(identical(before, after))
  invisible(TRUE)
}

source_without_execution(file.path(repo, "R", "trim_soorten_en_msi_evg.R"), "trim_main")
source_without_execution(file.path(repo, "R", "trim_sandra_soorten_en_msi_evg.R"), "trim_sandra_main")

cat("OK: beide TRIM-scripts zijn sourcebaar zonder analyse of bestandswrites.\n")
