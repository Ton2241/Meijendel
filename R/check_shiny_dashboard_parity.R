args <- commandArgs(trailingOnly = TRUE)

repo_dir <- normalizePath(if (length(args) >= 1L) args[[1]] else ".", mustWork = TRUE)
sql_path <- normalizePath(if (length(args) >= 2L) args[[2]] else file.path(repo_dir, "meijendel.sql"), mustWork = TRUE)
dashboard_msi_path <- normalizePath(
  if (length(args) >= 3L) args[[3]] else file.path(repo_dir, "trim_msi_evg", "msi_per_groep_per_jaar.csv"),
  mustWork = TRUE
)
functional_dashboard_msi_path <- normalizePath(
  file.path(dirname(dashboard_msi_path), "functionele_msi_per_groep_per_jaar.csv"),
  mustWork = TRUE
)
year_from <- if (length(args) >= 4L) as.integer(args[[4]]) else 1958L
year_to <- if (length(args) >= 5L) as.integer(args[[5]]) else 2025L

helpers_path <- file.path(repo_dir, "shiny_meijendel", "helpers.R")
if (!file.exists(helpers_path)) {
  stop("helpers.R ontbreekt: ", helpers_path, call. = FALSE)
}

source(helpers_path)

fail <- function(...) {
  stop(paste0(...), call. = FALSE)
}

if (!is.finite(year_from) || !is.finite(year_to) || year_from > year_to) {
  fail("Ongeldige jaren: ", year_from, "-", year_to)
}

load_time <- system.time(loaded <- load_meijendel_tables_cached(sql_path))
tbls <- loaded$data
selected_kavels <- sort(unique(tbls$plots$kavel_nummer))
selected_kavels <- selected_kavels[!is.na(selected_kavels) & nzchar(selected_kavels)]
if (!length(selected_kavels)) {
  fail("Geen kavels gevonden voor Shiny-paritycheck.")
}

analysis_time <- system.time(shiny_result <- analyse_subset(tbls, selected_kavels, year_from, year_to))
shiny_msi <- shiny_result$group_results$msi
dashboard_msi <- read.csv(dashboard_msi_path, stringsAsFactors = FALSE)

required_cols <- c("groep_100", "jaar", "msi", "msi_variant")
for (name in required_cols) {
  if (!name %in% names(shiny_msi)) fail("Kolom ontbreekt in Shiny-output: ", name)
  if (!name %in% names(dashboard_msi)) fail("Kolom ontbreekt in dashboard-CSV: ", name)
}

shiny_cmp <- shiny_msi[, required_cols, drop = FALSE]
dashboard_cmp <- dashboard_msi[, required_cols, drop = FALSE]
shiny_cmp$groep_100 <- as.integer(shiny_cmp$groep_100)
dashboard_cmp$groep_100 <- as.integer(dashboard_cmp$groep_100)
shiny_cmp$jaar <- as.integer(shiny_cmp$jaar)
dashboard_cmp$jaar <- as.integer(dashboard_cmp$jaar)
shiny_cmp$msi <- as.numeric(shiny_cmp$msi)
dashboard_cmp$msi <- as.numeric(dashboard_cmp$msi)

shiny_cmp <- shiny_cmp[
  shiny_cmp$jaar >= year_from &
    shiny_cmp$jaar <= year_to &
    shiny_cmp$groep_100 %in% seq(100L, 900L, by = 100L),
  ,
  drop = FALSE
]
dashboard_cmp <- dashboard_cmp[
  dashboard_cmp$jaar >= year_from &
    dashboard_cmp$jaar <= year_to &
    dashboard_cmp$groep_100 %in% seq(100L, 900L, by = 100L),
  ,
  drop = FALSE
]

key <- c("groep_100", "jaar", "msi_variant")
merged <- merge(
  dashboard_cmp,
  shiny_cmp,
  by = key,
  suffixes = c("_dashboard", "_shiny"),
  all = TRUE
)

missing_dashboard <- merged[is.na(merged$msi_dashboard), key, drop = FALSE]
missing_shiny <- merged[is.na(merged$msi_shiny), key, drop = FALSE]
if (nrow(missing_dashboard)) {
  fail("Shiny bevat rijen die ontbreken in dashboard-CSV: ", nrow(missing_dashboard))
}
if (nrow(missing_shiny)) {
  fail("Dashboard-CSV bevat rijen die ontbreken in Shiny-output: ", nrow(missing_shiny))
}

merged$abs_diff <- abs(merged$msi_dashboard - merged$msi_shiny)
max_diff <- max(merged$abs_diff, na.rm = TRUE)
if (!is.finite(max_diff)) {
  fail("Kon MSI-verschil niet berekenen.")
}
if (max_diff > 1e-8) {
  worst <- merged[order(-merged$abs_diff), ][1:5, ]
  print(worst)
  fail("Shiny/dashboard MSI-parity faalt; max verschil: ", signif(max_diff, 6))
}

if (!nrow(shiny_result$species_results$status)) fail("Shiny soortstatus is leeg.")
if (!nrow(shiny_result$species_results$indices)) fail("Shiny soortindices zijn leeg.")
if (!nrow(shiny_result$group_results$trends)) fail("Shiny groepstrends zijn leeg.")

functional_shiny <- shiny_result$functional_group_results$msi
functional_dashboard <- read.csv(functional_dashboard_msi_path, stringsAsFactors = FALSE)
functional_cols <- c("group_code", "jaar", "analysis_mode", "msi_variant", "msi")
for (name in functional_cols) {
  if (!name %in% names(functional_shiny)) fail("Kolom ontbreekt in functionele Shiny-output: ", name)
  if (!name %in% names(functional_dashboard)) fail("Kolom ontbreekt in functionele dashboard-CSV: ", name)
}
functional_shiny <- functional_shiny[, functional_cols, drop = FALSE]
functional_dashboard <- functional_dashboard[, functional_cols, drop = FALSE]
functional_shiny$jaar <- as.integer(functional_shiny$jaar)
functional_dashboard$jaar <- as.integer(functional_dashboard$jaar)
functional_shiny$msi <- as.numeric(functional_shiny$msi)
functional_dashboard$msi <- as.numeric(functional_dashboard$msi)
functional_shiny <- functional_shiny[functional_shiny$jaar >= year_from & functional_shiny$jaar <= year_to, , drop = FALSE]
functional_dashboard <- functional_dashboard[functional_dashboard$jaar >= year_from & functional_dashboard$jaar <= year_to, , drop = FALSE]
functional_key <- c("group_code", "jaar", "analysis_mode", "msi_variant")
functional_merged <- merge(
  functional_dashboard,
  functional_shiny,
  by = functional_key,
  suffixes = c("_dashboard", "_shiny"),
  all = TRUE
)
if (any(is.na(functional_merged$msi_dashboard))) fail("Functionele Shiny-rijen ontbreken in dashboard-CSV.")
if (any(is.na(functional_merged$msi_shiny))) fail("Functionele dashboard-rijen ontbreken in Shiny-output.")
functional_merged$abs_diff <- abs(functional_merged$msi_dashboard - functional_merged$msi_shiny)
functional_max_diff <- max(functional_merged$abs_diff, na.rm = TRUE)
if (!is.finite(functional_max_diff) || functional_max_diff > 1e-8) {
  fail("Functionele Shiny/dashboard MSI-parity faalt; max verschil: ", signif(functional_max_diff, 6))
}

functional_modes <- unique(functional_merged$analysis_mode)
functional_groups <- unique(functional_merged$group_code)
if (!setequal(functional_modes, c("binair", "gewogen"))) fail("Niet beide functionele analysemethoden aanwezig.")
if (length(functional_groups) != 5L) fail("Verwacht vijf functionele groepen, gevonden: ", length(functional_groups))

cat("Shiny/dashboard parity-check OK\n")
cat("Jaren:", year_from, "-", year_to, "\n")
cat("Kavels:", length(selected_kavels), "\n")
cat("Vergelijkingsrijen:", nrow(merged), "\n")
cat("Max MSI verschil:", format(max_diff, scientific = TRUE), "\n")
cat("Functionele vergelijkingsrijen:", nrow(functional_merged), "\n")
cat("Functioneel max MSI verschil:", format(functional_max_diff, scientific = TRUE), "\n")
cat("SQL laden seconden:", unname(load_time[["elapsed"]]), "\n")
cat("Analyse seconden:", unname(analysis_time[["elapsed"]]), "\n")
cat("Cache gebruikt:", loaded$from_cache, "\n")
