finite_positive_mean <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || any(!is.finite(x)) || any(x < 0)) return(NA_real_)
  value <- mean(x)
  if (value > 0) value else NA_real_
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
  # totals() is een afgeronde presentatietabel. Behoud de absolute
  # ongeronde vector en verifieer haar met de publieke index-API.
  tt <- rtrim::index(fit, which = "imputed")
  raw_totals <- as.numeric(fit$tt_imp)
  if (length(raw_totals) != nrow(tt) || any(!is.finite(raw_totals)) ||
      any(raw_totals <= 0) || !isTRUE(all.equal(raw_totals / raw_totals[[1L]], as.numeric(tt$imputed), tolerance = 1e-8))) {
    return(list(ok = FALSE, totals = NULL, reason = "ongeronde_totalen_contract_mislukt"))
  }
  mapped_years <- year_map$jaar[match(tt$time, year_map$trim_year)]
  totals <- stats::setNames(raw_totals, as.character(mapped_years))
  list(ok = TRUE, totals = totals, model = fit, warnings = unique(warnings), site_ids = sort(unique(drawn$bootstrap_site_id)))
}

# Geprofileerd loglineair site + venstermodel. De conditionele likelihood
# gebruikt per site twee venstersommen en hun werkelijk getelde jaren.
fit_bridge_calibration_window <- function(species_df, draw, plot_ids, pre_years, post_years) {
  invalid <- function(reason) list(ok = FALSE, totals = NULL, reason = reason)
  required <- c("bootstrap_cluster_id", "jaar", "geteld", "count_adjusted")
  if (length(setdiff(required, names(species_df)))) return(invalid("onvolledige_vensterinvoer"))
  years <- c(as.integer(pre_years), as.integer(post_years))
  if (anyDuplicated(years)) return(invalid("overlappende_of_dubbele_brugjaren"))
  drawn <- apply_cluster_draw(species_df, draw)
  drawn <- drawn[drawn$source_cluster_id %in% plot_ids & drawn$jaar %in% years & drawn$geteld %in% TRUE, , drop = FALSE]
  if (!nrow(drawn) || !setequal(unique(drawn$jaar), years)) return(invalid("onvolledige_ankercellen"))
  if (any(!is.finite(drawn$count_adjusted)) || any(drawn$count_adjusted < 0)) return(invalid("ongeldige_venstertelling"))
  if (anyDuplicated(drawn[c("bootstrap_site_id", "jaar")])) return(invalid("dubbele_venstercel"))
  drawn$window <- ifelse(drawn$jaar %in% pre_years, "pre", "post")
  summed <- aggregate(count_adjusted ~ bootstrap_site_id + window, drawn, sum)
  exposure <- aggregate(jaar ~ bootstrap_site_id + window, drawn, length)
  names(exposure)[names(exposure) == "jaar"] <- "exposure"
  summed <- merge(summed, exposure, by = c("bootstrap_site_id", "window"))
  paired <- merge(summed[summed$window == "pre", ], summed[summed$window == "post", ], by = "bootstrap_site_id", suffixes = c("_pre", "_post"))
  if (!nrow(paired)) return(invalid("geen_gemeenschappelijke_venstersites"))
  paired_years <- drawn$jaar[drawn$bootstrap_site_id %in% paired$bootstrap_site_id]
  if (!setequal(unique(paired_years), years)) return(invalid("onvolledige_ankercellen_gepaarde_sites"))
  if (sum(paired$count_adjusted_pre) <= 0 || sum(paired$count_adjusted_post) <= 0) return(invalid("nul_totaal_volledig_venster"))
  paired$total <- paired$count_adjusted_pre + paired$count_adjusted_post
  paired <- paired[paired$total > 0, , drop = FALSE]
  paired$proportion <- paired$count_adjusted_post / paired$total
  paired$log_exposure_ratio <- log(paired$exposure_post / paired$exposure_pre)
  warnings <- character()
  fit <- tryCatch(withCallingHandlers(
    stats::glm(proportion ~ 1 + offset(log_exposure_ratio), weights = total,
      family = stats::quasibinomial(link = "logit"), data = paired,
      control = stats::glm.control(epsilon = 1e-10, maxit = 100)),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
  ), error = function(e) e)
  if (inherits(fit, "error")) return(invalid(conditionMessage(fit)))
  ratio <- exp(unname(stats::coef(fit)[[1L]]))
  if (!isTRUE(fit$converged) || !is.finite(ratio) || ratio <= 0) return(invalid("venstermodel_niet_schatbaar"))
  # Gestandaardiseerd jaarlijks niveau over dezelfde informatieve sites.
  site_pre <- paired$total / (paired$exposure_pre + ratio * paired$exposure_post)
  pre_level <- sum(site_pre)
  totals <- stats::setNames(c(rep(pre_level, length(pre_years)), rep(pre_level * ratio, length(post_years))), as.character(years))
  list(ok = TRUE, totals = totals, model = fit, warnings = unique(warnings),
    site_ids = sort(unique(paired$bootstrap_site_id)), reason = NA_character_)
}

compute_bridge_variants <- function(species_df, pre_index, post_index, draw, config) {
  variants <- config$bridge_variants
  if (is.null(variants) || !length(variants)) stop("Geen brugvarianten geconfigureerd.", call. = FALSE)
  calibration_method <- config$calibration_method %||% config$config$calibration_method %||% "yearly_trim"
  if (!calibration_method %in% c("yearly_trim", "window_poisson")) stop("Onbekende brugkalibratiemethode.", call. = FALSE)
  calibration_fn <- if (calibration_method == "window_poisson") fit_bridge_calibration_window else fit_bridge_calibration_trim
  rows <- lapply(names(variants), function(name) {
    variant <- variants[[name]]
    calibration <- calibration_fn(
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
      bridge_method = paste(bridge$method, calibration_method, sep = ":"),
      calibration_method = calibration_method,
      bridge_status = bridge$status,
      bridge_reason = if (isTRUE(calibration$ok)) bridge$reason else calibration$reason,
      calibration_site_ids = paste(calibration$site_ids %||% integer(), collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
