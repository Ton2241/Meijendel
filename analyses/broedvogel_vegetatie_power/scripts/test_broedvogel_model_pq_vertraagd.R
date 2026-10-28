args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_pq_vertraagd.R"
))

specs <- pq_delayed_relation_specifications()
stopifnot(
  nrow(specs) == 17L,
  identical(sort(unique(specs$gradient)), sort(pq_gradient_names())),
  sum(specs$relation_type == "gemeenschap") == 5L,
  sum(specs$relation_type == "ecologisch") == 7L,
  sum(specs$relation_type == "functioneel") == 5L,
  !anyDuplicated(specs$analysis_id)
)

birds <- expand.grid(
  soort_id = c(1L, 2L), plot_id = 10L, jaar = 2001:2008,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
birds$row_id <- paste(birds$soort_id, birds$plot_id, birds$jaar, sep = ":")
birds$count <- as.integer(birds$soort_id == 1L)
birds$soort_naam <- ifelse(birds$soort_id == 1L, "Soort A", "Soort B")
birds$tellerteam_factor <- factor("T1")
birds$analyse_bron_factor <- factor(ifelse(birds$soort_id == 1L, "sovon_m", "jrvslg_m"))
birds$jaar_decennium <- (birds$jaar - 2000) / 10
birds$ervaring_plot_z <- 0
birds$ervaring_elders_z <- 0
birds$inspanning_duur_z <- 0
birds$inspanning_ongunstig_z <- 0
birds$inspanning_ongunstig_bekend <- 1
birds$log_oppervlakte_km2 <- 0

intervals <- data.frame(
  plot_id = 10L, start_year = c(1999L, 2003L), end_year = c(2003L, 2006L),
  interval_years = c(4L, 3L),
  open_pionier_change_per_year = c(0.02, -0.03),
  duingrasland_mos_korstmos_change_per_year = 0,
  nat_riet_change_per_year = 0,
  struweel_ruigte_change_per_year = 0,
  bomen_bos_change_per_year = 0,
  stringsAsFactors = FALSE
)
assigned <- assign_latest_pq_interval(birds, intervals, max_lag = 15L)
stopifnot(
  !anyDuplicated(assigned$row_id),
  all(assigned$lag_years %in% 0:15),
  assigned$interval_end_year[assigned$jaar == 2005L][[1L]] == 2003L,
  assigned$interval_end_year[assigned$jaar == 2007L][[1L]] == 2006L
)

memberships <- data.frame(
  group_type = c("ecologisch", "ecologisch"), group_id = "300",
  soort_id = c(1L, 2L), stringsAsFactors = FALSE
)
aggregated <- build_delayed_relation_population(
  assigned, specs[specs$analysis_id == "ecologisch_open_pionier", ], memberships
)
stopifnot(
  !anyDuplicated(aggregated$row_id),
  all(aggregated$n_species == 2L),
  all(aggregated$richness == 1L),
  all(aggregated$total_count == 1L),
  all(as.character(aggregated$analyse_bron_factor) == "gemengd"),
  all(aggregated$change_pp == 2 | aggregated$change_pp == -3)
)

count_formulas <- delayed_model_formulas("territoria", aggregated)
richness_formulas <- delayed_model_formulas("aanwezigheid", aggregated)
stopifnot(
  identical(names(count_formulas), c("basis", "lineair", "niet_lineair")),
  identical(names(richness_formulas), c("basis", "lineair", "niet_lineair")),
  grepl("change_pp_sq", paste(deparse(count_formulas$niet_lineair), collapse = " "), fixed = TRUE),
  grepl("cbind(richness, richness_absent)", paste(deparse(richness_formulas$basis), collapse = " "), fixed = TRUE)
)

events <- data.frame(
  plot_id = c(10L, 10L, 10L, 20L),
  interval_end_year = c(2000L, 2005L, 2024L, 2001L),
  change_pp = c(2, 5, 7, -4), stringsAsFactors = FALSE
)
selected <- select_nonoverlapping_large_events(
  events, lower_relative_year = -3L, upper_relative_year = 15L
)
stopifnot(
  !anyDuplicated(paste(selected$plot_id, selected$interval_end_year)),
  nrow(selected[selected$plot_id == 10L, ]) == 2L,
  2005L %in% selected$interval_end_year,
  2024L %in% selected$interval_end_year
)

cat("OK: vertraagde PQ-modelcontracten, unieke responskoppeling en gebeurtenisselectie.\n")
