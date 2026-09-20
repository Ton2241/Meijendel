TRIM_TREND_CONTRACT_VERSION <- "trim-trend-v2"
TRIM_OVERALL_METHOD <- "rtrim::overall(imputed); volledige variantie-covariantiematrix"

trim_fallback_reason <- function(model_label) {
  if (length(model_label) != 1L || is.na(model_label) || !nzchar(model_label)) {
    return("geen_model")
  }
  switch(
    model_label,
    model3_overdisp = "voorkeursmodel_gekozen",
    model3_overdisp_serialcor = "model3_overdisp_mislukt_fallback_naar_serialcor",
    model3_basis = "overdisp_varianten_mislukt_fallback_naar_basis",
    model2_basis = "model3_varianten_mislukt_fallback_naar_model2",
    "onbekend"
  )
}

trim_meaning_nl <- function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) return(NA_character_)
  switch(
    value,
    "Strong increase (p<0.01)" = "sterke_toename_p_kleiner_dan_0_01",
    "Strong decrease (p<0.01)" = "sterke_afname_p_kleiner_dan_0_01",
    "Strong increase (p<0.05)" = "sterke_toename_p_kleiner_dan_0_05",
    "Strong decrease (p<0.05)" = "sterke_afname_p_kleiner_dan_0_05",
    "Moderate increase (p<0.01)" = "matige_toename_p_kleiner_dan_0_01",
    "Moderate decrease (p<0.01)" = "matige_afname_p_kleiner_dan_0_01",
    "Moderate increase (p<0.05)" = "matige_toename_p_kleiner_dan_0_05",
    "Moderate decrease (p<0.05)" = "matige_afname_p_kleiner_dan_0_05",
    "Stable" = "stabiel",
    "Uncertain" = "onzeker",
    "Unknown (df<=0)" = "onvoldoende_vrijheidsgraden",
    NA_character_
  )
}

trim_contract_row <- function(
    periode,
    periode_van,
    periode_tot,
    n_kalenderjaren,
    n_modeltijdpunten,
    trend_formaliteit,
    trend_status,
    model,
    trend_pct_per_jaar = NA_real_,
    trend_se_pct = NA_real_,
    trend_ci95_laag_pct = NA_real_,
    trend_ci95_hoog_pct = NA_real_,
    trend_p = NA_real_,
    trend_methode = NA_character_,
    trendklasse = NA_character_,
    trendduiding_type = NA_character_) {
  data.frame(
    trend_contract = TRIM_TREND_CONTRACT_VERSION,
    trend_formaliteit = trend_formaliteit,
    periode = as.character(periode),
    eerste_jaar = as.integer(periode_van),
    laatste_jaar = as.integer(periode_tot),
    n_kalenderjaren = as.integer(n_kalenderjaren),
    n_modeltijdpunten = as.integer(n_modeltijdpunten),
    trend_pct_per_jaar = as.numeric(trend_pct_per_jaar),
    trend_se_pct = as.numeric(trend_se_pct),
    trend_ci95_laag_pct = as.numeric(trend_ci95_laag_pct),
    trend_ci95_hoog_pct = as.numeric(trend_ci95_hoog_pct),
    trend_p = as.numeric(trend_p),
    trend_methode = as.character(trend_methode),
    trend_status = as.character(trend_status),
    trendklasse = as.character(trendklasse),
    trendduiding_type = as.character(trendduiding_type),
    model = if (length(model) == 1L) as.character(model) else NA_character_,
    model_fallback_reden = trim_fallback_reason(model),
    stringsAsFactors = FALSE
  )
}

trim_overall_contract <- function(
    fit_obj,
    periode,
    periode_van = NA_integer_,
    periode_tot = NA_integer_) {
  model <- fit_obj$model
  model_label <- fit_obj$config
  year_map <- fit_obj$year_map

  if (is.null(model)) {
    return(trim_contract_row(
      periode = periode,
      periode_van = periode_van,
      periode_tot = periode_tot,
      n_kalenderjaren = if (is.finite(periode_van) && is.finite(periode_tot)) periode_tot - periode_van + 1L else NA_integer_,
      n_modeltijdpunten = 0L,
      trend_formaliteit = "niet_beschikbaar",
      trend_status = "geen_model",
      model = model_label
    ))
  }

  if (is.null(year_map) || !all(c("jaar", "trim_year") %in% names(year_map))) {
    return(trim_contract_row(
      periode = periode,
      periode_van = periode_van,
      periode_tot = periode_tot,
      n_kalenderjaren = NA_integer_,
      n_modeltijdpunten = model$ntime,
      trend_formaliteit = "niet_formeel",
      trend_status = "jaar_mapping_ontbreekt",
      model = model_label
    ))
  }

  year_map <- year_map[order(year_map$trim_year), , drop = FALSE]
  years <- as.integer(year_map$jaar)
  periode_van <- min(years)
  periode_tot <- max(years)
  n_calendar <- periode_tot - periode_van + 1L
  has_gaps <- length(years) != n_calendar || any(diff(years) != 1L)
  if (has_gaps) {
    return(trim_contract_row(
      periode = periode,
      periode_van = periode_van,
      periode_tot = periode_tot,
      n_kalenderjaren = n_calendar,
      n_modeltijdpunten = length(years),
      trend_formaliteit = "niet_formeel",
      trend_status = "kalenderjaargaten",
      model = model_label
    ))
  }

  result <- tryCatch(rtrim::overall(model, which = "imputed"), error = function(e) e)
  if (inherits(result, "error") || is.null(result$slope) || nrow(result$slope) != 1L) {
    return(trim_contract_row(
      periode = periode,
      periode_van = periode_van,
      periode_tot = periode_tot,
      n_kalenderjaren = n_calendar,
      n_modeltijdpunten = length(years),
      trend_formaliteit = "niet_beschikbaar",
      trend_status = "overall_mislukt",
      model = model_label
    ))
  }

  slope <- result$slope[1, , drop = FALSE]
  degrees_freedom <- length(years) - 2L
  t_value <- stats::qt(0.975, df = degrees_freedom)
  trim_contract_row(
    periode = periode,
    periode_van = periode_van,
    periode_tot = periode_tot,
    n_kalenderjaren = n_calendar,
    n_modeltijdpunten = length(years),
    trend_formaliteit = "formeel",
    trend_status = "beschikbaar",
    model = model_label,
    trend_pct_per_jaar = 100 * (slope$mul - 1),
    trend_se_pct = 100 * slope$se_mul,
    trend_ci95_laag_pct = 100 * (exp(slope$add - t_value * slope$se_add) - 1),
    trend_ci95_hoog_pct = 100 * (exp(slope$add + t_value * slope$se_add) - 1),
    trend_p = slope$p,
    trend_methode = TRIM_OVERALL_METHOD,
    trendklasse = trim_meaning_nl(slope$meaning),
    trendduiding_type = "rtrim_overall_classificatie"
  )
}

trim_descriptive_contract <- function(
    periode,
    periode_van,
    periode_tot,
    trend_pct_per_jaar,
    status,
    model = NA_character_) {
  trim_contract_row(
    periode = periode,
    periode_van = periode_van,
    periode_tot = periode_tot,
    n_kalenderjaren = periode_tot - periode_van + 1L,
    n_modeltijdpunten = periode_tot - periode_van + 1L,
    trend_formaliteit = "beschrijvend",
    trend_status = status,
    model = model,
    trend_pct_per_jaar = trend_pct_per_jaar,
    trend_methode = "loglineaire samenvatting van geschatte indices; geen formele inferentie",
    trendduiding_type = "beschrijvend_geen_trendklasse"
  )
}
