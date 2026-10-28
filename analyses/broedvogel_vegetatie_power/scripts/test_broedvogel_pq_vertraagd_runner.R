args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(
  repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_pq_vertraagd.R"
))

groups <- normalize_delayed_groups(list(
  evg_vogel_landschapgroep = data.frame(
    groepsnummer = c(300L, 600L), vogel_id = c(1L, 2L)
  ),
  functional_group_definition = data.frame(
    id = c(1L, 3L), naam_nl = c("Bodem", "Grond"), status = "approved"
  ),
  functional_group_membership = data.frame(
    functional_group_definition_id = c(1L, 3L), soort_id = c(1L, 2L),
    classification = "primary", membership_weight = 1
  )
))
stopifnot(
  nrow(groups) == 4L,
  setequal(groups$group_type, c("ecologisch", "functioneel")),
  !anyDuplicated(groups[c("group_type", "group_id", "soort_id")])
)

item <- data.frame(
  row_id = c("a", "b"), plot_id = c(1L, 2L), jaar = c(2010L, 2020L),
  interval_end_year = c(2008L, 2018L), lag_years = 2L,
  n_species = c(10L, 12L), stringsAsFactors = FALSE
)
coverage <- delayed_relation_coverage(
  item, pq_delayed_relation_specifications()[1L, ], threshold = 1.5,
  selected_events = 2L
)
stopifnot(
  coverage$plotyears == 2L, coverage$plots == 2L,
  coverage$first_response_year == 2010L, coverage$last_response_year == 2020L,
  coverage$large_change_threshold_pp == 1.5,
  coverage$selected_large_events == 2L
)

validation <- data.frame(
  validation_type = c(rep("ruimte", 5), "tijd"), status = "geslaagd",
  niet_lineair_vs_basis_logscore = 0.1,
  niet_lineair_vs_lineair_logscore = 0.05
)
summary <- summarise_delayed_result(
  pq_delayed_relation_specifications()[1L, ], "territoria",
  c(basis = "geslaagd", lineair = "geslaagd", niet_lineair = "geslaagd"),
  validation
)
stopifnot(
  summary$decision == "voorspellende_meerwaarde",
  summary$valid_spatial_folds == 5L,
  summary$temporal_status == "geslaagd"
)

cat("OK: vertraagde runnergroepering, dekking en beslissamenvatting.\n")
