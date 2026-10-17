#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Gebruik: audit_trim_bootstrap_clusters.R SQL_PATH OUTPUT_CSV", call. = FALSE)
sql_path <- normalizePath(args[[1L]], mustWork = TRUE)
output_path <- args[[2L]]
repo <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])), ".."), mustWork = TRUE)

analysis_env <- new.env(parent = globalenv())
sys.source(file.path(repo, "R", "trim_soorten_en_msi_evg.R"), envir = analysis_env)
source(file.path(repo, "R", "audit_trim_bridge_windows.R"))
source(file.path(repo, "R", "trim_bootstrap_core.R"))

read_key_values <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  fields <- strsplit(lines[grepl("=", lines, fixed = TRUE)], "=", fixed = TRUE)
  stats::setNames(vapply(fields, function(x) paste(x[-1L], collapse = "="), character(1)), vapply(fields, `[[`, character(1), 1L))
}
export_manifest_path <- paste0(sql_path, ".manifest")
if (!file.exists(export_manifest_path)) stop("Exportmanifest naast SQL-bron ontbreekt.", call. = FALSE)
export_manifest <- read_key_values(export_manifest_path)
if (as.numeric(export_manifest[["sql_bytes"]]) != unname(file.info(sql_path)$size)) stop("SQL-grootte wijkt af van exportmanifest.", call. = FALSE)
cache_path <- file.path(dirname(sql_path), export_manifest[["cache_file"]])
cache_manifest_path <- file.path(dirname(sql_path), export_manifest[["cache_manifest"]])
if (!file.exists(cache_path) || !file.exists(cache_manifest_path)) stop("Gekoppelde gevalideerde analysecache ontbreekt.", call. = FALSE)
cache_manifest <- read_key_values(cache_manifest_path)
if (!identical(cache_manifest[["sql_sha256"]], export_manifest[["sql_sha256"]])) stop("Cache- en exportmanifest verwijzen niet naar dezelfde bronhash.", call. = FALSE)
cache <- readRDS(cache_path)
if (!identical(as.character(cache$identity$sql_sha256), export_manifest[["sql_sha256"]])) stop("Cache-identiteit wijkt af van SQL-bronhash.", call. = FALSE)
tbls <- cache$data
tbls <- analysis_env$apply_meijendel_plot_scope(tbls, character())
tbls$plots$kavel_nummer <- analysis_env$normalize_kavel_nummer(tbls$plots$kavel_nummer)
basis <- analysis_env$prepare_analysis_basis(tbls, end_year = 2025L)
counted <- basis[basis$geteld %in% TRUE, , drop = FALSE]
if (!nrow(counted)) stop("Geen getelde plots in analysebasis.", call. = FALSE)

sets <- derive_bridge_plot_sets(basis, 1981:1983, 1986:1988)
by_plot <- split(counted, counted$plot_id)
definition <- do.call(rbind, lapply(by_plot, function(df) {
  kavels <- unique(df$kavel_nummer[!is.na(df$kavel_nummer) & nzchar(df$kavel_nummer)])
  if (length(kavels) != 1L) stop("Plot ", df$plot_id[[1L]], " heeft niet exact één kavelidentiteit.", call. = FALSE)
  historical <- any(df$in_hist_kern %in% TRUE)
  data.frame(
    plot_id = as.integer(df$plot_id[[1L]]),
    bootstrap_cluster_id = as.integer(df$plot_id[[1L]]),
    stratum = if (historical) "historische_kern" else "later_netwerk",
    eerst_jaar = min(df$jaar),
    laatst_jaar = max(df$jaar),
    primary_bridge_plot = df$plot_id[[1L]] %in% sets$common_any_year,
    strict_bridge_plot = df$plot_id[[1L]] %in% sets$common_all_years,
    reden = if (historical) "plot_in_historische_kern" else "plot_alleen_later_netwerk",
    kavel_nummer = kavels[[1L]],
    stringsAsFactors = FALSE
  )
}))
rownames(definition) <- NULL

if (nrow(definition) != 52L) stop("Verwacht 52 ooit getelde bronplots; gevonden ", nrow(definition), ".", call. = FALSE)
if (anyDuplicated(definition$plot_id) || anyDuplicated(definition$bootstrap_cluster_id)) stop("Plot- of cluster-ID is niet uniek.", call. = FALSE)
normalized <- normalize_kavel_identity(definition$kavel_nummer)
duplicates <- split(definition$plot_id, normalized)
duplicates <- duplicates[vapply(duplicates, function(x) length(unique(x)) > 1L, logical(1))]
if (length(duplicates)) stop("Genormaliseerde kavelnaam hoort bij meerdere plot-ID's: ", paste(names(duplicates), collapse = ", "), ".", call. = FALSE)
if (any(definition$eerst_jaar < 1958L | definition$laatst_jaar > 2025L)) stop("Clusterjaar buiten 1958-2025.", call. = FALSE)
if (!setequal(unique(definition$stratum), c("historische_kern", "later_netwerk"))) stop("Historisch of later stratum ontbreekt.", call. = FALSE)
if (sum(definition$primary_bridge_plot) != 33L) stop("Primaire brugset moet 33 plots bevatten.", call. = FALSE)
if (sum(definition$strict_bridge_plot) != 20L) stop("Strikte brugset moet 20 plots bevatten.", call. = FALSE)

definition <- definition[order(definition$plot_id), setdiff(names(definition), "kavel_nummer"), drop = FALSE]
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write.csv(definition, output_path, row.names = FALSE)
cat(sprintf(
  "OK: %d clusters; historische_kern=%d; later_netwerk=%d; primaire_brug=%d; strikte_brug=%d.\n",
  nrow(definition), sum(definition$stratum == "historische_kern"), sum(definition$stratum == "later_netwerk"),
  sum(definition$primary_bridge_plot), sum(definition$strict_bridge_plot)
))
