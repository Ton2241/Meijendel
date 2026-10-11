vegetation_validate_repo <- function() {
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

.vegetation_validate_repo <- vegetation_validate_repo()
source(file.path(
  .vegetation_validate_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_fit.R"
))

make_spatial_folds <- function(plotyears, k = 5L, seed = 20261011L) {
  require_prepare_fields(plotyears, c("plot_id", "jaar"), "plotjaren")
  plots <- sort(unique(as.integer(plotyears$plot_id)))
  k <- as.integer(k)
  if (k < 2L || k > length(plots)) stop("Ongeldig aantal ruimtelijke blokken.", call. = FALSE)
  set.seed(as.integer(seed))
  shuffled <- sample(plots, length(plots), replace = FALSE)
  out <- data.frame(
    plot_id = shuffled,
    fold_id = paste0("ruimte_", rep(seq_len(k), length.out = length(shuffled))),
    stringsAsFactors = FALSE
  )
  out[order(out$fold_id, out$plot_id), , drop = FALSE]
}

make_temporal_folds <- function(plotyears, cut_years = c(2016L, 2021L)) {
  require_prepare_fields(plotyears, c("plot_id", "jaar"), "plotjaren")
  years <- sort(unique(as.integer(plotyears$jaar)))
  cut_years <- sort(unique(as.integer(cut_years)))
  rows <- lapply(cut_years, function(cut_year) {
    training <- years[years < cut_year]
    testing <- years[years >= cut_year]
    if (!length(training) || !length(testing)) return(NULL)
    data.frame(
      fold_id = paste0("tijd_vanaf_", cut_year),
      train_max_year = max(training),
      test_min_year = min(testing),
      test_max_year = max(testing),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out) || !nrow(out)) stop("Geen geldige temporele blokken.", call. = FALSE)
  rownames(out) <- NULL
  out
}

score_count_predictions <- function(observed, predicted, theta) {
  observed <- as.numeric(observed)
  predicted <- pmax(as.numeric(predicted), .Machine$double.eps)
  valid <- is.finite(observed) & is.finite(predicted) & predicted > 0
  if (!is.finite(theta) || theta <= 0 || !any(valid)) {
    stop("Voorspelscore kan niet worden berekend.", call. = FALSE)
  }
  observed <- observed[valid]
  predicted <- predicted[valid]
  data.frame(
    n = length(observed),
    mean_log_score = mean(stats::dnbinom(observed, mu = predicted, size = theta, log = TRUE)),
    mae = mean(abs(observed - predicted)),
    rmse = sqrt(mean((observed - predicted)^2)),
    stringsAsFactors = FALSE
  )
}

compare_prediction_scores <- function(base_score, pq_score) {
  stopifnot(nrow(base_score) == 1L, nrow(pq_score) == 1L)
  data.frame(
    n = base_score$n,
    delta_mean_log_score = pq_score$mean_log_score - base_score$mean_log_score,
    delta_mae = base_score$mae - pq_score$mae,
    delta_rmse = base_score$rmse - pq_score$rmse,
    stringsAsFactors = FALSE
  )
}

predict_validation_model <- function(result, test_data) {
  if (!identical(result$status, "geslaagd") || !file.exists(result$fit_path)) {
    stop("Validatiemodel is niet geldig geschat.", call. = FALSE)
  }
  fit <- readRDS(result$fit_path)
  predicted <- stats::predict(
    fit, newdata = test_data, type = "response", allow.new.levels = TRUE
  )
  theta <- stats::sigma(fit)
  rm(fit)
  gc(verbose = FALSE)
  score_count_predictions(test_data$count, predicted, theta)
}

fit_vegetation_validation_fold <- function(
    data, metric, validation_type, fold_id, train_rows, test_rows, checkpoint_dir) {
  formulas <- vegetation_model_formulas(metric)
  train <- droplevels(data[train_rows, , drop = FALSE])
  test <- data[test_rows, , drop = FALSE]
  if (!nrow(train) || !nrow(test)) stop("Leeg trainings- of validatieblok.", call. = FALSE)
  if (length(intersect(train$row_id, test$row_id))) stop("Training en validatie overlappen.", call. = FALSE)
  models <- lapply(names(formulas), function(model_name) {
    fit_glmmtmb_safely(
      formulas[[model_name]], train,
      paste("validatie", validation_type, fold_id, metric, model_name, sep = "__"),
      checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  scores <- lapply(names(models), function(model_name) {
    score <- predict_validation_model(models[[model_name]], test)
    score$model <- model_name
    score
  })
  names(scores) <- names(models)
  comparison <- compare_prediction_scores(scores$basis, scores$pq)
  comparison$validatie <- validation_type
  comparison$fold_id <- fold_id
  comparison$metric <- metric
  comparison$n_train <- nrow(train)
  comparison$n_test <- nrow(test)
  comparison$train_row_hash <- row_set_sha256(train$row_id)
  comparison$test_row_hash <- row_set_sha256(test$row_id)
  comparison[, c(
    "validatie", "fold_id", "metric", "n_train", "n_test", "train_row_hash",
    "test_row_hash", "n", "delta_mean_log_score", "delta_mae", "delta_rmse"
  )]
}

run_vegetation_blocked_validation <- function(
    data, metric, checkpoint_dir, spatial_k = 5L,
    temporal_cut_years = c(2016L, 2021L), seed = 20261011L) {
  plotyears <- unique(data[c("plot_id", "jaar")])
  spatial <- make_spatial_folds(plotyears, spatial_k, seed)
  temporal <- make_temporal_folds(plotyears, temporal_cut_years)
  rows <- list()
  for (fold_id in unique(spatial$fold_id)) {
    test_plots <- spatial$plot_id[spatial$fold_id == fold_id]
    test_rows <- data$plot_id %in% test_plots
    rows[[length(rows) + 1L]] <- fit_vegetation_validation_fold(
      data, metric, "ruimte", fold_id, !test_rows, test_rows, checkpoint_dir
    )
  }
  for (i in seq_len(nrow(temporal))) {
    fold <- temporal[i, ]
    train_rows <- data$jaar <= fold$train_max_year
    test_rows <- data$jaar >= fold$test_min_year & data$jaar <= fold$test_max_year
    rows[[length(rows) + 1L]] <- fit_vegetation_validation_fold(
      data, metric, "tijd", fold$fold_id, train_rows, test_rows, checkpoint_dir
    )
  }
  do.call(rbind, rows)
}
