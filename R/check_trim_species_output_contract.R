#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) normalizePath(args[[1]], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)

read_output <- function(...) {
  read.csv(file.path(repo_root, ...), stringsAsFactors = FALSE, check.names = FALSE)
}

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

assert_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  assert_true(!length(missing), sprintf("%s mist kolommen: %s", label, paste(missing, collapse = ", ")))
}

assert_no_columns <- function(data, forbidden, label) {
  present <- intersect(forbidden, names(data))
  assert_true(!length(present), sprintf("%s bevat oude inferentievelden: %s", label, paste(present, collapse = ", ")))
}

main_trends <- read_output("trim", "soorten", "soorten_trendoverzicht.csv")
main_usable <- read_output("trim", "soorten", "soorten_trendoverzicht_bruikbare_tijdreeks.csv")
main_indices <- read_output("trim", "soorten", "soortindices_per_jaar.csv")
main_status <- read_output("trim", "soorten", "soorten_modelstatus.csv")
main_selection <- read_output("trim", "soorten", "soorten_bruikbare_tijdreeks_selectie.csv")

assert_true(nrow(main_status) == 159L, "hoofdstatus moet 159 soorten bevatten")
assert_true(length(unique(main_indices$soort_id)) == 137L, "hoofdindices moeten 137 soorten bevatten")
assert_true(nrow(main_trends) == 137L && length(unique(main_trends$soort_id)) == 137L, "hoofdtrendoverzicht moet 137 unieke soorten bevatten")
assert_true(nrow(main_usable) == 95L && length(unique(main_usable$soort_id)) == 95L, "bruikbare hoofdreeks moet 95 unieke soorten bevatten")
assert_true(setequal(main_trends$soort_id, unique(main_indices$soort_id)), "hoofdtrendsoorten wijken af van de indexsoorten")
assert_true(setequal(main_usable$soort_id, main_selection$soort_id), "bruikbare trendsoorten wijken af van de selectie")

overall_fields <- c(
  "trend_contract", "overall_trend_formaliteit", "overall_periode",
  "overall_eerste_jaar", "overall_laatste_jaar", "overall_trend_pct_per_jaar",
  "overall_trend_methode", "overall_trend_status"
)
period_suffixes <- c(
  "formaliteit", "periode", "eerste_jaar", "laatste_jaar", "n_kalenderjaren",
  "n_modeltijdpunten", "pct_per_jaar", "se_pct", "ci95_laag_pct",
  "ci95_hoog_pct", "p", "methode", "status", "klasse", "duiding_type",
  "model", "model_fallback_reden"
)
period_fields <- c(
  paste0("trend_pre_", period_suffixes),
  paste0("trend_post_", period_suffixes)
)
assert_columns(main_trends, c(overall_fields, period_fields), "hoofdtrendoverzicht")
assert_no_columns(
  main_trends,
  c("overall_p", "overall_r2", "overall_uitleg", "trend_pre_r2", "trend_post_r2"),
  "hoofdtrendoverzicht"
)
assert_true(all(main_trends$trend_contract == "trim-trend-v2"), "hoofdtrendoverzicht heeft verkeerde contractversie")
assert_true(all(main_trends$overall_trend_formaliteit == "beschrijvend"), "gebrugde hoofdtrend is niet overal beschrijvend")
assert_true(all(main_trends$overall_periode == "1958-2025"), "gebrugde hoofdperiode is onjuist")
assert_true(all(main_trends$trend_pre_periode == "1958-1983"), "pre-periodelabel is onjuist")
assert_true(all(main_trends$trend_post_periode == "1984-2025"), "post-periodelabel is onjuist")

for (prefix in c("trend_pre_", "trend_post_")) {
  formal <- main_trends[[paste0(prefix, "formaliteit")]] == "formeel"
  inferential <- c("pct_per_jaar", "se_pct", "ci95_laag_pct", "ci95_hoog_pct", "p")
  assert_true(all(vapply(inferential, function(field) all(is.finite(main_trends[[paste0(prefix, field)]][formal])), logical(1))), sprintf("%s formele rijen missen inferentie", prefix))
  not_formal <- !formal
  assert_true(all(vapply(inferential, function(field) all(is.na(main_trends[[paste0(prefix, field)]][not_formal])), logical(1))), sprintf("%s niet-formele rijen bevatten inferentie", prefix))
}

assert_true(all(main_trends$trend_pre_model == main_status$pre_model[match(main_trends$soort_id, main_status$soort_id)] | (is.na(main_trends$trend_pre_model) & is.na(main_status$pre_model[match(main_trends$soort_id, main_status$soort_id)]))), "pre-modelkeuzes wijken af van modelstatus")
assert_true(all(main_trends$trend_post_model == main_status$post_model[match(main_trends$soort_id, main_status$soort_id)] | (is.na(main_trends$trend_post_model) & is.na(main_status$post_model[match(main_trends$soort_id, main_status$soort_id)]))), "post-modelkeuzes wijken af van modelstatus")

sandra_trends <- read_output("trim", "sandra", "soorten", "soorten_trendoverzicht.csv")
sandra_indices <- read_output("trim", "sandra", "soorten", "soortindices_per_jaar.csv")
sandra_status <- read_output("trim", "sandra", "soorten", "soorten_modelstatus.csv")
sandra_selection <- read_output("trim", "sandra", "soorten", "soorten_selectie_sandra.csv")

sandra_fields <- c(
  "trend_contract", "trend_formaliteit", "periode", "eerste_jaar",
  "laatste_jaar", "n_kalenderjaren", "n_modeltijdpunten",
  "trend_pct_per_jaar", "trend_se_pct", "trend_ci95_laag_pct",
  "trend_ci95_hoog_pct", "trend_p", "trend_methode", "trend_status",
  "trendklasse", "trendduiding_type", "model", "model_fallback_reden"
)
assert_columns(sandra_trends, sandra_fields, "Sandra-trendoverzicht")
assert_no_columns(sandra_trends, c("trend_r2", "trend_uitleg"), "Sandra-trendoverzicht")
assert_true(sum(sandra_selection$in_sandra_selectie %in% TRUE) == 135L, "Sandra-selectie moet 135 waargenomen soorten bevatten")
assert_true(nrow(sandra_status) == 135L, "Sandra-modelstatus moet 135 geselecteerde soorten bevatten")
assert_true(nrow(sandra_trends) == 110L && length(unique(sandra_trends$soort_id)) == 110L, "Sandra-trendoverzicht moet 110 unieke soorten bevatten")
assert_true(setequal(sandra_trends$soort_id, unique(sandra_indices$soort_id)), "Sandra-trendsoorten wijken af van de indexsoorten")
assert_true(all(sandra_trends$trend_contract == "trim-trend-v2"), "Sandra heeft verkeerde contractversie")
assert_true(all(sandra_trends$periode == "1997-2022"), "Sandra-periode is onjuist")
assert_true(all(sandra_trends$trend_formaliteit == "formeel"), "Sandra bevat onverwacht niet-formele trends")
assert_true(all(is.finite(sandra_trends$trend_se_pct) & is.finite(sandra_trends$trend_ci95_laag_pct) & is.finite(sandra_trends$trend_ci95_hoog_pct) & is.finite(sandra_trends$trend_p)), "Sandra mist formele onzekerheidsvelden")
assert_true(all(sandra_trends$model == sandra_status$model[match(sandra_trends$soort_id, sandra_status$soort_id)]), "Sandra-modelkeuzes wijken af van modelstatus")

cat("TRIM-soortuitvoercontract: OK (137 hoofdsoorten; 95 bruikbaar; 110 Sandra, 1997-2022)\n")

assert_descriptive_group_trends <- function(data, expected_rows, label, required_estimates) {
  assert_true(nrow(data) == expected_rows, sprintf("%s moet %d trendregels bevatten", label, expected_rows))
  assert_columns(
    data,
    c("trend_contract", "trend_formaliteit", "trend_status", "trend_methode", required_estimates),
    label
  )
  assert_true(all(data$trend_contract == "trim-trend-v2"), sprintf("%s heeft verkeerde contractversie", label))
  assert_true(all(data$trend_formaliteit == "beschrijvend"), sprintf("%s is niet volledig beschrijvend", label))
  inferential <- grep("(^|_)(p|p_value|p_trend|p_overall_trend|r2|trendklasse|uitleg)($|_)", names(data), value = TRUE)
  assert_true(!length(inferential), sprintf("%s bevat formele inferentievelden: %s", label, paste(inferential, collapse = ", ")))
}

ecological_groups <- read_output("trim_msi_evg", "trendoverzicht_msi_groepen.csv")
functional_groups <- read_output("trim_msi_evg", "functionele_trendoverzicht_msi_groepen.csv")
sandra_groups <- read_output("trim", "sandra", "trim_msi_evg", "trendoverzicht_msi_groepen.csv")
alternative_groups <- read_output("output_ecologische_groepen", "trendanalyse_per_groep.csv")
alternative_periods <- read_output("output_ecologische_groepen", "trendanalyse_los_per_periode.csv")

assert_descriptive_group_trends(
  ecological_groups,
  18L,
  "ecologische TRIM-MSI",
  c("overall_trend_pct_per_jaar", "trend_pre_pct_per_jaar", "trend_post_pct_per_jaar")
)
assert_descriptive_group_trends(
  functional_groups,
  24L,
  "functionele TRIM-MSI",
  c("overall_trend_pct_per_jaar", "trend_pre_pct_per_jaar", "trend_post_pct_per_jaar")
)
assert_descriptive_group_trends(
  sandra_groups,
  18L,
  "Sandra TRIM-MSI",
  "trend_pct_per_jaar"
)
assert_descriptive_group_trends(
  alternative_groups,
  9L,
  "alternatieve ecologische MSI",
  c("overall_trend_pct_per_jaar", "pre_trend_pct_per_jaar", "post_trend_pct_per_jaar")
)
assert_descriptive_group_trends(
  alternative_periods,
  18L,
  "alternatieve ecologische MSI-perioden",
  "trend_pct_per_jaar"
)

cat("TRIM-groepsuitvoercontract: OK (18 ecologisch; 24 functioneel; groepen beschrijvend)\n")
