args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_validate.R"))

plotyears <- expand.grid(plot_id = 1:6, jaar = 2000:2025, KEEP.OUT.ATTRS = FALSE)
spatial_a <- make_spatial_folds(plotyears, k = 3L, seed = 42L)
spatial_b <- make_spatial_folds(plotyears, k = 3L, seed = 42L)
stopifnot(identical(spatial_a, spatial_b))
stopifnot(length(unique(spatial_a$fold_id)) == 3L)
stopifnot(all(table(spatial_a$plot_id) == 1L))
stopifnot(all(table(spatial_a$fold_id) == 2L))

temporal <- make_temporal_folds(plotyears, cut_years = c(2016L, 2021L))
stopifnot(identical(sort(unique(temporal$fold_id)), c("tijd_vanaf_2016", "tijd_vanaf_2021")))
stopifnot(all(temporal$train_max_year < temporal$test_min_year))

scores <- score_count_predictions(
  observed = c(0, 1, 3),
  predicted = c(0.2, 1.2, 2.5),
  theta = 2
)
stopifnot(scores$n == 3L)
stopifnot(is.finite(scores$mean_log_score))
stopifnot(is.finite(scores$mae))
stopifnot(is.finite(scores$rmse))

comparison <- compare_prediction_scores(
  transform(scores, model = "basis"),
  transform(scores, model = "pq")
)
stopifnot(comparison$delta_mae == 0)
stopifnot(comparison$delta_rmse == 0)
stopifnot(comparison$delta_mean_log_score == 0)

cat("OK: geblokkeerde validatie en voorspelscores\n")
