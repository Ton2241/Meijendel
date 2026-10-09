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

species_data <- do.call(rbind, lapply(1:3, function(species_id) {
  current <- grid[grid$soort_id == 1L, , drop = FALSE]
  current$soort_id <- species_id
  current$soort_factor <- factor(species_id)
  current$soort_plot_factor <- factor(paste(species_id, current$plot_id, sep = ":"))
  current$row_id <- paste(species_id, current$plot_id, current$jaar, sep = ":")
  if (species_id == 2L) current$count <- 0
  if (species_id == 3L) {
    current$ervaring_plot_mean <- 0
    current$ervaring_elders_mean <- 0
  }
  current
}))
species_eligibility_test <- data.frame(
  soort_id = 1:3,
  soort_naam = paste("Testsoort", 1:3),
  structureel_geschikt = TRUE,
  stringsAsFactors = FALSE
)

species_results <- fit_species_teller_models(
  species_data,
  species_eligibility_test,
  analysis_id = "synthetic_species",
  checkpoint_dir = checkpoint_dir
)
gee_results <- fit_species_gee_checks(
  species_data,
  species_eligibility_test,
  analysis_id = "synthetic_species"
)
quick_isolated <- run_isolated_with_timeout(function() 42L, timeout_seconds = 1)
slow_isolated <- run_isolated_with_timeout(function() { Sys.sleep(0.2); 42L }, timeout_seconds = 0.05)
stopifnot(
  identical(species_results$soort_id, 1:3),
  identical(gee_results$soort_id, 1:3),
  species_results$status[[1L]] %in% c("geslaagd", "modeluitval"),
  gee_results$status[[1L]] %in% c("geslaagd", "modeluitval"),
  identical(species_results$status[[2L]], "uitval"),
  identical(species_results$reden[[2L]], "geen_positieve_tellingen"),
  identical(gee_results$reden[[2L]], "geen_positieve_tellingen"),
  identical(species_results$reden[[3L]], "constante_ervaring"),
  identical(gee_results$reden[[3L]], "constante_ervaring"),
  identical(species_results$row_hash, gee_results$row_hash),
  identical(quick_isolated$status, "geslaagd"),
  identical(quick_isolated$value, 42L),
  identical(slow_isolated$status, "modeluitval"),
  grepl("tijdslimiet", slow_isolated$error, fixed = TRUE)
)

sensitivity <- summarise_teller_sensitivity(batch, species_results, gee_results)
stopifnot(
  is.data.frame(sensitivity$summary),
  nrow(sensitivity$species_comparison) == 3L,
  sensitivity$diagnostics$aantal_kandidaatsoorten == 3L
)

cat("OK: gezamenlijke M0-M2-modellen bewaken rijen, structuur en checkpoints.\n")
