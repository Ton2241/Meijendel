#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(rtrim))

source(file.path("R", "trim_trend_contract.R"))

assert_true <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}

assert_equal <- function(actual, expected, tolerance = 1e-10, message = "waarden verschillen") {
  if (length(actual) != length(expected) || any(is.na(actual) != is.na(expected))) {
    stop(message, call. = FALSE)
  }
  comparable <- !is.na(actual)
  if (any(abs(actual[comparable] - expected[comparable]) > tolerance)) {
    stop(message, call. = FALSE)
  }
}

data(skylark, package = "rtrim")
model <- trim(
  count ~ site + time,
  data = skylark,
  model = 3,
  overdisp = TRUE,
  serialcor = FALSE
)
year_map <- data.frame(jaar = 1990:1997, trim_year = 1:8)
fit_obj <- list(
  model = model,
  config = "model3_overdisp",
  year_map = year_map
)

formal <- trim_overall_contract(fit_obj, periode = "1990-1997")
raw <- rtrim::overall(model, which = "imputed")$slope[1, ]
t_value <- qt(0.975, df = nrow(year_map) - 2L)

required_fields <- c(
  "trend_contract", "trend_formaliteit", "periode", "eerste_jaar",
  "laatste_jaar", "n_kalenderjaren", "n_modeltijdpunten",
  "trend_pct_per_jaar", "trend_se_pct", "trend_ci95_laag_pct",
  "trend_ci95_hoog_pct", "trend_p", "trend_methode", "trend_status",
  "trendklasse", "trendduiding_type", "model", "model_fallback_reden"
)
assert_true(all(required_fields %in% names(formal)), "trim-trend-v2 mist verplichte velden")
assert_true(identical(formal$trend_contract, "trim-trend-v2"), "verkeerde contractversie")
assert_true(identical(formal$trend_formaliteit, "formeel"), "geldige periode moet formeel zijn")
assert_true(identical(formal$trend_status, "beschikbaar"), "geldige periode moet beschikbaar zijn")
assert_equal(formal$trend_pct_per_jaar, 100 * (raw$mul - 1), message = "trendschatting gebruikt niet rtrim::overall")
assert_equal(formal$trend_se_pct, 100 * raw$se_mul, message = "standaardfout is onjuist getransformeerd")
assert_equal(
  formal$trend_ci95_laag_pct,
  100 * (exp(raw$add - t_value * raw$se_add) - 1),
  message = "ondergrens 95%-BI is onjuist"
)
assert_equal(
  formal$trend_ci95_hoog_pct,
  100 * (exp(raw$add + t_value * raw$se_add) - 1),
  message = "bovengrens 95%-BI is onjuist"
)
assert_equal(formal$trend_p, raw$p, message = "p-waarde wijkt af van rtrim::overall")
assert_true(identical(formal$trend_methode, "rtrim::overall(imputed); volledige variantie-covariantiematrix"), "methode is niet expliciet")

missing_period <- trim_overall_contract(
  list(model = NULL, config = NA_character_, year_map = NULL),
  periode = "1958-1983",
  periode_van = 1958L,
  periode_tot = 1983L
)
assert_true(identical(missing_period$trend_formaliteit, "niet_beschikbaar"), "ontbrekend model is ten onrechte formeel")
assert_true(identical(missing_period$trend_status, "geen_model"), "ontbrekend model heeft verkeerde status")
assert_true(all(is.na(missing_period[c("trend_pct_per_jaar", "trend_se_pct", "trend_ci95_laag_pct", "trend_ci95_hoog_pct", "trend_p")])), "ontbrekende periode bevat inferentie")

gap_map <- year_map
gap_map$jaar[3:8] <- gap_map$jaar[3:8] + 1L
gap_period <- trim_overall_contract(
  within(fit_obj, year_map <- gap_map),
  periode = "1990-1998"
)
assert_true(identical(gap_period$trend_formaliteit, "niet_formeel"), "kalenderjaargat is niet geblokkeerd")
assert_true(identical(gap_period$trend_status, "kalenderjaargaten"), "kalenderjaargat heeft verkeerde status")
assert_true(all(is.na(gap_period[c("trend_pct_per_jaar", "trend_se_pct", "trend_ci95_laag_pct", "trend_ci95_hoog_pct", "trend_p")])), "kalenderjaargat bevat formele inferentie")

fallback <- trim_overall_contract(
  within(fit_obj, config <- "model2_basis"),
  periode = "1990-1997"
)
assert_true(identical(fallback$trend_formaliteit, "formeel"), "werkend fallbackmodel moet formeel blijven")
assert_true(identical(fallback$model_fallback_reden, "model3_varianten_mislukt_fallback_naar_model2"), "fallbackreden ontbreekt")
assert_equal(fallback$trend_pct_per_jaar, formal$trend_pct_per_jaar, message = "fallbacklabel verandert de berekening")

descriptive <- trim_descriptive_contract(
  periode = "1958-2025",
  periode_van = 1958L,
  periode_tot = 2025L,
  trend_pct_per_jaar = -1.25,
  status = "gebrugde_reeks"
)
assert_true(identical(descriptive$trend_formaliteit, "beschrijvend"), "gebrugde reeks moet beschrijvend zijn")
assert_true(is.na(descriptive$trend_p) && is.na(descriptive$trendklasse), "beschrijvende trend bevat formele claim")

cat("trim-trend-v2 contracttest: OK\n")
