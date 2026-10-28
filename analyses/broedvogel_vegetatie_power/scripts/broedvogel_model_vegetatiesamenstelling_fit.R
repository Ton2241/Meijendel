composition_fit_repo <- function() {
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

.composition_fit_repo <- composition_fit_repo()
source(file.path(
  .composition_fit_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatiesamenstelling.R"
))
source(file.path(
  .composition_fit_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_teller_fit.R"
))

composition_predictor_contract <- function() {
  paste0("compositie_pc", 1:3)
}

ipi_predictor_contract <- function() {
  c("ipi_nat_water", "ipi_struweel", "ipi_bos")
}

landcover_bird_group_contract <- function() {
  c(
    `100` = "water_aandeel",
    `200` = "riet_aandeel",
    `300` = "open_aandeel",
    `600` = "struik_aandeel",
    `700` = "boomgroep_aandeel",
    `800` = "bos_aandeel"
  )
}

prepare_joined_vegetation_population <- function(joined, lag_years) {
  if (!nrow(joined)) stop("Geen gekoppelde vogel- en vegetatierijen.", call. = FALSE)
  joined$lag_years <- as.integer(lag_years)
  joined$soort_factor <- factor(joined$soort_id)
  joined$jaar_factor <- factor(joined$jaar)
  joined$plotjaar_factor <- factor(paste(joined$plot_id, joined$jaar, sep = ":"))
  joined$soort_plot_factor <- factor(paste(joined$soort_id, joined$plot_id, sep = ":"))
  joined$tellerteam_factor <- factor(as.character(joined$tellerteam_factor))
  joined <- joined[order(joined$soort_id, joined$plot_id, joined$jaar), , drop = FALSE]
  rownames(joined) <- NULL
  if (anyDuplicated(joined$row_id)) stop("Vegetatiekoppeling heeft dubbele responsrijen gemaakt.", call. = FALSE)
  joined
}

build_multivariate_vegetation_population <- function(
    base_population, features, fields, lag_years = 0L) {
  lag_years <- as.integer(lag_years)
  if (length(lag_years) != 1L || is.na(lag_years) || !lag_years %in% 0:15) {
    stop("Vertraging moet een geheel aantal jaren van 0 tot en met 15 zijn.", call. = FALSE)
  }
  require_prepare_fields(
    base_population,
    c(
      "row_id", "soort_id", "soort_naam", "plot_id", "jaar", "count",
      "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z"
    ),
    "basis-modelpopulatie"
  )
  exclusions <- pq_response_exclusions()
  base_population <- base_population[
    !base_population$soort_id %in% exclusions$soort_id, , drop = FALSE
  ]
  features <- features[
    as.integer(features$plot_id) %in% unique(as.integer(base_population$plot_id)), , drop = FALSE
  ]
  features <- split_multivariate_plotyear_features(features, fields)
  features$vegetatie_jaar <- as.integer(features$jaar)
  features$jaar <- features$vegetatie_jaar + lag_years
  joined <- merge(
    base_population, features, by = c("plot_id", "jaar"),
    all = FALSE, sort = FALSE, suffixes = c("", "_vegetatie")
  )
  joined <- prepare_joined_vegetation_population(joined, lag_years)
  list(
    data = joined,
    plotyears = unique(joined[c("plot_id", "jaar", "vegetatie_jaar", "lag_years")]),
    row_hash = row_set_sha256(joined$row_id),
    lag_years = lag_years,
    excluded_species = exclusions
  )
}

multivariate_vegetation_model_formulas <- function(block, fields) {
  if (!nzchar(block) || !length(fields)) stop("Modelblok en kenmerken zijn verplicht.", call. = FALSE)
  base <- joint_teller_formulas()[["M2"]]
  terms <- unlist(lapply(fields, function(field) {
    paste0(field, c("_between_z", "_within_z"))
  }))
  addition <- paste(terms, collapse = " + ")
  random <- paste0("(0 + ", paste(terms, collapse = " + "), " || soort_factor)")
  vegetation <- stats::update.formula(
    base,
    stats::as.formula(paste("~ . +", addition, "+", random))
  )
  list(basis = base, vegetatie = vegetation)
}

multivariate_required_fields <- function(fields) {
  c(
    "row_id", "count", "jaar_decennium", "analyse_bron_factor",
    "log_oppervlakte_km2", "soort_factor", "soort_plot_factor", "jaar_factor",
    "plotjaar_factor", "tellerteam_factor", "ervaring_plot_z", "ervaring_elders_z",
    unlist(lapply(fields, function(field) paste0(field, c("_between_z", "_within_z"))))
  )
}

fit_multivariate_vegetation_pair <- function(
    data, block, fields, analysis_id, checkpoint_dir) {
  formulas <- multivariate_vegetation_model_formulas(block, fields)
  required <- multivariate_required_fields(fields)
  require_prepare_fields(data, required, paste0(block, "-modelpopulatie"))
  complete <- stats::complete.cases(data[required])
  model_data <- droplevels(data[complete, , drop = FALSE])
  if (!nrow(model_data)) stop("Geen complete modelrijen beschikbaar voor ", block, ".", call. = FALSE)
  expected_hash <- row_set_sha256(model_data$row_id)
  models <- lapply(names(formulas), function(model_name) {
    fit_glmmtmb_safely(
      formulas[[model_name]], model_data,
      paste(analysis_id, block, model_name, sep = "__"), checkpoint_dir
    )
  })
  names(models) <- names(formulas)
  hashes <- vapply(models, function(x) x$diagnostics$row_hash, character(1))
  if (any(hashes != expected_hash)) stop("Modelpaar gebruikt niet dezelfde responsrijen.", call. = FALSE)
  comparison <- do.call(rbind, Map(fit_summary_row, names(models), models))
  comparison$analysis_id <- analysis_id
  comparison$blok <- block
  comparison <- comparison[c("analysis_id", "blok", setdiff(names(comparison), c("analysis_id", "blok")))]
  list(
    models = models,
    comparison = comparison,
    row_hash = expected_hash,
    n = nrow(model_data),
    plotyears = length(unique(paste(model_data$plot_id, model_data$jaar, sep = ":"))),
    plots = length(unique(model_data$plot_id)),
    species = length(unique(model_data$soort_id))
  )
}

build_landcover_window_population <- function(
    base_population, landcover, membership, group_number, predictor) {
  require_prepare_fields(
    base_population,
    c("row_id", "soort_id", "soort_naam", "plot_id", "jaar", "count"),
    "basis-modelpopulatie"
  )
  require_prepare_fields(landcover, c("plot_id", "jaar", predictor), "landbedekking")
  require_prepare_fields(membership, c("groepsnummer", "vogel_id"), "evg_vogel_landschapgroep")
  species <- unique(as.integer(membership$vogel_id[membership$groepsnummer == group_number]))
  if (!length(species)) stop("Vogelgroep bevat geen soorten: ", group_number, call. = FALSE)
  out <- base_population[
    base_population$soort_id %in% species & !base_population$soort_id %in% pq_response_exclusions()$soort_id,
    , drop = FALSE
  ]
  out$landbedekking_jaar <- ifelse(
    out$jaar >= 1997L & out$jaar <= 2001L, 2001L,
    ifelse(out$jaar >= 2018L & out$jaar <= 2022L, 2022L, NA_integer_)
  )
  out <- out[!is.na(out$landbedekking_jaar), , drop = FALSE]
  features <- landcover[c("plot_id", "jaar", predictor)]
  names(features)[names(features) == "jaar"] <- "landbedekking_jaar"
  names(features)[names(features) == predictor] <- "landbedekking"
  joined <- merge(
    out, features, by = c("plot_id", "landbedekking_jaar"),
    all = FALSE, sort = FALSE
  )
  split_source <- unique(joined[c("plot_id", "landbedekking_jaar", "landbedekking")])
  names(split_source)[2L] <- "jaar"
  split_source <- split_multivariate_plotyear_features(split_source, "landbedekking")
  names(split_source)[names(split_source) == "jaar"] <- "landbedekking_jaar"
  joined <- merge(
    joined[c(setdiff(names(joined), "landbedekking"))], split_source,
    by = c("plot_id", "landbedekking_jaar"), all.x = TRUE, sort = FALSE
  )
  joined <- prepare_joined_vegetation_population(joined, 0L)
  list(
    data = joined,
    row_hash = row_set_sha256(joined$row_id),
    groepsnummer = as.integer(group_number),
    predictor = predictor
  )
}
