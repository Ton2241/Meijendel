#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("Gebruik: build_dashboard_browser_data.R CACHE_RDS CACHE_MANIFEST OUTPUT_JSON OUTPUT_MANIFEST", call. = FALSE)
}

cache_path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
cache_manifest_path <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
output_path <- args[[3L]]
output_manifest_path <- args[[4L]]

read_manifest <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  fields <- strsplit(lines[grepl("=", lines, fixed = TRUE)], "=", fixed = TRUE)
  stats::setNames(vapply(fields, function(x) paste(x[-1L], collapse = "="), character(1)), vapply(fields, `[[`, character(1), 1L))
}

sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE)
  hash <- sub("[[:space:]].*$", "", output[[1L]])
  if (!grepl("^[0-9a-f]{64}$", hash)) stop("SHA-256 kon niet worden bepaald voor ", path, ".", call. = FALSE)
  hash
}

file_bytes <- function(path) format(file.info(path)$size, scientific = FALSE)

required_tables <- c(
  "plots", "plot_analyse_scope", "soorten", "plot_jaar_oppervlak",
  "plot_jaar_teller", "territoria", "bronnen", "sovon_bmp_plotjaar",
  "evg_vogelgroepen", "evg_vogel_landschapgroep",
  "functional_group_definition", "functional_group_membership",
  "richtlijnen", "soort_richtlijn", "soorten_kenmerken",
  "soorten_kenmerken_datadictionary", "soorten_kenmerken_hoofdcategorien",
  "soorten_kenmerken_vogeltypering", "habitattypen", "plot_jaar_habitat",
  "plot_jaar_ahn_dtm", "plot_jaar_stikstof", "plot_jaar_infra",
  "plot_jaar_toegankelijkheid", "pq_plot_jaar_vegetatie",
  "dagwaarnemingen_wv", "maatregelen", "plot_jaar_landgebruik",
  "plot_jaar_maatregel", "plot_link", "soorten_habitattypen", "tellers", "trends"
)
required_columns <- list(
  plots = c("plot_id", "plot_naam", "kavel_nummer", "in_gebruik"),
  plot_analyse_scope = c("scope_code", "plot_id", "in_scope", "reden", "besluitdatum"),
  soorten = c("id", "euring_code", "soort_naam", "engelse_naam"),
  plot_jaar_oppervlak = c("plot_id", "jaar", "oppervlakte_km2"),
  plot_jaar_teller = c("teller_id", "plot_id", "jaar"),
  territoria = c("plot_id", "soort_id", "jaar", "territoria", "bron_id"),
  bronnen = c("id", "code"), sovon_bmp_plotjaar = c("plot_id", "jaar", "beoordelingsstatus"),
  evg_vogelgroepen = c("groepsnummer", "landschap_groep", "beschrijving_landschap_groep"),
  evg_vogel_landschapgroep = c("groepsnummer", "vogel_id"),
  functional_group_definition = c("id", "group_code", "group_version", "naam_nl", "minimum_exploratief", "minimum_hoofdindicator", "minimum_robuust", "status"),
  functional_group_membership = c("functional_group_definition_id", "soort_id", "binary_membership", "membership_weight", "classification"),
  richtlijnen = c("id", "naam"), soort_richtlijn = c("soort_id", "richtlijn_id"),
  soorten_kenmerken = c("id", "soort_id", "soortnaam", "hoofdcategorie_id", "code", "waarde"),
  soorten_kenmerken_datadictionary = c("id", "veld", "betekenis", "betekenis_nederlands", "parent_code", "code_type", "status"),
  soorten_kenmerken_hoofdcategorien = c("id", "code", "beschrijving"),
  soorten_kenmerken_vogeltypering = "soort_id", habitattypen = c("id", "habitat_code", "habitat_naam"),
  plot_jaar_habitat = c("plot_id", "jaar", "habitat_id", "aandeel_m2"),
  plot_jaar_ahn_dtm = c("plot_id", "jaar", "bron", "ahn_mean", "ahn_sd"),
  plot_jaar_stikstof = c("plot_id", "jaar", "bron", "stikstof_mean"),
  plot_jaar_infra = c("plot_id", "jaar", "bron", "variabele", "waarde"),
  plot_jaar_toegankelijkheid = c("plot_id", "jaar", "bron", "status_code"),
  pq_plot_jaar_vegetatie = c("plot_id", "jaar", "n_pq", "n_opnamen", "taxa_aantal", "soortenrijkdom_gem", "bedekking_som_gem", "shannon_gem", "dekking_kwaliteit", "bronstatus", "bronbestand", "importversie", "taxonlijst_versie"),
  dagwaarnemingen_wv = c("plot_id", "soort_id", "jaar", "maand", "dag", "aantal"),
  maatregelen = c("id", "omschrijving"), plot_jaar_landgebruik = c("plot_id", "jaar", "bron", "klasse", "pct"),
  plot_jaar_maatregel = c("plot_id", "jaar", "maatregel_id"), plot_link = c("plot_id", "link_type", "label", "url"),
  soorten_habitattypen = c("soort_id", "habitattype_id", "koppelingsterkte"), tellers = c("id", "tellercode"),
  trends = c("soort_id", "regio", "jaar", "waarde")
)

manifest <- read_manifest(cache_manifest_path)
required_manifest <- c("format", "sql_sha256", "sql_bytes", "parser_version", "cache_sha256", "cache_bytes")
missing_manifest <- setdiff(required_manifest, names(manifest))
if (length(missing_manifest)) stop("Cachemanifest mist: ", paste(missing_manifest, collapse = ", "), ".", call. = FALSE)
if (manifest[["format"]] != "meijendel-shiny-cache-manifest-v1") stop("Onbekend cachemanifestformaat.", call. = FALSE)
if (sha256_file(cache_path) != manifest[["cache_sha256"]]) stop("Cachehash wijkt af van cachemanifest.", call. = FALSE)
if (file_bytes(cache_path) != manifest[["cache_bytes"]]) stop("Cachegrootte wijkt af van cachemanifest.", call. = FALSE)

cache <- readRDS(cache_path)
identity <- cache[["identity"]]
if (!identical(cache[["format"]], "meijendel-shiny-cache-v1")) stop("Onbekend cacheformaat.", call. = FALSE)
for (field in c("sql_sha256", "sql_bytes", "parser_version")) {
  if (!identical(as.character(identity[[field]]), as.character(manifest[[field]]))) {
    stop("Cache-identiteit wijkt af voor ", field, ".", call. = FALSE)
  }
}
tables <- cache[["data"]]
missing_tables <- setdiff(required_tables, names(tables))
if (length(missing_tables)) stop("Dashboardcache mist: ", paste(missing_tables, collapse = ", "), ".", call. = FALSE)
tables <- tables[required_tables]
if (!all(vapply(tables, is.data.frame, logical(1)))) stop("Niet alle dashboardtabellen zijn dataframes.", call. = FALSE)
for (table_name in names(required_columns)) {
  missing_columns <- setdiff(required_columns[[table_name]], names(tables[[table_name]]))
  if (length(missing_columns)) {
    stop("Dashboardtabel ", table_name, " mist kolommen: ", paste(missing_columns, collapse = ", "), ".", call. = FALSE)
  }
}

payload <- list(
  format = "meijendel-dashboard-data-v1",
  sql_sha256 = manifest[["sql_sha256"]],
  sql_bytes = manifest[["sql_bytes"]],
  parser_version = as.integer(manifest[["parser_version"]]),
  tables = lapply(tables, function(table) list(columns = names(table), rows = table))
)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(output_manifest_path), recursive = TRUE, showWarnings = FALSE)
json_tmp <- paste0(output_path, ".next-", Sys.getpid())
manifest_tmp <- paste0(output_manifest_path, ".next-", Sys.getpid())
on.exit(unlink(c(json_tmp, manifest_tmp)), add = TRUE)
jsonlite::write_json(payload, json_tmp, auto_unbox = TRUE, dataframe = "values", na = "null", null = "null", digits = NA)
dashboard_hash <- sha256_file(json_tmp)
dashboard_bytes <- file_bytes(json_tmp)
writeLines(c(
  "format=meijendel-dashboard-data-manifest-v1",
  paste0("sql_sha256=", manifest[["sql_sha256"]]),
  paste0("sql_bytes=", manifest[["sql_bytes"]]),
  paste0("parser_version=", manifest[["parser_version"]]),
  paste0("dashboard_data_sha256=", dashboard_hash),
  paste0("dashboard_data_bytes=", dashboard_bytes),
  paste0("table_count=", length(tables))
), manifest_tmp, useBytes = TRUE)
if (!file.rename(json_tmp, output_path)) stop("Dashboarddataset kon niet atomair worden gepubliceerd.", call. = FALSE)
if (!file.rename(manifest_tmp, output_manifest_path)) stop("Dashboardmanifest kon niet atomair worden gepubliceerd.", call. = FALSE)
cat("DASHBOARD_DATA_STATUS=ready\n")
cat("DASHBOARD_DATA_SHA256=", dashboard_hash, "\n", sep = "")
cat("DASHBOARD_DATA_BYTES=", dashboard_bytes, "\n", sep = "")
