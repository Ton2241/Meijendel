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

fit_glmmtmb_safely <- function(formula, data, model_id, checkpoint_dir) {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    stop("R-pakket glmmTMB ontbreekt.", call. = FALSE)
  }
  require_prepare_fields(data, "row_id", "modelpopulatie")
  dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
  row_hash <- row_set_sha256(data$row_id)
  warnings <- character()
  started <- Sys.time()

  outcome <- tryCatch(
    withCallingHandlers(
      glmmTMB::glmmTMB(
        formula = formula,
        data = data,
        family = glmmTMB::nbinom2(link = "log"),
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
        elapsed_seconds = elapsed,
        error = conditionMessage(outcome),
        pdHess = NA,
        random_variances = NULL
      )
    ))
  }

  variance_components <- tryCatch(
    as.data.frame(glmmTMB::VarCorr(outcome)),
    error = function(error) data.frame(error = conditionMessage(error), stringsAsFactors = FALSE)
  )
  pd_hessian <- isTRUE(outcome$sdr$pdHess)
  fit_path <- file.path(checkpoint_dir, safe_model_filename(model_id))
  saveRDS(outcome, fit_path)
  result <- list(
    status = "geslaagd",
    fit_path = normalizePath(fit_path, mustWork = TRUE),
    warnings = unique(warnings),
    diagnostics = list(
      model_id = model_id,
      n = nrow(data),
      row_hash = row_hash,
      elapsed_seconds = elapsed,
      error = NULL,
      pdHess = pd_hessian,
      random_variances = variance_components
    )
  )
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
