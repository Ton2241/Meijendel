power_pipeline_repo <- function() {
  configured <- Sys.getenv("MEIJENDEL_REPO", unset = "")
  if (nzchar(configured)) return(normalizePath(configured, mustWork = TRUE))
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
  normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
}

.power_pipeline_repo <- power_pipeline_repo()
source(file.path(
  .power_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "run_broedvogel_pq_vertraagd.R"
))
source(file.path(
  .power_pipeline_repo, "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_power_pq_vertraagd.R"
))

bind_power_rows <- function(items) {
  items <- items[vapply(items, function(x) is.data.frame(x) && nrow(x), logical(1))]
  if (!length(items)) return(data.frame())
  out <- do.call(rbind, items)
  rownames(out) <- NULL
  out
}

build_candidate_power_scenarios <- function(
    analysis_id, beta, covariance, data,
    historical_effects = c(0, seq(5, 80, 5)),
    future_effects = c(10, 20, 30),
    information_multipliers = seq(1, 25, 0.25),
    simulations = 10000L, seed = 20261028L) {
  directions <- delayed_change_directions(data$change_pp)
  if (!nrow(directions)) return(data.frame())
  anchor_lag <- max(as.integer(data$lag_years), na.rm = TRUE)
  rows <- list()
  index <- 0L
  add_scenario <- function(direction, change_pp, target_percent, multiplier, type) {
    index <<- index + 1L
    result <- simulate_delayed_wald_power(
      beta, covariance, delayed_power_contrast(change_pp, anchor_lag),
      target_percent = target_percent, information_multiplier = multiplier,
      simulations = simulations, seed = as.integer(seed + index)
    )
    result$analysis_id <- analysis_id
    result$direction <- direction
    result$anchor_change_pp <- change_pp
    result$anchor_lag_years <- anchor_lag
    result$scenario_type <- type
    result[c(
      "analysis_id", "direction", "anchor_change_pp", "anchor_lag_years",
      "scenario_type", setdiff(names(result), c(
        "analysis_id", "direction", "anchor_change_pp", "anchor_lag_years",
        "scenario_type"
      ))
    )]
  }
  for (i in seq_len(nrow(directions))) {
    direction <- directions$direction[[i]]
    change_pp <- directions$change_pp[[i]]
    contrast <- delayed_power_contrast(change_pp, anchor_lag)
    observed_log <- sum(contrast * as.numeric(beta[power_change_terms()]))
    observed_percent <- 100 * abs(exp(observed_log) - 1)
    for (effect in historical_effects) {
      rows[[length(rows) + 1L]] <- add_scenario(
        direction, change_pp, effect, 1, "historische_detectiegrens"
      )
    }
    for (effect in future_effects) {
      for (multiplier in information_multipliers) {
        rows[[length(rows) + 1L]] <- add_scenario(
          direction, change_pp, effect, multiplier, "toekomstig_meetvolume"
        )
      }
    }
    rows[[length(rows) + 1L]] <- add_scenario(
      direction, change_pp, observed_percent, 1, "waargenomen_modelschaal"
    )
  }
  bind_power_rows(rows)
}

summarise_power_requirements <- function(
    scenarios, structure, target_power = 0.8, plots_per_pq_round = NULL) {
  keys <- unique(scenarios[c("analysis_id", "direction")])
  historical <- future <- list()
  for (i in seq_len(nrow(keys))) {
    id <- keys$analysis_id[[i]]
    direction <- keys$direction[[i]]
    current <- scenarios[
      scenarios$analysis_id == id & scenarios$direction == direction,
      , drop = FALSE
    ]
    detectable <- current[
      current$scenario_type == "historische_detectiegrens" &
        current$target_percent > 0 & current$status == "geslaagd" &
        current$lower95 >= target_power,
      , drop = FALSE
    ]
    observed <- current[
      current$scenario_type == "waargenomen_modelschaal", , drop = FALSE
    ]
    historical[[length(historical) + 1L]] <- data.frame(
      analysis_id = id, direction = direction,
      minimum_detectable_percent = if (nrow(detectable)) {
        min(detectable$target_percent)
      } else NA_real_,
      threshold_status = if (nrow(detectable)) "bereikt" else "niet_bereikt_tot_80_pct",
      observed_model_percent = if (nrow(observed)) observed$target_percent[[1L]] else NA_real_,
      observed_model_rate_ratio = if (nrow(observed)) observed$target_rate_ratio[[1L]] else NA_real_,
      observed_model_power = if (nrow(observed)) observed$power[[1L]] else NA_real_,
      observed_model_lower95 = if (nrow(observed)) observed$lower95[[1L]] else NA_real_,
      observed_model_upper95 = if (nrow(observed)) observed$upper95[[1L]] else NA_real_,
      stringsAsFactors = FALSE
    )
    future_effects <- sort(unique(current$target_percent[
      current$scenario_type == "toekomstig_meetvolume"
    ]))
    info <- structure[structure$analysis_id == id, , drop = FALSE]
    round_plots <- if (is.null(plots_per_pq_round)) {
      info$plots[[1L]]
    } else {
      as.numeric(plots_per_pq_round[[1L]])
    }
    for (effect in future_effects) {
      candidates <- current[
        current$scenario_type == "toekomstig_meetvolume" &
          current$target_percent == effect & current$status == "geslaagd" &
          current$lower95 >= target_power,
        , drop = FALSE
      ]
      multiplier <- if (nrow(candidates)) {
        min(candidates$information_multiplier)
      } else NA_real_
      translated <- if (is.finite(multiplier)) {
        translate_information_multiplier(
          multiplier, info$plotyears[[1L]], info$first_year[[1L]],
          info$last_year[[1L]], info$intervals[[1L]], round_plots
        )
      } else data.frame(
        information_multiplier = NA_real_, additional_plotyears = NA_integer_,
        equivalent_additional_years = NA_integer_, additional_intervals = NA_integer_,
        equivalent_complete_pq_rounds = NA_integer_
      )
      future[[length(future) + 1L]] <- data.frame(
        analysis_id = id, direction = direction, target_percent = effect,
        requirement_status = if (is.finite(multiplier)) "bereikt" else "niet_bereikt_tot_25x",
        required_information_multiplier = multiplier,
        translated[c(
          "additional_plotyears", "equivalent_additional_years",
          "additional_intervals", "equivalent_complete_pq_rounds"
        )], stringsAsFactors = FALSE
      )
    }
  }
  list(historical = bind_power_rows(historical), future = bind_power_rows(future))
}

read_power_source <- function(source_run_dir) {
  required <- c(
    "pq_vertraagd_state.rds", "pq_vertraagd_samenvatting.csv",
    "pq_vertraagd_manifest.json"
  )
  missing <- required[!file.exists(file.path(source_run_dir, required))]
  if (length(missing)) {
    stop("Bronrun mist bestand(en): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  list(
    state = readRDS(file.path(source_run_dir, "pq_vertraagd_state.rds")),
    summary = utils::read.csv(
      file.path(source_run_dir, "pq_vertraagd_samenvatting.csv"),
      stringsAsFactors = FALSE, check.names = FALSE
    ),
    manifest = jsonlite::read_json(
      file.path(source_run_dir, "pq_vertraagd_manifest.json"), simplifyVector = TRUE
    )
  )
}

candidate_power_model <- function(source_run_dir, analysis_id) {
  path <- file.path(
    source_run_dir, "modellen",
    paste0(analysis_id, "__territoria__niet_lineair.rds")
  )
  if (!file.exists(path)) stop("Kandidaatmodel ontbreekt: ", basename(path), call. = FALSE)
  fit <- readRDS(path)
  coefficients <- glmmTMB::fixef(fit)$cond
  covariance <- stats::vcov(fit)$cond
  terms <- power_change_terms()
  if (!all(terms %in% names(coefficients)) || !all(terms %in% rownames(covariance))) {
    stop("Kandidaatmodel mist veranderingscoëfficiënten: ", analysis_id, call. = FALSE)
  }
  list(
    path = path, beta = coefficients[terms],
    covariance = covariance[terms, terms, drop = FALSE]
  )
}

write_power_manifest <- function(path, metadata, source_run_dir, source, candidates,
                                 model_files, outputs, simulations) {
  manifest <- c(metadata, list(
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    source_run = list(
      run_id = source$manifest$run_id,
      git_commit = source$manifest$git_commit,
      manifest_sha256 = sha256_file(file.path(source_run_dir, "pq_vertraagd_manifest.json")),
      state_sha256 = sha256_file(file.path(source_run_dir, "pq_vertraagd_state.rds"))
    ),
    candidates = candidates,
    candidate_models = lapply(model_files, function(model) list(
      file = basename(model$path), sha256 = sha256_file(model$path)
    )),
    detection_rule = list(
      test = "gezamenlijke Waldtoets van zes veranderingstermen",
      alpha = 0.05, target_power = 0.8,
      direction = "geschat ankereffect moet dezelfde richting hebben",
      failures = "ongeldige covariantie telt niet als detectie"
    ),
    effect_scenarios = list(
      historical_percent = c(0, seq(5, 80, 5)),
      future_percent = c(10, 20, 30),
      information_multiplier = seq(1, 25, 0.25),
      anchor = "mediane afname of toename; maximaal werkelijk waargenomen lag"
    ),
    simulations_per_scenario = as.integer(simulations),
    future_interpretation = paste(
      "equivalent meetvolume bij dezelfde plot-, jaar-, teller/tellerteam-,",
      "PQ- en variantiestructuur; geen kalenderprognose"
    ),
    package_versions = package_versions_for_manifest(),
    outputs = lapply(outputs, function(output_path) list(
      file = basename(output_path), bytes = unname(file.info(output_path)$size),
      sha256 = sha256_file(output_path)
    ))
  ))
  jsonlite::write_json(
    manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA
  )
  path
}

run_delayed_power_pipeline <- function(
    source_run_dir, run_dir, metadata, compact_results_dir = NULL,
    simulations = 10000L) {
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  source <- read_power_source(source_run_dir)
  candidates <- select_delayed_power_candidates(source$summary)
  if (!length(candidates)) stop("Bronrun bevat geen gevalideerde territoriumkandidaten.", call. = FALSE)
  team_data <- unique(source$state$assigned[c(
    "plot_id", "jaar", "tellerteam_sleutel", "aantal_tellers",
    "ervaring_plot_mean", "ervaring_elders_mean"
  )])
  structures <- scenarios <- model_files <- list()
  for (i in seq_along(candidates)) {
    id <- candidates[[i]]
    data <- source$state$items[[id]]
    if (is.null(data) || !nrow(data)) stop("Kandidaatpopulatie ontbreekt: ", id, call. = FALSE)
    structures[[id]] <- summarise_delayed_candidate_structure(data, team_data)
    model_files[[id]] <- candidate_power_model(source_run_dir, id)
    scenarios[[id]] <- build_candidate_power_scenarios(
      id, model_files[[id]]$beta, model_files[[id]]$covariance, data,
      simulations = simulations, seed = 20261028L + i * 100000L
    )
  }
  structure <- bind_power_rows(structures)
  scenario <- bind_power_rows(scenarios)
  requirements <- summarise_power_requirements(scenario, structure)
  outputs <- c(
    structuur = write_csv_atomic(structure, file.path(run_dir, "pq_power_structuur.csv")),
    scenarios = write_csv_atomic(scenario, file.path(run_dir, "pq_power_scenarios.csv")),
    historisch = write_csv_atomic(requirements$historical, file.path(run_dir, "pq_power_historisch.csv")),
    toekomst = write_csv_atomic(requirements$future, file.path(run_dir, "pq_power_toekomst.csv"))
  )
  manifest_path <- file.path(run_dir, "pq_power_manifest.json")
  write_power_manifest(
    manifest_path, metadata, source_run_dir, source, candidates,
    model_files, outputs, simulations
  )
  if (!is.null(compact_results_dir)) {
    dir.create(compact_results_dir, recursive = TRUE, showWarnings = FALSE)
    for (name in names(outputs)) {
      file.copy(
        outputs[[name]], file.path(compact_results_dir, paste0("pq_power_laatste_", name, ".csv")),
        overwrite = TRUE
      )
    }
    file.copy(
      manifest_path, file.path(compact_results_dir, "pq_power_laatste_manifest.json"),
      overwrite = TRUE
    )
  }
  list(manifest_path = manifest_path, outputs = outputs)
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) != 6L) {
    stop(
      "Gebruik: SOURCE_RUN_DIR RUN_DIR RUN_ID GIT_COMMIT RESULT_DIR SIMULATIONS",
      call. = FALSE
    )
  }
  result <- run_delayed_power_pipeline(
    source_run_dir = cli[[1L]], run_dir = cli[[2L]],
    metadata = list(run_id = cli[[3L]], git_commit = cli[[4L]]),
    compact_results_dir = cli[[5L]], simulations = as.integer(cli[[6L]])
  )
  cat(result$manifest_path, "\n", sep = "")
}
