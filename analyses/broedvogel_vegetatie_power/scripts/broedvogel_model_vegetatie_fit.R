vegetation_fit_repo <- function() {
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

.vegetation_fit_repo <- vegetation_fit_repo()
source(file.path(
  .vegetation_fit_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_data.R"
))
source(file.path(
  .vegetation_fit_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_fit.R"
))

vegetation_model_formulas <- function(metric) {
  if (!metric %in% names(pq_metric_contract())) {
    stop("Onbekende PQ-maat: ", metric, call. = FALSE)
  }
  base <- joint_teller_formulas()[["M2"]]
  between <- paste0(metric, "_between_z")
  within <- paste0(metric, "_within_z")
  pq <- stats::update.formula(
    base,
    stats::as.formula(paste(
      "~ . +", between, "+", within,
      "+ (0 +", between, "+", within, "|| soort_factor)"
    ))
  )
  list(basis = base, pq = pq)
}

vegetation_required_fields <- function(metric) {
  c(
    "row_id", "count", "jaar_decennium", "analyse_bron_factor",
    "log_oppervlakte_km2", "soort_factor", "soort_plot_factor", "jaar_factor",
    "plotjaar_factor", "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z",
    paste0(metric, "_between_z"), paste0(metric, "_within_z")
  )
}

extract_vegetation_species_effects <- function(result, metric, species_lookup) {
  if (!identical(result$status, "geslaagd") || !file.exists(result$fit_path)) {
    return(data.frame())
  }
  fit <- readRDS(result$fit_path)
  fixed <- glmmTMB::fixef(fit)$cond
  random <- tryCatch(glmmTMB::ranef(fit)$cond$soort_factor, error = function(e) NULL)
  between <- paste0(metric, "_between_z")
  within <- paste0(metric, "_within_z")
  if (is.null(random) || !all(c(between, within) %in% names(random))) {
    rm(fit)
    gc(verbose = FALSE)
    return(data.frame())
  }
  out <- data.frame(
    soort_id = as.integer(rownames(random)),
    metric = metric,
    beta_tussen_plots = unname(fixed[[between]]) + random[[between]],
    beta_binnen_plot = unname(fixed[[within]]) + random[[within]],
    stringsAsFactors = FALSE
  )
  out <- merge(out, unique(species_lookup[c("soort_id", "soort_naam")]), by = "soort_id", all.x = TRUE)
  out$ratio_tussen_plots_per_sd <- exp(out$beta_tussen_plots)
  out$ratio_binnen_plot_per_sd <- exp(out$beta_binnen_plot)
  rm(fit)
  gc(verbose = FALSE)
  out[order(out$soort_id), , drop = FALSE]
}

fit_vegetation_model_pair <- function(data, metric, analysis_id, checkpoint_dir) {
  formulas <- vegetation_model_formulas(metric)
  required <- vegetation_required_fields(metric)
  require_prepare_fields(data, required, "vegetatie-modelpopulatie")
  complete <- stats::complete.cases(data[required])
  model_data <- droplevels(data[complete, , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete vegetatie-modelrijen beschikbaar.", call. = FALSE)
  expected_hash <- row_set_sha256(model_data$row_id)
  models <- lapply(names(formulas), function(model_name) {
    fit_glmmtmb_safely(
      formulas[[model_name]], model_data,
      paste(analysis_id, metric, model_name, sep = "__"), checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  hashes <- vapply(models, function(x) x$diagnostics$row_hash, character(1))
  if (any(hashes != expected_hash)) stop("Basis- en PQ-model gebruiken niet dezelfde responsrijen.", call. = FALSE)
  comparison <- do.call(rbind, Map(fit_summary_row, names(models), models))
  comparison$analysis_id <- analysis_id
  comparison$metric <- metric
  comparison <- comparison[c("analysis_id", "metric", setdiff(names(comparison), c("analysis_id", "metric")))]
  species_effects <- extract_vegetation_species_effects(models$pq, metric, model_data)
  list(
    models = models,
    comparison = comparison,
    species_effects = species_effects,
    row_hash = expected_hash,
    n = nrow(model_data),
    plotyears = length(unique(paste(model_data$plot_id, model_data$jaar, sep = ":"))),
    plots = length(unique(model_data$plot_id)),
    species = length(unique(model_data$soort_id))
  )
}
