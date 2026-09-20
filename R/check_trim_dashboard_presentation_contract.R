#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) normalizePath(args[[1]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

dashboard <- paste(readLines(file.path(repo_root, "bmp_meijendel_index.html"), warn = FALSE), collapse = "\n")
main_trends <- read.csv(
  file.path(repo_root, "trim", "soorten", "soorten_trendoverzicht.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
main_status <- read.csv(
  file.path(repo_root, "trim", "soorten", "soorten_modelstatus.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
ecological_groups <- read.csv(
  file.path(repo_root, "trim_msi_evg", "trendoverzicht_msi_groepen.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
functional_groups <- read.csv(
  file.path(repo_root, "trim_msi_evg", "functionele_trendoverzicht_msi_groepen.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
group_gam_interpretation <- read.csv(
  file.path(repo_root, "trim_msi_evg", "gam_interpretatie_msi_groepen.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
standalone_gam_interpretation <- read.csv(
  file.path(repo_root, "output_ecologische_groepen", "gam_interpretatie_per_groep.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_dashboard_fragments <- c(
  "overall_trend_formaliteit",
  "trend_pre_se_pct", "trend_pre_ci95_laag_pct", "trend_pre_ci95_hoog_pct", "trend_pre_p", "trend_pre_methode",
  "trend_post_se_pct", "trend_post_ci95_laag_pct", "trend_post_ci95_hoog_pct", "trend_post_p", "trend_post_methode",
  "trend_formaliteit",
  "beschrijvende samenvatting",
  "geen formele p-waarde",
  "geen volledige TRIM-onzekerheid"
)
for (fragment in required_dashboard_fragments) {
  assert_true(grepl(fragment, dashboard, fixed = TRUE), sprintf("dashboard mist contractfragment: %s", fragment))
}

forbidden_dashboard_fragments <- c(
  "row.overall_uitleg", "row.trend_uitleg", "row.trend_pre_uitleg", "row.trend_post_uitleg",
  "Trendlabels zijn eigen duidingen op basis van de TRIM-index"
)
for (fragment in forbidden_dashboard_fragments) {
  assert_true(!grepl(fragment, dashboard, fixed = TRUE), sprintf("dashboard gebruikt verouderde inferentie: %s", fragment))
}

both_periods <- main_trends$trend_pre_formaliteit == "formeel" & main_trends$trend_post_formaliteit == "formeel"
only_post <- main_trends$trend_pre_formaliteit != "formeel" & main_trends$trend_post_formaliteit == "formeel"
fallback <- main_trends$trend_pre_model_fallback_reden != "voorkeursmodel_gekozen" |
  main_trends$trend_post_model_fallback_reden != "voorkeursmodel_gekozen"
insufficient <- main_status$analyse_categorie %in% c("lokaal_incidenteel", "te_zeldzaam")

assert_true(any(both_periods), "geen dashboardtestsoort met twee formele perioden gevonden")
assert_true(any(only_post), "geen dashboardtestsoort met alleen een formele post-periode gevonden")
assert_true(any(fallback, na.rm = TRUE), "geen dashboardtestsoort met fallbackmodel gevonden")
assert_true(any(insufficient), "geen dashboardtestsoort met onvoldoende reeks gevonden")

assert_true(all(ecological_groups$trend_formaliteit == "beschrijvend"), "ecologische groepen zijn niet allemaal beschrijvend")
assert_true(all(functional_groups$trend_formaliteit == "beschrijvend"), "functionele groepen zijn niet allemaal beschrijvend")
assert_true(
  !any(grepl("trendclassificatie|betrouwbaar", group_gam_interpretation$toelichting, ignore.case = TRUE)),
  "GAM-toelichting lange reeks bevat nog formele of betrouwbaarheidsduiding"
)
assert_true(
  !any(grepl("trendclassificatie|betrouwbaar", standalone_gam_interpretation$toelichting, ignore.case = TRUE)),
  "losse ecologische GAM-toelichting bevat nog formele of betrouwbaarheidsduiding"
)

cat(sprintf(
  paste0(
    "TRIM-dashboardpresentatiecontract: OK ",
    "(%d twee perioden; %d alleen-post; %d fallback; %d onvoldoende; %d groepsregels)\n"
  ),
  sum(both_periods), sum(only_post), sum(fallback, na.rm = TRUE), sum(insufficient),
  nrow(ecological_groups) + nrow(functional_groups)
))
