environment_model_repo <- function() {
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

.environment_model_repo <- environment_model_repo()
source(file.path(
  .environment_model_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_habitatgericht.R"
))

environment_predictor_groups <- function() {
  list(
    land_open_pct = c("Droog natuurlijk terrein", "Open droog natuurlijk terrein"),
    land_bos_pct = "Bos",
    land_water_pct = c("Water", "Overig binnenwater")
  )
}

harmonize_cbs_landuse <- function(landuse) {
  require_prepare_fields(
    landuse, c("plot_id", "jaar", "bron", "klasse", "pct"),
    "plot_jaar_landgebruik"
  )
  landuse$plot_id <- as.integer(landuse$plot_id)
  landuse$jaar <- as.integer(landuse$jaar)
  landuse$pct <- as.numeric(landuse$pct)
  key <- paste(landuse$plot_id, landuse$jaar, landuse$bron, landuse$klasse, sep = ":")
  if (anyDuplicated(key)) stop("Landgebruik bevat dubbele plot-jaar-bron-klasseregels.", call. = FALSE)
  if (any(!is.finite(landuse$pct)) || any(landuse$pct < 0)) {
    stop("Landgebruik bevat ontbrekende, niet-eindige of negatieve percentages.", call. = FALSE)
  }
  excluded_years <- sort(unique(landuse$jaar[grepl("^BG96_", landuse$klasse)]))
  usable <- landuse[!landuse$jaar %in% excluded_years, , drop = FALSE]
  if (!nrow(usable)) stop("Geen harmoniseerbare CBS-landgebruiksregels.", call. = FALSE)
  totals <- aggregate(usable$pct, usable[c("plot_id", "jaar")], sum)
  names(totals)[3L] <- "land_totaal_pct"
  if (any(abs(totals$land_totaal_pct - 100) > 0.1)) {
    stop("Landgebruik telt per plotjaar niet op tot circa 100 procent.", call. = FALSE)
  }
  out <- totals
  groups <- environment_predictor_groups()
  for (field in names(groups)) {
    current <- usable[usable$klasse %in% groups[[field]], , drop = FALSE]
    values <- if (nrow(current)) {
      aggregate(current$pct, current[c("plot_id", "jaar")], sum)
    } else {
      data.frame(plot_id = integer(), jaar = integer(), x = numeric())
    }
    names(values)[3L] <- field
    out <- merge(out, values, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
    out[[field]][is.na(out[[field]])] <- 0
  }
  selected <- names(groups)
  out$land_overig_pct <- out$land_totaal_pct - rowSums(out[selected])
  if (any(out$land_overig_pct < -1e-8)) {
    stop("Geharmoniseerde landgebruiksklassen overlappen.", call. = FALSE)
  }
  out$land_overig_pct <- pmax(out$land_overig_pct, 0)
  out <- out[order(out$jaar, out$plot_id), c(
    "plot_id", "jaar", selected, "land_overig_pct", "land_totaal_pct"
  )]
  rownames(out) <- NULL
  attr(out, "uitgesloten_jaren") <- as.integer(excluded_years)
  out
}

prepare_nitrogen_features <- function(nitrogen) {
  require_prepare_fields(
    nitrogen, c("plot_id", "jaar", "bron", "stikstof_mean"),
    "plot_jaar_stikstof"
  )
  nitrogen$plot_id <- as.integer(nitrogen$plot_id)
  nitrogen$jaar <- as.integer(nitrogen$jaar)
  nitrogen$stikstof_mean <- as.numeric(nitrogen$stikstof_mean)
  key <- paste(nitrogen$plot_id, nitrogen$jaar, sep = ":")
  if (anyDuplicated(key)) stop("Stikstof bevat dubbele plot-jaarrijen.", call. = FALSE)
  if (any(!is.finite(nitrogen$stikstof_mean) | nitrogen$stikstof_mean < 0)) {
    stop("Stikstof bevat een ongeldige gemiddelde depositie.", call. = FALSE)
  }
  split_multivariate_plotyear_features(
    nitrogen[c("plot_id", "jaar", "stikstof_mean")], "stikstof_mean"
  )
}

build_environment_population <- function(
    base_population, features, fields, lag_years = 0L) {
  require_prepare_fields(
    base_population,
    c(
      "row_id", "soort_id", "soort_naam", "plot_id", "jaar", "count",
      "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z",
      "inspanning_duur_z", "inspanning_ongunstig_z",
      "inspanning_ongunstig_bekend"
    ),
    "basis-modelpopulatie"
  )
  lag_years <- as.integer(lag_years)
  if (length(lag_years) != 1L || is.na(lag_years) || !lag_years %in% 0:3) {
    stop("Omgevingsvertraging moet 0, 1, 2 of 3 jaar zijn.", call. = FALSE)
  }
  fields <- as.character(fields)
  require_prepare_fields(features, c("plot_id", "jaar", fields), "omgevingskenmerken")
  exclusions <- pq_response_exclusions()
  base_population <- base_population[
    !base_population$soort_id %in% exclusions$soort_id, , drop = FALSE
  ]
  split_fields <- unlist(lapply(fields, function(field) {
    c(paste0(field, "_between_z"), paste0(field, "_within_z"))
  }))
  already_split <- all(split_fields %in% names(features))
  prepared <- if (already_split) features else {
    split_multivariate_plotyear_features(features, fields)
  }
  prepared$omgevingsjaar <- as.integer(prepared$jaar)
  prepared$jaar <- prepared$omgevingsjaar + lag_years
  joined <- merge(
    base_population, prepared, by = c("plot_id", "jaar"),
    all = FALSE, sort = FALSE, suffixes = c("", "_omgeving")
  )
  joined <- prepare_joined_vegetation_population(joined, lag_years)
  list(
    data = joined,
    row_hash = row_set_sha256(joined$row_id),
    fields = fields,
    lag_years = lag_years,
    excluded_species = exclusions
  )
}

environment_model_formulas <- function(block, fields, data = NULL) {
  if (!nzchar(block) || !length(fields)) stop("Omgevingsblok en kenmerken zijn verplicht.", call. = FALSE)
  base <- targeted_habitat_formulas(data)[["basis"]]
  terms <- unlist(lapply(fields, function(field) {
    paste0(field, c("_between_z", "_within_z"))
  }))
  environment <- stats::update.formula(
    base,
    stats::as.formula(paste(
      "~ . +", paste(terms, collapse = " + "),
      "+ (0 +", paste(terms, collapse = " + "), "|| soort_factor)"
    ))
  )
  out <- list(basis = base, omgeving = environment)
  attr(out, "structureel_weggelaten") <- attr(targeted_habitat_formulas(data), "structureel_weggelaten")
  out
}

environment_required_fields <- function(fields) {
  c(
    "row_id", "count", "jaar_decennium", "analyse_bron_factor",
    "log_oppervlakte_km2", "soort_factor", "soort_plot_factor", "jaar_factor",
    "plotjaar_factor", "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z",
    "inspanning_duur_z", "inspanning_ongunstig_z", "inspanning_ongunstig_bekend",
    weather_model_fields(),
    unlist(lapply(fields, function(field) paste0(field, c("_between_z", "_within_z"))))
  )
}

fit_environment_pair <- function(data, block, fields, analysis_id, checkpoint_dir) {
  required <- environment_required_fields(fields)
  require_prepare_fields(data, required, paste0(block, "-modelpopulatie"))
  model_data <- droplevels(data[stats::complete.cases(data[required]), , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete modelrijen voor ", analysis_id, ".", call. = FALSE)
  formulas <- environment_model_formulas(block, fields, model_data)
  models <- lapply(names(formulas), function(name) {
    fit_glmmtmb_safely(
      formulas[[name]], model_data, paste(analysis_id, name, sep = "__"), checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  comparison <- do.call(rbind, Map(fit_summary_row, names(models), models))
  comparison$analysis_id <- analysis_id
  comparison$blok <- block
  comparison$structureel_weggelaten <- paste(
    attr(formulas, "structureel_weggelaten"), collapse = "; "
  )
  list(models = models, comparison = comparison, data = model_data, fields = fields)
}

extract_environment_effects <- function(result, analysis_id) {
  model <- result$models$omgeving
  if (!identical(model$status, "geslaagd") || !file.exists(model$fit_path)) return(data.frame())
  fit <- readRDS(model$fit_path)
  coefficients <- summary(fit)$coefficients$cond
  terms <- intersect(
    c(
      unlist(lapply(result$fields, function(field) paste0(field, c("_between_z", "_within_z")))),
      weather_model_fields()
    ),
    rownames(coefficients)
  )
  out <- data.frame(
    analysis_id = analysis_id, term = terms,
    beta = coefficients[terms, "Estimate"],
    standaardfout = coefficients[terms, "Std. Error"],
    z = coefficients[terms, "z value"],
    p = coefficients[terms, "Pr(>|z|)"],
    ratio_per_sd = exp(coefficients[terms, "Estimate"]),
    basis_status = result$models$basis$status,
    omgeving_status = result$models$omgeving$status,
    vergelijking_geldig = identical(result$models$basis$status, "geslaagd") &&
      identical(result$models$omgeving$status, "geslaagd"),
    stringsAsFactors = FALSE
  )
  rm(fit)
  gc(verbose = FALSE)
  out
}

extract_environment_species_effects <- function(result, analysis_id, species_lookup) {
  model <- result$models$omgeving
  if (!identical(model$status, "geslaagd") || !file.exists(model$fit_path)) return(data.frame())
  fit <- readRDS(model$fit_path)
  fixed <- glmmTMB::fixef(fit)$cond
  random <- tryCatch(glmmTMB::ranef(fit)$cond$soort_factor, error = function(e) NULL)
  if (is.null(random)) return(data.frame())
  rows <- do.call(rbind, lapply(result$fields, function(field) {
    between <- paste0(field, "_between_z")
    within <- paste0(field, "_within_z")
    if (!all(c(between, within) %in% names(random))) return(NULL)
    data.frame(
      analysis_id = analysis_id,
      soort_id = as.integer(rownames(random)),
      predictor = field,
      beta_tussen_plots = unname(fixed[[between]]) + random[[between]],
      beta_binnen_plot = unname(fixed[[within]]) + random[[within]],
      basis_status = result$models$basis$status,
      omgeving_status = result$models$omgeving$status,
      vergelijking_geldig = identical(result$models$basis$status, "geslaagd") &&
        identical(result$models$omgeving$status, "geslaagd"),
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(rows) || !nrow(rows)) return(data.frame())
  rows <- merge(
    rows, unique(species_lookup[c("soort_id", "soort_naam")]),
    by = "soort_id", all.x = TRUE, sort = FALSE
  )
  rows$ratio_tussen_plots_per_sd <- exp(rows$beta_tussen_plots)
  rows$ratio_binnen_plot_per_sd <- exp(rows$beta_binnen_plot)
  rm(fit)
  gc(verbose = FALSE)
  rows[order(rows$analysis_id, rows$predictor, rows$soort_id), , drop = FALSE]
}

environment_temporal_design <- function(data, train_end, test_start) {
  require_prepare_fields(data, c("omgevingsjaar", "jaar"), "omgevingsmodel")
  train_rows <- data$omgevingsjaar <= as.integer(train_end)
  test_rows <- data$omgevingsjaar >= as.integer(test_start)
  list(
    uitvoerbaar = any(train_rows) && any(test_rows) &&
      length(unique(data$omgevingsjaar[train_rows])) >= 2L &&
      length(unique(data$omgevingsjaar[test_rows])) >= 1L,
    train_rows = train_rows,
    test_rows = test_rows,
    train_jaren = sort(unique(data$omgevingsjaar[train_rows])),
    test_jaren = sort(unique(data$omgevingsjaar[test_rows])),
    reden = if (any(train_rows) && any(test_rows)) "" else "Leeg trainings- of tijdstoetsblok."
  )
}

capture_environment_prediction <- function(fun) {
  tryCatch(
    list(status = "geslaagd", waarde = fun(), fout = ""),
    error = function(error) list(
      status = "mislukt", waarde = NULL,
      fout = trimws(gsub("[[:space:]]+", " ", conditionMessage(error)))
    )
  )
}

environment_validation_fold <- function(
    data, block, fields, analysis_id, validation_type, fold_id,
    train_rows, test_rows, checkpoint_dir) {
  train <- droplevels(data[train_rows, , drop = FALSE])
  test <- data[test_rows, , drop = FALSE]
  if (!nrow(train) || !nrow(test)) return(targeted_validation_failure(
    validation_type, fold_id, analysis_id, train, test, "Leeg trainings- of validatieblok."
  ))
  result <- fit_environment_pair(
    train, block, fields,
    paste("validatie", validation_type, fold_id, analysis_id, sep = "__"),
    checkpoint_dir
  )
  invalid <- names(result$models)[vapply(
    result$models, function(x) !identical(x$status, "geslaagd"), logical(1)
  )]
  if (length(invalid)) {
    messages <- vapply(result$models[invalid], targeted_failure_message, character(1))
    return(targeted_validation_failure(
      validation_type, fold_id, analysis_id, train, test,
      paste(paste(invalid, messages, sep = ": "), collapse = " | ")
    ))
  }
  predictions <- capture_environment_prediction(function() list(
    basis = targeted_prediction_values(result$models$basis, test),
    environment = targeted_prediction_values(result$models$omgeving, test)
  ))
  if (!identical(predictions$status, "geslaagd")) {
    return(targeted_validation_failure(
      validation_type, fold_id, analysis_id, train, test,
      paste0("Voorspelling niet uitvoerbaar: ", predictions$fout)
    ))
  }
  basis <- predictions$waarde$basis
  environment <- predictions$waarde$environment
  comparison <- compare_prediction_scores(
    score_count_predictions(test$count, basis$mu, basis$theta),
    score_count_predictions(test$count, environment$mu, environment$theta)
  )
  data.frame(
    validatie = validation_type, fold_id = fold_id, blok = analysis_id,
    status = "geslaagd", fout = "", n_train = nrow(train), n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id), test_row_hash = row_set_sha256(test$row_id),
    n = comparison$n, delta_mean_log_score = comparison$delta_mean_log_score,
    delta_mae = comparison$delta_mae, delta_rmse = comparison$delta_rmse,
    stringsAsFactors = FALSE
  )
}

run_environment_validation <- function(
    data, block, fields, analysis_id, checkpoint_dir,
    train_end, test_start, spatial_k = 5L, seed = 20261012L) {
  folds <- make_spatial_folds(unique(data[c("plot_id", "jaar")]), spatial_k, seed)
  rows <- lapply(unique(folds$fold_id), function(fold_id) {
    test_plots <- folds$plot_id[folds$fold_id == fold_id]
    environment_validation_fold(
      data, block, fields, analysis_id, "ruimte", fold_id,
      !data$plot_id %in% test_plots, data$plot_id %in% test_plots,
      checkpoint_dir
    )
  })
  design <- environment_temporal_design(data, train_end, test_start)
  rows[[length(rows) + 1L]] <- if (design$uitvoerbaar) {
    environment_validation_fold(
      data, block, fields, analysis_id, "tijd",
      paste0("tot_", train_end, "_vanaf_", test_start),
      design$train_rows, design$test_rows, checkpoint_dir
    )
  } else {
    targeted_validation_failure(
      "tijd", paste0("tot_", train_end, "_vanaf_", test_start), analysis_id,
      data[design$train_rows, , drop = FALSE], data[design$test_rows, , drop = FALSE],
      design$reden, status = "niet_uitvoerbaar"
    )
  }
  do.call(rbind, rows)
}

summarise_environment_group_effects <- function(species_effects, memberships, definitions) {
  if (!nrow(species_effects) || !nrow(memberships)) return(data.frame())
  require_prepare_fields(memberships, c("groep_type", "groep_id", "soort_id", "gewicht"), "groepskoppeling")
  require_prepare_fields(definitions, c("groep_type", "groep_id", "groep_naam"), "groepsdefinitie")
  joined <- merge(species_effects, memberships, by = "soort_id", all = FALSE)
  if (!nrow(joined)) return(data.frame())
  keys <- c("analysis_id", "predictor", "groep_type", "groep_id")
  split_rows <- split(joined, interaction(joined[keys], drop = TRUE, lex.order = TRUE))
  out <- do.call(rbind, lapply(split_rows, function(current) {
    weights <- as.numeric(current$gewicht)
    data.frame(
      analysis_id = current$analysis_id[[1L]], predictor = current$predictor[[1L]],
      groep_type = current$groep_type[[1L]], groep_id = current$groep_id[[1L]],
      soorten = length(unique(current$soort_id)), gewicht_som = sum(weights),
      beta_tussen_plots = stats::weighted.mean(current$beta_tussen_plots, weights),
      beta_binnen_plot = stats::weighted.mean(current$beta_binnen_plot, weights),
      basis_status = current$basis_status[[1L]],
      omgeving_status = current$omgeving_status[[1L]],
      vergelijking_geldig = all(current$vergelijking_geldig),
      stringsAsFactors = FALSE
    )
  }))
  out <- merge(out, definitions, by = c("groep_type", "groep_id"), all.x = TRUE)
  out$ratio_tussen_plots_per_sd <- exp(out$beta_tussen_plots)
  out$ratio_binnen_plot_per_sd <- exp(out$beta_binnen_plot)
  out[order(out$groep_type, out$groep_id, out$analysis_id, out$predictor), , drop = FALSE]
}
