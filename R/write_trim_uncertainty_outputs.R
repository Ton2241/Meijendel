trim_uncertainty_required_columns <- function() {
  c(
    "entity_type", "entity_id", "period", "method", "estimate_pct_per_year",
    "se_pct", "ci_low_pct", "ci_high_pct", "p_value", "interval_method",
    "planned_replicates", "valid_replicates", "valid_fraction",
    "publication_status", "bridge_variant", "bridge_status", "coverage_status",
    "run_id"
  )
}

validate_trim_uncertainty_table <- function(data, run_id, label) {
  missing <- setdiff(trim_uncertainty_required_columns(), names(data))
  if (length(missing)) stop(label, " mist kolommen: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  key <- data[, c("entity_type", "entity_id", "period", "bridge_variant"), drop = FALSE]
  if (anyDuplicated(key)) stop(label, " bevat dubbele entiteit-periode-variantregels.", call. = FALSE)
  if (any(data$run_id != run_id)) stop(label, " bevat een afwijkend run-ID.", call. = FALSE)
  formal <- data$publication_status != "onvoldoende_bootstrap"
  if (any(formal & (!is.finite(data$estimate_pct_per_year) | !is.finite(data$ci_low_pct) | !is.finite(data$ci_high_pct)))) {
    stop(label, " bevat niet-eindige formele schattingen of grenzen.", call. = FALSE)
  }
  if (any(data$ci_low_pct > data$estimate_pct_per_year, na.rm = TRUE) || any(data$ci_high_pct < data$estimate_pct_per_year, na.rm = TRUE)) {
    stop(label, " bevat een puntschatting buiten het interval.", call. = FALSE)
  }
  insufficient <- data$publication_status == "onvoldoende_bootstrap"
  if (any(insufficient & (is.finite(data$ci_low_pct) | is.finite(data$ci_high_pct)))) {
    stop(label, " publiceert grenzen bij onvoldoende bootstrap.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_canonical_trim_manifest <- function(manifest) {
  if (!identical(as.integer(manifest$analysis_end_year), 2026L)) stop("Canonieke activatie vereist eindjaar 2026.", call. = FALSE)
  if (as.integer(manifest$planned_replicates) < 2000L) stop("Canonieke activatie vereist minimaal 2.000 replicaties.", call. = FALSE)
  if (!identical(manifest$publication_status, "publiceerbaar")) stop("Canonieke activatie vereist publicatiestatus publiceerbaar.", call. = FALSE)
  invisible(TRUE)
}

write_trim_uncertainty_outputs <- function(bundle, manifest, output_root, mode = c("fixture", "canonical")) {
  mode <- match.arg(mode)
  required_bundle <- c(
    "species_trends", "species_bridges", "bridge_sensitivity", "historical_core_sensitivity",
    "group_trends", "functional_group_trends", "sandra_species_trends", "sandra_group_trends", "diagnostics"
  )
  missing <- setdiff(required_bundle, names(bundle))
  if (length(missing)) stop("Uitvoerbundle mist: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  if (mode == "canonical") validate_canonical_trim_manifest(manifest)
  run_id <- manifest$run_id
  trend_names <- c("species_trends", "species_bridges", "group_trends", "functional_group_trends", "sandra_species_trends", "sandra_group_trends")
  for (name in trend_names) validate_trim_uncertainty_table(bundle[[name]], run_id, name)
  for (name in c("bridge_sensitivity", "historical_core_sensitivity")) {
    data <- bundle[[name]]
    if (!all(c("envelope_type", "run_id") %in% names(data)) || any(data$envelope_type != "gevoeligheidsenvelop_geen_bi")) {
      stop(name, " mist het verplichte gevoeligheidsenveloplabel.", call. = FALSE)
    }
    if (any(data$run_id != run_id)) stop(name, " bevat een afwijkend run-ID.", call. = FALSE)
  }

  output_root <- normalizePath(dirname(output_root), winslash = "/", mustWork = TRUE) |> file.path(basename(output_root))
  if (file.exists(output_root)) stop("Doelmap bestaat al; atomische schrijver overschrijft niet.", call. = FALSE)
  staging <- paste0(output_root, ".partial-", Sys.getpid())
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  paths <- c(
    species_trends = "trim/soorten/soorten_trends_met_onzekerheid.csv",
    species_bridges = "trim/soorten/soorten_brugfactoren_met_onzekerheid.csv",
    bridge_sensitivity = "trim/soorten/brugvenstergevoeligheid.csv",
    historical_core_sensitivity = "trim/soorten/historische_kerngevoeligheid.csv",
    group_trends = "trim_msi_evg/groepstrends_met_onzekerheid.csv",
    functional_group_trends = "trim_msi_evg/functionele_groepstrends_met_onzekerheid.csv",
    sandra_species_trends = "trim/sandra/soorten/soorten_trends_met_onzekerheid.csv",
    sandra_group_trends = "trim/sandra/trim_msi_evg/groepstrends_met_onzekerheid.csv",
    diagnostics = "trim/bootstrap/diagnostiek.csv"
  )
  for (name in names(paths)) {
    path <- file.path(staging, paths[[name]])
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(bundle[[name]], path, row.names = FALSE, na = "")
  }
  manifest_path <- file.path(staging, "trim", "bootstrap", "run_manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
  if (!file.rename(staging, output_root)) stop("Atomische promotie van onzekerheidsuitvoer mislukt.", call. = FALSE)
  invisible(output_root)
}
