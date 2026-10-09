args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
test_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R"
repo <- normalizePath(file.path(dirname(test_path), "..", "..", ".."), mustWork = TRUE)

Sys.setenv(MEIJENDEL_REPO = repo)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_prepare.R"))

years <- 1990:2019
plot_ids <- rep(1:3, length.out = length(years))
team_keys <- rep(c("10", "11", "12"), length.out = length(years))
team_counts <- rep(c(1L, 1L, 2L), length.out = length(years))

teams <- data.frame(
  plot_id = plot_ids,
  jaar = years,
  tellerteam_sleutel = team_keys,
  aantal_tellers = team_counts,
  ervaring_plot_mean = log1p(seq_along(years) - 1L),
  ervaring_plot_min = log1p(pmax(0L, seq_along(years) - 2L)),
  ervaring_plot_max = log1p(seq_along(years)),
  ervaring_elders_mean = log1p((seq_along(years) - 1L) %% 5L),
  ervaring_elders_min = 0,
  ervaring_elders_max = log1p((seq_along(years) - 1L) %% 5L + 1L),
  stringsAsFactors = FALSE
)

species_rows <- function(species_id, positives) {
  data.frame(
    soort_id = species_id,
    soort_naam = paste("Soort", species_id),
    euring_code = 100L + species_id,
    plot_id = plot_ids,
    jaar = years,
    kavel_nummer = paste0("M", plot_ids),
    oppervlakte_km2 = c(1, 1.5, 2)[plot_ids],
    geteld = TRUE,
    count_raw = c(rep(1, positives), rep(0, length(years) - positives)),
    analyse_bron_code = rep(c("sovon_m", "jrvslg_m"), length.out = length(years)),
    nulstatus = c(rep("territorium_vastgesteld", positives), rep("letterlijke_nul", length(years) - positives)),
    stringsAsFactors = FALSE
  )
}

matrix <- rbind(species_rows(1L, 10L), species_rows(2L, 9L))
matrix <- rbind(
  matrix,
  transform(species_rows(3L, 1L)[1L, ], plot_id = 9L, jaar = 2016L, kavel_nummer = "M62"),
  transform(species_rows(3L, 1L)[2L, ], plot_id = 1L, jaar = 2020L, kavel_nummer = "M1"),
  transform(species_rows(3L, 1L)[3L, ], plot_id = 2L, jaar = 2021L, kavel_nummer = "M2", geteld = FALSE, count_raw = NA_real_, nulstatus = "formeel_afgekeurd")
)

visits <- data.frame(
  bezoek_id = 1:31,
  plot_id = c(plot_ids, plot_ids[[1L]]),
  jaar = c(years, years[[1L]]),
  dagvanjaar = c(rep(100L, 30L), 120L),
  bezoekduur_min = c(rep(60L, 30L), 30L),
  gunstig = c(rep(1L, 30L), 0L),
  stringsAsFactors = FALSE
)

valid_plot_years <- unique(matrix[c("plot_id", "jaar")])
effort <- build_bmp_effort(visits, valid_plot_years)
first_effort <- effort[effort$plot_id == plot_ids[[1L]] & effort$jaar == years[[1L]], , drop = FALSE]
stopifnot(
  nrow(first_effort) == 1L,
  first_effort$aantal_bezoeken == 2L,
  first_effort$totale_bezoekduur_min == 90,
  first_effort$eerste_bezoekdag == 100L,
  first_effort$laatste_bezoekdag == 120L,
  isTRUE(all.equal(first_effort$aandeel_gunstig, 0.5))
)

populations <- build_teller_model_populations(matrix, teams, effort)
long <- populations$long
single <- populations$single_teller
with_effort <- populations$effort_1984_2025
eligibility <- populations$eligibility

stopifnot(
  !any(long$kavel_nummer == "M62" & long$jaar == 2016L),
  !any(long$jaar == 2020L),
  !any(long$jaar == 2021L),
  all(single$aantal_tellers == 1L),
  all(with_effort$jaar >= 1984L & with_effort$jaar <= 2025L),
  all(with_effort$totale_bezoekduur_min > 0),
  all(c("analyse_bron_code", "nulstatus", "oppervlakte_km2", "ervaring_plot_mean") %in% names(long)),
  identical(levels(long$analyse_bron_factor)[[1L]], "sovon_m"),
  identical(long$row_id, paste(long$soort_id, long$plot_id, long$jaar, sep = ":")),
  isTRUE(all.equal(long$jaar_decennium, (long$jaar - 1990) / 10))
)

eligible_1 <- eligibility[eligibility$soort_id == 1L, , drop = FALSE]
eligible_2 <- eligibility[eligibility$soort_id == 2L, , drop = FALSE]
stopifnot(
  eligible_1$n == 30L,
  eligible_1$positief == 10L,
  eligible_1$plots == 3L,
  eligible_1$teams == 3L,
  eligible_1$jaren == 30L,
  isTRUE(eligible_1$structureel_geschikt),
  eligible_2$positief == 9L,
  !eligible_2$structureel_geschikt
)

scale_info <- populations$scaling
stopifnot(
  isTRUE(all.equal(mean(long$ervaring_plot_z), 0, tolerance = 1e-12)),
  isTRUE(all.equal(scale_info$ervaring_plot_mean, mean(long$ervaring_plot_mean))),
  isTRUE(all.equal(
    single$ervaring_plot_z,
    (single$ervaring_plot_mean - scale_info$ervaring_plot_mean) / scale_info$ervaring_plot_sd
  ))
)

cat("OK: lange, één-teller- en inspanningspopulaties zijn vast en herleidbaar.\n")
