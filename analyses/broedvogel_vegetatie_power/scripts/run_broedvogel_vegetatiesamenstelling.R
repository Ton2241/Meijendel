composition_pipeline_repo <- function() {
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

.composition_pipeline_repo <- composition_pipeline_repo()
source(file.path(
  .composition_pipeline_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_teller_model.R"
))

composition_coverage_lags <- function() 0:3

primary_composition_model_lags <- function() 0L

validation_worker_count <- function() {
  workers <- suppressWarnings(as.integer(Sys.getenv("MEIJENDEL_MODEL_WORKERS", unset = "2")))
  if (length(workers) != 1L || is.na(workers) || workers < 1L) workers <- 1L
  min(workers, 2L)
}
source(file.path(
  .composition_pipeline_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatiesamenstelling_fit.R"
))
source(file.path(
  .composition_pipeline_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatie_validate.R"
))

read_tsv_required <- function(input_dir, name) {
  path <- file.path(input_dir, paste0(name, ".tsv"))
  if (!file.exists(path)) stop("Extract mist ", basename(path), ".", call. = FALSE)
  utils::read.delim(
    path, header = TRUE, sep = "\t", na.strings = "NULL", quote = "",
    comment.char = "", check.names = FALSE, stringsAsFactors = FALSE
  )
}

read_composition_extract <- function(input_dir) {
  extract <- read_teller_extract(input_dir)
  for (name in c(
    "pq_vegetatie_opname", "pq_vegetatie_waarneming", "pq_vegetatie_opname_plot",
    "landbedekking_schmidt_2025", "evg_vogel_landschapgroep"
  )) {
    extract$data[[name]] <- read_tsv_required(input_dir, name)
  }
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(extract$source_files, `[[`, character(1), "sha256"), collapse = "")
  extract$source_fingerprint_sha256 <- digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  extract
}

add_landcover_derived_features <- function(landcover) {
  required <- paste0(names(landcover_class_contract()), "_aandeel")
  require_prepare_fields(landcover, required, "landbedekking")
  out <- landcover
  out$open_aandeel <- out$laag_aandeel + out$zand_aandeel
  out$houtig_aandeel <- out$struik_aandeel + out$bos_aandeel + out$boomgroep_aandeel
  out
}

build_composition_pipeline_state <- function(input_dir) {
  extract <- read_composition_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)

  composition <- build_pq_composition_features(
    extract$data$pq_vegetatie_opname,
    extract$data$pq_vegetatie_waarneming,
    extract$data$pq_vegetatie_opname_plot,
    n_axes = length(composition_predictor_contract())
  )
  ipi <- build_ipi_plotyear_features(
    extract$data$pq_vegetatie_opname,
    extract$data$pq_vegetatie_opname_plot
  )
  landcover <- normalize_landcover_supplement(
    extract$data$landbedekking_schmidt_2025,
    extract$data$plots
  )
  landcover <- add_landcover_derived_features(landcover)

  composition_populations <- lapply(composition_coverage_lags(), function(lag) {
    build_multivariate_vegetation_population(
      populations$long, composition$features,
      composition_predictor_contract(), lag
    )
  })
  names(composition_populations) <- paste0("lag", composition_coverage_lags())
  ipi_populations <- lapply(composition_coverage_lags(), function(lag) {
    build_multivariate_vegetation_population(
      populations$long, ipi, ipi_predictor_contract(), lag
    )
  })
  names(ipi_populations) <- paste0("lag", composition_coverage_lags())

  groups <- landcover_bird_group_contract()
  landcover_populations <- lapply(names(groups), function(group) {
    build_landcover_window_population(
      populations$long, landcover, extract$data$evg_vogel_landschapgroep,
      as.integer(group), unname(groups[[group]])
    )
  })
  names(landcover_populations) <- paste0("groep", names(groups))

  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    matrix_result = matrix_result,
    teller_layer = teller_layer,
    populations = populations,
    composition = composition,
    ipi = ipi,
    landcover = landcover,
    composition_populations = composition_populations,
    ipi_populations = ipi_populations,
    landcover_populations = landcover_populations
  )
}

coverage_row <- function(block, analysis_id, item) {
  data <- item$data
  data.frame(
    blok = block,
    analysis_id = analysis_id,
    rows = nrow(data),
    plotyears = length(unique(paste(data$plot_id, data$jaar, sep = ":"))),
    plots = length(unique(data$plot_id)),
    species = length(unique(data$soort_id)),
    first_bird_year = min(data$jaar),
    last_bird_year = max(data$jaar),
    row_hash = item$row_hash,
    stringsAsFactors = FALSE
  )
}

composition_pipeline_coverage <- function(state) {
  rows <- list()
  for (name in names(state$composition_populations)) {
    rows[[length(rows) + 1L]] <- coverage_row("compositie", name, state$composition_populations[[name]])
  }
  for (name in names(state$ipi_populations)) {
    rows[[length(rows) + 1L]] <- coverage_row("ipi", name, state$ipi_populations[[name]])
  }
  for (name in names(state$landcover_populations)) {
    rows[[length(rows) + 1L]] <- coverage_row("landbedekking", name, state$landcover_populations[[name]])
  }
  do.call(rbind, rows)
}

validation_failure_row <- function(
    validation_type, fold_id, block, train, test, message) {
  data.frame(
    validatie = validation_type,
    fold_id = fold_id,
    blok = block,
    status = "mislukt",
    fout = message,
    n_train = nrow(train),
    n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id),
    test_row_hash = row_set_sha256(test$row_id),
    n = nrow(test),
    delta_mean_log_score = NA_real_,
    delta_mae = NA_real_,
    delta_rmse = NA_real_,
    stringsAsFactors = FALSE
  )
}

fit_multivariate_validation_fold <- function(
    data, block, fields, validation_type, fold_id, train_rows, test_rows,
    checkpoint_dir) {
  formulas <- multivariate_vegetation_model_formulas(block, fields)
  train <- droplevels(data[train_rows, , drop = FALSE])
  test <- data[test_rows, , drop = FALSE]
  if (!nrow(train) || !nrow(test)) {
    return(validation_failure_row(
      validation_type, fold_id, block, train, test, "Leeg trainings- of validatieblok."
    ))
  }
  if (length(intersect(train$row_id, test$row_id))) {
    return(validation_failure_row(
      validation_type, fold_id, block, train, test, "Training en validatie overlappen."
    ))
  }
  models <- lapply(names(formulas), function(model_name) {
    fit_glmmtmb_safely(
      formulas[[model_name]], train,
      paste("validatie", validation_type, fold_id, block, model_name, sep = "__"),
      checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  invalid <- names(models)[vapply(models, function(model) !identical(model$status, "geslaagd"), logical(1))]
  if (length(invalid)) {
    messages <- vapply(models[invalid], function(model) model$diagnostics$fout, character(1))
    return(validation_failure_row(
      validation_type, fold_id, block, train, test,
      paste(paste(invalid, messages, sep = ": "), collapse = " | ")
    ))
  }
  scores <- tryCatch(
    lapply(models, predict_validation_model, test_data = test),
    error = function(e) e
  )
  if (inherits(scores, "error")) {
    return(validation_failure_row(
      validation_type, fold_id, block, train, test, conditionMessage(scores)
    ))
  }
  comparison <- compare_prediction_scores(scores$basis, scores$vegetatie)
  data.frame(
    validatie = validation_type,
    fold_id = fold_id,
    blok = block,
    status = "geslaagd",
    fout = "",
    n_train = nrow(train),
    n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id),
    test_row_hash = row_set_sha256(test$row_id),
    n = comparison$n,
    delta_mean_log_score = comparison$delta_mean_log_score,
    delta_mae = comparison$delta_mae,
    delta_rmse = comparison$delta_rmse,
    stringsAsFactors = FALSE
  )
}

run_multivariate_blocked_validation <- function(
    data, block, fields, checkpoint_dir, spatial_k = 5L,
    temporal_cut_years = c(2016L, 2021L), seed = 20261011L) {
  plotyears <- unique(data[c("plot_id", "jaar")])
  spatial <- make_spatial_folds(plotyears, spatial_k, seed)
  temporal <- make_temporal_folds(plotyears, temporal_cut_years)
  tasks <- list()
  for (fold_id in unique(spatial$fold_id)) {
    test_plots <- spatial$plot_id[spatial$fold_id == fold_id]
    test_rows <- data$plot_id %in% test_plots
    tasks[[length(tasks) + 1L]] <- list(
      validation_type = "ruimte", fold_id = fold_id,
      train_rows = !test_rows, test_rows = test_rows
    )
  }
  for (i in seq_len(nrow(temporal))) {
    fold <- temporal[i, ]
    train_rows <- data$jaar <= fold$train_max_year
    test_rows <- data$jaar >= fold$test_min_year & data$jaar <= fold$test_max_year
    tasks[[length(tasks) + 1L]] <- list(
      validation_type = "tijd", fold_id = fold$fold_id,
      train_rows = train_rows, test_rows = test_rows
    )
  }
  execute <- function(task) {
    fit_multivariate_validation_fold(
      data, block, fields, task$validation_type, task$fold_id,
      task$train_rows, task$test_rows, checkpoint_dir
    )
  }
  workers <- validation_worker_count()
  rows <- if (workers > 1L && .Platform$OS.type != "windows") {
    parallel::mclapply(tasks, execute, mc.cores = workers, mc.preschedule = FALSE)
  } else {
    lapply(tasks, execute)
  }
  do.call(rbind, rows)
}

summarise_block_validation <- function(validation) {
  groups <- split(seq_len(nrow(validation)), paste(validation$validatie, validation$blok, sep = ":"))
  out <- lapply(groups, function(indices) {
    current <- validation[indices, , drop = FALSE]
    if (!"status" %in% names(current)) current$status <- "geslaagd"
    success <- current[current$status == "geslaagd", , drop = FALSE]
    data.frame(
      validatie = current$validatie[[1L]],
      blok = current$blok[[1L]],
      aantal_blokken = nrow(current),
      geslaagd = nrow(success),
      mislukt = nrow(current) - nrow(success),
      delta_logscore_gem = if (nrow(success)) mean(success$delta_mean_log_score) else NA_real_,
      delta_mae_gem = if (nrow(success)) mean(success$delta_mae) else NA_real_,
      delta_rmse_gem = if (nrow(success)) mean(success$delta_rmse) else NA_real_,
      aandeel_betere_logscore = if (nrow(success)) mean(success$delta_mean_log_score > 0) else NA_real_,
      aandeel_lagere_mae = if (nrow(success)) mean(success$delta_mae > 0) else NA_real_,
      aandeel_lagere_rmse = if (nrow(success)) mean(success$delta_rmse > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result[order(result$validatie, result$blok), , drop = FALSE]
}

extract_multivariate_fixed_effects <- function(results) {
  rows <- list()
  for (name in names(results)) {
    result <- results[[name]]
    model <- result$models$vegetatie
    if (!identical(model$status, "geslaagd") || !file.exists(model$fit_path)) next
    fit <- readRDS(model$fit_path)
    coefficients <- summary(fit)$coefficients$cond
    terms <- rownames(coefficients)
    terms <- terms[grepl("_(between|within)_z$", terms)]
    if (length(terms)) {
      current <- data.frame(
        analysis_id = result$comparison$analysis_id[[1L]],
        blok = result$comparison$blok[[1L]],
        term = terms,
        beta = coefficients[terms, "Estimate"],
        standaardfout = coefficients[terms, "Std. Error"],
        z = coefficients[terms, "z value"],
        p = coefficients[terms, "Pr(>|z|)"],
        ratio_per_sd = exp(coefficients[terms, "Estimate"]),
        stringsAsFactors = FALSE
      )
      rows[[length(rows) + 1L]] <- current
    }
    rm(fit)
    gc(verbose = FALSE)
  }
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$blok, out$analysis_id, out$term), , drop = FALSE]
}

decide_height_followup <- function(validation_summary) {
  spatial <- validation_summary[
    validation_summary$validatie == "ruimte" & is.finite(validation_summary$delta_logscore_gem),
    , drop = FALSE
  ]
  useful <- nrow(spatial) && any(
    spatial$delta_logscore_gem > 0 & spatial$aandeel_betere_logscore >= 0.6
  )
  if (useful) {
    return(list(
      status = "aanvullende_hoogteproxy_nuttig",
      advies = paste(
        "De structuurgevoelige vegetatieblokken leveren ruimtelijk signaal, maar meten",
        "geen verticale gelaagdheid. Leid daarom in een afzonderlijke vervolgstap",
        "vegetatiehoogte af als DSM minus DTM uit de openbare AHN-cycli, met het",
        "werkelijke inwinningsjaar voor Meijendel."
      )
    ))
  }
  list(
    status = "hoogteproxy_niet_automatisch_toevoegen",
    advies = paste(
      "De onderzochte vegetatieblokken leveren nog geen bestendige ruimtelijke",
      "voorspelwinst. Voeg AHN-hoogte daarom alleen toe in een vooraf gerichte",
      "toets voor vogelgroepen waarvoor verticale structuur ecologisch essentieel is."
    )
  )
}

flatten_model_comparisons <- function(results) {
  do.call(rbind, lapply(results, function(result) result$comparison))
}

run_composition_pipeline <- function(
    input_dir = NULL, run_dir, metadata, resume = FALSE,
    compact_results_dir = NULL, seed = 20261011L) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state_path <- file.path(run_dir, "vegetatiesamenstelling_state.rds")
  if (isTRUE(resume)) {
    if (!file.exists(state_path)) stop("Hervatten kan niet: vegetatiesamenstelling_state.rds ontbreekt.", call. = FALSE)
    state <- readRDS(state_path)
  } else {
    if (is.null(input_dir)) stop("Voor een nieuwe run is een extractmap verplicht.", call. = FALSE)
    state <- build_composition_pipeline_state(input_dir)
    state$run_metadata <- metadata
    saveRDS(state, state_path)
  }
  Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = metadata$git_commit)
  set.seed(seed)
  checkpoint_dir <- file.path(run_dir, "modellen")

  results <- list()
  for (lag in primary_composition_model_lags()) {
    key <- paste0("compositie_lag", lag)
    results[[key]] <- fit_multivariate_vegetation_pair(
      state$composition_populations[[paste0("lag", lag)]]$data,
      "compositie", composition_predictor_contract(), paste0("lag", lag), checkpoint_dir
    )
    key <- paste0("ipi_lag", lag)
    results[[key]] <- fit_multivariate_vegetation_pair(
      state$ipi_populations[[paste0("lag", lag)]]$data,
      "ipi", ipi_predictor_contract(), paste0("lag", lag), checkpoint_dir
    )
  }
  landcover_contract <- landcover_bird_group_contract()
  for (group in names(landcover_contract)) {
    key <- paste0("landbedekking_groep", group)
    results[[key]] <- fit_multivariate_vegetation_pair(
      state$landcover_populations[[paste0("groep", group)]]$data,
      "landbedekking", "landbedekking", paste0("groep", group), checkpoint_dir
    )
  }

  validation <- rbind(
    run_multivariate_blocked_validation(
      state$composition_populations$lag0$data, "compositie",
      composition_predictor_contract(), checkpoint_dir, seed = seed
    ),
    run_multivariate_blocked_validation(
      state$ipi_populations$lag0$data, "ipi",
      ipi_predictor_contract(), checkpoint_dir, seed = seed
    )
  )
  for (group in names(landcover_contract)) {
    validation <- rbind(
      validation,
      run_multivariate_blocked_validation(
        state$landcover_populations[[paste0("groep", group)]]$data,
        paste0("landbedekking_groep", group), "landbedekking", checkpoint_dir,
        temporal_cut_years = 2018L, seed = seed
      )
    )
  }

  validation_summary <- summarise_block_validation(validation)
  height_decision <- decide_height_followup(validation_summary)
  height_table <- data.frame(
    status = height_decision$status,
    advies = height_decision$advies,
    bronvoorkeur = "AHN DSM minus DTM per werkelijke inwinningsdatum",
    bronstatus = "open data; nog niet voor deze analyse afgeleid",
    stringsAsFactors = FALSE
  )
  outputs <- c(
    dekking = write_csv_atomic(
      composition_pipeline_coverage(state), file.path(run_dir, "vegetatiesamenstelling_dekking.csv")
    ),
    pca_variantie = write_csv_atomic(
      state$composition$variance, file.path(run_dir, "vegetatiesamenstelling_pca_variantie.csv")
    ),
    pca_ladingen = write_csv_atomic(
      state$composition$loadings, file.path(run_dir, "vegetatiesamenstelling_pca_ladingen.csv")
    ),
    pca_scores = write_csv_atomic(
      state$composition$features, file.path(run_dir, "vegetatiesamenstelling_pca_scores.csv")
    ),
    ipi = write_csv_atomic(
      state$ipi, file.path(run_dir, "vegetatiesamenstelling_ipi.csv")
    ),
    landbedekking = write_csv_atomic(
      state$landcover, file.path(run_dir, "vegetatiesamenstelling_landbedekking.csv")
    ),
    modellen = write_csv_atomic(
      flatten_model_comparisons(results), file.path(run_dir, "vegetatiesamenstelling_modellen.csv")
    ),
    effecten = write_csv_atomic(
      extract_multivariate_fixed_effects(results), file.path(run_dir, "vegetatiesamenstelling_effecten.csv")
    ),
    validatie = write_csv_atomic(
      validation, file.path(run_dir, "vegetatiesamenstelling_validatie.csv")
    ),
    samenvatting = write_csv_atomic(
      validation_summary, file.path(run_dir, "vegetatiesamenstelling_samenvatting.csv")
    ),
    hoogtebesluit = write_csv_atomic(
      height_table, file.path(run_dir, "vegetatiesamenstelling_hoogtebesluit.csv")
    )
  )
  output_metadata <- lapply(outputs, function(path) list(
    file = basename(path), bytes = unname(file.info(path)$size), sha256 = sha256_file(path)
  ))
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = state$source_fingerprint_sha256,
    package_versions = package_versions_for_manifest(),
    tables = state$extract_metadata,
    response_exclusions = pq_response_exclusions(),
    composition_quality = state$composition$quality,
    composition_axes = composition_predictor_contract(),
    coverage_lags = composition_coverage_lags(),
    fitted_lags = primary_composition_model_lags(),
    ipi_groups = ipi_group_contract(),
    landcover_groups = landcover_bird_group_contract(),
    height_decision = height_decision,
    outputs = output_metadata
  ))
  manifest_path <- file.path(run_dir, "vegetatiesamenstelling_manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)

  if (!is.null(compact_results_dir)) {
    dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
    for (name in names(outputs)) {
      destination <- file.path(
        compact_results_dir, paste0("vegetatiesamenstelling_laatste_", name, ".csv")
      )
      if (!file.copy(outputs[[name]], destination, overwrite = TRUE)) {
        stop("Kon compact resultaat niet kopieren: ", name, call. = FALSE)
      }
    }
    if (!file.copy(
      manifest_path,
      file.path(compact_results_dir, "vegetatiesamenstelling_laatste_manifest.json"),
      overwrite = TRUE
    )) stop("Kon compact manifest niet kopieren.", call. = FALSE)
  }
  list(manifest = manifest, manifest_path = manifest_path, outputs = outputs)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) < 3L || !cli[[1L]] %in% c("new", "resume")) {
    stop(paste(
      "Gebruik: Rscript run_broedvogel_vegetatiesamenstelling.R new",
      "INPUT_DIR RUN_DIR RUN_ID GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR;",
      "of resume RUN_DIR RESULT_DIR"
    ), call. = FALSE)
  }
  if (cli[[1L]] == "new") {
    if (length(cli) != 8L) stop("Nieuwe run: acht argumenten vereist.", call. = FALSE)
    result <- run_composition_pipeline(
      input_dir = cli[[2L]], run_dir = cli[[3L]],
      metadata = list(
        run_id = cli[[4L]], git_commit = cli[[5L]], database_name = cli[[6L]],
        mysql_version = cli[[7L]]
      ),
      compact_results_dir = cli[[8L]]
    )
  } else {
    if (length(cli) != 3L) stop("Hervatten: runmap en resultaatmap vereist.", call. = FALSE)
    state <- readRDS(file.path(cli[[2L]], "vegetatiesamenstelling_state.rds"))
    metadata <- state$run_metadata
    result <- run_composition_pipeline(
      run_dir = cli[[2L]], metadata = metadata, resume = TRUE,
      compact_results_dir = cli[[3L]]
    )
  }
  cat(result$manifest_path, "\n", sep = "")
}
