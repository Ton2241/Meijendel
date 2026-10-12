args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_omgeving.R"
))

landuse <- data.frame(
  plot_id = rep(c(1L, 2L), each = 6L),
  jaar = rep(c(2010L, 2022L), each = 6L),
  bron = rep(c("CBS_BBG2010", "CBS_NBBG2022"), each = 6L),
  klasse = c(
    "Droog natuurlijk terrein", "Bos", "Water", "Hoofdweg", "Recreatie", "Bebouwd exclusief bedrijfsterrein",
    "Open droog natuurlijk terrein", "Bos", "Overig binnenwater", "Hoofdweg", "Sportterrein", "Woonterrein"
  ),
  pct = c(70, 20, 5, 2, 2, 1, 65, 25, 4, 2, 3, 1),
  stringsAsFactors = FALSE
)
harmonized <- harmonize_cbs_landuse(landuse)
stopifnot(
  nrow(harmonized) == 2L,
  identical(harmonized$jaar, c(2010L, 2022L)),
  all.equal(harmonized$land_open_pct, c(70, 65)),
  all.equal(harmonized$land_bos_pct, c(20, 25)),
  all.equal(harmonized$land_water_pct, c(5, 4)),
  all.equal(harmonized$land_overig_pct, c(5, 6)),
  identical(attr(harmonized, "uitgesloten_jaren"), integer())
)

with_1996 <- rbind(
  landuse,
  data.frame(
    plot_id = 1L, jaar = 1996L, bron = "CBS_BBG1996", klasse = "BG96_61",
    pct = 100, stringsAsFactors = FALSE
  )
)
harmonized_1996 <- harmonize_cbs_landuse(with_1996)
stopifnot(
  identical(attr(harmonized_1996, "uitgesloten_jaren"), 1996L),
  !1996L %in% harmonized_1996$jaar
)

nitrogen <- data.frame(
  plot_id = rep(c(1L, 2L), each = 3L),
  jaar = rep(2020:2022, 2L),
  bron = "RIVM_HIST_STIKSTOF",
  stikstof_mean = c(1000, 900, 800, 1200, 1100, 1000),
  stringsAsFactors = FALSE
)
nitrogen_features <- prepare_nitrogen_features(nitrogen)
stopifnot(
  nrow(nitrogen_features) == 6L,
  all(abs(aggregate(
    nitrogen_features$stikstof_mean_within,
    list(nitrogen_features$plot_id), mean
  )$x) < 1e-12)
)

base <- data.frame(
  row_id = paste0("r", 1:8),
  soort_id = rep(c(10L, 20L), each = 4L),
  soort_naam = rep(c("Soort A", "Soort B"), each = 4L),
  plot_id = rep(c(1L, 1L, 2L, 2L), 2L),
  jaar = rep(c(2020L, 2021L, 2020L, 2021L), 2L),
  count = 1,
  jaar_decennium = 0,
  analyse_bron_factor = factor("sovon"),
  log_oppervlakte_km2 = 0,
  tellerteam_factor = factor(rep(c("A", "A", "B", "B"), 2L)),
  ervaring_plot_z = 0,
  ervaring_elders_z = 0,
  inspanning_duur_z = 0,
  inspanning_ongunstig_z = 0,
  inspanning_ongunstig_bekend = 1,
  stringsAsFactors = FALSE
)
features <- data.frame(
  plot_id = rep(c(1L, 2L), each = 2L),
  jaar = rep(c(2020L, 2021L), 2L),
  stikstof_mean = c(1000, 900, 1200, 1100)
)
population <- build_environment_population(base, features, "stikstof_mean", lag_years = 0L)
stopifnot(nrow(population$data) == 8L, population$lag_years == 0L)

weather <- data.frame(
  jaar = 2020:2021,
  weer_winter_temperatuur_c = c(5, 6),
  weer_winter_vorstdagen = c(10, 8),
  weer_voorjaar_temperatuur_c = c(11, 12),
  weer_voorjaar_neerslag_mm = c(200, 180)
)
controlled <- add_habitat_controls(population$data, weather)
formulas <- environment_model_formulas("stikstof", "stikstof_mean", controlled)
formula_text <- paste(deparse(formulas$omgeving), collapse = " ")
stopifnot(
  grepl("tellerteam_factor", formula_text, fixed = TRUE),
  grepl("weer_winter_temperatuur_z", formula_text, fixed = TRUE),
  grepl("stikstof_mean_between_z", formula_text, fixed = TRUE),
  grepl("stikstof_mean_within_z", formula_text, fixed = TRUE),
  grepl("||", formula_text, fixed = TRUE),
  grepl("soort_factor", formula_text, fixed = TRUE)
)

design_data <- controlled[c(1L, 2L, 3L), , drop = FALSE]
design_data$omgevingsjaar <- c(2019L, 2020L, 2021L)
design <- environment_temporal_design(design_data, train_end = 2020L, test_start = 2021L)
stopifnot(
  isTRUE(design$uitvoerbaar),
  identical(design$train_rows, c(TRUE, TRUE, FALSE)),
  identical(design$test_rows, c(FALSE, FALSE, TRUE))
)

prediction_failure <- capture_environment_prediction(function() {
  stop("Prediction is not possible for unknown fixed effects")
})
stopifnot(
  identical(prediction_failure$status, "mislukt"),
  grepl("unknown fixed effects", prediction_failure$fout, fixed = TRUE),
  !grepl("\n", prediction_failure$fout, fixed = TRUE)
)

species_effects <- data.frame(
  analysis_id = "voorbeeld", soort_id = c(10L, 20L), predictor = "x",
  beta_tussen_plots = c(0.1, 0.2), beta_binnen_plot = c(0.01, 0.02),
  ratio_tussen_plots_per_sd = exp(c(0.1, 0.2)),
  ratio_binnen_plot_per_sd = exp(c(0.01, 0.02)),
  basis_status = "modeluitval", omgeving_status = "geslaagd",
  vergelijking_geldig = FALSE, stringsAsFactors = FALSE
)
memberships <- data.frame(
  groep_type = "ecologisch", groep_id = "100", soort_id = c(10L, 20L),
  gewicht = 1, stringsAsFactors = FALSE
)
definitions <- data.frame(
  groep_type = "ecologisch", groep_id = "100", groep_naam = "Voorbeeldgroep",
  stringsAsFactors = FALSE
)
grouped <- summarise_environment_group_effects(species_effects, memberships, definitions)
stopifnot(
  identical(grouped$basis_status, "modeluitval"),
  identical(grouped$omgeving_status, "geslaagd"),
  identical(grouped$vergelijking_geldig, FALSE)
)

cat("OK: stikstof- en bodemgebruikvoorbereiding, formules en tijdssplitsing\n")
