vegetation_pipeline_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
    return(normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

.vegetation_pipeline_repo <- vegetation_pipeline_repo()
source(file.path(
  .vegetation_pipeline_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "run_broedvogel_teller_model.R"
))
source(file.path(
  .vegetation_pipeline_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_validate.R"
))

read_vegetation_extract <- function(input_dir) {
  extract <- read_teller_extract(input_dir)
  path <- file.path(input_dir, "pq_plot_jaar_vegetatie.tsv")
  if (!file.exists(path)) stop("Extract mist pq_plot_jaar_vegetatie.tsv.", call. = FALSE)
  extract$data$pq_plot_jaar_vegetatie <- utils::read.delim(
    path, header = TRUE, sep = "\t", na.strings = "NULL", quote = "",
    comment.char = "", check.names = FALSE, stringsAsFactors = FALSE
  )
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(extract$source_files, `[[`, character(1), "sha256"), collapse = "")
  extract$source_fingerprint_sha256 <- digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  extract
}

build_vegetation_pipeline_state <- function(input_dir) {
  extract <- read_vegetation_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)
  vegetation <- lapply(0:3, function(lag) {
    build_vegetation_population(populations$long, extract$data$pq_plot_jaar_vegetatie, lag)
  })
  names(vegetation) <- paste0("lag", 0:3)
  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    matrix_result = matrix_result,
    teller_layer = teller_layer,
    populations = populations,
    vegetation = vegetation
  )
}

vegetation_coverage <- function(state) {
  do.call(rbind, lapply(state$vegetation, function(item) {
    data.frame(
      lag_years = item$lag_years,
      rows = nrow(item$data),
      plotyears = nrow(item$plotyears),
      plots = length(unique(item$data$plot_id)),
      species = length(unique(item$data$soort_id)),
      first_bird_year = min(item$data$jaar),
      last_bird_year = max(item$data$jaar),
      row_hash = item$row_hash,
      stringsAsFactors = FALSE
    )
  }))
}

validate_vegetation_coverage <- function(coverage, expected_plots = 35L) {
  if (!identical(as.integer(coverage$lag_years), 0:3)) {
    stop("Vegetatiedekking mist een of meer vooraf vastgelegde vertragingen.", call. = FALSE)
  }
  if (any(coverage$plots != expected_plots)) {
    stop("Onverwachte plotdekking in het vegetatiemodel.", call. = FALSE)
  }
  if (any(coverage$rows <= 0 | coverage$plotyears <= 0 | coverage$species <= 0)) {
    stop("Lege vegetatie-modelpopulatie.", call. = FALSE)
  }
  invisible(TRUE)
}

summarise_vegetation_validation <- function(validation) {
  groups <- split(seq_len(nrow(validation)), paste(validation$validatie, validation$metric, sep = ":"))
  out <- lapply(groups, function(indices) {
    current <- validation[indices, , drop = FALSE]
    data.frame(
      validatie = current$validatie[[1L]],
      metric = current$metric[[1L]],
      aantal_blokken = nrow(current),
      delta_logscore_gem = mean(current$delta_mean_log_score),
      delta_mae_gem = mean(current$delta_mae),
      delta_rmse_gem = mean(current$delta_rmse),
      aandeel_betere_logscore = mean(current$delta_mean_log_score > 0),
      aandeel_lagere_mae = mean(current$delta_mae > 0),
      aandeel_lagere_rmse = mean(current$delta_rmse > 0),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result[order(result$validatie, result$metric), , drop = FALSE]
}

flatten_vegetation_comparisons <- function(full_results) {
  do.call(rbind, lapply(names(full_results), function(name) full_results[[name]]$comparison))
}

flatten_vegetation_species <- function(full_results) {
  rows <- lapply(names(full_results), function(name) {
    current <- full_results[[name]]$species_effects
    if (!nrow(current)) return(NULL)
    current$analysis_id <- name
    current
  })
  do.call(rbind, rows)
}

write_vegetation_manifest <- function(path, metadata, state, formulas, outputs) {
  output_metadata <- lapply(outputs, function(output_path) list(
    file = basename(output_path), bytes = unname(file.info(output_path)$size), sha256 = sha256_file(output_path)
  ))
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = state$source_fingerprint_sha256,
    package_versions = package_versions_for_manifest(),
    tables = state$extract_metadata,
    formulas = formula_manifest(formulas),
    lags = 0:3,
    primary_validation_lag = 0L,
    outputs = output_metadata
  ))
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  manifest
}

run_vegetation_model_pipeline <- function(
    input_dir = NULL, run_dir, metadata, resume = FALSE, compact_results_dir = NULL,
    spatial_k = 5L, temporal_cut_years = c(2016L, 2021L), seed = 20261011L) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state_path <- file.path(run_dir, "vegetatie_model_state.rds")
  if (isTRUE(resume)) {
    if (!file.exists(state_path)) stop("Hervatten kan niet: vegetatie_model_state.rds ontbreekt.", call. = FALSE)
    state <- readRDS(state_path)
  } else {
    if (is.null(input_dir)) stop("Voor een nieuwe run is een extractmap verplicht.", call. = FALSE)
    state <- build_vegetation_pipeline_state(input_dir)
    state$run_metadata <- metadata
    saveRDS(state, state_path)
  }
  Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = metadata$git_commit)
  set.seed(seed)
  coverage <- vegetation_coverage(state)
  validate_vegetation_coverage(coverage)
  checkpoint_dir <- file.path(run_dir, "modellen")
  metrics <- names(pq_metric_contract())
  full_results <- list()
  for (lag in 0:3) {
    population <- state$vegetation[[paste0("lag", lag)]]$data
    for (metric in metrics) {
      analysis_id <- paste0("lag", lag)
      key <- paste(analysis_id, metric, sep = "__")
      full_results[[key]] <- fit_vegetation_model_pair(
        population, metric, analysis_id, checkpoint_dir
      )
    }
  }
  primary <- state$vegetation$lag0$data
  validation_rows <- lapply(metrics, function(metric) {
    run_vegetation_blocked_validation(
      primary, metric, checkpoint_dir, spatial_k, temporal_cut_years, seed
    )
  })
  validation <- do.call(rbind, validation_rows)
  validation_summary <- summarise_vegetation_validation(validation)
  comparisons <- flatten_vegetation_comparisons(full_results)
  species <- flatten_vegetation_species(full_results)

  outputs <- c(
    dekking = write_csv_atomic(coverage, file.path(run_dir, "vegetatie_model_dekking.csv")),
    modellen = write_csv_atomic(comparisons, file.path(run_dir, "vegetatie_model_modellen.csv")),
    validatie = write_csv_atomic(validation, file.path(run_dir, "vegetatie_model_validatie.csv")),
    samenvatting = write_csv_atomic(validation_summary, file.path(run_dir, "vegetatie_model_samenvatting.csv")),
    soorten = write_csv_atomic(species, file.path(run_dir, "vegetatie_model_soorten.csv"))
  )
  formulas <- unlist(lapply(metrics, vegetation_model_formulas), recursive = FALSE)
  names(formulas) <- unlist(lapply(metrics, function(metric) paste(metric, c("basis", "pq"), sep = "_")))
  manifest_path <- file.path(run_dir, "vegetatie_model_manifest.json")
  manifest <- write_vegetation_manifest(manifest_path, metadata, state, formulas, outputs)
  if (!is.null(compact_results_dir)) {
    dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
    for (name in names(outputs)) {
      destination <- file.path(compact_results_dir, paste0("vegetatie_model_laatste_", name, ".csv"))
      if (!file.copy(outputs[[name]], destination, overwrite = TRUE)) stop("Kon compact resultaat niet kopieren.", call. = FALSE)
    }
    if (!file.copy(manifest_path, file.path(compact_results_dir, "vegetatie_model_laatste_manifest.json"), overwrite = TRUE)) {
      stop("Kon compact vegetatiemanifest niet kopieren.", call. = FALSE)
    }
  }
  list(manifest = manifest, manifest_path = manifest_path, outputs = outputs)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) < 3L || !cli[[1L]] %in% c("new", "resume")) {
    stop("Gebruik: Rscript run_broedvogel_vegetatie_model.R new INPUT_DIR RUN_DIR RUN_ID GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR; of resume RUN_DIR RESULT_DIR", call. = FALSE)
  }
  if (cli[[1L]] == "new") {
    if (length(cli) != 8L) stop("Nieuwe run: acht argumenten vereist.", call. = FALSE)
    result <- run_vegetation_model_pipeline(
      input_dir = cli[[2L]], run_dir = cli[[3L]],
      metadata = list(run_id = cli[[4L]], git_commit = cli[[5L]], database_name = cli[[6L]], mysql_version = cli[[7L]]),
      compact_results_dir = cli[[8L]]
    )
  } else {
    if (length(cli) != 3L) stop("Hervatten: runmap en resultaatmap vereist.", call. = FALSE)
    state <- readRDS(file.path(cli[[2L]], "vegetatie_model_state.rds"))
    metadata <- state$run_metadata
    current_commit <- trimws(system2("git", c("-C", shQuote(.vegetation_pipeline_repo), "rev-parse", "HEAD"), stdout = TRUE))
    if (!identical(current_commit, metadata$git_commit)) stop("Hervatten geweigerd: codecommit wijkt af.", call. = FALSE)
    result <- run_vegetation_model_pipeline(run_dir = cli[[2L]], metadata = metadata, resume = TRUE, compact_results_dir = cli[[3L]])
  }
  cat(result$manifest_path, "\n", sep = "")
}
