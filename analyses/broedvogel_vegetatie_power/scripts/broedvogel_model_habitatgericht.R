habitat_model_repo <- function() {
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

.habitat_model_repo <- habitat_model_repo()
source(file.path(
  .habitat_model_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatiesamenstelling_fit.R"
))
source(file.path(
  .habitat_model_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatie_validate.R"
))

weather_model_fields <- function() {
  c(
    "weer_winter_temperatuur_z",
    "weer_winter_vorstdagen_z",
    "weer_voorjaar_temperatuur_z",
    "weer_voorjaar_neerslag_z"
  )
}

build_weather_covariates <- function(weather) {
  require_prepare_fields(weather, c("datum", "tg_c", "tn_c", "rh_mm"), "weer_analyse")
  weather$datum <- as.Date(weather$datum)
  weather$jaar <- as.integer(format(weather$datum, "%Y"))
  weather$maand <- as.integer(format(weather$datum, "%m"))
  weather$tg_c <- as.numeric(weather$tg_c)
  weather$tn_c <- as.numeric(weather$tn_c)
  weather$rh_mm <- as.numeric(weather$rh_mm)
  years <- seq.int(min(weather$jaar) + 1L, max(weather$jaar))
  mean_finite <- function(x) if (any(is.finite(x))) mean(x[is.finite(x)]) else NA_real_
  sum_finite <- function(x) if (any(is.finite(x))) sum(x[is.finite(x)]) else NA_real_
  rows <- lapply(years, function(year) {
    winter <- weather[
      (weather$jaar == year - 1L & weather$maand == 12L) |
        (weather$jaar == year & weather$maand %in% 1:2),
      , drop = FALSE
    ]
    spring <- weather[
      weather$jaar == year & weather$maand %in% 3:6,
      , drop = FALSE
    ]
    data.frame(
      jaar = year,
      weer_winter_temperatuur_c = mean_finite(winter$tg_c),
      weer_winter_vorstdagen = sum(is.finite(winter$tn_c) & winter$tn_c < 0),
      weer_voorjaar_temperatuur_c = mean_finite(spring$tg_c),
      weer_voorjaar_neerslag_mm = sum_finite(spring$rh_mm),
      weer_winter_dagen = nrow(winter),
      weer_voorjaar_dagen = nrow(spring),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[order(out$jaar), , drop = FALSE]
}

add_habitat_controls <- function(data, weather_year) {
  require_prepare_fields(
    data,
    c(
      "jaar", "inspanning_duur_z", "inspanning_ongunstig_z",
      "inspanning_ongunstig_bekend"
    ),
    "habitat-modelpopulatie"
  )
  require_prepare_fields(
    weather_year,
    c(
      "jaar", "weer_winter_temperatuur_c", "weer_winter_vorstdagen",
      "weer_voorjaar_temperatuur_c", "weer_voorjaar_neerslag_mm"
    ),
    "jaarlijkse weercovariaten"
  )
  out <- merge(data, weather_year, by = "jaar", all.x = TRUE, sort = FALSE)
  mapping <- c(
    weer_winter_temperatuur_z = "weer_winter_temperatuur_c",
    weer_winter_vorstdagen_z = "weer_winter_vorstdagen",
    weer_voorjaar_temperatuur_z = "weer_voorjaar_temperatuur_c",
    weer_voorjaar_neerslag_z = "weer_voorjaar_neerslag_mm"
  )
  for (target in names(mapping)) out[[target]] <- standardize_for_fit(out[[mapping[[target]]]])
  out <- out[order(out$soort_id, out$plot_id, out$jaar), , drop = FALSE]
  rownames(out) <- NULL
  out
}

build_ahn_habitat_population <- function(
    base_population, height, membership, group_number, predictor,
    lag_years = 0L, window_half_width = 2L) {
  require_prepare_fields(
    base_population,
    c("row_id", "soort_id", "plot_id", "jaar", "count"),
    "basis-modelpopulatie"
  )
  require_prepare_fields(
    height, c("plot_id", "inwinningsjaar", predictor, "datum_methode"),
    "AHN-vegetatiestructuur"
  )
  require_prepare_fields(membership, c("groepsnummer", "vogel_id"), "vogelgroepen")
  lag_years <- as.integer(lag_years)
  window_half_width <- as.integer(window_half_width)
  if (length(lag_years) != 1L || is.na(lag_years) || !lag_years %in% 0:3) {
    stop("AHN-vertraging moet 0, 1, 2 of 3 jaar zijn.", call. = FALSE)
  }
  if (length(window_half_width) != 1L || is.na(window_half_width) || window_half_width < 0L) {
    stop("AHN-vensterbreedte is ongeldig.", call. = FALSE)
  }
  species <- unique(as.integer(membership$vogel_id[membership$groepsnummer == group_number]))
  species <- setdiff(species, pq_response_exclusions()$soort_id)
  selected <- base_population[base_population$soort_id %in% species, , drop = FALSE]
  features <- height[c("plot_id", "inwinningsjaar", predictor, "datum_methode")]
  names(features)[names(features) == "inwinningsjaar"] <- "jaar"
  names(features)[names(features) == predictor] <- "habitat"
  split <- split_multivariate_plotyear_features(features[c("plot_id", "jaar", "habitat")], "habitat")
  split$datum_methode <- features$datum_methode[match(
    paste(split$plot_id, split$jaar), paste(features$plot_id, features$jaar)
  )]
  expanded <- do.call(rbind, lapply(seq_len(nrow(split)), function(i) {
    current <- split[i, , drop = FALSE]
    years <- seq.int(
      current$jaar - window_half_width + lag_years,
      current$jaar + window_half_width + lag_years
    )
    current[rep(1L, length(years)), , drop = FALSE] |>
      transform(ahn_jaar = current$jaar, jaar = years, lag_years = lag_years)
  }))
  joined <- merge(selected, expanded, by = c("plot_id", "jaar"), all = FALSE, sort = FALSE)
  joined <- prepare_joined_vegetation_population(joined, lag_years)
  list(
    data = joined,
    row_hash = row_set_sha256(joined$row_id),
    groepsnummer = as.integer(group_number),
    predictor = predictor,
    lag_years = lag_years,
    window_half_width = window_half_width
  )
}

build_targeted_landcover_population <- function(
    base_population, landcover, membership, group_number, predictor) {
  item <- build_landcover_window_population(
    base_population, landcover, membership, group_number, predictor
  )
  names(item$data)[names(item$data) == "landbedekking_between_z"] <- "habitat_between_z"
  names(item$data)[names(item$data) == "landbedekking_within_z"] <- "habitat_within_z"
  item$groepsnummer <- as.integer(group_number)
  item$predictor <- predictor
  item
}

targeted_habitat_formulas <- function(data = NULL) {
  base <- joint_teller_formulas(TRUE, "inspanning_duur_z")[["M2"]]
  omitted <- character()
  if (!is.null(data)) {
    source_levels <- unique(as.character(data$analyse_bron_factor))
    source_levels <- source_levels[!is.na(source_levels)]
    if (length(source_levels) < 2L) {
      base <- stats::update.formula(base, ~ . - analyse_bron_factor)
      omitted <- c(omitted, "analyse_bron_factor (constant binnen modelpopulatie)")
    }
  }
  controls <- c(
    "inspanning_ongunstig_z", "inspanning_ongunstig_bekend",
    weather_model_fields()
  )
  controlled <- stats::update.formula(
    base, stats::as.formula(paste("~ . +", paste(controls, collapse = " + ")))
  )
  habitat <- stats::update.formula(
    controlled, ~ . + habitat_between_z + habitat_within_z
  )
  out <- list(basis = controlled, habitat = habitat)
  attr(out, "structureel_weggelaten") <- omitted
  out
}

targeted_habitat_required_fields <- function() {
  c(
    "row_id", "count", "jaar_decennium", "analyse_bron_factor",
    "log_oppervlakte_km2", "soort_factor", "soort_plot_factor", "jaar_factor",
    "plotjaar_factor", "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z",
    "inspanning_duur_z", "inspanning_ongunstig_z",
    "inspanning_ongunstig_bekend", weather_model_fields(),
    "habitat_between_z", "habitat_within_z"
  )
}

decide_targeted_model <- function(
    basis_status, habitat_status, beta_within, expected_direction,
    temporal_delta_logscore, spatial_share_better, loo_min_delta_logscore) {
  checks <- c(
    numeriek_geldig = identical(basis_status, "geslaagd") &&
      identical(habitat_status, "geslaagd"),
    verwachte_richting = is.finite(beta_within) &&
      sign(beta_within) == sign(expected_direction),
    voorspelt_latere_jaren = is.finite(temporal_delta_logscore) &&
      temporal_delta_logscore > 0,
    ruimtelijk_bestendig = is.finite(spatial_share_better) &&
      spatial_share_better >= 0.6,
    niet_een_soort_bepalend = is.finite(loo_min_delta_logscore) &&
      loo_min_delta_logscore > 0
  )
  list(
    status = if (all(checks)) "door_naar_power" else "niet_door_naar_power",
    checks = checks,
    reden = paste(names(checks)[!checks], collapse = "; ")
  )
}

fit_targeted_habitat_pair <- function(data, analysis_id, checkpoint_dir) {
  required <- targeted_habitat_required_fields()
  require_prepare_fields(data, required, paste0(analysis_id, "-modelpopulatie"))
  model_data <- droplevels(data[stats::complete.cases(data[required]), , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete modelrijen voor ", analysis_id, ".", call. = FALSE)
  formulas <- targeted_habitat_formulas(model_data)
  models <- lapply(names(formulas), function(name) {
    fit_glmmtmb_safely(
      formulas[[name]], model_data, paste(analysis_id, name, sep = "__"), checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  comparison <- do.call(rbind, Map(fit_summary_row, names(models), models))
  comparison$analysis_id <- analysis_id
  comparison$structureel_weggelaten <- paste(
    attr(formulas, "structureel_weggelaten"), collapse = "; "
  )
  list(models = models, comparison = comparison, data = model_data)
}

targeted_failure_message <- function(model) {
  if (!is.null(model$diagnostics$error) && nzchar(model$diagnostics$error)) {
    return(model$diagnostics$error)
  }
  warnings <- model$warnings[!is.na(model$warnings) & nzchar(model$warnings)]
  if (length(warnings)) return(paste(unique(warnings), collapse = " | "))
  if (identical(model$diagnostics$pdHess, FALSE)) return("Hessiaan niet positief-definiet")
  "onbekende modeluitval"
}

targeted_prediction_values <- function(model, test) {
  if (!identical(model$status, "geslaagd") || !file.exists(model$fit_path)) {
    stop(targeted_failure_message(model), call. = FALSE)
  }
  fit <- readRDS(model$fit_path)
  mu <- stats::predict(fit, newdata = test, type = "response", allow.new.levels = TRUE)
  theta <- stats::sigma(fit)
  rm(fit)
  gc(verbose = FALSE)
  list(mu = as.numeric(mu), theta = theta)
}

targeted_validation_failure <- function(
    validation_type, fold_id, block, train, test, message,
    status = "mislukt") {
  data.frame(
    validatie = validation_type, fold_id = fold_id, blok = block,
    status = status, fout = message,
    n_train = nrow(train), n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id),
    test_row_hash = row_set_sha256(test$row_id), n = nrow(test),
    delta_mean_log_score = NA_real_, delta_mae = NA_real_, delta_rmse = NA_real_,
    stringsAsFactors = FALSE
  )
}

targeted_temporal_design <- function(data) {
  snapshot_fields <- intersect(c("landbedekking_jaar", "ahn_jaar"), names(data))
  if (length(snapshot_fields) != 1L) {
    return(list(
      uitvoerbaar = FALSE,
      aantal_onafhankelijke_structuurmetingen = NA_integer_,
      reden = "Veld met het onafhankelijke vegetatiestructuurmoment ontbreekt of is niet uniek."
    ))
  }
  snapshots <- sort(unique(data[[snapshot_fields[[1L]]]][
    is.finite(data[[snapshot_fields[[1L]]]])
  ]))
  list(
    uitvoerbaar = length(snapshots) >= 3L,
    aantal_onafhankelijke_structuurmetingen = length(snapshots),
    reden = if (length(snapshots) >= 3L) "" else paste0(
      "Slechts ", length(snapshots),
      " onafhankelijke vegetatiestructuurmetingen; het eerste meetmoment alleen ",
      "leert geen respons op verandering voor toetsing op het tweede meetmoment."
    )
  )
}

targeted_validation_fold <- function(
    data, analysis_id, validation_type, fold_id, train_rows, test_rows,
    checkpoint_dir) {
  train <- droplevels(data[train_rows, , drop = FALSE])
  test <- data[test_rows, , drop = FALSE]
  if (!nrow(train) || !nrow(test)) {
    return(list(summary = targeted_validation_failure(
      validation_type, fold_id, analysis_id, train, test,
      "Leeg trainings- of validatieblok."
    ), leave_one_species_out = data.frame()))
  }
  result <- fit_targeted_habitat_pair(
    train, paste("validatie", validation_type, fold_id, analysis_id, sep = "__"),
    checkpoint_dir
  )
  invalid <- names(result$models)[vapply(
    result$models, function(x) !identical(x$status, "geslaagd"), logical(1)
  )]
  if (length(invalid)) {
    messages <- vapply(result$models[invalid], targeted_failure_message, character(1))
    return(list(summary = targeted_validation_failure(
      validation_type, fold_id, analysis_id, train, test,
      paste(paste(invalid, messages, sep = ": "), collapse = " | ")
    ), leave_one_species_out = data.frame()))
  }
  basis <- targeted_prediction_values(result$models$basis, test)
  habitat <- targeted_prediction_values(result$models$habitat, test)
  comparison <- compare_prediction_scores(
    score_count_predictions(test$count, basis$mu, basis$theta),
    score_count_predictions(test$count, habitat$mu, habitat$theta)
  )
  summary <- data.frame(
    validatie = validation_type, fold_id = fold_id, blok = analysis_id,
    status = "geslaagd", fout = "", n_train = nrow(train), n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id), test_row_hash = row_set_sha256(test$row_id),
    n = comparison$n, delta_mean_log_score = comparison$delta_mean_log_score,
    delta_mae = comparison$delta_mae, delta_rmse = comparison$delta_rmse,
    stringsAsFactors = FALSE
  )
  loo <- do.call(rbind, lapply(sort(unique(test$soort_id)), function(species) {
    keep <- test$soort_id != species
    if (!any(keep)) return(NULL)
    score <- compare_prediction_scores(
      score_count_predictions(test$count[keep], basis$mu[keep], basis$theta),
      score_count_predictions(test$count[keep], habitat$mu[keep], habitat$theta)
    )
    data.frame(
      validatie = validation_type, fold_id = fold_id, blok = analysis_id,
      weggelaten_soort_id = species, n = score$n,
      delta_mean_log_score = score$delta_mean_log_score,
      stringsAsFactors = FALSE
    )
  }))
  list(summary = summary, leave_one_species_out = loo)
}

run_targeted_validation <- function(
    data, analysis_id, checkpoint_dir, temporal_cut_year, spatial_k = 5L,
    seed = 20261011L) {
  folds <- make_spatial_folds(unique(data[c("plot_id", "jaar")]), spatial_k, seed)
  tasks <- lapply(unique(folds$fold_id), function(fold_id) {
    test_plots <- folds$plot_id[folds$fold_id == fold_id]
    list(type = "ruimte", id = fold_id, test = data$plot_id %in% test_plots)
  })
  results <- lapply(tasks, function(task) targeted_validation_fold(
    data, analysis_id, task$type, task$id, !task$test, task$test, checkpoint_dir
  ))
  temporal_design <- targeted_temporal_design(data)
  temporal_test <- data$jaar >= temporal_cut_year
  if (temporal_design$uitvoerbaar) {
    results[[length(results) + 1L]] <- targeted_validation_fold(
      data, analysis_id, "tijd", paste0("tijd_vanaf_", temporal_cut_year),
      !temporal_test, temporal_test, checkpoint_dir
    )
  } else {
    results[[length(results) + 1L]] <- list(
      summary = targeted_validation_failure(
        "tijd", paste0("tijd_vanaf_", temporal_cut_year), analysis_id,
        data[!temporal_test, , drop = FALSE], data[temporal_test, , drop = FALSE],
        temporal_design$reden, status = "niet_uitvoerbaar"
      ),
      leave_one_species_out = data.frame()
    )
  }
  list(
    summary = do.call(rbind, lapply(results, `[[`, "summary")),
    leave_one_species_out = do.call(rbind, lapply(results, `[[`, "leave_one_species_out"))
  )
}

extract_targeted_effects <- function(result, analysis_id) {
  model <- result$models$habitat
  if (!identical(model$status, "geslaagd") || !file.exists(model$fit_path)) return(data.frame())
  fit <- readRDS(model$fit_path)
  coefficients <- summary(fit)$coefficients$cond
  terms <- intersect(
    c("habitat_between_z", "habitat_within_z", weather_model_fields()),
    rownames(coefficients)
  )
  out <- data.frame(
    analysis_id = analysis_id, term = terms,
    beta = coefficients[terms, "Estimate"],
    standaardfout = coefficients[terms, "Std. Error"],
    z = coefficients[terms, "z value"],
    p = coefficients[terms, "Pr(>|z|)"],
    ratio_per_sd = exp(coefficients[terms, "Estimate"]),
    stringsAsFactors = FALSE
  )
  rm(fit)
  gc(verbose = FALSE)
  out
}
