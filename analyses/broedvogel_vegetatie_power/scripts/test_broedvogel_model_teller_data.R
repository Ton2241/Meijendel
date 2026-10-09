args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
test_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R"
repo <- normalizePath(file.path(dirname(test_path), "..", "..", ".."), mustWork = TRUE)

Sys.setenv(MEIJENDEL_REPO = repo)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_data.R"))

plots <- data.frame(
  plot_id = 1:5,
  plot_naam = c("Plot 1", "Plot 2", "M62", "Golfclub", "Voorlinden"),
  kavel_nummer = c("M1", "M2", "M62", "M66", "M91"),
  stringsAsFactors = FALSE
)
scope <- data.frame(
  scope_code = rep("meijendel_natura2000", 5L),
  plot_id = 1:5,
  in_scope = c(1L, 1L, 1L, 0L, 0L),
  reden = c(rep("Onderdeel van Natura 2000-analysegebied.", 3L), rep("Geen onderdeel van Natura 2000-analysegebied.", 2L)),
  stringsAsFactors = FALSE
)
pjt <- data.frame(
  plot_id = c(1L, 1L, 1L, 2L, 1L, 1L, 2L, 2L, 3L, 4L, 5L),
  jaar = c(2010L, 2010L, 2010L, 2010L, 2011L, 2011L, 2012L, 2012L, 2016L, 2010L, 2011L),
  teller_id = c(9L, 2L, 9L, 2L, 2L, 9L, 3L, 2L, 3L, 3L, 3L),
  stringsAsFactors = FALSE
)

stopifnot(identical(canonical_tellerteam_key(c(9L, 2L, 9L)), "2+9"))

result <- build_teller_experience_layer(list(
  plots = plots,
  plot_analyse_scope = scope,
  plot_jaar_teller = pjt
), 1958L, 2025L)

participations <- result$participations
teams <- result$teams
stopifnot(
  nrow(participations) == 7L,
  nrow(teams) == 4L,
  !any(participations$plot_id %in% c(3L, 4L, 5L)),
  !any(participations$jaar == 2016L)
)

row <- function(teller_id, plot_id, year) {
  participations[
    participations$teller_id == teller_id &
      participations$plot_id == plot_id &
      participations$jaar == year,
    ,
    drop = FALSE
  ]
}

# Twee deelnames in hetzelfde kalenderjaar zijn geen eerdere ervaring voor
# elkaar. Het algemene ervaringsjaar 2010 telt later maar eenmaal.
first_second_plot <- row(2L, 2L, 2010L)
later_second_plot <- row(2L, 2L, 2012L)
stopifnot(
  nrow(first_second_plot) == 1L,
  first_second_plot$eerdere_jaren_totaal == 0L,
  later_second_plot$eerdere_jaren_totaal == 2L,
  later_second_plot$eerdere_jaren_plot == 1L,
  later_second_plot$eerdere_jaren_elders == 1L,
  all(
    participations$eerdere_jaren_plot + participations$eerdere_jaren_elders ==
      participations$eerdere_jaren_totaal
  )
)

team_2010 <- teams[teams$plot_id == 1L & teams$jaar == 2010L, , drop = FALSE]
team_2012 <- teams[teams$plot_id == 2L & teams$jaar == 2012L, , drop = FALSE]
stopifnot(
  identical(team_2010$tellerteam_sleutel, "2+9"),
  team_2010$aantal_tellers == 2L,
  identical(team_2012$tellerteam_sleutel, "2+3"),
  isTRUE(all.equal(team_2012$ervaring_plot_mean, log1p(1) / 2)),
  isTRUE(all.equal(team_2012$ervaring_plot_min, 0)),
  isTRUE(all.equal(team_2012$ervaring_plot_max, log1p(1))),
  isTRUE(all.equal(team_2012$ervaring_elders_mean, log1p(1) / 2)),
  isTRUE(all.equal(team_2012$ervaring_elders_min, 0)),
  isTRUE(all.equal(team_2012$ervaring_elders_max, log1p(1)))
)

cat("OK: tellerteams en uitsluitend eerdere geregistreerde ervaring zijn canoniek afgeleid.\n")
