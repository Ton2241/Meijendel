finite_positive_mean <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x) & x > 0]
  if (!length(x)) NA_real_ else mean(x)
}

values_for_years <- function(x, years) {
  if (is.null(x)) return(numeric())
  if (is.null(names(x))) stop("Jaarwaarden moeten benoemde kalenderjaren hebben.", call. = FALSE)
  x[match(as.character(years), names(x))]
}

compute_empirical_bridge <- function(
    pre_index,
    post_index,
    calibration_totals,
    pre_years = 1981:1983,
    post_years = 1986:1988,
    allow_transition_years = FALSE) {
  pre_years <- as.integer(pre_years)
  post_years <- as.integer(post_years)
  if (!allow_transition_years && any(post_years %in% c(1984L, 1985L))) {
    stop("1984 en 1985 mogen de primaire brug niet kalibreren.", call. = FALSE)
  }
  method <- sprintf(
    "common_plot_trim_%s_to_%s",
    paste(range(pre_years), collapse = "_"),
    paste(range(post_years), collapse = "_")
  )
  invalid <- function(reason) list(
    level_ratio = NA_real_, bridge_factor = NA_real_, method = method,
    status = "geen_formele_brug", reason = reason
  )
  if (is.null(calibration_totals)) return(invalid("hulp_trim_mislukt"))

  pre_total <- finite_positive_mean(values_for_years(calibration_totals, pre_years))
  post_total <- finite_positive_mean(values_for_years(calibration_totals, post_years))
  pre_anchor <- finite_positive_mean(values_for_years(pre_index, pre_years))
  post_anchor <- finite_positive_mean(values_for_years(post_index, post_years))
  if (!all(is.finite(c(pre_total, post_total, pre_anchor, post_anchor))) || any(c(pre_total, post_total, pre_anchor, post_anchor) <= 0)) {
    return(invalid("niet_positief_of_onvolledig_ankervenster"))
  }
  level_ratio <- post_total / pre_total
  bridge_factor <- pre_anchor * level_ratio / post_anchor
  if (!is.finite(level_ratio) || level_ratio <= 0 || !is.finite(bridge_factor) || bridge_factor <= 0) {
    return(invalid("ongeldige_niveauverhouding"))
  }
  list(
    level_ratio = level_ratio,
    bridge_factor = bridge_factor,
    method = method,
    status = "formele_brug",
    reason = NA_character_
  )
}

fit_bridge_calibration_trim <- function(species_df, draw, plot_ids, pre_years, post_years) {
  required <- c("bootstrap_cluster_id", "jaar", "geteld", "count_adjusted")
  missing <- setdiff(required, names(species_df))
  if (length(missing)) return(list(ok = FALSE, totals = NULL, reason = paste("mist", paste(missing, collapse = ","))))
  drawn <- apply_cluster_draw(species_df, draw)
  years <- c(as.integer(pre_years), as.integer(post_years))
  drawn <- drawn[
    drawn$source_cluster_id %in% plot_ids & drawn$jaar %in% years &
      drawn$geteld %in% TRUE & is.finite(drawn$count_adjusted),
    , drop = FALSE
  ]
  if (!nrow(drawn) || length(unique(drawn$jaar)) < length(years)) {
    return(list(ok = FALSE, totals = NULL, reason = "onvolledige_ankercellen"))
  }
  year_map <- data.frame(jaar = sort(unique(years)), trim_year = seq_along(sort(unique(years))))
  drawn <- merge(drawn, year_map, by = "jaar", all.x = TRUE)
  fit_data <- data.frame(site = drawn$bootstrap_site_id, year = drawn$trim_year, count = drawn$count_adjusted)
  warnings <- character()
  fit <- tryCatch(
    withCallingHandlers(
      rtrim::trim(fit_data, model = 3, overdisp = TRUE, serialcor = FALSE, autodelete = TRUE, conv_crit = 1e-5, max_iter = 400),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  if (inherits(fit, "error")) return(list(ok = FALSE, totals = NULL, reason = conditionMessage(fit), warnings = warnings))
  tt <- rtrim::totals(fit, which = "imputed")
  mapped_years <- year_map$jaar[match(tt$time, year_map$trim_year)]
  totals <- stats::setNames(as.numeric(tt$imputed), as.character(mapped_years))
  list(ok = TRUE, totals = totals, model = fit, warnings = unique(warnings), site_ids = sort(unique(drawn$bootstrap_site_id)))
}

compute_bridge_variants <- function(species_df, pre_index, post_index, draw, config) {
  variants <- config$bridge_variants
  if (is.null(variants) || !length(variants)) stop("Geen brugvarianten geconfigureerd.", call. = FALSE)
  rows <- lapply(names(variants), function(name) {
    variant <- variants[[name]]
    calibration <- fit_bridge_calibration_trim(
      species_df, draw, variant$plot_ids, variant$pre_years, variant$post_years
    )
    bridge <- compute_empirical_bridge(
      pre_index, post_index,
      if (isTRUE(calibration$ok)) calibration$totals else NULL,
      variant$pre_years, variant$post_years,
      allow_transition_years = isTRUE(variant$allow_transition_years)
    )
    data.frame(
      bridge_variant = name,
      pre_years = paste(range(variant$pre_years), collapse = "-"),
      post_years = paste(range(variant$post_years), collapse = "-"),
      level_ratio = bridge$level_ratio,
      bridge_factor = bridge$bridge_factor,
      bridge_method = bridge$method,
      bridge_status = bridge$status,
      bridge_reason = if (isTRUE(calibration$ok)) bridge$reason else calibration$reason,
      calibration_site_ids = paste(calibration$site_ids %||% integer(), collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
