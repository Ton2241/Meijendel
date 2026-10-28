args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "pq_vertragingsdekking.R"
))

base <- expand.grid(
  soort_id = c(1L, 2L),
  plot_id = c(10L, 20L),
  jaar = 2001:2010,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
base$soort_naam <- ifelse(base$soort_id == 1L, "A", "B")
base$count <- 1
base$row_id <- paste(base$soort_id, base$plot_id, base$jaar, sep = ":")
base$tellerteam_factor <- factor(ifelse(base$plot_id == 10L, "T1", "T2"))
base$ervaring_plot_z <- 0
base$ervaring_elders_z <- 0

composition <- data.frame(
  plot_id = rep(c(10L, 20L), each = 3),
  jaar = rep(2001:2003, 2),
  compositie_pc1 = c(-1, 0, 1, 2, 3, 4),
  compositie_pc2 = c(2, 1, 0, -1, -2, -3),
  compositie_pc3 = c(0, 1, 0, 1, 0, 1),
  stringsAsFactors = FALSE
)
ipi <- data.frame(
  plot_id = composition$plot_id,
  jaar = composition$jaar,
  ipi_nat_water = c(0, .1, .2, .2, .3, .4),
  ipi_struweel = c(.2, .3, .4, .1, .2, .3),
  ipi_bos = c(.1, .1, .2, .4, .4, .5),
  stringsAsFactors = FALSE
)

state <- build_pq_delay_populations(base, composition, ipi)
coverage <- pq_delay_coverage_table(state)

stopifnot(nrow(coverage) == 32L)
stopifnot(identical(sort(unique(coverage$lag_years)), 0:15))
stopifnot(identical(unique(coverage$blok), c("compositie", "ipi")))
stopifnot(all(coverage$plotyears[coverage$lag_years <= 7L] == 6L))
stopifnot(all(coverage$plotyears[coverage$lag_years == 8L] == 4L))
stopifnot(all(coverage$plotyears[coverage$lag_years == 9L] == 2L))
empty <- coverage[coverage$lag_years >= 10L, , drop = FALSE]
stopifnot(nrow(empty) == 12L)
stopifnot(all(empty$rows == 0L))
stopifnot(all(empty$plotyears == 0L))
stopifnot(all(empty$plots == 0L))
stopifnot(all(empty$species == 0L))
stopifnot(all(is.na(empty$first_bird_year)))
stopifnot(all(is.na(empty$last_bird_year)))
stopifnot(all(is.na(empty$first_vegetation_year)))
stopifnot(all(is.na(empty$last_vegetation_year)))

relative_fixture <- data.frame(
  blok = rep(c("compositie", "ipi"), each = 2),
  lag_years = rep(0:1, 2),
  plotyears = c(406L, 390L, 406L, 390L),
  stringsAsFactors = FALSE
)
relative_fixture <- add_relative_plotyear_coverage(relative_fixture)
stopifnot(identical(relative_fixture$aandeel_plotjaren_tov_lag0, c(
  1, 390 / 406, 1, 390 / 406
)))

cat("OK: PQ-vertragingsdekking 0-15\n")
