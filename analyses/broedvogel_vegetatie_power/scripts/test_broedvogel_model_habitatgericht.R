args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_habitatgericht.R"
))

weather <- data.frame(
  datum = as.Date(c(
    "2019-12-15", "2020-01-15", "2020-02-15", "2020-03-15", "2020-04-15",
    "2020-05-15", "2020-06-15"
  )),
  tg_c = c(5, 4, 3, 8, 10, 12, 14),
  tn_c = c(1, -1, -2, 3, 5, 7, 9),
  rh_mm = c(1, 2, 3, 4, 5, 6, 7)
)
annual <- build_weather_covariates(weather)
y2020 <- annual[annual$jaar == 2020L, , drop = FALSE]
stopifnot(
  nrow(y2020) == 1L,
  isTRUE(all.equal(y2020$weer_winter_temperatuur_c, 4)),
  y2020$weer_winter_vorstdagen == 2L,
  isTRUE(all.equal(y2020$weer_voorjaar_temperatuur_c, 11)),
  isTRUE(all.equal(y2020$weer_voorjaar_neerslag_mm, 22))
)

base <- expand.grid(
  soort_id = c(1L, 2L, 5L), plot_id = c(10L, 20L), jaar = c(2014L, 2020L),
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
base$soort_naam <- ifelse(base$soort_id == 5L, "Aalscholver", ifelse(base$soort_id == 1L, "A", "B"))
base$count <- 1
base$row_id <- paste(base$soort_id, base$plot_id, base$jaar, sep = ":")
base$tellerteam_factor <- factor("T1")
base$soort_factor <- factor(base$soort_id)
base$soort_plot_factor <- factor(paste(base$soort_id, base$plot_id, sep = ":"))
base$jaar_factor <- factor(base$jaar)
base$plotjaar_factor <- factor(paste(base$plot_id, base$jaar, sep = ":"))
base$jaar_decennium <- (base$jaar - 1990) / 10
base$analyse_bron_factor <- factor("sovon_m")
base$ervaring_plot_z <- 0
base$ervaring_elders_z <- 0
base$log_oppervlakte_km2 <- 0
base$inspanning_duur_z <- 0
base$inspanning_ongunstig_z <- 0
base$inspanning_ongunstig_bekend <- 1

height <- expand.grid(plot_id = c(10L, 20L), inwinningsjaar = c(2014L, 2020L))
height$aandeel_bomen <- c(.1, .2, .3, .4)
height$datum_methode <- "vlakoverlap"
membership <- data.frame(groepsnummer = 800L, vogel_id = c(1L, 2L, 5L))
population <- build_ahn_habitat_population(
  base, height, membership, 800L, "aandeel_bomen", lag_years = 0L,
  window_half_width = 0L
)
stopifnot(
  nrow(population$data) == 8L,
  !5L %in% population$data$soort_id,
  all(c("habitat_between_z", "habitat_within_z") %in% names(population$data))
)

landcover <- data.frame(
  plot_id = rep(c(10L, 20L), each = 2), jaar = rep(c(2001L, 2022L), 2),
  water_aandeel = c(.1, .2, .3, .4)
)
land_population <- build_targeted_landcover_population(
  base, landcover, membership, 800L, "water_aandeel"
)
stopifnot(all(c("habitat_between_z", "habitat_within_z") %in% names(land_population$data)))

controls <- data.frame(
  jaar = c(2014L, 2020L),
  weer_winter_temperatuur_c = c(3, 4),
  weer_winter_vorstdagen = c(10, 8),
  weer_voorjaar_temperatuur_c = c(11, 12),
  weer_voorjaar_neerslag_mm = c(200, 180)
)
controlled <- add_habitat_controls(population$data, controls)
stopifnot(all(weather_model_fields() %in% names(controlled)))
formulas <- targeted_habitat_formulas(controlled)
formula_text <- paste(deparse(formulas$habitat), collapse = " ")
stopifnot(
  grepl("inspanning_duur_z", formula_text, fixed = TRUE),
  grepl("inspanning_ongunstig_z", formula_text, fixed = TRUE),
  grepl("inspanning_ongunstig_bekend", formula_text, fixed = TRUE),
  grepl("weer_winter_temperatuur_z", formula_text, fixed = TRUE),
  grepl("habitat_within_z", formula_text, fixed = TRUE),
  !grepl("analyse_bron_factor", formula_text, fixed = TRUE)
)
controlled$analyse_bron_factor <- as.character(controlled$analyse_bron_factor)
controlled$analyse_bron_factor[seq_len(nrow(controlled)) %% 2L == 0L] <- "jrvslg_m"
controlled$analyse_bron_factor <- factor(controlled$analyse_bron_factor)
multi_source_formula <- paste(
  deparse(targeted_habitat_formulas(controlled)$habitat), collapse = " "
)
stopifnot(grepl("analyse_bron_factor", multi_source_formula, fixed = TRUE))
temporal_design <- targeted_temporal_design(controlled)
stopifnot(
  !temporal_design$uitvoerbaar,
  temporal_design$aantal_onafhankelijke_structuurmetingen == 2L
)

decision <- decide_targeted_model(
  basis_status = "geslaagd", habitat_status = "geslaagd",
  beta_within = 0.2, expected_direction = 1,
  temporal_delta_logscore = 0.01, spatial_share_better = 0.8,
  loo_min_delta_logscore = 0.001
)
stopifnot(decision$status == "door_naar_power")
decision_bad <- decide_targeted_model(
  basis_status = "geslaagd", habitat_status = "geslaagd",
  beta_within = 0.2, expected_direction = 1,
  temporal_delta_logscore = -0.01, spatial_share_better = 0.8,
  loo_min_delta_logscore = 0.001
)
stopifnot(decision_bad$status == "niet_door_naar_power")
specs <- targeted_specifications()
stopifnot(
  nrow(specs) == 10L,
  identical(specs$analysis_id, c(
    "land_water", "land_riet", "land_open", "land_struweel", "land_boomgroep",
    "land_bos", "ahn_open", "ahn_struweel", "ahn_boomgroep", "ahn_bos"
  ))
)

reclass_dir <- tempfile("habitat-reclass-")
dir.create(reclass_dir)
reclass_state <- list(
  items = list(test = list(data = data.frame(
    jaar = c(2014L, 2020L), ahn_jaar = c(2014L, 2020L)
  ))),
  specs = data.frame(analysis_id = "test", expected_direction = 1)
)
saveRDS(reclass_state, file.path(reclass_dir, "habitatgericht_state.rds"))
reclass_validation <- data.frame(
  validatie = c("ruimte", "tijd"), fold_id = c("1", "tijd_vanaf_2018"),
  blok = "test", status = "geslaagd", fout = "", n_train = 1L, n_test = 1L,
  train_row_hash = "a", test_row_hash = "b", n = 1L,
  delta_mean_log_score = c(0.1, 0.2), delta_mae = 0, delta_rmse = 0
)
reclass_summary <- data.frame(
  analysis_id = "test", bron = "ahn", groepsnummer = 1L,
  predictor = "aandeel_bomen", rijen = 2L, plots = 1L, soorten = 1L,
  jaren = 2L, basis_status = "geslaagd", habitat_status = "geslaagd",
  beta_binnen_plot = 0.2, tijd_delta_logscore = 0.2,
  ruimte_aandeel_beter = 1, loo_min_delta_logscore = 0.1,
  besluit = "door_naar_power", reden = "", validatie_geslaagd = 2L,
  validatie_mislukt = 0L, validatie_niet_uitvoerbaar = 0L
)
reclass_loo <- data.frame(
  validatie = "tijd", fold_id = "tijd_vanaf_2018", blok = "test",
  weggelaten_soort_id = 1L, n = 1L, delta_mean_log_score = 0.1
)
reclass_files <- c(
  samenvatting = "habitatgericht_samenvatting.csv",
  validatie = "habitatgericht_validatie.csv",
  soortgevoeligheid = "habitatgericht_soortgevoeligheid.csv"
)
invisible(write_csv_atomic(
  reclass_summary, file.path(reclass_dir, reclass_files[["samenvatting"]])
))
invisible(write_csv_atomic(
  reclass_validation, file.path(reclass_dir, reclass_files[["validatie"]])
))
invisible(write_csv_atomic(
  reclass_loo, file.path(reclass_dir, reclass_files[["soortgevoeligheid"]])
))
reclass_manifest <- list(outputs = lapply(reclass_files, function(file) list(file = file)))
jsonlite::write_json(
  reclass_manifest, file.path(reclass_dir, "habitatgericht_manifest.json"),
  auto_unbox = TRUE, pretty = TRUE
)
reclassify_two_snapshot_temporal_results(reclass_dir)
reclassified <- utils::read.csv(
  file.path(reclass_dir, "habitatgericht_samenvatting.csv"), check.names = FALSE
)
stopifnot(
  is.na(reclassified$tijd_delta_logscore),
  is.na(reclassified$loo_min_delta_logscore),
  reclassified$besluit == "niet_door_naar_power",
  grepl("voorspelt_latere_jaren", reclassified$reden, fixed = TRUE),
  grepl("niet_een_soort_bepalend", reclassified$reden, fixed = TRUE),
  reclassified$validatie_geslaagd == 1L,
  reclassified$validatie_niet_uitvoerbaar == 1L
)

cat("OK: gerichte habitatpopulaties scheiden structuur, weer en meetinspanning.\n")
