habitat_pipeline_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
  normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
}

.habitat_pipeline_repo <- habitat_pipeline_repo()
source(file.path(
  .habitat_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_vegetatiesamenstelling.R"
))
source(file.path(
  .habitat_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_habitatgericht.R"
))

read_targeted_extract <- function(input_dir) {
  extract <- read_composition_extract(input_dir)
  extract$data$weer_analyse <- read_tsv_required(input_dir, "weer_analyse")
  extract$data$ahn_vegetatiestructuur <- read_tsv_required(input_dir, "ahn_vegetatiestructuur")
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(extract$source_files, `[[`, character(1), "sha256"), collapse = "")
  extract$source_fingerprint_sha256 <- digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  extract
}

targeted_specifications <- function() {
  data.frame(
    analysis_id = c(
      "land_water", "land_riet", "land_open", "land_struweel", "land_boomgroep",
      "land_bos", "ahn_open", "ahn_struweel", "ahn_boomgroep", "ahn_bos"
    ),
    source = c(rep("landbedekking", 6), rep("ahn", 4)),
    group_number = c(100L, 200L, 300L, 600L, 700L, 800L, 300L, 600L, 700L, 800L),
    predictor = c(
      "water_aandeel", "riet_aandeel", "open_aandeel", "struik_aandeel",
      "boomgroep_aandeel", "bos_aandeel", "open_lage_aandeel",
      "aandeel_struweel", "aandeel_bomen", "aandeel_bomen"
    ),
    temporal_cut_year = c(rep(2018L, 6), rep(2018L, 4)),
    expected_direction = 1,
    stringsAsFactors = FALSE
  )
}

build_targeted_state <- function(input_dir) {
  extract <- read_targeted_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)
  weather <- build_weather_covariates(extract$data$weer_analyse)
  landcover <- add_landcover_derived_features(normalize_landcover_supplement(
    extract$data$landbedekking_schmidt_2025, extract$data$plots
  ))
  height <- extract$data$ahn_vegetatiestructuur
  height$open_lage_aandeel <- as.numeric(height$aandeel_open) +
    as.numeric(height$aandeel_lage_vegetatie)
  specs <- targeted_specifications()
  model_population <- populations$effort_1984_2025
  items <- lapply(seq_len(nrow(specs)), function(i) {
    spec <- specs[i, ]
    item <- if (spec$source == "landbedekking") {
      build_targeted_landcover_population(
        model_population, landcover, extract$data$evg_vogel_landschapgroep,
        spec$group_number, spec$predictor
      )
    } else {
      build_ahn_habitat_population(
        model_population, height, extract$data$evg_vogel_landschapgroep,
        spec$group_number, spec$predictor, lag_years = 0L, window_half_width = 2L
      )
    }
    item$data <- add_habitat_controls(item$data, weather)
    item
  })
  names(items) <- specs$analysis_id
  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    specs = specs, populations = populations, weather = weather,
    landcover = landcover, height = height, items = items
  )
}

summarise_targeted_result <- function(spec, fit, validation, effects) {
  spatial <- validation$summary[
    validation$summary$validatie == "ruimte" & validation$summary$status == "geslaagd",
    , drop = FALSE
  ]
  temporal <- validation$summary[
    validation$summary$validatie == "tijd" & validation$summary$status == "geslaagd",
    , drop = FALSE
  ]
  loo <- validation$leave_one_species_out[
    validation$leave_one_species_out$validatie == "tijd", , drop = FALSE
  ]
  within <- effects[effects$term == "habitat_within_z", , drop = FALSE]
  decision <- decide_targeted_model(
    fit$models$basis$status, fit$models$habitat$status,
    if (nrow(within)) within$beta[[1L]] else NA_real_, spec$expected_direction,
    if (nrow(temporal)) temporal$delta_mean_log_score[[1L]] else NA_real_,
    if (nrow(spatial)) mean(spatial$delta_mean_log_score > 0) else NA_real_,
    if (nrow(loo)) min(loo$delta_mean_log_score) else NA_real_
  )
  data.frame(
    analysis_id = spec$analysis_id, bron = spec$source,
    groepsnummer = spec$group_number, predictor = spec$predictor,
    rijen = nrow(fit$data), plots = length(unique(fit$data$plot_id)),
    soorten = length(unique(fit$data$soort_id)), jaren = length(unique(fit$data$jaar)),
    basis_status = fit$models$basis$status, habitat_status = fit$models$habitat$status,
    beta_binnen_plot = if (nrow(within)) within$beta[[1L]] else NA_real_,
    tijd_delta_logscore = if (nrow(temporal)) temporal$delta_mean_log_score[[1L]] else NA_real_,
    ruimte_aandeel_beter = if (nrow(spatial)) mean(spatial$delta_mean_log_score > 0) else NA_real_,
    loo_min_delta_logscore = if (nrow(loo)) min(loo$delta_mean_log_score) else NA_real_,
    besluit = decision$status, reden = decision$reden,
    validatie_geslaagd = sum(validation$summary$status == "geslaagd"),
    validatie_mislukt = sum(validation$summary$status == "mislukt"),
    validatie_niet_uitvoerbaar = sum(
      validation$summary$status == "niet_uitvoerbaar"
    ),
    stringsAsFactors = FALSE
  )
}

targeted_temporal_design_manifest <- function(state) {
  land_years <- sort(unique(state$items$land_water$data$landbedekking_jaar))
  ahn_years <- sort(unique(state$items$ahn_open$data$ahn_jaar))
  designs <- lapply(state$items, function(item) targeted_temporal_design(item$data))
  executable <- vapply(designs, `[[`, logical(1), "uitvoerbaar")
  list(
    status = if (all(executable)) "uitvoerbaar" else if (any(executable)) {
      "gedeeltelijk_uitvoerbaar"
    } else {
      "niet_uitvoerbaar"
    },
    reden = if (all(executable)) "" else paste(unique(vapply(
      designs[!executable], `[[`, character(1), "reden"
    )), collapse = " "),
    landbedekking_meetjaren = as.integer(land_years),
    ahn_meetjaren = as.integer(ahn_years)
  )
}

run_targeted_pipeline <- function(input_dir, run_dir, metadata, compact_results_dir = NULL) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state <- build_targeted_state(input_dir)
  saveRDS(state, file.path(run_dir, "habitatgericht_state.rds"))
  Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = metadata$git_commit)
  checkpoint_dir <- file.path(run_dir, "modellen")
  fits <- validations <- effects <- summaries <- list()
  for (i in seq_len(nrow(state$specs))) {
    spec <- state$specs[i, ]
    id <- spec$analysis_id
    fits[[id]] <- fit_targeted_habitat_pair(state$items[[id]]$data, id, checkpoint_dir)
    effects[[id]] <- extract_targeted_effects(fits[[id]], id)
    validations[[id]] <- run_targeted_validation(
      fits[[id]]$data, id, checkpoint_dir, spec$temporal_cut_year
    )
    summaries[[id]] <- summarise_targeted_result(
      spec, fits[[id]], validations[[id]], effects[[id]]
    )
  }
  outputs <- c(
    samenvatting = write_csv_atomic(do.call(rbind, summaries), file.path(run_dir, "habitatgericht_samenvatting.csv")),
    modellen = write_csv_atomic(do.call(rbind, lapply(fits, `[[`, "comparison")), file.path(run_dir, "habitatgericht_modellen.csv")),
    effecten = write_csv_atomic(do.call(rbind, effects), file.path(run_dir, "habitatgericht_effecten.csv")),
    validatie = write_csv_atomic(do.call(rbind, lapply(validations, `[[`, "summary")), file.path(run_dir, "habitatgericht_validatie.csv")),
    soortgevoeligheid = write_csv_atomic(do.call(rbind, lapply(validations, `[[`, "leave_one_species_out")), file.path(run_dir, "habitatgericht_soortgevoeligheid.csv")),
    weer = write_csv_atomic(state$weather, file.path(run_dir, "habitatgericht_weer.csv")),
    ahn = write_csv_atomic(state$height, file.path(run_dir, "habitatgericht_ahn.csv"))
  )
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = state$source_fingerprint_sha256,
    package_versions = package_versions_for_manifest(),
    specifications = state$specs,
    temporal_validation_design = targeted_temporal_design_manifest(state),
    outputs = lapply(outputs, function(path) list(
      file = basename(path), bytes = unname(file.info(path)$size), sha256 = sha256_file(path)
    ))
  ))
  manifest_path <- file.path(run_dir, "habitatgericht_manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  if (!is.null(compact_results_dir)) {
    for (name in names(outputs)) file.copy(
      outputs[[name]], file.path(compact_results_dir, paste0("habitatgericht_laatste_", name, ".csv")),
      overwrite = TRUE
    )
    file.copy(manifest_path, file.path(compact_results_dir, "habitatgericht_laatste_manifest.json"), overwrite = TRUE)
  }
  manifest_path
}

reclassify_two_snapshot_temporal_results <- function(run_dir, compact_results_dir = NULL) {
  state_path <- file.path(run_dir, "habitatgericht_state.rds")
  validation_path <- file.path(run_dir, "habitatgericht_validatie.csv")
  summary_path <- file.path(run_dir, "habitatgericht_samenvatting.csv")
  loo_path <- file.path(run_dir, "habitatgericht_soortgevoeligheid.csv")
  manifest_path <- file.path(run_dir, "habitatgericht_manifest.json")
  stopifnot(file.exists(state_path), file.exists(validation_path), file.exists(summary_path))
  state <- readRDS(state_path)
  validation <- utils::read.csv(validation_path, check.names = FALSE)
  summary <- utils::read.csv(summary_path, check.names = FALSE)
  reasons <- setNames(vapply(names(state$items), function(id) {
    targeted_temporal_design(state$items[[id]]$data)$reden
  }, character(1)), names(state$items))
  temporal <- validation$validatie == "tijd"
  validation$status[temporal] <- "niet_uitvoerbaar"
  validation$fout[temporal] <- unname(reasons[validation$blok[temporal]])
  for (id in summary$analysis_id) {
    rows <- validation$blok == id
    summary$validatie_geslaagd[summary$analysis_id == id] <- sum(
      validation$status[rows] == "geslaagd"
    )
    summary$validatie_mislukt[summary$analysis_id == id] <- sum(
      validation$status[rows] == "mislukt"
    )
  }
  summary$validatie_niet_uitvoerbaar <- vapply(summary$analysis_id, function(id) {
    sum(validation$status[validation$blok == id] == "niet_uitvoerbaar")
  }, integer(1))
  summary$tijd_delta_logscore <- NA_real_
  summary$loo_min_delta_logscore <- NA_real_
  for (id in summary$analysis_id) {
    row <- summary$analysis_id == id
    spec_row <- state$specs[state$specs$analysis_id == id, , drop = FALSE]
    decision <- decide_targeted_model(
      summary$basis_status[row], summary$habitat_status[row],
      summary$beta_binnen_plot[row], spec_row$expected_direction[[1L]],
      NA_real_, summary$ruimte_aandeel_beter[row], NA_real_
    )
    summary$besluit[row] <- decision$status
    summary$reden[row] <- decision$reden
  }
  write_csv_atomic(validation, validation_path)
  write_csv_atomic(summary, summary_path)
  if (file.exists(loo_path)) {
    loo <- utils::read.csv(loo_path, check.names = FALSE)
    if (nrow(loo)) loo <- loo[loo$validatie != "tijd", , drop = FALSE]
    write_csv_atomic(loo, loo_path)
  }
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$temporal_validation_design <- targeted_temporal_design_manifest(state)
  for (name in names(manifest$outputs)) {
    path <- file.path(run_dir, manifest$outputs[[name]]$file)
    manifest$outputs[[name]]$bytes <- unname(file.info(path)$size)
    manifest$outputs[[name]]$sha256 <- sha256_file(path)
  }
  jsonlite::write_json(
    manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE,
    null = "null", digits = NA
  )
  if (!is.null(compact_results_dir)) {
    for (name in names(manifest$outputs)) {
      source <- file.path(run_dir, manifest$outputs[[name]]$file)
      file.copy(
        source,
        file.path(compact_results_dir, paste0("habitatgericht_laatste_", name, ".csv")),
        overwrite = TRUE
      )
    }
    file.copy(
      manifest_path,
      file.path(compact_results_dir, "habitatgericht_laatste_manifest.json"),
      overwrite = TRUE
    )
  }
  invisible(manifest_path)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) != 7L) stop("Zeven argumenten vereist.", call. = FALSE)
  path <- run_targeted_pipeline(
    cli[[1L]], cli[[2L]],
    list(run_id = cli[[3L]], git_commit = cli[[4L]], reporting_commit = cli[[4L]],
         database_name = cli[[5L]], mysql_version = cli[[6L]]),
    cli[[7L]]
  )
  cat(path, "\n", sep = "")
}
