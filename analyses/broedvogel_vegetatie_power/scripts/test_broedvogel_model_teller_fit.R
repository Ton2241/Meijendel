args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
test_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R"
repo <- normalizePath(file.path(dirname(test_path), "..", "..", ".."), mustWork = TRUE)

Sys.setenv(MEIJENDEL_REPO = repo)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_fit.R"))

formula_text <- function(formula) paste(deparse(formula, width.cutoff = 500L), collapse = " ")

base_formulas <- joint_teller_formulas()
stopifnot(identical(names(base_formulas), c("M0", "M1", "M2")))
base_text <- lapply(base_formulas, formula_text)
stopifnot(
  all(vapply(base_text, grepl, logical(1), pattern = "offset\\(log_oppervlakte_km2\\)")),
  all(vapply(base_text, grepl, logical(1), pattern = "plotjaar_factor", fixed = TRUE)),
  !grepl("tellerteam_factor", base_text$M0, fixed = TRUE),
  grepl("tellerteam_factor", base_text$M1, fixed = TRUE),
  !grepl("ervaring_plot_z", base_text$M1, fixed = TRUE),
  grepl("ervaring_plot_z", base_text$M2, fixed = TRUE),
  grepl("ervaring_elders_z", base_text$M2, fixed = TRUE),
  grepl("|| soort_factor", base_text$M2, fixed = TRUE)
)

effort_formulas <- joint_teller_formulas(
  include_effort = TRUE,
  effort_variable = "inspanning_duur_z"
)
effort_text <- lapply(effort_formulas, formula_text)
stopifnot(all(vapply(effort_text, grepl, logical(1), pattern = "inspanning_duur_z", fixed = TRUE)))

set.seed(20261009)
grid <- expand.grid(
  soort_id = 1:4,
  plot_id = 1:4,
  jaar = 2012:2021,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
grid$team <- paste0("T", (grid$plot_id + grid$jaar) %% 5L)
grid$row_id <- paste(grid$soort_id, grid$plot_id, grid$jaar, sep = ":")
grid$jaar_decennium <- (grid$jaar - 1990) / 10
grid$analyse_bron_factor <- factor(rep(c("sovon_m", "jrvslg_m"), length.out = nrow(grid)))
grid$log_oppervlakte_km2 <- log(c(1, 1.25, 1.5, 2)[grid$plot_id])
grid$soort_factor <- factor(grid$soort_id)
grid$soort_plot_factor <- factor(paste(grid$soort_id, grid$plot_id, sep = ":"))
grid$jaar_factor <- factor(grid$jaar)
grid$plotjaar_factor <- factor(paste(grid$plot_id, grid$jaar, sep = ":"))
grid$tellerteam_factor <- factor(grid$team)
grid$ervaring_plot_mean <- log1p(pmax(0, grid$jaar - 2012))
grid$ervaring_plot_min <- log1p(pmax(0, grid$jaar - 2013))
grid$ervaring_plot_max <- log1p(pmax(0, grid$jaar - 2011))
grid$ervaring_elders_mean <- log1p((grid$jaar + grid$plot_id) %% 5L)
grid$ervaring_elders_min <- log1p((grid$jaar + grid$plot_id) %% 3L)
grid$ervaring_elders_max <- log1p((grid$jaar + grid$plot_id) %% 7L)
grid$inspanning_duur_z <- as.numeric(scale(log1p(300 + 10 * grid$plot_id + grid$jaar %% 4L)))
grid$count <- stats::rnbinom(nrow(grid), mu = exp(1 + 0.08 * grid$jaar_decennium), size = 3)

prepared <- prepare_experience_variant(grid, "mean")
stopifnot(
  identical(prepared$row_id, grid$row_id),
  isTRUE(all.equal(mean(prepared$ervaring_plot_z), 0, tolerance = 1e-12)),
  isTRUE(all.equal(mean(prepared$ervaring_elders_z), 0, tolerance = 1e-12))
)

diagnostics <- teller_team_diagnostics(prepared)
stopifnot(
  diagnostics$aantal_teams == length(unique(grid$team)),
  diagnostics$aantal_plotjaren == length(unique(paste(grid$plot_id, grid$jaar, sep = ":"))),
  diagnostics$eenmalige_teams >= 0L,
  diagnostics$aandeel_eenmalige_teams >= 0,
  diagnostics$aandeel_eenmalige_teams <= 1
)

checkpoint_dir <- tempfile("teller-fit-")
dir.create(checkpoint_dir)
simple <- fit_glmmtmb_safely(
  count ~ jaar_decennium + offset(log_oppervlakte_km2) + (1 | plotjaar_factor),
  prepared,
  "synthetic_simple",
  checkpoint_dir
)
stopifnot(
  identical(simple$status, "geslaagd"),
  file.exists(simple$fit_path),
  identical(simple$diagnostics$row_hash, row_set_sha256(prepared$row_id))
)

forced <- fit_glmmtmb_safely(
  count ~ niet_bestaande_variabele,
  prepared,
  "synthetic_forced_error",
  checkpoint_dir
)
stopifnot(
  identical(forced$status, "modeluitval"),
  file.exists(simple$fit_path),
  is.null(forced$fit_path)
)

batch <- fit_joint_teller_models(
  prepared,
  analysis_id = "synthetic_joint",
  checkpoint_dir = checkpoint_dir,
  experience_variant = "mean"
)
stopifnot(
  identical(names(batch$models), c("M0", "M1", "M2")),
  all(vapply(batch$models, function(x) x$status %in% c("geslaagd", "modeluitval"), logical(1))),
  length(unique(vapply(batch$models, function(x) x$diagnostics$row_hash, character(1)))) == 1L,
  identical(batch$comparison$row_hash, rep(row_set_sha256(prepared$row_id), 3L)),
  identical(batch$diagnostics$ervaring_variant, "mean")
)

cat("OK: gezamenlijke M0-M2-modellen bewaken rijen, structuur en checkpoints.\n")
