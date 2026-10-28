pq_delay_repo <- function() {
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

.pq_delay_repo <- pq_delay_repo()
source(file.path(
  .pq_delay_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_vegetatiesamenstelling.R"
))

build_pq_delay_populations <- function(base_population, composition, ipi) {
  lags <- composition_coverage_lags()
  composition_populations <- lapply(lags, function(lag) {
    build_multivariate_vegetation_population(
      base_population, composition, composition_predictor_contract(), lag
    )
  })
  names(composition_populations) <- paste0("lag", lags)
  ipi_populations <- lapply(lags, function(lag) {
    build_multivariate_vegetation_population(
      base_population, ipi, ipi_predictor_contract(), lag
    )
  })
  names(ipi_populations) <- paste0("lag", lags)
  list(
    composition_populations = composition_populations,
    ipi_populations = ipi_populations
  )
}

pq_delay_coverage_table <- function(state) {
  rows <- list()
  add_block <- function(block, populations) {
    lapply(names(populations), function(name) {
      item <- populations[[name]]
      row <- coverage_row(block, name, item)
      years <- as.integer(item$plotyears$vegetatie_jaar)
      row$first_vegetation_year <- min(years)
      row$last_vegetation_year <- max(years)
      row
    })
  }
  rows <- c(
    rows,
    add_block("compositie", state$composition_populations),
    add_block("ipi", state$ipi_populations)
  )
  out <- do.call(rbind, rows)
  out$blok <- factor(out$blok, levels = c("compositie", "ipi"))
  out <- out[order(out$blok, out$lag_years), , drop = FALSE]
  out$blok <- as.character(out$blok)
  rownames(out) <- NULL
  out
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) != 7L) {
    stop(paste(
      "Gebruik: Rscript pq_vertragingsdekking.R INPUT_DIR RUN_DIR RUN_ID",
      "GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR"
    ), call. = FALSE)
  }
  input_dir <- cli[[1L]]
  run_dir <- cli[[2L]]
  compact_results_dir <- cli[[7L]]
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

  extract <- read_teller_extract(input_dir)
  for (name in c(
    "pq_vegetatie_opname", "pq_vegetatie_waarneming", "pq_vegetatie_opname_plot"
  )) {
    extract$data[[name]] <- read_tsv_required(input_dir, name)
  }
  extract$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(
    vapply(extract$source_files, `[[`, character(1), "sha256"),
    collapse = ""
  )
  source_fingerprint <- digest::digest(
    fingerprint, algo = "sha256", serialize = FALSE
  )

  matrix_result <- build_broedvogel_analysis_matrix(
    extract$data, 1958L, 2025L
  )
  teller_layer <- build_teller_experience_layer(
    extract$data, 1958L, 2025L
  )
  effort <- build_bmp_effort(
    extract$data$dagbezoeken_bmp, matrix_result$basis
  )
  populations <- build_teller_model_populations(
    matrix_result$matrix, teller_layer$teams, effort
  )
  composition <- build_pq_composition_features(
    extract$data$pq_vegetatie_opname,
    extract$data$pq_vegetatie_waarneming,
    extract$data$pq_vegetatie_opname_plot,
    n_axes = length(composition_predictor_contract())
  )
  ipi <- build_ipi_plotyear_features(
    extract$data$pq_vegetatie_opname,
    extract$data$pq_vegetatie_opname_plot
  )
  state <- build_pq_delay_populations(
    populations$long, composition$features, ipi
  )
  coverage <- pq_delay_coverage_table(state)
  lag0_rows <- coverage$lag_years == 0L
  lag0_plotyears <- coverage$plotyears[match(
    coverage$blok, coverage$blok[lag0_rows]
  )]
  coverage$aandeel_plotjaren_tov_lag0 <- (
    coverage$plotyears / lag0_plotyears
  )
  coverage <- coverage[c(
    "blok", "lag_years", "rows", "plotyears", "plots", "species",
    "first_vegetation_year", "last_vegetation_year",
    "first_bird_year", "last_bird_year", "aandeel_plotjaren_tov_lag0",
    "row_hash", "analysis_id"
  )]

  output_path <- file.path(run_dir, "pq_vertragingsdekking.csv")
  write_csv_atomic(coverage, output_path)
  metadata <- list(
    run_id = cli[[3L]],
    git_commit = cli[[4L]],
    database_name = cli[[5L]],
    mysql_version = cli[[6L]],
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_fingerprint_sha256 = source_fingerprint,
    source_files = extract$source_files,
    coverage_lags = composition_coverage_lags(),
    fitted_models = 0L,
    scope = "v_meijendel_analyseplot_actueel; M66 en M91 uitgesloten",
    response_exclusions = pq_response_exclusions(),
    bird_population = list(
      rows = nrow(populations$long),
      plotyears = length(unique(paste(
        populations$long$plot_id, populations$long$jaar, sep = ":"
      ))),
      plots = length(unique(populations$long$plot_id)),
      species = length(unique(populations$long$soort_id)),
      first_year = min(populations$long$jaar),
      last_year = max(populations$long$jaar)
    ),
    pq_source = list(
      observations = nrow(extract$data$pq_vegetatie_opname),
      taxon_rows = nrow(extract$data$pq_vegetatie_waarneming),
      linked_observations = length(unique(
        extract$data$pq_vegetatie_opname_plot$opname_id
      )),
      linked_plots = length(unique(
        extract$data$pq_vegetatie_opname_plot$plot_id
      )),
      first_year = min(extract$data$pq_vegetatie_opname$jaar),
      last_year = max(extract$data$pq_vegetatie_opname$jaar)
    ),
    output = list(
      file = basename(output_path),
      rows = nrow(coverage),
      sha256 = sha256_file(output_path)
    )
  )
  manifest_path <- file.path(run_dir, "pq_vertragingsdekking_manifest.json")
  jsonlite::write_json(
    metadata, manifest_path, auto_unbox = TRUE, pretty = TRUE,
    null = "null", digits = NA
  )
  dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(
    output_path,
    file.path(compact_results_dir, "pq_vertragingsdekking_laatste.csv"),
    overwrite = TRUE
  )) stop("Kon compacte lagdekking niet schrijven.", call. = FALSE)
  if (!file.copy(
    manifest_path,
    file.path(compact_results_dir, "pq_vertragingsdekking_laatste_manifest.json"),
    overwrite = TRUE
  )) stop("Kon compact lagmanifest niet schrijven.", call. = FALSE)
  cat(manifest_path, "\n", sep = "")
}
