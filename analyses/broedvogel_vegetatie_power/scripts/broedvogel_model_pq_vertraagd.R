pq_delayed_repo <- function() {
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

.pq_delayed_repo <- pq_delayed_repo()
source(file.path(
  .pq_delayed_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_habitatgericht.R"
))

pq_gradient_names <- function() {
  c(
    "open_pionier", "duingrasland_mos_korstmos", "nat_riet",
    "struweel_ruigte", "bomen_bos"
  )
}

pq_delayed_relation_specifications <- function() {
  community <- data.frame(
    analysis_id = paste0("gemeenschap_", pq_gradient_names()),
    relation_type = "gemeenschap", group_type = "gemeenschap",
    group_id = NA_character_, gradient = pq_gradient_names(),
    group_name = "Gehele broedvogelgemeenschap", stringsAsFactors = FALSE
  )
  ecological <- data.frame(
    analysis_id = c(
      "ecologisch_open_pionier", "ecologisch_duingrasland",
      "ecologisch_nat_water", "ecologisch_nat_riet",
      "ecologisch_struweel", "ecologisch_bomen_bosrand",
      "ecologisch_bomen_bos"
    ),
    relation_type = "ecologisch", group_type = "ecologisch",
    group_id = c("300", "300", "100", "200", "600", "700", "800"),
    gradient = c(
      "open_pionier", "duingrasland_mos_korstmos", "nat_riet", "nat_riet",
      "struweel_ruigte", "bomen_bos", "bomen_bos"
    ),
    group_name = c(
      "Vogels van pionierbegroeiingen", "Vogels van pionierbegroeiingen",
      "Watervogels", "Rietvogels", "Struweelvogels", "Bosrandvogels", "Bosvogels"
    ), stringsAsFactors = FALSE
  )
  functional <- data.frame(
    analysis_id = c(
      "functioneel_open_grondbroeders", "functioneel_gras_bodemfoerageerders",
      "functioneel_nat_langeafstand", "functioneel_struweel_langeafstand",
      "functioneel_bos_holenbroeders"
    ),
    relation_type = "functioneel", group_type = "functioneel",
    group_id = c("3", "1", "5", "5", "4"),
    gradient = pq_gradient_names(),
    group_name = c(
      "Grondbroeders", "Bodemfoeragerende insecteneters",
      "Langeafstandstrekkers", "Langeafstandstrekkers", "Holenbroeders"
    ), stringsAsFactors = FALSE
  )
  out <- rbind(community, ecological, functional)
  rownames(out) <- NULL
  out
}

require_delayed_fields <- function(data, fields, label) {
  missing <- setdiff(fields, names(data))
  if (length(missing)) {
    stop(label, " mist veld(en): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

assign_latest_pq_interval <- function(birds, intervals, max_lag = 15L) {
  require_delayed_fields(birds, c("row_id", "plot_id", "jaar"), "vogelpopulatie")
  require_delayed_fields(
    intervals,
    c("plot_id", "start_year", "end_year", "interval_years",
      paste0(pq_gradient_names(), "_change_per_year")),
    "PQ-intervallen"
  )
  max_lag <- as.integer(max_lag)
  if (length(max_lag) != 1L || is.na(max_lag) || max_lag < 0L || max_lag > 15L) {
    stop("Maximale PQ-vertraging moet tussen 0 en 15 jaar liggen.", call. = FALSE)
  }
  joined <- merge(birds, intervals, by = "plot_id", all = FALSE, sort = FALSE)
  joined$lag_years <- as.integer(joined$jaar) - as.integer(joined$end_year)
  joined <- joined[joined$lag_years >= 0L & joined$lag_years <= max_lag, , drop = FALSE]
  joined <- joined[order(joined$row_id, -joined$end_year, joined$start_year), , drop = FALSE]
  joined <- joined[!duplicated(joined$row_id), , drop = FALSE]
  names(joined)[names(joined) == "start_year"] <- "interval_start_year"
  names(joined)[names(joined) == "end_year"] <- "interval_end_year"
  joined$event_id <- paste(joined$plot_id, joined$interval_end_year, sep = ":")
  rownames(joined) <- NULL
  joined
}

constant_value <- function(x, label) {
  values <- unique(x[!is.na(x)])
  if (length(values) != 1L) stop(label, " is niet constant binnen plotjaar.", call. = FALSE)
  values[[1L]]
}

build_delayed_relation_population <- function(assigned, specification, memberships) {
  if (nrow(specification) != 1L) stop("Exact één relatiespecificatie vereist.", call. = FALSE)
  required <- c(
    "row_id", "soort_id", "plot_id", "jaar", "count", "interval_start_year",
    "interval_end_year", "interval_years", "lag_years", "event_id",
    "jaar_decennium", "analyse_bron_factor", "tellerteam_factor",
    "ervaring_plot_z", "ervaring_elders_z", "log_oppervlakte_km2",
    "inspanning_duur_z", "inspanning_ongunstig_z", "inspanning_ongunstig_bekend"
  )
  require_delayed_fields(assigned, required, "gekoppelde vogelpopulatie")
  gradient_field <- paste0(specification$gradient[[1L]], "_change_per_year")
  require_delayed_fields(assigned, gradient_field, "gekoppelde vogelpopulatie")
  selected <- assigned
  if (specification$group_type[[1L]] != "gemeenschap") {
    require_delayed_fields(
      memberships, c("group_type", "group_id", "soort_id"), "vogelgroepskoppelingen"
    )
    species <- unique(as.integer(memberships$soort_id[
      memberships$group_type == specification$group_type[[1L]] &
        memberships$group_id == specification$group_id[[1L]]
    ]))
    selected <- selected[selected$soort_id %in% species, , drop = FALSE]
  }
  if (!nrow(selected)) return(data.frame())
  selected <- selected[order(selected$plot_id, selected$jaar, selected$soort_id), , drop = FALSE]
  keys <- paste(selected$plot_id, selected$jaar, selected$interval_end_year, sep = ":")
  groups <- split(seq_len(nrow(selected)), keys)
  carry <- c(
    "plot_id", "jaar", "interval_start_year", "interval_end_year", "interval_years",
    "lag_years", "event_id", "jaar_decennium", "tellerteam_factor",
    "ervaring_plot_z", "ervaring_elders_z",
    "log_oppervlakte_km2", "inspanning_duur_z", "inspanning_ongunstig_z",
    "inspanning_ongunstig_bekend", gradient_field
  )
  weather <- intersect(weather_model_fields(), names(selected))
  carry <- c(carry, weather)
  rows <- lapply(groups, function(indices) {
    current <- selected[indices, , drop = FALSE]
    values <- lapply(carry, function(field) constant_value(current[[field]], field))
    names(values) <- carry
    out <- as.data.frame(values, stringsAsFactors = FALSE)
    sources <- sort(unique(as.character(current$analyse_bron_factor)))
    sources <- sources[!is.na(sources) & nzchar(sources)]
    out$analyse_bron_factor <- if (length(sources) == 1L) sources else "gemengd"
    out$total_count <- sum(as.numeric(current$count), na.rm = TRUE)
    out$richness <- sum(as.numeric(current$count) > 0, na.rm = TRUE)
    out$n_species <- length(unique(current$soort_id))
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out$analysis_id <- specification$analysis_id[[1L]]
  out$relation_type <- specification$relation_type[[1L]]
  out$group_type <- specification$group_type[[1L]]
  out$group_id <- specification$group_id[[1L]]
  out$group_name <- specification$group_name[[1L]]
  out$gradient <- specification$gradient[[1L]]
  out$change_pp <- 100 * as.numeric(out[[gradient_field]])
  out$lag15 <- as.numeric(out$lag_years) / 15
  out$change_pp_sq <- out$change_pp^2
  out$lag15_sq <- out$lag15^2
  out$richness_absent <- out$n_species - out$richness
  out$plot_factor <- factor(out$plot_id)
  out$year_factor <- factor(out$jaar)
  out$analyse_bron_factor <- factor(out$analyse_bron_factor)
  out$tellerteam_factor <- factor(out$tellerteam_factor)
  out$row_id <- paste(
    out$analysis_id, out$plot_id, out$jaar, out$interval_end_year, sep = ":"
  )
  out <- out[order(out$plot_id, out$jaar), , drop = FALSE]
  rownames(out) <- NULL
  out
}

formula_terms_if_usable <- function(data, fields) {
  fields[vapply(fields, function(field) {
    if (!field %in% names(data)) return(FALSE)
    values <- data[[field]]
    sum(is.finite(suppressWarnings(as.numeric(values)))) > 1L &&
      length(unique(values[!is.na(values)])) > 1L
  }, logical(1))]
}

random_term_if_usable <- function(data, field) {
  if (!field %in% names(data) || length(unique(data[[field]][!is.na(data[[field]])])) < 2L) {
    return(character())
  }
  paste0("(1 | ", field, ")")
}

delayed_model_formulas <- function(response_type = c("territoria", "aanwezigheid"), data) {
  response_type <- match.arg(response_type)
  response <- if (response_type == "territoria") {
    "total_count"
  } else {
    "cbind(richness, richness_absent)"
  }
  fixed <- c("jaar_decennium", "ervaring_plot_z", "ervaring_elders_z")
  if (response_type == "aanwezigheid") fixed <- c(fixed, "log_oppervlakte_km2")
  fixed <- c(
    fixed,
    formula_terms_if_usable(data, c(
      "analyse_bron_factor", "inspanning_duur_z", "inspanning_ongunstig_z",
      "inspanning_ongunstig_bekend", weather_model_fields()
    ))
  )
  random <- unlist(lapply(
    c("plot_factor", "year_factor", "tellerteam_factor"),
    function(field) random_term_if_usable(data, field)
  ))
  offset <- if (response_type == "territoria") "offset(log_oppervlakte_km2)" else character()
  rhs <- paste(c(fixed, random, offset), collapse = " + ")
  basis <- stats::as.formula(paste(response, "~", rhs))
  linear <- stats::update.formula(basis, ~ . + change_pp * lag15)
  nonlinear <- stats::update.formula(
    basis,
    ~ . + change_pp + change_pp_sq + lag15 + lag15_sq +
      change_pp:lag15 + change_pp_sq:lag15 +
      change_pp:lag15_sq + change_pp_sq:lag15_sq
  )
  list(basis = basis, lineair = linear, niet_lineair = nonlinear)
}

select_nonoverlapping_large_events <- function(
    events, lower_relative_year = -3L, upper_relative_year = 15L) {
  require_delayed_fields(events, c("plot_id", "interval_end_year", "change_pp"), "gebeurtenissen")
  lower_relative_year <- as.integer(lower_relative_year)
  upper_relative_year <- as.integer(upper_relative_year)
  if (lower_relative_year >= 0L || upper_relative_year < 0L) {
    stop("Gebeurtenisvenster moet jaren voor en na de verandering bevatten.", call. = FALSE)
  }
  ordered <- events[order(
    events$plot_id, -abs(events$change_pp), events$interval_end_year
  ), , drop = FALSE]
  kept <- logical(nrow(ordered))
  by_plot <- split(seq_len(nrow(ordered)), ordered$plot_id)
  for (indices in by_plot) {
    occupied <- integer()
    for (index in indices) {
      years <- seq.int(
        ordered$interval_end_year[[index]] + lower_relative_year,
        ordered$interval_end_year[[index]] + upper_relative_year
      )
      if (!length(intersect(years, occupied))) {
        kept[[index]] <- TRUE
        occupied <- c(occupied, years)
      }
    }
  }
  out <- ordered[kept, , drop = FALSE]
  out <- out[order(out$plot_id, out$interval_end_year), , drop = FALSE]
  rownames(out) <- NULL
  out
}

fit_delayed_model_set <- function(
    data, response_type = c("territoria", "aanwezigheid"), analysis_id,
    checkpoint_dir) {
  response_type <- match.arg(response_type)
  formulas <- delayed_model_formulas(response_type, data)
  required <- unique(unlist(lapply(formulas, all.vars)))
  required <- unique(c("row_id", required))
  require_delayed_fields(data, required, "vertraagde modelpopulatie")
  complete <- stats::complete.cases(data[required])
  model_data <- droplevels(data[complete, , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete vertraagde modelrijen.", call. = FALSE)
  family <- if (response_type == "territoria") {
    glmmTMB::nbinom2(link = "log")
  } else {
    stats::binomial(link = "logit")
  }
  family_label <- if (response_type == "territoria") "nbinom2" else "binomial"
  models <- lapply(names(formulas), function(model_name) {
    fit_glmmtmb_safely(
      formulas[[model_name]], model_data,
      paste(analysis_id, response_type, model_name, sep = "__"),
      checkpoint_dir, family = family, family_label = family_label
    )
  })
  names(models) <- names(formulas)
  hashes <- vapply(models, function(result) result$diagnostics$row_hash, character(1))
  if (length(unique(hashes)) != 1L) {
    stop("De drie modellen gebruiken niet exact dezelfde responsrijen.", call. = FALSE)
  }
  comparison <- do.call(rbind, Map(fit_summary_row, names(models), models))
  comparison$analysis_id <- analysis_id
  comparison$response_type <- response_type
  comparison <- comparison[c(
    "analysis_id", "response_type", setdiff(
      names(comparison), c("analysis_id", "response_type")
    )
  )]
  list(
    data = model_data, formulas = formulas, models = models,
    comparison = comparison, row_hash = hashes[[1L]]
  )
}

score_delayed_predictions <- function(
    observed, predicted, response_type = c("territoria", "aanwezigheid"),
    theta = NA_real_, trials = NULL) {
  response_type <- match.arg(response_type)
  predicted <- as.numeric(predicted)
  if (response_type == "territoria") {
    score <- score_count_predictions(observed, predicted, theta)
    return(score[c("mean_log_score", "mae", "rmse")])
  }
  observed <- as.numeric(observed)
  trials <- as.numeric(trials)
  valid <- is.finite(observed) & is.finite(trials) & trials > 0 &
    is.finite(predicted) & predicted > 0 & predicted < 1
  if (!any(valid)) stop("Aanwezigheidsvoorspelling bevat geen geldige rijen.", call. = FALSE)
  proportion <- observed[valid] / trials[valid]
  predicted <- pmin(pmax(predicted[valid], 1e-8), 1 - 1e-8)
  data.frame(
    mean_log_score = mean(stats::dbinom(
      observed[valid], size = trials[valid], prob = predicted, log = TRUE
    )),
    mae = mean(abs(proportion - predicted)),
    rmse = sqrt(mean((proportion - predicted)^2)),
    stringsAsFactors = FALSE
  )
}

compare_three_prediction_scores <- function(base_score, linear_score, nonlinear_score) {
  stopifnot(nrow(base_score) == 1L, nrow(linear_score) == 1L, nrow(nonlinear_score) == 1L)
  data.frame(
    niet_lineair_vs_basis_logscore = nonlinear_score$mean_log_score - base_score$mean_log_score,
    niet_lineair_vs_lineair_logscore = nonlinear_score$mean_log_score - linear_score$mean_log_score,
    niet_lineair_vs_basis_mae = base_score$mae - nonlinear_score$mae,
    niet_lineair_vs_lineair_mae = linear_score$mae - nonlinear_score$mae,
    niet_lineair_vs_basis_rmse = base_score$rmse - nonlinear_score$rmse,
    niet_lineair_vs_lineair_rmse = linear_score$rmse - nonlinear_score$rmse,
    stringsAsFactors = FALSE
  )
}

decide_delayed_predictive_value <- function(validation) {
  required <- c(
    "validation_type", "status", "niet_lineair_vs_basis_logscore",
    "niet_lineair_vs_lineair_logscore"
  )
  require_delayed_fields(validation, required, "vertraagde validatie")
  spatial <- validation[
    validation$validation_type == "ruimte" & validation$status == "geslaagd",
    , drop = FALSE
  ]
  temporal <- validation[
    validation$validation_type == "tijd" & validation$status == "geslaagd",
    , drop = FALSE
  ]
  share_base <- if (nrow(spatial)) {
    mean(spatial$niet_lineair_vs_basis_logscore > 0)
  } else NA_real_
  share_linear <- if (nrow(spatial)) {
    mean(spatial$niet_lineair_vs_lineair_logscore > 0)
  } else NA_real_
  time_base <- if (nrow(temporal)) temporal$niet_lineair_vs_basis_logscore[[1L]] else NA_real_
  time_linear <- if (nrow(temporal)) temporal$niet_lineair_vs_lineair_logscore[[1L]] else NA_real_
  checks <- c(
    vijf_ruimtelijke_blokken_geldig = nrow(spatial) == 5L,
    ruimtelijk_beter_dan_basis = is.finite(share_base) && share_base >= 0.6,
    ruimtelijk_beter_dan_lineair = is.finite(share_linear) && share_linear >= 0.6,
    later_beter_dan_basis = is.finite(time_base) && time_base > 0,
    later_beter_dan_lineair = is.finite(time_linear) && time_linear > 0
  )
  list(
    decision = if (all(checks)) {
      "voorspellende_meerwaarde"
    } else {
      "geen_bestendige_voorspellende_meerwaarde"
    },
    reason = paste(names(checks)[!checks], collapse = "; "),
    spatial_share_better_than_base = share_base,
    spatial_share_better_than_linear = share_linear,
    temporal_delta_vs_base = time_base,
    temporal_delta_vs_linear = time_linear
  )
}

large_change_threshold <- function(change_pp) {
  values <- abs(as.numeric(change_pp))
  values <- values[is.finite(values) & values > 0]
  if (!length(values)) return(NA_real_)
  unname(stats::quantile(values, probs = 0.75, type = 1, names = FALSE))
}

delayed_validation_failure <- function(
    validation_type, fold_id, analysis_id, response_type, train, test, message,
    model_status = "modeluitval") {
  data.frame(
    validation_type = validation_type, fold_id = fold_id,
    analysis_id = analysis_id, response_type = response_type,
    status = model_status, reason = message,
    n_train = nrow(train), n_test = nrow(test),
    train_row_hash = if (nrow(train)) row_set_sha256(train$row_id) else NA_character_,
    test_row_hash = if (nrow(test)) row_set_sha256(test$row_id) else NA_character_,
    basis_status = NA_character_, lineair_status = NA_character_,
    niet_lineair_status = NA_character_,
    niet_lineair_vs_basis_logscore = NA_real_,
    niet_lineair_vs_lineair_logscore = NA_real_,
    niet_lineair_vs_basis_mae = NA_real_,
    niet_lineair_vs_lineair_mae = NA_real_,
    niet_lineair_vs_basis_rmse = NA_real_,
    niet_lineair_vs_lineair_rmse = NA_real_,
    stringsAsFactors = FALSE
  )
}

score_delayed_fit <- function(result, test, response_type) {
  if (!identical(result$status, "geslaagd") || !file.exists(result$fit_path)) {
    stop("Validatiemodel is niet geldig geschat.", call. = FALSE)
  }
  fit <- readRDS(result$fit_path)
  predicted <- stats::predict(
    fit, newdata = test, type = "response", re.form = NA,
    allow.new.levels = TRUE
  )
  score <- if (response_type == "territoria") {
    score_delayed_predictions(
      test$total_count, predicted, response_type, theta = stats::sigma(fit)
    )
  } else {
    score_delayed_predictions(
      test$richness, predicted, response_type, trials = test$n_species
    )
  }
  rm(fit)
  gc(verbose = FALSE)
  score
}

fit_delayed_validation_fold <- function(
    data, response_type, analysis_id, validation_type, fold_id,
    train_rows, test_rows, checkpoint_dir) {
  train <- droplevels(data[train_rows, , drop = FALSE])
  test <- data[test_rows, , drop = FALSE]
  if (!nrow(train) || !nrow(test)) {
    return(delayed_validation_failure(
      validation_type, fold_id, analysis_id, response_type, train, test,
      "Leeg trainings- of validatieblok.", "niet_uitvoerbaar"
    ))
  }
  if (length(intersect(train$row_id, test$row_id))) {
    stop("Training en validatie overlappen.", call. = FALSE)
  }
  fit <- fit_delayed_model_set(
    train, response_type,
    paste("validatie", validation_type, fold_id, analysis_id, sep = "__"),
    checkpoint_dir
  )
  statuses <- vapply(fit$models, `[[`, character(1), "status")
  if (any(statuses != "geslaagd")) {
    out <- delayed_validation_failure(
      validation_type, fold_id, analysis_id, response_type, train, test,
      paste(names(statuses)[statuses != "geslaagd"], collapse = "; ")
    )
    out$basis_status <- statuses[["basis"]]
    out$lineair_status <- statuses[["lineair"]]
    out$niet_lineair_status <- statuses[["niet_lineair"]]
    return(out)
  }
  scores <- lapply(fit$models, score_delayed_fit, test = test, response_type = response_type)
  comparison <- compare_three_prediction_scores(
    scores$basis, scores$lineair, scores$niet_lineair
  )
  data.frame(
    validation_type = validation_type, fold_id = fold_id,
    analysis_id = analysis_id, response_type = response_type,
    status = "geslaagd", reason = "", n_train = nrow(train), n_test = nrow(test),
    train_row_hash = row_set_sha256(train$row_id),
    test_row_hash = row_set_sha256(test$row_id),
    basis_status = statuses[["basis"]], lineair_status = statuses[["lineair"]],
    niet_lineair_status = statuses[["niet_lineair"]],
    comparison, stringsAsFactors = FALSE
  )
}

run_delayed_blocked_validation <- function(
    data, response_type, analysis_id, checkpoint_dir, spatial_k = 5L,
    temporal_cut_year = 2018L, seed = 20261028L) {
  plotyears <- unique(data[c("plot_id", "jaar")])
  spatial <- make_spatial_folds(plotyears, spatial_k, seed)
  rows <- lapply(unique(spatial$fold_id), function(fold_id) {
    test_plots <- spatial$plot_id[spatial$fold_id == fold_id]
    test_rows <- data$plot_id %in% test_plots
    fit_delayed_validation_fold(
      data, response_type, analysis_id, "ruimte", fold_id,
      !test_rows, test_rows, checkpoint_dir
    )
  })
  train_rows <- data$jaar < temporal_cut_year
  test_rows <- data$jaar >= temporal_cut_year
  rows[[length(rows) + 1L]] <- fit_delayed_validation_fold(
    data, response_type, analysis_id, "tijd", paste0("tijd_vanaf_", temporal_cut_year),
    train_rows, test_rows, checkpoint_dir
  )
  do.call(rbind, rows)
}

delayed_change_directions <- function(change_pp) {
  values <- as.numeric(change_pp)
  negative <- values[is.finite(values) & values < 0]
  positive <- values[is.finite(values) & values > 0]
  rows <- list()
  if (length(negative)) rows$afname <- data.frame(
    direction = "afname",
    change_pp = stats::median(negative),
    stringsAsFactors = FALSE
  )
  if (length(positive)) rows$toename <- data.frame(
    direction = "toename",
    change_pp = stats::median(positive),
    stringsAsFactors = FALSE
  )
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

gate_delayed_decision_by_effect_status <- function(decision, effect_status) {
  if (!identical(decision, "voorspellende_meerwaarde")) return(decision)
  if (!length(effect_status) || any(effect_status != "geslaagd")) {
    return("voorspellende_meerwaarde_onzekerheid_ongeldig")
  }
  decision
}

bind_nonempty_data_frames <- function(items) {
  items <- items[vapply(items, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(items)) return(data.frame())
  do.call(rbind, items)
}

representative_delayed_newdata <- function(data, change_pp, lags = 0:15) {
  base <- data[rep(1L, length(lags)), , drop = FALSE]
  base$lag_years <- as.integer(lags)
  base$lag15 <- base$lag_years / 15
  base$lag15_sq <- base$lag15^2
  base$change_pp <- as.numeric(change_pp)
  base$change_pp_sq <- base$change_pp^2
  numeric_controls <- intersect(c(
    "jaar_decennium", "ervaring_plot_z", "ervaring_elders_z",
    "log_oppervlakte_km2", "inspanning_duur_z", "inspanning_ongunstig_z",
    weather_model_fields()
  ), names(base))
  for (field in numeric_controls) {
    value <- stats::median(as.numeric(data[[field]]), na.rm = TRUE)
    if (is.finite(value)) base[[field]] <- value
  }
  base
}

prediction_covariance_status <- function(covariance) {
  covariance <- as.matrix(covariance)
  if (!nrow(covariance) || nrow(covariance) != ncol(covariance)) {
    return(list(status = "ongeldige_onzekerheid", reason = "Voorspelcovariantie is niet vierkant."))
  }
  if (!all(is.finite(covariance))) {
    return(list(status = "ongeldige_onzekerheid", reason = "Voorspelcovariantie bevat niet-eindige waarden."))
  }
  eigenvalues <- tryCatch(
    eigen((covariance + t(covariance)) / 2, symmetric = TRUE, only.values = TRUE)$values,
    error = function(error) NA_real_
  )
  if (!all(is.finite(eigenvalues)) || min(eigenvalues) < -1e-7) {
    return(list(status = "ongeldige_onzekerheid", reason = "Voorspelcovariantie is niet positief semidefiniet."))
  }
  list(status = "geslaagd", reason = "")
}

simulate_delayed_effect_curve <- function(
    fit, data, direction, change_pp, response_type, simulations = 1000L,
    seed = 20261028L) {
  lags <- 0:15
  reference <- representative_delayed_newdata(data, 0, lags)
  changed <- representative_delayed_newdata(data, change_pp, lags)
  newdata <- rbind(reference, changed)
  prediction <- stats::predict(
    fit, newdata = newdata, type = "link", re.form = NA,
    allow.new.levels = TRUE, se.fit = TRUE, cov.fit = TRUE
  )
  eta <- as.numeric(prediction$fit)
  covariance <- as.matrix(prediction$cov.fit)
  covariance_status <- prediction_covariance_status(covariance)
  if (!identical(covariance_status$status, "geslaagd")) {
    stop(covariance_status$reason, call. = FALSE)
  }
  set.seed(seed)
  draws <- MASS::mvrnorm(as.integer(simulations), mu = eta, Sigma = covariance)
  n_lag <- length(lags)
  transform_response <- if (response_type == "territoria") exp else stats::plogis
  point_ref <- transform_response(eta[seq_len(n_lag)])
  point_change <- transform_response(eta[n_lag + seq_len(n_lag)])
  draw_ref <- transform_response(draws[, seq_len(n_lag), drop = FALSE])
  draw_change <- transform_response(draws[, n_lag + seq_len(n_lag), drop = FALSE])
  if (response_type == "territoria") {
    point_effect <- point_change / point_ref
    draw_effect <- draw_change / draw_ref
    measure <- "rate_ratio"
  } else {
    point_effect <- (point_change / (1 - point_change)) /
      (point_ref / (1 - point_ref))
    draw_effect <- (draw_change / (1 - draw_change)) /
      (draw_ref / (1 - draw_ref))
    measure <- "odds_ratio"
  }
  curve <- data.frame(
    direction = direction, change_pp = change_pp, lag_years = lags,
    effect_measure = measure, effect = as.numeric(point_effect),
    lower95 = apply(draw_effect, 2L, stats::quantile, probs = 0.025, na.rm = TRUE),
    upper95 = apply(draw_effect, 2L, stats::quantile, probs = 0.975, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  max_index <- which.max(abs(log(curve$effect)))
  windows <- c(3L, 7L, 15L)
  cumulative <- lapply(windows, function(max_lag) {
    indices <- seq_len(max_lag + 1L)
    point <- sum(point_change[indices]) / sum(point_ref[indices])
    simulated <- rowSums(draw_change[, indices, drop = FALSE]) /
      rowSums(draw_ref[, indices, drop = FALSE])
    data.frame(
      window = paste0("0-", max_lag), effect = point,
      lower95 = stats::quantile(simulated, 0.025, na.rm = TRUE),
      upper95 = stats::quantile(simulated, 0.975, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  summary <- data.frame(
    direction = direction, change_pp = change_pp,
    direct_effect = curve$effect[curve$lag_years == 0L],
    direct_lower95 = curve$lower95[curve$lag_years == 0L],
    direct_upper95 = curve$upper95[curve$lag_years == 0L],
    maximum_effect_lag = curve$lag_years[[max_index]],
    maximum_effect = curve$effect[[max_index]],
    effect_at_15 = curve$effect[curve$lag_years == 15L],
    cumulative_0_3 = cumulative[[1L]]$effect,
    cumulative_0_7 = cumulative[[2L]]$effect,
    cumulative_0_15 = cumulative[[3L]]$effect,
    stringsAsFactors = FALSE
  )
  list(curve = curve, summary = summary, cumulative = do.call(rbind, cumulative))
}

extract_delayed_effects <- function(
    fit_result, analysis_id, response_type, simulations = 1000L) {
  nonlinear <- fit_result$models$niet_lineair
  if (!identical(nonlinear$status, "geslaagd") || !file.exists(nonlinear$fit_path)) {
    return(list(curve = data.frame(), summary = data.frame(), cumulative = data.frame()))
  }
  directions <- delayed_change_directions(fit_result$data$change_pp)
  if (!nrow(directions)) {
    return(list(curve = data.frame(), summary = data.frame(), cumulative = data.frame()))
  }
  fit <- readRDS(nonlinear$fit_path)
  results <- lapply(seq_len(nrow(directions)), function(i) {
    tryCatch(
      {
        result <- simulate_delayed_effect_curve(
          fit, fit_result$data, directions$direction[[i]], directions$change_pp[[i]],
          response_type, simulations = simulations,
          seed = 20261028L + i
        )
        result$summary$effect_status <- "geslaagd"
        result$summary$effect_reason <- ""
        result
      },
      error = function(error) list(
        curve = data.frame(), cumulative = data.frame(),
        summary = data.frame(
          direction = directions$direction[[i]], change_pp = directions$change_pp[[i]],
          direct_effect = NA_real_, direct_lower95 = NA_real_, direct_upper95 = NA_real_,
          maximum_effect_lag = NA_integer_, maximum_effect = NA_real_,
          effect_at_15 = NA_real_, cumulative_0_3 = NA_real_,
          cumulative_0_7 = NA_real_, cumulative_0_15 = NA_real_,
          effect_status = "ongeldige_onzekerheid",
          effect_reason = conditionMessage(error), stringsAsFactors = FALSE
        )
      )
    )
  })
  add_keys <- function(data) {
    data$analysis_id <- analysis_id
    data$response_type <- response_type
    data[c("analysis_id", "response_type", setdiff(
      names(data), c("analysis_id", "response_type")
    ))]
  }
  rm(fit)
  gc(verbose = FALSE)
  list(
    curve = {
      value <- bind_nonempty_data_frames(lapply(results, `[[`, "curve"))
      if (nrow(value)) add_keys(value) else value
    },
    summary = add_keys(do.call(rbind, lapply(results, `[[`, "summary"))),
    cumulative = {
      value <- bind_nonempty_data_frames(lapply(results, `[[`, "cumulative"))
      if (nrow(value)) add_keys(value) else value
    }
  )
}

build_large_event_analysis <- function(data, analysis_id, response_type) {
  candidates <- unique(data[c(
    "plot_id", "interval_start_year", "interval_end_year", "interval_years", "change_pp"
  )])
  threshold <- large_change_threshold(candidates$change_pp)
  candidates <- candidates[
    is.finite(candidates$change_pp) & abs(candidates$change_pp) >= threshold,
    , drop = FALSE
  ]
  if (!nrow(candidates)) {
    return(list(events = data.frame(), curve = data.frame(), threshold = threshold))
  }
  events <- select_nonoverlapping_large_events(candidates)
  events$event_id_sensitivity <- paste(events$plot_id, events$interval_end_year, sep = ":")
  events$direction <- ifelse(events$change_pp < 0, "afname", "toename")
  expanded <- merge(
    events[c("plot_id", "interval_end_year", "event_id_sensitivity", "direction", "change_pp")],
    data[c("plot_id", "jaar", "total_count", "richness", "n_species")],
    by = "plot_id", all = FALSE, sort = FALSE
  )
  expanded$relative_year <- expanded$jaar - expanded$interval_end_year
  expanded <- expanded[expanded$relative_year >= -3L & expanded$relative_year <= 15L, , drop = FALSE]
  if (anyDuplicated(paste(expanded$plot_id, expanded$jaar))) {
    stop("Een vogelplotjaar is aan meerdere grote gebeurtenissen gekoppeld.", call. = FALSE)
  }
  groups <- split(seq_len(nrow(expanded)), expanded$event_id_sensitivity)
  rows <- lapply(groups, function(indices) {
    current <- expanded[indices, , drop = FALSE]
    baseline <- current[current$relative_year %in% -3:-1, , drop = FALSE]
    if (nrow(baseline) < 2L) return(NULL)
    if (response_type == "territoria") {
      baseline_value <- mean(baseline$total_count)
      current$event_effect <- log((current$total_count + 0.5) / (baseline_value + 0.5))
      measure <- "log_count_ratio"
    } else {
      baseline_value <- mean(baseline$richness / baseline$n_species)
      probability <- current$richness / current$n_species
      bounded <- function(x) pmin(pmax(x, 1e-6), 1 - 1e-6)
      current$event_effect <- stats::qlogis(bounded(probability)) -
        stats::qlogis(bounded(baseline_value))
      measure <- "log_odds_difference"
    }
    current$event_measure <- measure
    current
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(list(events = events, curve = data.frame(), threshold = threshold))
  }
  event_rows <- do.call(rbind, rows)
  curve_groups <- split(
    seq_len(nrow(event_rows)), paste(event_rows$direction, event_rows$relative_year, sep = ":")
  )
  curve <- do.call(rbind, lapply(curve_groups, function(indices) {
    current <- event_rows[indices, , drop = FALSE]
    n <- nrow(current)
    estimate <- mean(current$event_effect)
    standard_error <- if (n > 1L) stats::sd(current$event_effect) / sqrt(n) else NA_real_
    data.frame(
      direction = current$direction[[1L]], relative_year = current$relative_year[[1L]],
      event_measure = current$event_measure[[1L]], n_events = n,
      estimate = estimate, lower95 = estimate - 1.96 * standard_error,
      upper95 = estimate + 1.96 * standard_error, stringsAsFactors = FALSE
    )
  }))
  for (object in c("events", "curve")) {
    value <- get(object)
    value$analysis_id <- analysis_id
    value$response_type <- response_type
    value <- value[c("analysis_id", "response_type", setdiff(
      names(value), c("analysis_id", "response_type")
    ))]
    assign(object, value)
  }
  list(events = events, curve = curve, threshold = threshold)
}
