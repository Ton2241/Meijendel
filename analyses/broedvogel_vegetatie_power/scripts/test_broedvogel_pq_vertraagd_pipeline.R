args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_pq_vertraagd.R"
))

set.seed(20261028L)
n <- 240L
synthetic <- data.frame(
  row_id = paste0("r", seq_len(n)),
  plot_id = rep(1:12, each = 20),
  jaar = rep(2001:2020, 12),
  jaar_decennium = rep((2001:2020 - 2000) / 10, 12),
  change_pp = rep(seq(-4, 4, length.out = 20), 12),
  lag_years = rep(0:15, length.out = n),
  ervaring_plot_z = 0, ervaring_elders_z = 0,
  log_oppervlakte_km2 = 0, inspanning_duur_z = 0,
  inspanning_ongunstig_z = 0, inspanning_ongunstig_bekend = 1,
  analyse_bron_factor = factor("sovon_m"),
  tellerteam_factor = factor(rep(paste0("T", 1:6), length.out = n)),
  stringsAsFactors = FALSE
)
synthetic$lag15 <- synthetic$lag_years / 15
synthetic$change_pp_sq <- synthetic$change_pp^2
synthetic$lag15_sq <- synthetic$lag15^2
synthetic$plot_factor <- factor(synthetic$plot_id)
synthetic$year_factor <- factor(synthetic$jaar)
mu <- exp(1 + 0.035 * synthetic$change_pp_sq - 0.5 * synthetic$lag15_sq)
synthetic$total_count <- stats::rnbinom(n, mu = mu, size = 5)
synthetic$n_species <- 20L
synthetic$richness <- pmin(synthetic$total_count, synthetic$n_species)
synthetic$richness_absent <- synthetic$n_species - synthetic$richness

checkpoint <- tempfile("pq-vertraagd-model-")
dir.create(checkpoint)
Sys.setenv(MEIJENDEL_ANALYSIS_COMMIT = "test-pq-vertraagd")
fit <- fit_delayed_model_set(synthetic, "territoria", "synthetisch", checkpoint)
stopifnot(
  identical(names(fit$models), c("basis", "lineair", "niet_lineair")),
  length(unique(vapply(fit$models, function(x) x$diagnostics$row_hash, character(1)))) == 1L,
  nrow(fit$comparison) == 3L
)

base_score <- data.frame(mean_log_score = -2, mae = 3, rmse = 4)
linear_score <- data.frame(mean_log_score = -1.8, mae = 2.8, rmse = 3.8)
nonlinear_score <- data.frame(mean_log_score = -1.7, mae = 2.7, rmse = 3.7)
comparison <- compare_three_prediction_scores(base_score, linear_score, nonlinear_score)
stopifnot(
  isTRUE(all.equal(comparison$niet_lineair_vs_basis_logscore, 0.3)),
  isTRUE(all.equal(comparison$niet_lineair_vs_lineair_logscore, 0.1)),
  isTRUE(all.equal(comparison$niet_lineair_vs_basis_mae, 0.3))
)

validation <- data.frame(
  validation_type = c(rep("ruimte", 5), "tijd"),
  status = "geslaagd",
  niet_lineair_vs_basis_logscore = c(.2, .1, .1, -.1, .05, .1),
  niet_lineair_vs_lineair_logscore = c(.1, .05, .03, -.2, .01, .02),
  stringsAsFactors = FALSE
)
decision <- decide_delayed_predictive_value(validation)
stopifnot(
  decision$decision == "voorspellende_meerwaarde",
  decision$spatial_share_better_than_base == 0.8,
  decision$spatial_share_better_than_linear == 0.8
)
validation$niet_lineair_vs_lineair_logscore[validation$validation_type == "tijd"] <- -0.01
stopifnot(
  decide_delayed_predictive_value(validation)$decision ==
    "geen_bestendige_voorspellende_meerwaarde"
)

threshold <- large_change_threshold(c(0, -1, 2, -3, 4))
stopifnot(isTRUE(all.equal(threshold, 3)))

bad_covariance <- prediction_covariance_status(matrix(NA_real_, 2, 2))
stopifnot(
  bad_covariance$status == "ongeldige_onzekerheid",
  grepl("niet-eindig", bad_covariance$reason, fixed = TRUE)
)

cat("OK: vertraagde modelset, drieledige voorspellingstoets en besluitregel.\n")
