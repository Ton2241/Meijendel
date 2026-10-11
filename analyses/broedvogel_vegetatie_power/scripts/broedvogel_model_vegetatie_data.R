vegetation_data_repo <- function() {
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

.vegetation_data_repo <- vegetation_data_repo()
source(file.path(
  .vegetation_data_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_prepare.R"
))

pq_metric_contract <- function() {
  c(
    soortenrijkdom = "soortenrijkdom_gem",
    shannon = "shannon_gem",
    bedekking = "bedekking_som_gem"
  )
}

pq_standardize <- function(x) {
  current_sd <- stats::sd(x)
  if (!is.finite(current_sd) || current_sd <= 0) return(rep(0, length(x)))
  (x - mean(x)) / current_sd
}

build_pq_plotyear_features <- function(pq) {
  metrics <- pq_metric_contract()
  require_prepare_fields(
    pq,
    c("plot_id", "jaar", "n_pq", "n_opnamen", unname(metrics), "dekking_kwaliteit"),
    "pq_plot_jaar_vegetatie"
  )
  out <- pq
  out$plot_id <- as.integer(out$plot_id)
  out$jaar <- as.integer(out$jaar)
  key <- paste(out$plot_id, out$jaar, sep = ":")
  if (anyDuplicated(key)) stop("PQ-gegevens bevatten dubbele plot-jaarrijen.", call. = FALSE)
  metric_values <- out[unname(metrics)]
  metric_values[] <- lapply(metric_values, as.numeric)
  if (any(!is.finite(as.matrix(metric_values)))) {
    stop("PQ-gegevens bevatten ontbrekende of niet-eindige vegetatiewaarden.", call. = FALSE)
  }
  out[unname(metrics)] <- metric_values

  for (metric in names(metrics)) {
    source_field <- unname(metrics[[metric]])
    plot_mean <- ave(out[[source_field]], out$plot_id, FUN = mean)
    between_field <- paste0(metric, "_between")
    within_field <- paste0(metric, "_within")
    out[[between_field]] <- plot_mean
    out[[within_field]] <- out[[source_field]] - plot_mean
    out[[paste0(between_field, "_z")]] <- pq_standardize(out[[between_field]])
    out[[paste0(within_field, "_z")]] <- pq_standardize(out[[within_field]])
  }
  out[order(out$jaar, out$plot_id), , drop = FALSE]
}

build_vegetation_population <- function(base_population, pq, lag_years = 0L) {
  lag_years <- as.integer(lag_years)
  if (length(lag_years) != 1L || is.na(lag_years) || !lag_years %in% 0:3) {
    stop("Vertraging moet exact 0, 1, 2 of 3 jaar zijn.", call. = FALSE)
  }
  require_prepare_fields(
    base_population,
    c(
      "row_id", "soort_id", "soort_naam", "plot_id", "jaar", "count",
      "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z"
    ),
    "basis-modelpopulatie"
  )
  if (anyDuplicated(base_population$row_id)) {
    stop("Basis-modelpopulatie bevat dubbele soort-plot-jaarcellen.", call. = FALSE)
  }
  pq <- pq[as.integer(pq$plot_id) %in% unique(as.integer(base_population$plot_id)), , drop = FALSE]
  pq_features <- build_pq_plotyear_features(pq)
  pq_features$pq_jaar <- pq_features$jaar
  pq_features$jaar <- pq_features$pq_jaar + lag_years
  joined <- merge(
    base_population,
    pq_features,
    by = c("plot_id", "jaar"),
    all = FALSE,
    sort = FALSE,
    suffixes = c("", "_pq")
  )
  if (!nrow(joined)) stop("Geen gekoppelde vogel- en PQ-rijen voor deze vertraging.", call. = FALSE)
  joined$lag_years <- lag_years
  joined$soort_factor <- factor(joined$soort_id)
  joined$jaar_factor <- factor(joined$jaar)
  joined$plotjaar_factor <- factor(paste(joined$plot_id, joined$jaar, sep = ":"))
  joined$soort_plot_factor <- factor(paste(joined$soort_id, joined$plot_id, sep = ":"))
  joined$tellerteam_factor <- factor(as.character(joined$tellerteam_factor))
  joined <- joined[order(joined$soort_id, joined$plot_id, joined$jaar), , drop = FALSE]
  rownames(joined) <- NULL
  if (anyDuplicated(joined$row_id)) stop("PQ-koppeling heeft dubbele responsrijen gemaakt.", call. = FALSE)
  plotyears <- unique(joined[c("plot_id", "jaar", "pq_jaar", "lag_years")])
  list(
    data = joined,
    plotyears = plotyears[order(plotyears$jaar, plotyears$plot_id), , drop = FALSE],
    row_hash = row_set_sha256(joined$row_id),
    lag_years = lag_years
  )
}
