environment_pipeline_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
  normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
}

.environment_pipeline_repo <- environment_pipeline_repo()
source(file.path(
  .environment_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_teller_model.R"
))
source(file.path(
  .environment_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_omgeving.R"
))

read_environment_extract <- function(input_dir) {
  extract <- read_teller_extract(input_dir)
  for (name in c(
    "weer_analyse", "plot_jaar_stikstof", "plot_jaar_landgebruik",
    "evg_vogelgroepen", "evg_vogel_landschapgroep",
    "functional_group_definition", "functional_group_membership"
  )) {
    path <- file.path(input_dir, paste0(name, ".tsv"))
    if (!file.exists(path)) stop("Extract mist bestand: ", basename(path), ".", call. = FALSE)
    extract$data[[name]] <- utils::read.delim(
      path, header = TRUE, sep = "\t", na.strings = "NULL", quote = "",
      comment.char = "", check.names = FALSE, stringsAsFactors = FALSE
    )
  }
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(extract$source_files, `[[`, character(1), "sha256"), collapse = "")
  extract$source_fingerprint_sha256 <- digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  extract
}

environment_specifications <- function() {
  list(
    stikstof = list(
      fields = "stikstof_mean", source = "stikstof", lag = 0L,
      train_end = 2018L, test_start = 2019L
    ),
    land_open = list(
      fields = "land_open_pct", source = "landgebruik", lag = 0L,
      train_end = 2015L, test_start = 2017L
    ),
    land_bos = list(
      fields = "land_bos_pct", source = "landgebruik", lag = 0L,
      train_end = 2015L, test_start = 2017L
    ),
    land_water = list(
      fields = "land_water_pct", source = "landgebruik", lag = 0L,
      train_end = 2015L, test_start = 2017L
    ),
    land_gecombineerd = list(
      fields = c("land_open_pct", "land_bos_pct", "land_water_pct"),
      source = "landgebruik", lag = 0L, train_end = 2015L, test_start = 2017L
    ),
    stikstof_en_land = list(
      fields = c("stikstof_mean", "land_open_pct", "land_bos_pct", "land_water_pct"),
      source = "gecombineerd", lag = 0L, train_end = 2015L, test_start = 2017L
    )
  )
}

normalize_environment_groups <- function(data) {
  evg_def <- data$evg_vogelgroepen
  evg_mem <- data$evg_vogel_landschapgroep
  broad <- c(100L, 200L, 300L, 400L, 500L, 600L, 700L, 800L)
  evg_def <- evg_def[as.integer(evg_def$groepsnummer) %in% broad, , drop = FALSE]
  evg_mem <- evg_mem[as.integer(evg_mem$groepsnummer) %in% broad, , drop = FALSE]
  definitions <- data.frame(
    groep_type = "ecologisch", groep_id = as.character(evg_def$groepsnummer),
    groep_naam = evg_def$landschap_groep, stringsAsFactors = FALSE
  )
  memberships <- data.frame(
    groep_type = "ecologisch", groep_id = as.character(evg_mem$groepsnummer),
    soort_id = as.integer(evg_mem$vogel_id), gewicht = 1,
    stringsAsFactors = FALSE
  )
  fg_def <- data$functional_group_definition
  fg_def <- fg_def[fg_def$status == "approved", , drop = FALSE]
  fg_mem <- data$functional_group_membership
  fg_mem <- fg_mem[
    as.integer(fg_mem$functional_group_definition_id) %in% as.integer(fg_def$id) &
      fg_mem$classification %in% c("primary", "secondary") &
      as.numeric(fg_mem$membership_weight) > 0,
    , drop = FALSE
  ]
  definitions <- rbind(definitions, data.frame(
    groep_type = "functioneel", groep_id = as.character(fg_def$id),
    groep_naam = fg_def$naam_nl, stringsAsFactors = FALSE
  ))
  memberships <- rbind(memberships, data.frame(
    groep_type = "functioneel",
    groep_id = as.character(fg_mem$functional_group_definition_id),
    soort_id = as.integer(fg_mem$soort_id),
    gewicht = as.numeric(fg_mem$membership_weight), stringsAsFactors = FALSE
  ))
  list(definitions = definitions, memberships = memberships)
}

build_environment_state <- function(input_dir) {
  extract <- read_environment_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)
  weather <- build_weather_covariates(extract$data$weer_analyse)
  nitrogen <- prepare_nitrogen_features(extract$data$plot_jaar_stikstof)
  landuse <- harmonize_cbs_landuse(extract$data$plot_jaar_landgebruik)
  combined <- merge(
    nitrogen[c("plot_id", "jaar", "stikstof_mean")],
    landuse[c("plot_id", "jaar", names(environment_predictor_groups()))],
    by = c("plot_id", "jaar"), all = FALSE, sort = FALSE
  )
  sources <- list(stikstof = nitrogen, landgebruik = landuse, gecombineerd = combined)
  specs <- environment_specifications()
  items <- lapply(names(specs), function(id) {
    spec <- specs[[id]]
    item <- build_environment_population(
      populations$effort_1984_2025, sources[[spec$source]], spec$fields, spec$lag
    )
    item$data <- add_habitat_controls(item$data, weather)
    item
  })
  names(items) <- names(specs)
  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    specs = specs, items = items, weather = weather, nitrogen = nitrogen,
    landuse = landuse, combined = combined,
    groups = normalize_environment_groups(extract$data)
  )
}

summarise_environment_result <- function(id, spec, fit, validation) {
  spatial <- validation[validation$validatie == "ruimte" & validation$status == "geslaagd", , drop = FALSE]
  temporal <- validation[validation$validatie == "tijd" & validation$status == "geslaagd", , drop = FALSE]
  numerical <- all(vapply(fit$models, function(x) identical(x$status, "geslaagd"), logical(1)))
  spatial_share <- if (nrow(spatial)) mean(spatial$delta_mean_log_score > 0) else NA_real_
  temporal_delta <- if (nrow(temporal)) temporal$delta_mean_log_score[[1L]] else NA_real_
  predictive <- numerical && is.finite(spatial_share) && spatial_share >= 0.6 &&
    is.finite(temporal_delta) && temporal_delta > 0
  data.frame(
    analysis_id = id, bron = spec$source, predictors = paste(spec$fields, collapse = ";"),
    rijen = nrow(fit$data), plotjaren = length(unique(paste(fit$data$plot_id, fit$data$jaar))),
    plots = length(unique(fit$data$plot_id)), soorten = length(unique(fit$data$soort_id)),
    eerste_jaar = min(fit$data$jaar), laatste_jaar = max(fit$data$jaar),
    basis_status = fit$models$basis$status, omgeving_status = fit$models$omgeving$status,
    ruimte_geldige_blokken = nrow(spatial), ruimte_aandeel_beter = spatial_share,
    tijd_status = if (nrow(temporal)) "geslaagd" else validation$status[validation$validatie == "tijd"][[1L]],
    tijd_delta_logscore = temporal_delta,
    besluit = if (predictive) "voorspellende_meerwaarde" else "geen_bestendige_voorspellende_meerwaarde",
    stringsAsFactors = FALSE
  )
}

write_environment_manifest <- function(path, metadata, state, outputs) {
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = state$source_fingerprint_sha256,
    tables = state$extract_metadata,
    package_versions = package_versions_for_manifest(),
    specifications = state$specs,
    landgebruik_uitgesloten_jaren = attr(state$landuse, "uitgesloten_jaren"),
    outputs = lapply(outputs, function(output_path) list(
      file = basename(output_path), bytes = unname(file.info(output_path)$size),
      sha256 = sha256_file(output_path)
    ))
  ))
  jsonlite::write_json(
    manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA
  )
  path
}

run_environment_pipeline <- function(input_dir, run_dir, metadata, compact_results_dir = NULL) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state <- build_environment_state(input_dir)
  saveRDS(state, file.path(run_dir, "omgeving_state.rds"))
  Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = metadata$git_commit)
  checkpoint_dir <- file.path(run_dir, "modellen")
  fits <- validations <- effects <- species <- groups <- summaries <- list()
  for (id in names(state$specs)) {
    spec <- state$specs[[id]]
    fits[[id]] <- fit_environment_pair(
      state$items[[id]]$data, id, spec$fields, id, checkpoint_dir
    )
    effects[[id]] <- extract_environment_effects(fits[[id]], id)
    species[[id]] <- extract_environment_species_effects(
      fits[[id]], id, state$items[[id]]$data
    )
    groups[[id]] <- summarise_environment_group_effects(
      species[[id]], state$groups$memberships, state$groups$definitions
    )
    validations[[id]] <- run_environment_validation(
      fits[[id]]$data, id, spec$fields, id, checkpoint_dir,
      spec$train_end, spec$test_start
    )
    summaries[[id]] <- summarise_environment_result(
      id, spec, fits[[id]], validations[[id]]
    )
  }
  bind_nonempty <- function(items) {
    items <- items[vapply(items, nrow, integer(1)) > 0L]
    if (!length(items)) return(data.frame())
    do.call(rbind, items)
  }
  coverage <- do.call(rbind, lapply(names(state$items), function(id) {
    data <- state$items[[id]]$data
    data.frame(
      analysis_id = id, rijen = nrow(data),
      plotjaren = length(unique(paste(data$plot_id, data$jaar))),
      plots = length(unique(data$plot_id)), soorten = length(unique(data$soort_id)),
      eerste_jaar = min(data$jaar), laatste_jaar = max(data$jaar),
      row_hash = state$items[[id]]$row_hash, stringsAsFactors = FALSE
    )
  }))
  outputs <- c(
    samenvatting = write_csv_atomic(do.call(rbind, summaries), file.path(run_dir, "omgeving_samenvatting.csv")),
    dekking = write_csv_atomic(coverage, file.path(run_dir, "omgeving_dekking.csv")),
    modellen = write_csv_atomic(do.call(rbind, lapply(fits, `[[`, "comparison")), file.path(run_dir, "omgeving_modellen.csv")),
    effecten = write_csv_atomic(bind_nonempty(effects), file.path(run_dir, "omgeving_effecten.csv")),
    soorten = write_csv_atomic(bind_nonempty(species), file.path(run_dir, "omgeving_soorten.csv")),
    groepen = write_csv_atomic(bind_nonempty(groups), file.path(run_dir, "omgeving_groepen.csv")),
    validatie = write_csv_atomic(do.call(rbind, validations), file.path(run_dir, "omgeving_validatie.csv")),
    stikstof = write_csv_atomic(state$nitrogen, file.path(run_dir, "omgeving_stikstof.csv")),
    landgebruik = write_csv_atomic(state$landuse, file.path(run_dir, "omgeving_landgebruik.csv"))
  )
  manifest_path <- file.path(run_dir, "omgeving_manifest.json")
  write_environment_manifest(manifest_path, metadata, state, outputs)
  if (!is.null(compact_results_dir)) {
    for (name in names(outputs)) file.copy(
      outputs[[name]], file.path(compact_results_dir, paste0("omgeving_laatste_", name, ".csv")),
      overwrite = TRUE
    )
    file.copy(
      manifest_path, file.path(compact_results_dir, "omgeving_laatste_manifest.json"),
      overwrite = TRUE
    )
  }
  manifest_path
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) != 7L) stop("Zeven argumenten vereist.", call. = FALSE)
  path <- run_environment_pipeline(
    cli[[1L]], cli[[2L]],
    list(
      run_id = cli[[3L]], git_commit = cli[[4L]], reporting_commit = cli[[4L]],
      database_name = cli[[5L]], mysql_version = cli[[6L]]
    ),
    cli[[7L]]
  )
  cat(path, "\n", sep = "")
}
