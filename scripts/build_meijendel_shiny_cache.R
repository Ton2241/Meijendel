#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("Gebruik: build_meijendel_shiny_cache.R DUMP DUMPMANIFEST KANDIDAAT_RDS HELPERS", call. = FALSE)
}

dump_path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
manifest_path <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
candidate_path <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
helpers_path <- normalizePath(args[[4L]], winslash = "/", mustWork = TRUE)

source(helpers_path)
manifest <- read_meijendel_manifest(manifest_path)
identity <- meijendel_cache_identity_from_manifest(manifest, MEIJENDEL_PARSER_CACHE_VERSION)
source_commit <- Sys.getenv("MEIJENDEL_SOURCE_COMMIT", unset = "uncommitted")
if (!identical(source_commit, "uncommitted") && !grepl("^[0-9a-f]{40}$", source_commit)) {
  stop("MEIJENDEL_SOURCE_COMMIT moet 40 lowercase hextekens of uncommitted zijn.", call. = FALSE)
}

data <- parse_meijendel_tables(dump_path)
created_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
cache <- list(
  format = MEIJENDEL_CACHE_FORMAT,
  identity = identity,
  created_at = created_at,
  source_commit = source_commit,
  r_version = as.character(getRversion()),
  serialization_version = 3L,
  data = data
)

next_path <- paste0(candidate_path, ".next.", Sys.getpid())
on.exit(unlink(next_path), add = TRUE)
saveRDS(cache, next_path, version = 3)
validate_meijendel_cache(readRDS(next_path), identity)
if (!file.rename(next_path, candidate_path)) {
  stop("Gevalideerde cache kon niet atomisch worden gepubliceerd: ", candidate_path, call. = FALSE)
}

cat("CACHE_RDS=", candidate_path, "\n", sep = "")
cat("CACHE_PARSER_VERSION=", MEIJENDEL_PARSER_CACHE_VERSION, "\n", sep = "")
cat("CACHE_R_VERSION=", cache$r_version, "\n", sep = "")
cat("CACHE_SERIALIZATION_VERSION=3\n")
cat("CACHE_CREATED_AT=", created_at, "\n", sep = "")
cat("CACHE_SOURCE_COMMIT=", source_commit, "\n", sep = "")
