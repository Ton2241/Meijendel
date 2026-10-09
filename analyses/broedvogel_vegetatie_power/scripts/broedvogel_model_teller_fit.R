fit_model_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))

  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
    return(normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

.fit_model_repo <- fit_model_repo()
source(file.path(
  .fit_model_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_prepare.R"
))

joint_teller_formulas <- function(include_effort = FALSE, effort_variable = NULL) {
  if (isTRUE(include_effort) && (is.null(effort_variable) || !nzchar(effort_variable))) {
    stop("Bij een inspanningsmodel is een inspanningsvariabele verplicht.", call. = FALSE)
  }
  if (!is.null(effort_variable) && !grepl("^[.A-Za-z][.A-Za-z0-9_]*$", effort_variable)) {
    stop("Ongeldige naam voor de inspanningsvariabele.", call. = FALSE)
  }

  fixed <- c("jaar_decennium", "analyse_bron_factor")
  if (isTRUE(include_effort)) fixed <- c(fixed, effort_variable)
  base_terms <- c(
    fixed,
    "offset(log_oppervlakte_km2)",
    "(1 + jaar_decennium | soort_factor)",
    "(1 | soort_plot_factor)",
    "(1 | jaar_factor)",
    "(1 | plotjaar_factor)"
  )
  m0 <- stats::as.formula(paste("count ~", paste(base_terms, collapse = " + ")))
  m1 <- stats::update.formula(m0, ~ . + (1 | tellerteam_factor))
  m2 <- stats::update.formula(
    m1,
    ~ . + ervaring_plot_z + ervaring_elders_z +
      (0 + ervaring_plot_z + ervaring_elders_z || soort_factor)
  )
  list(M0 = m0, M1 = m1, M2 = m2)
}

standardize_for_fit <- function(x) {
  x <- as.numeric(x)
  current_sd <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(current_sd) || current_sd <= 0) return(rep(0, length(x)))
  (x - mean(x, na.rm = TRUE)) / current_sd
}

prepare_experience_variant <- function(data, experience_variant = c("mean", "min", "max")) {
  experience_variant <- match.arg(experience_variant)
  plot_field <- paste0("ervaring_plot_", experience_variant)
  elsewhere_field <- paste0("ervaring_elders_", experience_variant)
  require_prepare_fields(data, c("row_id", plot_field, elsewhere_field), "modelpopulatie")
  data$ervaring_plot_z <- standardize_for_fit(data[[plot_field]])
  data$ervaring_elders_z <- standardize_for_fit(data[[elsewhere_field]])
  data
}

teller_team_diagnostics <- function(data) {
  require_prepare_fields(
    data,
    c("plot_id", "jaar", "tellerteam_factor"),
    "modelpopulatie"
  )
  plotyears <- unique(data.frame(
    plot_id = data$plot_id,
    jaar = data$jaar,
    team = as.character(data$tellerteam_factor),
    stringsAsFactors = FALSE
  ))
  repetitions <- table(plotyears$team)
  number_teams <- length(repetitions)
  singleton_teams <- sum(repetitions == 1L)
  list(
    aantal_plotjaren = nrow(plotyears),
    aantal_teams = number_teams,
    eenmalige_teams = singleton_teams,
    aandeel_eenmalige_teams = if (number_teams) singleton_teams / number_teams else NA_real_,
    team_plotjaren_min = if (number_teams) min(repetitions) else NA_integer_,
    team_plotjaren_mediaan = if (number_teams) stats::median(repetitions) else NA_real_,
    team_plotjaren_max = if (number_teams) max(repetitions) else NA_integer_
  )
}

safe_model_filename <- function(model_id) {
  cleaned <- gsub("[^A-Za-z0-9._-]+", "_", model_id)
  if (!nzchar(cleaned)) stop("Lege modelidentificatie.", call. = FALSE)
  paste0(cleaned, ".rds")
}

model_checkpoint_contract_hash <- function(formula, family_label, row_hash, model_id) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("R-pakket digest ontbreekt.", call. = FALSE)
  code_commit <- Sys.getenv("MEIJENDEL_ANALYSIS_COMMIT", unset = "")
  if (!nzchar(code_commit)) stop("MEIJENDEL_ANALYSIS_COMMIT ontbreekt voor het modelcheckpoint.", call. = FALSE)
  digest::digest(
    list(
      contract_version = 1L,
      git_commit = code_commit,
      model_id = model_id,
      row_hash = row_hash,
      formula = paste(deparse(formula, width.cutoff = 500L), collapse = " "),
      family = family_label,
      glmmTMB_version = as.character(utils::packageVersion("glmmTMB"))
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

variance_components_from_fit <- function(fit) {
  conditional <- glmmTMB::VarCorr(fit)$cond
  rows <- lapply(names(conditional), function(group) {
    matrix <- conditional[[group]]
    standard_deviation <- attr(matrix, "stddev")
    data.frame(
      grp = group,
      term = names(standard_deviation),
      variance = as.numeric(diag(matrix)),
      sdcor = as.numeric(standard_deviation),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

fit_glmmtmb_safely <- function(
    formula,
    data,
    model_id,
    checkpoint_dir,
    family = glmmTMB::nbinom2(link = "log"),
    family_label = "nbinom2") {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("R-pakket glmmTMB ontbreekt.", call. = FALSE)
  }
  require_prepare_fields(data, "row_id", "modelpopulatie")
  dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
  row_hash <- row_set_sha256(data$row_id)
  contract_hash <- model_checkpoint_contract_hash(formula, family_label, row_hash, model_id)
  fit_path <- file.path(checkpoint_dir, safe_model_filename(model_id))
  metadata_path <- paste0(fit_path, ".meta.rds")
  if (file.exists(fit_path) && file.exists(metadata_path)) {
    saved <- readRDS(metadata_path)
    if (is.list(saved) &&
        identical(saved$diagnostics$row_hash, row_hash) &&
        identical(saved$diagnostics$checkpoint_contract_hash, contract_hash)) {
      has_convergence_warning <- any(grepl(
        "convergence problem|false convergence|non-positive-definite",
        saved$warnings,
        ignore.case = TRUE
      ))
      saved$status <- if (isTRUE(saved$diagnostics$pdHess) && !has_convergence_warning) {
        "geslaagd"
      } else {
        "modeluitval"
      }
      saved$fit_path <- normalizePath(fit_path, mustWork = TRUE)
      saved$resumed <- TRUE
      return(saved)
    }
  }
  warnings <- character()
  started <- Sys.time()

  outcome <- tryCatch(
    withCallingHandlers(
      glmmTMB::glmmTMB(
        formula = formula,
        data = data,
        family = family,
        control = glmmTMB::glmmTMBControl(
          optCtrl = list(iter.max = 1000L, eval.max = 1000L)
        )
      ),
      warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

  if (inherits(outcome, "error")) {
    gc(verbose = FALSE)
    return(list(
      status = "modeluitval",
      fit_path = NULL,
      warnings = unique(warnings),
      diagnostics = list(
        model_id = model_id,
        n = nrow(data),
        row_hash = row_hash,
        checkpoint_contract_hash = contract_hash,
        elapsed_seconds = elapsed,
        error = conditionMessage(outcome),
        pdHess = NA,
        family = family_label,
        random_variances = NULL
      )
    ))
  }

  variance_components <- tryCatch(
    variance_components_from_fit(outcome),
    error = function(error) data.frame(error = conditionMessage(error), stringsAsFactors = FALSE)
  )
  pd_hessian <- isTRUE(outcome$sdr$pdHess)
  has_convergence_warning <- any(grepl(
    "convergence problem|false convergence|non-positive-definite",
    warnings,
    ignore.case = TRUE
  ))
  saveRDS(outcome, fit_path)
  result <- list(
    status = if (pd_hessian && !has_convergence_warning) "geslaagd" else "modeluitval",
    fit_path = normalizePath(fit_path, mustWork = TRUE),
    warnings = unique(warnings),
    diagnostics = list(
      model_id = model_id,
      n = nrow(data),
      row_hash = row_hash,
      checkpoint_contract_hash = contract_hash,
      elapsed_seconds = elapsed,
      error = NULL,
      pdHess = pd_hessian,
      family = family_label,
      random_variances = variance_components
    )
  )
  result$resumed <- FALSE
  saveRDS(result, metadata_path)
  rm(outcome)
  gc(verbose = FALSE)
  result
}

fit_summary_row <- function(model_name, result) {
  fit_statistics <- c(logLik = NA_real_, AIC = NA_real_, BIC = NA_real_)
  if (identical(result$status, "geslaagd") && file.exists(result$fit_path)) {
    fit <- readRDS(result$fit_path)
    fit_statistics <- c(
      logLik = as.numeric(stats::logLik(fit)),
      AIC = stats::AIC(fit),
      BIC = stats::BIC(fit)
    )
    rm(fit)
    gc(verbose = FALSE)
  }
  data.frame(
    model = model_name,
    status = result$status,
    n = result$diagnostics$n,
    row_hash = result$diagnostics$row_hash,
    logLik = unname(fit_statistics[["logLik"]]),
    AIC = unname(fit_statistics[["AIC"]]),
    BIC = unname(fit_statistics[["BIC"]]),
    pdHess = result$diagnostics$pdHess,
    waarschuwingen = paste(result$warnings, collapse = " | "),
    fout = if (is.null(result$diagnostics$error)) "" else result$diagnostics$error,
    stringsAsFactors = FALSE
  )
}

extract_species_trends <- function(models) {
  successful <- names(models)[vapply(models, function(x) identical(x$status, "geslaagd"), logical(1))]
  if (!length(successful)) return(data.frame())
  selected <- tail(successful, 1L)
  fit <- readRDS(models[[selected]]$fit_path)
  fixed <- glmmTMB::fixef(fit)$cond
  fixed_trend <- unname(fixed[["jaar_decennium"]])
  random <- tryCatch(glmmTMB::ranef(fit)$cond$soort_factor, error = function(error) NULL)
  if (is.null(random) || !"jaar_decennium" %in% names(random)) {
    rm(fit)
    gc(verbose = FALSE)
    return(data.frame())
  }
  out <- data.frame(
    model = selected,
    soort_id = rownames(random),
    log_trend_per_decennium = fixed_trend + random$jaar_decennium,
    stringsAsFactors = FALSE
  )
  out$factor_per_jaar <- exp(out$log_trend_per_decennium / 10)
  out$procent_per_jaar <- 100 * (out$factor_per_jaar - 1)
  rm(fit)
  gc(verbose = FALSE)
  out
}

fit_joint_teller_models <- function(
    data,
    analysis_id,
    checkpoint_dir,
    experience_variant = "mean",
    effort_variable = NULL) {
  prepared <- prepare_experience_variant(data, experience_variant)
  include_effort <- !is.null(effort_variable)
  formulas <- joint_teller_formulas(include_effort, effort_variable)
  required <- c(
    "row_id", "count", "jaar_decennium", "analyse_bron_factor", "log_oppervlakte_km2",
    "soort_factor", "soort_plot_factor", "jaar_factor", "plotjaar_factor",
    "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z"
  )
  if (include_effort) required <- c(required, effort_variable)
  require_prepare_fields(prepared, required, "modelpopulatie")
  complete <- stats::complete.cases(prepared[required])
  model_data <- droplevels(prepared[complete, , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete modelrijen beschikbaar.", call. = FALSE)
  expected_hash <- row_set_sha256(model_data$row_id)

  models <- vector("list", length(formulas))
  names(models) <- names(formulas)
  for (model_name in names(formulas)) {
    model_id <- paste(analysis_id, experience_variant, model_name, sep = "__")
    models[[model_name]] <- fit_glmmtmb_safely(
      formulas[[model_name]], model_data, model_id, checkpoint_dir
    )
  }
  model_hashes <- vapply(models, function(result) result$diagnostics$row_hash, character(1))
  if (any(model_hashes != expected_hash)) {
    stop("M0-M2 zijn niet op exact dezelfde responscellen gefit.", call. = FALSE)
  }

  comparison <- do.call(
    rbind,
    Map(fit_summary_row, names(models), models)
  )
  rownames(comparison) <- NULL
  list(
    models = models,
    comparison = comparison,
    species_trends = extract_species_trends(models),
    diagnostics = c(
      list(
        analysis_id = analysis_id,
        ervaring_variant = experience_variant,
        inspanningsvariabele = effort_variable,
        row_hash = expected_hash,
        n = nrow(model_data)
      ),
      teller_team_diagnostics(model_data)
    )
  )
}

species_teller_formulas <- function(include_source = TRUE, effort_variable = NULL) {
  fixed <- "jaar_decennium"
  if (include_source) fixed <- c(fixed, "analyse_bron_factor")
  if (!is.null(effort_variable)) fixed <- c(fixed, effort_variable)
  base <- c(
    fixed,
    "offset(log_oppervlakte_km2)",
    "(1 | plot_factor)",
    "(1 | jaar_factor)"
  )
  m0 <- stats::as.formula(paste("count ~", paste(base, collapse = " + ")))
  m1 <- stats::update.formula(m0, ~ . + (1 | tellerteam_factor))
  m2 <- stats::update.formula(m1, ~ . + ervaring_plot_z + ervaring_elders_z)
  list(M0 = m0, M1 = m1, M2 = m2)
}

eligible_species <- function(eligibility) {
  require_prepare_fields(
    eligibility,
    c("soort_id", "soort_naam", "structureel_geschikt"),
    "soortselectie"
  )
  out <- eligibility[as.logical(eligibility$structureel_geschikt), c("soort_id", "soort_naam"), drop = FALSE]
  out$soort_id <- as.integer(out$soort_id)
  out <- out[order(out$soort_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

coefficient_from_fit <- function(fit, term) {
  coefficients <- summary(fit)$coefficients$cond
  if (!term %in% rownames(coefficients)) return(c(estimate = NA_real_, se = NA_real_))
  c(
    estimate = unname(coefficients[term, "Estimate"]),
    se = unname(coefficients[term, "Std. Error"])
  )
}

team_sd_from_fit <- function(fit) {
  components <- tryCatch(variance_components_from_fit(fit), error = function(error) NULL)
  if (is.null(components) || !all(c("grp", "sdcor") %in% names(components))) return(NA_real_)
  team <- components[components$grp == "tellerteam_factor" & !is.na(components$sdcor), , drop = FALSE]
  if (!nrow(team)) NA_real_ else unname(team$sdcor[[1L]])
}

experience_ratio <- function(beta, earlier_years, raw_sd) {
  if (!is.finite(beta) || !is.finite(raw_sd) || raw_sd <= 0) return(NA_real_)
  exp(beta * log1p(earlier_years) / raw_sd)
}

empty_species_result <- function(species_id, species_name, status, reason, row_hash) {
  data.frame(
    soort_id = as.integer(species_id),
    soort_naam = as.character(species_name),
    status = status,
    reden = reason,
    row_hash = row_hash,
    m0_status = NA_character_, m1_status = NA_character_, m2_status = NA_character_,
    m0_familie = NA_character_, m1_familie = NA_character_, m2_familie = NA_character_,
    trend_m0_pct_jaar = NA_real_, trend_m0_se = NA_real_, trend_m0_laag = NA_real_, trend_m0_hoog = NA_real_,
    trend_m2_pct_jaar = NA_real_, trend_m2_se = NA_real_, trend_m2_laag = NA_real_, trend_m2_hoog = NA_real_,
    trendverschil_pctpunt = NA_real_, intervalbreedte_ratio_m2_m0 = NA_real_,
    team_sd = NA_real_, ervaring_plot_beta = NA_real_, ervaring_elders_beta = NA_real_,
    ratio_plot_1 = NA_real_, ratio_plot_3 = NA_real_, ratio_plot_5 = NA_real_,
    ratio_elders_1 = NA_real_, ratio_elders_3 = NA_real_, ratio_elders_5 = NA_real_,
    stringsAsFactors = FALSE
  )
}

fit_species_teller_models <- function(
    data,
    eligibility,
    analysis_id,
    checkpoint_dir,
    effort_variable = NULL) {
  candidates <- eligible_species(eligibility)
  prepared <- prepare_experience_variant(data, "mean")
  if (!"plot_factor" %in% names(prepared)) prepared$plot_factor <- factor(prepared$plot_id)
  required <- c(
    "row_id", "count", "jaar_decennium", "log_oppervlakte_km2", "analyse_bron_factor",
    "plot_factor", "jaar_factor", "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z"
  )
  if (!is.null(effort_variable)) required <- c(required, effort_variable)
  require_prepare_fields(prepared, required, "modelpopulatie")
  global_plot_sd <- stats::sd(prepared$ervaring_plot_mean, na.rm = TRUE)
  global_elsewhere_sd <- stats::sd(prepared$ervaring_elders_mean, na.rm = TRUE)

  results <- lapply(seq_len(nrow(candidates)), function(index) {
    species_id <- candidates$soort_id[[index]]
    species_name <- candidates$soort_naam[[index]]
    current <- prepared[prepared$soort_id == species_id, , drop = FALSE]
    current <- current[stats::complete.cases(current[required]), , drop = FALSE]
    current <- droplevels(current[order(current$plot_id, current$jaar), , drop = FALSE])
    current_hash <- row_set_sha256(current$row_id)
    if (!nrow(current) || sum(current$count > 0) == 0L) {
      return(empty_species_result(species_id, species_name, "uitval", "geen_positieve_tellingen", current_hash))
    }
    if (stats::sd(current$ervaring_plot_z) == 0 || stats::sd(current$ervaring_elders_z) == 0) {
      return(empty_species_result(species_id, species_name, "uitval", "constante_ervaring", current_hash))
    }

    include_source <- nlevels(droplevels(current$analyse_bron_factor)) > 1L
    formulas <- species_teller_formulas(include_source, effort_variable)
    fits <- vector("list", 3L)
    names(fits) <- names(formulas)
    for (model_name in names(formulas)) {
      model_id <- paste(analysis_id, species_id, model_name, sep = "__")
      result <- fit_glmmtmb_safely(formulas[[model_name]], current, model_id, checkpoint_dir)
      if (identical(result$status, "modeluitval")) {
        result <- fit_glmmtmb_safely(
          formulas[[model_name]], current, paste0(model_id, "__poisson"), checkpoint_dir,
          family = stats::poisson(link = "log"), family_label = "poisson_na_nb_uitval"
        )
      }
      fits[[model_name]] <- result
    }
    statuses <- vapply(fits, `[[`, character(1), "status")
    if (any(statuses != "geslaagd")) {
      failed <- names(statuses)[statuses != "geslaagd"]
      out <- empty_species_result(
        species_id, species_name, "modeluitval", paste0("fit_mislukt_", paste(failed, collapse = "_")), current_hash
      )
      out$m0_status <- statuses[["M0"]]
      out$m1_status <- statuses[["M1"]]
      out$m2_status <- statuses[["M2"]]
      return(out)
    }

    fit0 <- readRDS(fits$M0$fit_path)
    fit1 <- readRDS(fits$M1$fit_path)
    fit2 <- readRDS(fits$M2$fit_path)
    trend0 <- coefficient_from_fit(fit0, "jaar_decennium")
    trend2 <- coefficient_from_fit(fit2, "jaar_decennium")
    experience_plot <- coefficient_from_fit(fit2, "ervaring_plot_z")[["estimate"]]
    experience_elsewhere <- coefficient_from_fit(fit2, "ervaring_elders_z")[["estimate"]]
    annual <- function(beta) 100 * (exp(beta / 10) - 1)
    annual_bound <- function(beta, se, sign) 100 * (exp((beta + sign * 1.96 * se) / 10) - 1)
    interval0 <- c(annual_bound(trend0[["estimate"]], trend0[["se"]], -1), annual_bound(trend0[["estimate"]], trend0[["se"]], 1))
    interval2 <- c(annual_bound(trend2[["estimate"]], trend2[["se"]], -1), annual_bound(trend2[["estimate"]], trend2[["se"]], 1))
    out <- empty_species_result(species_id, species_name, "geslaagd", "", current_hash)
    out$m0_status <- fits$M0$status; out$m1_status <- fits$M1$status; out$m2_status <- fits$M2$status
    out$m0_familie <- fits$M0$diagnostics$family; out$m1_familie <- fits$M1$diagnostics$family; out$m2_familie <- fits$M2$diagnostics$family
    out$trend_m0_pct_jaar <- annual(trend0[["estimate"]]); out$trend_m0_se <- trend0[["se"]]
    out$trend_m0_laag <- interval0[[1L]]; out$trend_m0_hoog <- interval0[[2L]]
    out$trend_m2_pct_jaar <- annual(trend2[["estimate"]]); out$trend_m2_se <- trend2[["se"]]
    out$trend_m2_laag <- interval2[[1L]]; out$trend_m2_hoog <- interval2[[2L]]
    out$trendverschil_pctpunt <- out$trend_m2_pct_jaar - out$trend_m0_pct_jaar
    out$intervalbreedte_ratio_m2_m0 <- diff(interval2) / diff(interval0)
    out$team_sd <- team_sd_from_fit(fit1)
    out$ervaring_plot_beta <- experience_plot; out$ervaring_elders_beta <- experience_elsewhere
    for (years in c(1, 3, 5)) {
      out[[paste0("ratio_plot_", years)]] <- experience_ratio(experience_plot, years, global_plot_sd)
      out[[paste0("ratio_elders_", years)]] <- experience_ratio(experience_elsewhere, years, global_elsewhere_sd)
    }
    rm(fit0, fit1, fit2)
    gc(verbose = FALSE)
    out
  })
  do.call(rbind, results)
}

gee_coefficient <- function(fit, term) {
  coefficients <- summary(fit)$coefficients
  if (!term %in% rownames(coefficients)) return(c(estimate = NA_real_, se = NA_real_))
  c(estimate = coefficients[term, "Estimate"], se = coefficients[term, "Std.err"])
}

gee_teller_formulas <- function(include_source = TRUE) {
  fixed <- "jaar_decennium"
  if (include_source) fixed <- c(fixed, "analyse_bron_factor")
  m0 <- stats::as.formula(paste(
    "count ~",
    paste(c(fixed, "offset(log_oppervlakte_km2)"), collapse = " + ")
  ))
  list(M0 = m0, M2 = stats::update.formula(m0, ~ . + ervaring_plot_z + ervaring_elders_z))
}

gee_checkpoint_contract_hash <- function(formulas, row_hash, analysis_id, species_id) {
  code_commit <- Sys.getenv("MEIJENDEL_ANALYSIS_COMMIT", unset = "")
  if (!nzchar(code_commit)) stop("MEIJENDEL_ANALYSIS_COMMIT ontbreekt voor het GEE-checkpoint.", call. = FALSE)
  digest::digest(
    list(
      contract_version = 1L,
      git_commit = code_commit,
      analysis_id = analysis_id,
      species_id = as.integer(species_id),
      row_hash = row_hash,
      formulas = lapply(formulas, function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")),
      family = "poisson_log",
      correlation = "exchangeable",
      geepack_version = as.character(utils::packageVersion("geepack"))
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

validate_gee_fit <- function(fit, terms) {
  error_code <- suppressWarnings(as.integer(fit$geese$error))
  if (length(error_code) != 1L || is.na(error_code) || error_code != 0L) {
    return(list(valid = FALSE, error_code = if (length(error_code)) error_code[[1L]] else NA_integer_, coefficients = NULL))
  }
  coefficients <- lapply(terms, function(term) gee_coefficient(fit, term))
  names(coefficients) <- terms
  finite <- all(vapply(coefficients, function(value) {
    length(value) == 2L && all(is.finite(as.numeric(value)))
  }, logical(1)))
  list(valid = finite, error_code = error_code, coefficients = coefficients)
}

run_isolated_with_timeout <- function(fun, timeout_seconds = 60) {
  if (!is.numeric(timeout_seconds) || length(timeout_seconds) != 1L || timeout_seconds <= 0) {
    stop("De tijdslimiet moet één positief aantal seconden zijn.", call. = FALSE)
  }
  if (.Platform$OS.type != "unix") {
    return(tryCatch(
      {
        setTimeLimit(elapsed = timeout_seconds, transient = TRUE)
        on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
        list(status = "geslaagd", value = fun(), error = NULL)
      },
      error = function(error) list(status = "modeluitval", value = NULL, error = conditionMessage(error))
    ))
  }
  job <- parallel::mcparallel(
    tryCatch(
      list(status = "geslaagd", value = fun(), error = NULL),
      error = function(error) list(status = "modeluitval", value = NULL, error = conditionMessage(error))
    ),
    silent = TRUE
  )
  deadline <- Sys.time() + timeout_seconds
  repeat {
    collected <- suppressWarnings(parallel::mccollect(job, wait = FALSE))
    if (length(collected)) {
      result <- collected[[1L]]
      if (inherits(result, "try-error")) {
        return(list(status = "modeluitval", value = NULL, error = as.character(result)))
      }
      return(result)
    }
    if (Sys.time() >= deadline) {
      tools::pskill(job$pid, signal = 15L)
      suppressWarnings(parallel::mccollect(job, wait = TRUE))
      return(list(
        status = "modeluitval",
        value = NULL,
        error = paste0("tijdslimiet_", timeout_seconds, "_seconden")
      ))
    }
    Sys.sleep(0.05)
  }
}

fit_species_gee_checks <- function(
    data,
    eligibility,
    analysis_id,
    checkpoint_dir = NULL,
    timeout_seconds = 60) {
  if (!requireNamespace("geepack", quietly = TRUE)) stop("R-pakket geepack ontbreekt.", call. = FALSE)
  candidates <- eligible_species(eligibility)
  prepared <- prepare_experience_variant(data, "mean")
  required <- c(
    "row_id", "count", "jaar_decennium", "log_oppervlakte_km2", "analyse_bron_factor",
    "plot_id", "ervaring_plot_z", "ervaring_elders_z"
  )
  require_prepare_fields(prepared, required, "modelpopulatie")

  results <- lapply(seq_len(nrow(candidates)), function(index) {
    species_id <- candidates$soort_id[[index]]
    species_name <- candidates$soort_naam[[index]]
    current <- prepared[prepared$soort_id == species_id, , drop = FALSE]
    current <- current[stats::complete.cases(current[required]), , drop = FALSE]
    current <- droplevels(current[order(current$plot_id, current$jaar), , drop = FALSE])
    current_hash <- row_set_sha256(current$row_id)
    include_source <- nlevels(droplevels(current$analyse_bron_factor)) > 1L
    formulas <- gee_teller_formulas(include_source)
    contract_hash <- gee_checkpoint_contract_hash(formulas, current_hash, analysis_id, species_id)
    blank <- data.frame(
      soort_id = species_id, soort_naam = species_name, status = "uitval", reden = "",
      row_hash = current_hash, correlatiestructuur = "exchangeable",
      trend_m0_pct_jaar = NA_real_, trend_m2_pct_jaar = NA_real_, trendverschil_pctpunt = NA_real_,
      trend_m0_se = NA_real_, trend_m2_se = NA_real_,
      ervaring_plot_beta = NA_real_, ervaring_elders_beta = NA_real_,
      ervaring_plot_se = NA_real_, ervaring_elders_se = NA_real_,
      gee_error_m0 = NA_integer_, gee_error_m2 = NA_integer_,
      checkpoint_contract_hash = contract_hash,
      stringsAsFactors = FALSE
    )
    checkpoint_path <- if (is.null(checkpoint_dir)) NULL else file.path(
      checkpoint_dir,
      safe_model_filename(paste("gee", analysis_id, species_id, sep = "__"))
    )
    if (!is.null(checkpoint_path)) {
      dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
      if (file.exists(checkpoint_path)) {
        saved <- readRDS(checkpoint_path)
        if (is.data.frame(saved) && nrow(saved) == 1L &&
            identical(saved$row_hash, current_hash) &&
            identical(saved$checkpoint_contract_hash, contract_hash)) {
          return(saved)
        }
      }
    }
    finish <- function(result) {
      if (!is.null(checkpoint_path)) saveRDS(result, checkpoint_path)
      result
    }
    if (!nrow(current) || sum(current$count > 0) == 0L) {
      blank$reden <- "geen_positieve_tellingen"
      return(finish(blank))
    }
    if (stats::sd(current$ervaring_plot_z) == 0 || stats::sd(current$ervaring_elders_z) == 0) {
      blank$reden <- "constante_ervaring"
      return(finish(blank))
    }
    isolated <- run_isolated_with_timeout(function() {
      local_warnings <- character()
      fits <- withCallingHandlers(
        list(
          M0 = geepack::geeglm(formulas$M0, data = current, id = plot_id, family = stats::poisson("log"), corstr = "exchangeable"),
          M2 = geepack::geeglm(formulas$M2, data = current, id = plot_id, family = stats::poisson("log"), corstr = "exchangeable")
        ),
        warning = function(warning) {
          local_warnings <<- c(local_warnings, conditionMessage(warning))
          invokeRestart("muffleWarning")
        }
      )
      list(fits = fits, warnings = unique(local_warnings))
    }, timeout_seconds)
    if (!identical(isolated$status, "geslaagd")) {
      blank$status <- "modeluitval"
      blank$reden <- isolated$error
      return(finish(blank))
    }
    fits <- isolated$value$fits
    warnings <- isolated$value$warnings
    diagnostics_m0 <- validate_gee_fit(fits$M0, "jaar_decennium")
    diagnostics_m2 <- validate_gee_fit(
      fits$M2,
      c("jaar_decennium", "ervaring_plot_z", "ervaring_elders_z")
    )
    blank$gee_error_m0 <- diagnostics_m0$error_code
    blank$gee_error_m2 <- diagnostics_m2$error_code
    if (!isTRUE(diagnostics_m0$valid) || !isTRUE(diagnostics_m2$valid)) {
      blank$status <- "modeluitval"
      blank$reden <- "ongeldige_gee_convergentie_of_coefficient"
      return(finish(blank))
    }
    trend0 <- diagnostics_m0$coefficients$jaar_decennium[["estimate"]]
    trend2 <- diagnostics_m2$coefficients$jaar_decennium[["estimate"]]
    annual <- function(beta) 100 * (exp(beta / 10) - 1)
    blank$status <- "geslaagd"; blank$reden <- paste(unique(warnings), collapse = " | ")
    blank$trend_m0_pct_jaar <- annual(trend0); blank$trend_m2_pct_jaar <- annual(trend2)
    blank$trendverschil_pctpunt <- blank$trend_m2_pct_jaar - blank$trend_m0_pct_jaar
    blank$trend_m0_se <- diagnostics_m0$coefficients$jaar_decennium[["se"]]
    blank$trend_m2_se <- diagnostics_m2$coefficients$jaar_decennium[["se"]]
    blank$ervaring_plot_beta <- diagnostics_m2$coefficients$ervaring_plot_z[["estimate"]]
    blank$ervaring_elders_beta <- diagnostics_m2$coefficients$ervaring_elders_z[["estimate"]]
    blank$ervaring_plot_se <- diagnostics_m2$coefficients$ervaring_plot_z[["se"]]
    blank$ervaring_elders_se <- diagnostics_m2$coefficients$ervaring_elders_z[["se"]]
    finish(blank)
  })
  do.call(rbind, results)
}

summarise_teller_sensitivity <- function(joint, species, gee) {
  require_prepare_fields(species, c("soort_id", "status", "row_hash"), "soortmodellen")
  require_prepare_fields(gee, c("soort_id", "status", "row_hash"), "GEE-controle")
  comparison <- merge(species, gee, by = c("soort_id", "soort_naam"), all = TRUE, suffixes = c("_glmm", "_gee"), sort = TRUE)
  successful <- comparison$status_glmm == "geslaagd" & comparison$status_gee == "geslaagd"
  same_direction <- successful &
    sign(comparison$ervaring_plot_beta_glmm) == sign(comparison$ervaring_plot_beta_gee) &
    sign(comparison$ervaring_elders_beta_glmm) == sign(comparison$ervaring_elders_beta_gee)
  finite_shift <- species$trendverschil_pctpunt[is.finite(species$trendverschil_pctpunt)]
  summary <- data.frame(
    metric = c(
      "kandidaatsoorten", "glmm_geslaagd", "glmm_uitval", "gee_geslaagd", "gee_uitval",
      "mediaan_absolute_trendverschuiving_pctpunt", "richtingsovereenkomst_glmm_gee"
    ),
    value = c(
      nrow(species), sum(species$status == "geslaagd"), sum(species$status != "geslaagd"),
      sum(gee$status == "geslaagd"), sum(gee$status != "geslaagd"),
      if (length(finite_shift)) stats::median(abs(finite_shift)) else NA_real_,
      if (any(successful)) mean(same_direction[successful]) else NA_real_
    ),
    stringsAsFactors = FALSE
  )
  list(
    summary = summary,
    species_comparison = comparison,
    diagnostics = list(
      aantal_kandidaatsoorten = nrow(species),
      gelijke_soortselectie = identical(sort(species$soort_id), sort(gee$soort_id)),
      gelijke_responsrijen = nrow(comparison) == nrow(species) &&
        !anyNA(comparison$row_hash_glmm) && !anyNA(comparison$row_hash_gee) &&
        all(comparison$row_hash_glmm == comparison$row_hash_gee),
      gezamenlijk_model = joint$comparison
    )
  )
}
