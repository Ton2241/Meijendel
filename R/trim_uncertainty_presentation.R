trim_uncertainty_presentation_paths <- function(root) {
  c(
    species = file.path(root, "trim", "soorten", "soorten_trends_met_onzekerheid.csv"),
    groups = file.path(root, "trim_msi_evg", "groepstrends_met_onzekerheid.csv"),
    functional = file.path(root, "trim_msi_evg", "functionele_groepstrends_met_onzekerheid.csv")
  )
}

prepare_trim_uncertainty_rows <- function(rows) {
  variant_rank <- ifelse(grepl("robuust", rows$entity_id, fixed = TRUE), 1L,
    ifelse(grepl("volledig", rows$entity_id, fixed = TRUE), 2L, 3L))
  status_rank <- ifelse(rows$publication_status == "onvoldoende_bootstrap", 2L, 1L)
  rows <- rows[order(status_rank, variant_rank, rows$entity_id, rows$period), , drop = FALSE]
  formal <- rows$publication_status != "onvoldoende_bootstrap" &
    is.finite(rows$ci_low_pct) & is.finite(rows$ci_high_pct)
  rows$display_ci <- NA_character_
  rows$display_ci[formal] <- sprintf("%.2f%% tot %.2f%%", rows$ci_low_pct[formal], rows$ci_high_pct[formal])
  rows$method_note <- ifelse(
    rows$bridge_variant == "niet_van_toepassing",
    "Gestratificeerde clusterbootstrap zonder brug.",
    "Gecombineerde trend via een geschatte gemeenschappelijke-plotbrug van 1981–1983 naar 1986–1988; geen enkel doorlopend TRIM-model."
  )
  rows
}

load_trim_uncertainty_for_presentation <- function(root) {
  manifest_path <- file.path(root, "trim", "bootstrap", "run_manifest.json")
  if (!file.exists(manifest_path)) return(list(status = "descriptive_pending_final_run"))
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  publishable <- identical(as.integer(manifest$analysis_end_year), 2026L) &&
    as.integer(manifest$planned_replicates) >= 2000L &&
    identical(manifest$publication_status, "publiceerbaar")
  if (!publishable) return(list(status = "descriptive_pending_final_run", manifest = manifest))

  paths <- trim_uncertainty_presentation_paths(root)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Publiceerbaar manifest zonder volledige onzekerheidsbestanden: ", paste(names(missing), collapse = ", "), call. = FALSE)
  tables <- lapply(paths, utils::read.csv, stringsAsFactors = FALSE)
  bad_run <- vapply(tables, function(x) !nrow(x) || any(x$run_id != manifest$run_id), logical(1))
  if (any(bad_run)) stop("Onzekerheidsbestand is leeg of heeft een afwijkend run-ID.", call. = FALSE)
  list(
    status = "precomputed_formal",
    manifest = manifest,
    species = prepare_trim_uncertainty_rows(tables$species),
    groups = prepare_trim_uncertainty_rows(tables$groups),
    functional = prepare_trim_uncertainty_rows(tables$functional)
  )
}
