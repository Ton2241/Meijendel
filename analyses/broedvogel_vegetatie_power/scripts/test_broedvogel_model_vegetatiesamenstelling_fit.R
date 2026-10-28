args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatiesamenstelling_fit.R"
))

expect_error <- function(expr, pattern) {
  found <- tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
  stopifnot(grepl(pattern, found, fixed = TRUE))
}

base <- expand.grid(
  soort_id = c(1L, 2L, 5L),
  plot_id = c(10L, 20L),
  jaar = 2001:2003,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
base$soort_naam <- ifelse(base$soort_id == 5L, "Aalscholver", ifelse(base$soort_id == 1L, "A", "B"))
base$count <- base$soort_id + base$jaar - 2001L
base$row_id <- paste(base$soort_id, base$plot_id, base$jaar, sep = ":")
base$tellerteam_factor <- factor(ifelse(base$plot_id == 10L, "T1", "T2"))
base$soort_factor <- factor(base$soort_id)
base$soort_plot_factor <- factor(paste(base$soort_id, base$plot_id, sep = ":"))
base$jaar_factor <- factor(base$jaar)
base$plotjaar_factor <- factor(paste(base$plot_id, base$jaar, sep = ":"))
base$jaar_decennium <- (base$jaar - 1990) / 10
base$analyse_bron_factor <- factor("sovon_m")
base$ervaring_plot_z <- 0
base$ervaring_elders_z <- 0
base$log_oppervlakte_km2 <- 0

composition <- data.frame(
  plot_id = rep(c(10L, 20L), each = 3),
  jaar = rep(2001:2003, 2),
  compositie_pc1 = c(-1, 0, 1, 2, 3, 4),
  compositie_pc2 = c(2, 1, 0, -1, -2, -3),
  compositie_pc3 = c(0, 1, 0, 1, 0, 1),
  stringsAsFactors = FALSE
)
population <- build_multivariate_vegetation_population(
  base, composition, composition_predictor_contract(), lag_years = 0L
)
stopifnot(nrow(population$data) == 12L)
stopifnot(!5L %in% population$data$soort_id)
stopifnot(all(paste0(composition_predictor_contract(), "_within_z") %in% names(population$data)))

composition_lag15 <- composition
composition_lag15$jaar <- composition_lag15$jaar - 15L
population_lag15 <- build_multivariate_vegetation_population(
  base, composition_lag15, composition_predictor_contract(), lag_years = 15L
)
stopifnot(nrow(population_lag15$data) == 12L)
stopifnot(all(population_lag15$data$jaar - population_lag15$data$vegetatie_jaar == 15L))
expect_error(
  build_multivariate_vegetation_population(
    base, composition_lag15, composition_predictor_contract(), lag_years = 16L
  ),
  "Vertraging moet een geheel aantal jaren van 0 tot en met 15 zijn."
)

formulas <- multivariate_vegetation_model_formulas(
  "compositie", composition_predictor_contract()
)
formula_text <- paste(deparse(formulas$vegetatie), collapse = " ")
stopifnot(grepl("compositie_pc1_between_z", formula_text, fixed = TRUE))
stopifnot(grepl("compositie_pc3_within_z", formula_text, fixed = TRUE))
stopifnot(grepl("soort_factor", formula_text, fixed = TRUE))

ipi_fields <- ipi_predictor_contract()
stopifnot(identical(ipi_fields, c("ipi_nat_water", "ipi_struweel", "ipi_bos")))

groups <- landcover_bird_group_contract()
stopifnot(identical(unname(groups[c("100", "200", "300", "600", "700", "800")]), c(
  "water_aandeel", "riet_aandeel", "open_aandeel", "struik_aandeel",
  "boomgroep_aandeel", "bos_aandeel"
)))

landcover <- data.frame(
  plot_id = rep(c(10L, 20L), each = 2),
  jaar = rep(c(2001L, 2022L), 2),
  water_aandeel = c(.2, .3, .1, .1),
  stringsAsFactors = FALSE
)
base_windows <- base
base_windows$jaar <- rep(c(1999L, 2020L, 2021L), length.out = nrow(base_windows))
base_windows$row_id <- paste(base_windows$soort_id, base_windows$plot_id, base_windows$jaar, seq_len(nrow(base_windows)), sep = ":")
membership <- data.frame(groepsnummer = 100L, vogel_id = c(1L, 2L))
window_population <- build_landcover_window_population(
  base_windows, landcover, membership, 100L, "water_aandeel"
)
stopifnot(all(window_population$data$landbedekking_jaar %in% c(2001L, 2022L)))
stopifnot(!5L %in% window_population$data$soort_id)
stopifnot(all(window_population$data$jaar %in% c(1999L, 2020L, 2021L)))

cat("OK: multivariate vegetatie- en landbedekkingsmodellen\n")
