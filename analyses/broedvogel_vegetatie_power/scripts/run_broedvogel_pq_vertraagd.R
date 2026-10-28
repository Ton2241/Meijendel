delayed_pipeline_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
  normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
}

.delayed_pipeline_repo <- delayed_pipeline_repo()
source(file.path(
  .delayed_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_teller_model.R"
))
source(file.path(
  .delayed_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_pq_vertraagd.R"
))

read_delayed_tsv <- function(input_dir, name) {
  path <- file.path(input_dir, paste0(name, ".tsv"))
  if (!file.exists(path)) stop("Extract mist bestand: ", basename(path), call. = FALSE)
  utils::read.delim(
    path, header = TRUE, sep = "\t", na.strings = "NULL", quote = "",
    comment.char = "", check.names = FALSE, stringsAsFactors = FALSE
  )
}

read_delayed_extract <- function(input_dir) {
  extract <- read_teller_extract(input_dir)
  for (name in c(
    "evg_vogel_landschapgroep", "functional_group_definition",
    "functional_group_membership", "weer_analyse"
  )) {
    extract$data[[name]] <- read_delayed_tsv(input_dir, name)
  }
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(
    extract$source_files, `[[`, character(1), "sha256"
  ), collapse = "")
  extract$source_fingerprint_sha256 <- digest::digest(
    fingerprint, algo = "sha256", serialize = FALSE
  )
  extract
}

normalize_delayed_groups <- function(data) {
  ecological <- data$evg_vogel_landschapgroep
  ecological <- ecological[
    as.integer(ecological$groepsnummer) %in% c(100L, 200L, 300L, 600L, 700L, 800L),
    , drop = FALSE
  ]
  ecological <- data.frame(
    group_type = "ecologisch", group_id = as.character(ecological$groepsnummer),
    soort_id = as.integer(ecological$vogel_id), stringsAsFactors = FALSE
  )
  definitions <- data$functional_group_definition
  definitions <- definitions[definitions$status == "approved", , drop = FALSE]
  functional <- data$functional_group_membership
  functional <- functional[
    as.integer(functional$functional_group_definition_id) %in% as.integer(definitions$id) &
      functional$classification %in% c("primary", "secondary") &
      as.numeric(functional$membership_weight) > 0,
    , drop = FALSE
  ]
  functional <- data.frame(
    group_type = "functioneel",
    group_id = as.character(functional$functional_group_definition_id),
    soort_id = as.integer(functional$soort_id), stringsAsFactors = FALSE
  )
  out <- unique(rbind(ecological, functional))
  out[order(out$group_type, out$group_id, out$soort_id), , drop = FALSE]
}

read_gradient_intervals <- function(path) {
  if (!file.exists(path)) stop("PQ-gradientintervallen ontbreken: ", path, call. = FALSE)
  data <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  require_delayed_fields(
    data,
    c("plot_id", "start_year", "end_year", "interval_years",
      paste0(pq_gradient_names(), "_change_per_year")),
    "PQ-gradientintervallen"
  )
  data
}

build_delayed_pipeline_state <- function(input_dir, gradient_path) {
  extract <- read_delayed_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)
  weather <- build_weather_covariates(extract$data$weer_analyse)
  birds <- populations$effort_1984_2025
  birds <- birds[!birds$soort_id %in% pq_response_exclusions()$soort_id, , drop = FALSE]
  birds <- add_habitat_controls(birds, weather)
  intervals <- read_gradient_intervals(gradient_path)
  assigned <- assign_latest_pq_interval(birds, intervals, 15L)
  groups <- normalize_delayed_groups(extract$data)
  specs <- pq_delayed_relation_specifications()
  items <- lapply(seq_len(nrow(specs)), function(i) {
    build_delayed_relation_population(assigned, specs[i, , drop = FALSE], groups)
  })
  names(items) <- specs$analysis_id
  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    gradient_file = list(
      file = basename(gradient_path), sha256 = sha256_file(gradient_path),
      rows = nrow(intervals)
    ),
    specifications = specs, groups = groups, intervals = intervals,
    weather = weather, assigned = assigned, items = items
  )
}

delayed_relation_coverage <- function(
    data, specification, threshold = NA_real_, selected_events = 0L) {
  data.frame(
    analysis_id = specification$analysis_id,
    relation_type = specification$relation_type,
    group_type = specification$group_type,
    group_id = specification$group_id,
    group_name = specification$group_name,
    gradient = specification$gradient,
    plotyears = nrow(data),
    plots = length(unique(data$plot_id)),
    species_in_group = if (nrow(data)) max(data$n_species) else 0L,
    intervals = length(unique(data$event_id)),
    first_response_year = if (nrow(data)) min(data$jaar) else NA_integer_,
    last_response_year = if (nrow(data)) max(data$jaar) else NA_integer_,
    maximum_lag = if (nrow(data)) max(data$lag_years) else NA_integer_,
    large_change_threshold_pp = threshold,
    selected_large_events = as.integer(selected_events),
    row_hash = if (nrow(data)) row_set_sha256(data$row_id) else NA_character_,
    stringsAsFactors = FALSE
  )
}

delayed_modelability <- function(data, response_type) {
  checks <- c(
    minimaal_50_plotjaren = nrow(data) >= 50L,
    minimaal_10_plots = length(unique(data$plot_id)) >= 10L,
    minimaal_10_jaren = length(unique(data$jaar)) >= 10L,
    verandering_varieert = length(unique(data$change_pp[is.finite(data$change_pp)])) >= 5L,
    respons_varieert = if (response_type == "territoria") {
      length(unique(data$total_count)) >= 2L
    } else {
      length(unique(data$richness / data$n_species)) >= 2L
    }
  )
  list(
    executable = all(checks), checks = checks,
    reason = paste(names(checks)[!checks], collapse = "; ")
  )
}

summarise_delayed_result <- function(
    specification, response_type, model_statuses, validation,
    modelability = list(executable = TRUE, reason = "")) {
  if (!isTRUE(modelability$executable)) {
    return(data.frame(
      analysis_id = specification$analysis_id, response_type = response_type,
      relation_type = specification$relation_type, group_name = specification$group_name,
      gradient = specification$gradient, basis_status = "niet_uitvoerbaar",
      lineair_status = "niet_uitvoerbaar", niet_lineair_status = "niet_uitvoerbaar",
      valid_spatial_folds = 0L, spatial_share_better_than_base = NA_real_,
      spatial_share_better_than_linear = NA_real_, temporal_status = "niet_uitvoerbaar",
      temporal_delta_vs_base = NA_real_, temporal_delta_vs_linear = NA_real_,
      decision = "niet_uitvoerbaar", reason = modelability$reason,
      stringsAsFactors = FALSE
    ))
  }
  decision <- decide_delayed_predictive_value(validation)
  spatial <- validation[
    validation$validation_type == "ruimte" & validation$status == "geslaagd",
    , drop = FALSE
  ]
  temporal <- validation[validation$validation_type == "tijd", , drop = FALSE]
  numerical <- all(model_statuses == "geslaagd")
  final_decision <- if (numerical) decision$decision else "geen_geldige_modelvergelijking"
  reason <- paste(c(
    if (!numerical) paste(names(model_statuses)[model_statuses != "geslaagd"], collapse = "; "),
    decision$reason
  )[nzchar(c(
    if (!numerical) paste(names(model_statuses)[model_statuses != "geslaagd"], collapse = "; ") else "",
    decision$reason
  ))], collapse = "; ")
  data.frame(
    analysis_id = specification$analysis_id, response_type = response_type,
    relation_type = specification$relation_type, group_name = specification$group_name,
    gradient = specification$gradient,
    basis_status = unname(model_statuses[["basis"]]),
    lineair_status = unname(model_statuses[["lineair"]]),
    niet_lineair_status = unname(model_statuses[["niet_lineair"]]),
    valid_spatial_folds = nrow(spatial),
    spatial_share_better_than_base = decision$spatial_share_better_than_base,
    spatial_share_better_than_linear = decision$spatial_share_better_than_linear,
    temporal_status = if (nrow(temporal)) temporal$status[[1L]] else "niet_uitvoerbaar",
    temporal_delta_vs_base = decision$temporal_delta_vs_base,
    temporal_delta_vs_linear = decision$temporal_delta_vs_linear,
    decision = final_decision, reason = reason, stringsAsFactors = FALSE
  )
}

bind_delayed_rows <- function(items) {
  items <- items[vapply(items, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(items)) return(data.frame())
  do.call(rbind, items)
}

empty_delayed_model_rows <- function(specification, response_type, reason) {
  models <- data.frame(
    analysis_id = specification$analysis_id, response_type = response_type,
    model_name = c("basis", "lineair", "niet_lineair"),
    status = "niet_uitvoerbaar", n = NA_integer_, row_hash = NA_character_,
    pdHess = NA, family = NA_character_, elapsed_seconds = NA_real_,
    logLik = NA_real_, AIC = NA_real_, BIC = NA_real_, warning = reason,
    error = reason, stringsAsFactors = FALSE
  )
  validation <- delayed_validation_failure(
    "ruimte", "geen", specification$analysis_id, response_type,
    data.frame(), data.frame(), reason, "niet_uitvoerbaar"
  )
  list(models = models, validation = validation)
}

write_delayed_manifest <- function(path, metadata, state, outputs) {
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = state$source_fingerprint_sha256,
    tables = state$extract_metadata,
    gradient_file = state$gradient_file,
    package_versions = package_versions_for_manifest(),
    response_exclusions = pq_response_exclusions(),
    interval_assignment = paste(
      "ieder vogelplotjaar hoogstens eenmaal; meest recente voorafgaande",
      "geldige PQ-verandering; maximaal 15 jaar"
    ),
    model_comparison = c("basis", "lineair_vertraagd", "begrensd_kwadratisch_niet_lineair"),
    validation = list(spatial_folds = 5L, temporal_test_from = 2018L),
    large_event_rule = list(
      threshold = "75e percentiel van absolute niet-nul verandering per relatie",
      window = "-3 tot en met +15 jaar; geen overlappende vogelplotjaren"
    ),
    specifications = state$specifications,
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

run_delayed_pipeline <- function(
    input_dir = NULL, gradient_path = NULL, run_dir, metadata,
    compact_results_dir = NULL, resume = FALSE, simulations = 1000L) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state_path <- file.path(run_dir, "pq_vertraagd_state.rds")
  if (isTRUE(resume)) {
    if (!file.exists(state_path)) stop("Hervatten kan niet: statebestand ontbreekt.", call. = FALSE)
    state <- readRDS(state_path)
  } else {
    if (is.null(input_dir) || is.null(gradient_path)) {
      stop("Nieuwe run vereist extractmap en gradientintervallen.", call. = FALSE)
    }
    state <- build_delayed_pipeline_state(input_dir, gradient_path)
    state$run_metadata <- metadata
    saveRDS(state, state_path)
  }
  Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = metadata$git_commit)
  checkpoint_dir <- file.path(run_dir, "modellen")
  model_rows <- validation_rows <- summaries <- curves <- effect_summaries <- list()
  cumulatives <- event_rows <- event_curves <- coverages <- list()
  for (i in seq_len(nrow(state$specifications))) {
    specification <- state$specifications[i, , drop = FALSE]
    id <- specification$analysis_id[[1L]]
    data <- state$items[[id]]
    event_for_coverage <- build_large_event_analysis(data, id, "territoria")
    coverages[[id]] <- delayed_relation_coverage(
      data, specification, event_for_coverage$threshold,
      nrow(event_for_coverage$events)
    )
    for (response_type in c("territoria", "aanwezigheid")) {
      key <- paste(id, response_type, sep = "__")
      modelability <- delayed_modelability(data, response_type)
      if (!modelability$executable) {
        empty <- empty_delayed_model_rows(specification, response_type, modelability$reason)
        model_rows[[key]] <- empty$models
        validation_rows[[key]] <- empty$validation
        summaries[[key]] <- summarise_delayed_result(
          specification, response_type, c(
            basis = "niet_uitvoerbaar", lineair = "niet_uitvoerbaar",
            niet_lineair = "niet_uitvoerbaar"
          ), empty$validation, modelability
        )
        next
      }
      fit <- fit_delayed_model_set(data, response_type, id, checkpoint_dir)
      validation <- run_delayed_blocked_validation(
        fit$data, response_type, id, checkpoint_dir
      )
      effects <- extract_delayed_effects(
        fit, id, response_type, simulations = simulations
      )
      events <- build_large_event_analysis(fit$data, id, response_type)
      statuses <- vapply(fit$models, `[[`, character(1), "status")
      model_rows[[key]] <- fit$comparison
      validation_rows[[key]] <- validation
      summaries[[key]] <- summarise_delayed_result(
        specification, response_type, statuses, validation, modelability
      )
      curves[[key]] <- effects$curve
      effect_summaries[[key]] <- effects$summary
      cumulatives[[key]] <- effects$cumulative
      event_rows[[key]] <- events$events
      event_curves[[key]] <- events$curve
    }
  }
  outputs <- c(
    samenvatting = write_csv_atomic(bind_delayed_rows(summaries), file.path(run_dir, "pq_vertraagd_samenvatting.csv")),
    dekking = write_csv_atomic(bind_delayed_rows(coverages), file.path(run_dir, "pq_vertraagd_dekking.csv")),
    modellen = write_csv_atomic(bind_delayed_rows(model_rows), file.path(run_dir, "pq_vertraagd_modellen.csv")),
    validatie = write_csv_atomic(bind_delayed_rows(validation_rows), file.path(run_dir, "pq_vertraagd_validatie.csv")),
    effectcurve = write_csv_atomic(bind_delayed_rows(curves), file.path(run_dir, "pq_vertraagd_effectcurve.csv")),
    effecten = write_csv_atomic(bind_delayed_rows(effect_summaries), file.path(run_dir, "pq_vertraagd_effecten.csv")),
    cumulatief = write_csv_atomic(bind_delayed_rows(cumulatives), file.path(run_dir, "pq_vertraagd_cumulatief.csv")),
    gebeurtenissen = write_csv_atomic(bind_delayed_rows(event_rows), file.path(run_dir, "pq_vertraagd_gebeurtenissen.csv")),
    gebeurteniscurve = write_csv_atomic(bind_delayed_rows(event_curves), file.path(run_dir, "pq_vertraagd_gebeurteniscurve.csv"))
  )
  manifest_path <- file.path(run_dir, "pq_vertraagd_manifest.json")
  write_delayed_manifest(manifest_path, metadata, state, outputs)
  if (!is.null(compact_results_dir)) {
    dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
    for (name in names(outputs)) {
      file.copy(
        outputs[[name]],
        file.path(compact_results_dir, paste0("pq_vertraagd_laatste_", name, ".csv")),
        overwrite = TRUE
      )
    }
    file.copy(
      manifest_path,
      file.path(compact_results_dir, "pq_vertraagd_laatste_manifest.json"),
      overwrite = TRUE
    )
  }
  list(manifest_path = manifest_path, outputs = outputs)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (!length(cli) || !cli[[1L]] %in% c("new", "resume")) {
    stop("Gebruik: new INPUT_DIR GRADIENT_CSV RUN_DIR RUN_ID GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR; of resume RUN_DIR RESULT_DIR", call. = FALSE)
  }
  if (cli[[1L]] == "new") {
    if (length(cli) != 9L) stop("Nieuwe run: negen argumenten vereist.", call. = FALSE)
    result <- run_delayed_pipeline(
      input_dir = cli[[2L]], gradient_path = cli[[3L]], run_dir = cli[[4L]],
      metadata = list(
        run_id = cli[[5L]], git_commit = cli[[6L]], database_name = cli[[7L]],
        mysql_version = cli[[8L]]
      ), compact_results_dir = cli[[9L]]
    )
  } else {
    if (length(cli) != 3L) stop("Hervatten vereist runmap en resultaatmap.", call. = FALSE)
    state <- readRDS(file.path(cli[[2L]], "pq_vertraagd_state.rds"))
    metadata <- state$run_metadata
    current_commit <- trimws(system2(
      "git", c("-C", shQuote(.delayed_pipeline_repo), "rev-parse", "HEAD"), stdout = TRUE
    ))
    if (!identical(current_commit, metadata$git_commit)) {
      stop("Hervatten geweigerd: codecommit wijkt af.", call. = FALSE)
    }
    result <- run_delayed_pipeline(
      run_dir = cli[[2L]], metadata = metadata, compact_results_dir = cli[[3L]],
      resume = TRUE
    )
  }
  cat(result$manifest_path, "\n", sep = "")
}
