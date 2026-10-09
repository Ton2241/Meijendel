teller_pipeline_repo <- function() {
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

.teller_pipeline_repo <- teller_pipeline_repo()
source(file.path(.teller_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_data.R"))
source(file.path(.teller_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_data.R"))
source(file.path(.teller_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_prepare.R"))
source(file.path(.teller_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_teller_fit.R"))

collect_tsv_metadata <- function(input_dir) {
  paths <- sort(list.files(input_dir, pattern = "\\.tsv$", full.names = TRUE))
  if (!length(paths)) stop("Geen TSV-extracten gevonden.", call. = FALSE)
  names(paths) <- sub("\\.tsv$", "", basename(paths))
  lapply(paths, function(path) {
    list(
      file = basename(path),
      rows = max(0L, length(readLines(path, warn = FALSE)) - 1L),
      bytes = unname(file.info(path)$size),
      sha256 = sha256_file(path)
    )
  })
}

run_resumable_step <- function(step_id, row_hash, checkpoint_dir, resume, fun) {
  dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
  checkpoint_path <- file.path(checkpoint_dir, safe_model_filename(step_id))
  if (isTRUE(resume) && file.exists(checkpoint_path)) {
    saved <- readRDS(checkpoint_path)
    if (is.list(saved) && identical(saved$checkpoint_status, "groen") && identical(saved$row_hash, row_hash)) {
      return(list(resumed = TRUE, value = saved$value, checkpoint_path = checkpoint_path))
    }
  }
  value <- fun()
  saveRDS(
    list(checkpoint_status = "groen", row_hash = row_hash, completed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"), value = value),
    checkpoint_path
  )
  list(resumed = FALSE, value = value, checkpoint_path = checkpoint_path)
}

package_versions_for_manifest <- function() {
  packages <- c("glmmTMB", "geepack", "digest", "jsonlite")
  stats::setNames(
    lapply(packages, function(package) {
      if (requireNamespace(package, quietly = TRUE)) as.character(utils::packageVersion(package)) else NA_character_
    }),
    packages
  )
}

formula_manifest <- function(formulas) {
  lapply(formulas, function(formula) paste(deparse(formula, width.cutoff = 500L), collapse = " "))
}

write_teller_manifest <- function(path, metadata, source_files, response_hashes, formulas, outputs) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("R-pakket jsonlite ontbreekt.", call. = FALSE)
  output_metadata <- lapply(outputs, function(output_path) {
    list(
      file = basename(output_path),
      bytes = unname(file.info(output_path)$size),
      sha256 = sha256_file(output_path)
    )
  })
  manifest <- c(
    metadata,
    list(
      package_versions = package_versions_for_manifest(),
      tables = source_files,
      formulas = formula_manifest(formulas),
      response_row_hashes = as.list(response_hashes),
      outputs = output_metadata
    )
  )
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  manifest
}

read_teller_extract <- function(input_dir) {
  base <- read_broedvogel_extract(input_dir)
  visit_path <- file.path(input_dir, "dagbezoeken_bmp.tsv")
  if (!file.exists(visit_path)) stop("Extract mist bestand: dagbezoeken_bmp.tsv.", call. = FALSE)
  base$data$dagbezoeken_bmp <- utils::read.delim(
    visit_path, header = TRUE, sep = "\t", na.strings = "NULL", quote = "",
    comment.char = "", check.names = FALSE, stringsAsFactors = FALSE
  )
  base$source_files <- collect_tsv_metadata(input_dir)
  fingerprint <- paste(vapply(base$source_files, `[[`, character(1), "sha256"), collapse = "")
  base$source_fingerprint_sha256 <- digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  base
}

build_teller_pipeline_state <- function(input_dir) {
  extract <- read_teller_extract(input_dir)
  matrix_result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  teller_layer <- build_teller_experience_layer(extract$data, 1958L, 2025L)
  effort <- build_bmp_effort(extract$data$dagbezoeken_bmp, matrix_result$basis)
  populations <- build_teller_model_populations(matrix_result$matrix, teller_layer$teams, effort)
  list(
    extract_metadata = extract$source_files,
    source_fingerprint_sha256 = extract$source_fingerprint_sha256,
    matrix_result = matrix_result,
    teller_layer = teller_layer,
    effort = effort,
    populations = populations
  )
}

write_csv_atomic <- function(data, path) {
  temporary <- paste0(path, ".tmp")
  utils::write.csv(data, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) stop("Kon resultaatbestand niet plaatsen: ", path, call. = FALSE)
  path
}

flatten_joint_diagnostics <- function(joint_results) {
  rows <- lapply(names(joint_results), function(analysis_id) {
    result <- joint_results[[analysis_id]]
    comparison <- result$comparison
    comparison$analysis_id <- analysis_id
    comparison[, c("analysis_id", setdiff(names(comparison), "analysis_id")), drop = FALSE]
  })
  do.call(rbind, rows)
}

run_teller_model_pipeline <- function(
    input_dir = NULL,
    run_dir,
    metadata,
    resume = FALSE,
    compact_results_dir = NULL,
    random_seed = 20261009L) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  state_path <- file.path(run_dir, "teller_model_state.rds")
  if (isTRUE(resume)) {
    if (!file.exists(state_path)) stop("Hervatten kan niet: teller_model_state.rds ontbreekt.", call. = FALSE)
    state <- readRDS(state_path)
  } else {
    if (is.null(input_dir)) stop("Voor een nieuwe run is een extractmap verplicht.", call. = FALSE)
    state <- build_teller_pipeline_state(input_dir)
    state$run_metadata <- metadata
    saveRDS(state, state_path)
  }
  set.seed(random_seed)
  populations <- state$populations
  checkpoint_dir <- file.path(run_dir, "checkpoints")
  model_checkpoint_dir <- file.path(run_dir, "modellen")

  joint_specs <- list(
    lang_mean = list(data = populations$long, variant = "mean", effort = NULL),
    lang_min = list(data = populations$long, variant = "min", effort = NULL),
    lang_max = list(data = populations$long, variant = "max", effort = NULL),
    een_teller_mean = list(data = populations$single_teller, variant = "mean", effort = NULL),
    inspanning_duur = list(data = populations$effort_1984_2025, variant = "mean", effort = "inspanning_duur_z"),
    inspanning_bezoeken = list(data = populations$effort_1984_2025, variant = "mean", effort = "inspanning_bezoeken_z")
  )
  joint <- lapply(names(joint_specs), function(analysis_id) {
    spec <- joint_specs[[analysis_id]]
    hash <- row_set_sha256(spec$data$row_id)
    run_resumable_step(analysis_id, hash, checkpoint_dir, resume, function() {
      fit_joint_teller_models(spec$data, analysis_id, model_checkpoint_dir, spec$variant, spec$effort)
    })$value
  })
  names(joint) <- names(joint_specs)

  species_specs <- list(
    lang = list(data = populations$long, effort = NULL),
    een_teller = list(data = populations$single_teller, effort = NULL),
    inspanning_duur = list(data = populations$effort_1984_2025, effort = "inspanning_duur_z"),
    inspanning_bezoeken = list(data = populations$effort_1984_2025, effort = "inspanning_bezoeken_z")
  )
  species <- lapply(names(species_specs), function(analysis_id) {
    spec <- species_specs[[analysis_id]]
    eligibility <- species_eligibility(spec$data)
    hash <- row_set_sha256(spec$data$row_id)
    run_resumable_step(paste0("soorten_", analysis_id), hash, checkpoint_dir, resume, function() {
      fit_species_teller_models(spec$data, eligibility, paste0("soorten_", analysis_id), model_checkpoint_dir, spec$effort)
    })$value
  })
  names(species) <- names(species_specs)
  gee <- run_resumable_step("gee_lang", populations$row_hashes[["long"]], checkpoint_dir, resume, function() {
    fit_species_gee_checks(populations$long, populations$eligibility, "gee_lang")
  })$value
  sensitivity <- summarise_teller_sensitivity(joint$lang_mean, species$lang, gee)

  coverage_path <- write_csv_atomic(populations$coverage, file.path(run_dir, "teller_model_dekking.csv"))
  summary_path <- write_csv_atomic(sensitivity$summary, file.path(run_dir, "teller_model_samenvatting.csv"))
  species_combined <- do.call(rbind, lapply(names(species), function(name) {
    current <- species[[name]]; current$analyse <- name; current
  }))
  species_path <- write_csv_atomic(species_combined, file.path(run_dir, "teller_model_soorten.csv"))
  diagnostics_path <- write_csv_atomic(flatten_joint_diagnostics(joint), file.path(run_dir, "teller_model_diagnostiek.csv"))
  outputs <- c(dekking = coverage_path, samenvatting = summary_path, soorten = species_path, diagnostiek = diagnostics_path)
  manifest_path <- file.path(run_dir, "teller_model_manifest.json")
  manifest <- write_teller_manifest(
    manifest_path,
    metadata = c(metadata, list(
      executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
      random_seed = random_seed,
      source_fingerprint_sha256 = state$source_fingerprint_sha256
    )),
    source_files = state$extract_metadata,
    response_hashes = populations$row_hashes,
    formulas = joint_teller_formulas(),
    outputs = outputs
  )
  if (!is.null(compact_results_dir)) {
    dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
    stable <- c(
      dekking = "teller_model_laatste_dekking.csv",
      samenvatting = "teller_model_laatste_samenvatting.csv",
      soorten = "teller_model_laatste_soorten.csv",
      diagnostiek = "teller_model_laatste_diagnostiek.csv"
    )
    for (name in names(stable)) file.copy(outputs[[name]], file.path(compact_results_dir, stable[[name]]), overwrite = TRUE)
    file.copy(manifest_path, file.path(compact_results_dir, "teller_model_laatste_manifest.json"), overwrite = TRUE)
  }
  list(manifest = manifest, manifest_path = manifest_path, outputs = outputs)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) < 3L || !cli[[1L]] %in% c("new", "resume")) {
    stop("Gebruik: Rscript run_broedvogel_teller_model.R new INPUT_DIR RUN_DIR RUN_ID GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR; of resume RUN_DIR RESULT_DIR", call. = FALSE)
  }
  mode <- cli[[1L]]
  if (mode == "new") {
    if (length(cli) != 8L) stop("Nieuwe run: acht argumenten vereist.", call. = FALSE)
    result <- run_teller_model_pipeline(
      input_dir = cli[[2L]], run_dir = cli[[3L]],
      metadata = list(run_id = cli[[4L]], git_commit = cli[[5L]], database_name = cli[[6L]], mysql_version = cli[[7L]]),
      resume = FALSE, compact_results_dir = cli[[8L]]
    )
  } else {
    if (length(cli) != 3L) stop("Hervatten: runmap en resultaatmap vereist.", call. = FALSE)
    state <- readRDS(file.path(cli[[2L]], "teller_model_state.rds"))
    metadata <- state$run_metadata
    if (is.null(metadata)) stop("Hervatten kan niet: runmetadata ontbreekt in de statuslaag.", call. = FALSE)
    result <- run_teller_model_pipeline(run_dir = cli[[2L]], metadata = metadata, resume = TRUE, compact_results_dir = cli[[3L]])
  }
  cat(result$manifest_path, "\n", sep = "")
}
