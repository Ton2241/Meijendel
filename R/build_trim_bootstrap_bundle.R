#!/usr/bin/env Rscript

bundle_sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  hash <- if (length(output)) sub("[[:space:]].*$", "", output[[1L]]) else ""
  if (!grepl("^[0-9a-f]{64}$", hash)) stop("Bundlehash kon niet worden bepaald.", call. = FALSE)
  hash
}

trim_bootstrap_engine_files <- function() {
  c(
    "R/run_trim_bootstrap_batch.R",
    "R/trim_bootstrap_core.R",
    "R/trim_bridge_core.R"
  )
}

trim_bootstrap_engine_hashes <- function(repo) {
  repo <- normalizePath(repo, mustWork = TRUE)
  files <- trim_bootstrap_engine_files()
  paths <- file.path(repo, files)
  if (any(!file.exists(paths))) stop("Bootstrapengine is onvolledig: ", paste(files[!file.exists(paths)], collapse = ", "), ".", call. = FALSE)
  stats::setNames(vapply(paths, bundle_sha256_file, character(1)), files)
}

write_trim_bootstrap_bundle <- function(context, identity, bundle_dir, metadata) {
  required_identity <- c("run_id", "source_hash", "config_hash", "code_commit", "software_id")
  if (length(setdiff(required_identity, names(identity)))) stop("Bundle-identiteit is onvolledig.", call. = FALSE)
  if (file.exists(bundle_dir)) stop("Bundledoel bestaat al; overschrijven is niet toegestaan.", call. = FALSE)
  staging <- paste0(bundle_dir, ".partial-", Sys.getpid())
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  saveRDS(context, file.path(staging, "context.rds"), compress = TRUE)
  saveRDS(identity, file.path(staging, "identity.rds"), compress = TRUE)
  manifest <- c(
    list(format = "trim-bootstrap-input-bundle-v1", run_id = identity$run_id),
    metadata,
    list(
      source_hash = identity$source_hash,
      config_hash = identity$config_hash,
      code_commit = identity$code_commit,
      context_sha256 = bundle_sha256_file(file.path(staging, "context.rds")),
      identity_sha256 = bundle_sha256_file(file.path(staging, "identity.rds")),
      created_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  )
  jsonlite::write_json(manifest, file.path(staging, "bundle_manifest.json"), auto_unbox = TRUE, pretty = TRUE)
  if (!file.rename(staging, bundle_dir)) stop("Atomische bundelpromotie mislukt.", call. = FALSE)
  invisible(manifest)
}

build_bootstrap_group_definitions <- function(ecological_mapping, functional_mapping, robust_species_ids) {
  definitions <- list()
  for (group_id in sort(unique(ecological_mapping$groep_100))) {
    mapping <- ecological_mapping[ecological_mapping$groep_100 == group_id, c("soort_id"), drop = FALSE]
    for (variant in c("robuust", "volledig")) {
      selected <- if (variant == "robuust") mapping[mapping$soort_id %in% robust_species_ids, , drop = FALSE] else mapping
      definitions[[length(definitions) + 1L]] <- list(
        entity_id = paste("eco", group_id, variant, sep = "-"), mapping = selected,
        variant = variant, aggregation = "geometrisch"
      )
    }
  }
  for (group_code in sort(unique(functional_mapping$group_code))) {
    mapping <- functional_mapping[functional_mapping$group_code == group_code, c("soort_id", "binary_membership", "membership_weight"), drop = FALSE]
    for (mode in c("binair", "gewogen")) for (variant in c("robuust", "volledig")) {
      selected <- if (variant == "robuust") mapping[mapping$soort_id %in% robust_species_ids, , drop = FALSE] else mapping
      definitions[[length(definitions) + 1L]] <- list(
        entity_id = paste("fun", group_code, mode, variant, sep = "-"), mapping = selected,
        variant = variant, aggregation = mode
      )
    }
  }
  definitions
}

select_fixed_robust_species <- function(species_results, required_years) {
  indices <- species_results$indices
  valid_status <- species_results$status$soort_id[species_results$status$analyse_categorie == "brugbare_tijdreeks"]
  by_species <- split(indices, indices$soort_id)
  complete <- names(Filter(function(df) {
    valid <- df$jaar[is.finite(df$index_gebrugged) & df$index_gebrugged > 0]
    identical(sort(unique(as.integer(valid))), sort(unique(as.integer(required_years))))
  }, by_species))
  intersect(as.integer(complete), as.integer(valid_status))
}

select_formal_primary_species <- function(context, required_years) {
  clusters <- context$clusters[order(context$clusters$stratum, context$clusters$bootstrap_cluster_id), , drop = FALSE]
  identity_draw <- data.frame(
    source_cluster_id = clusters$bootstrap_cluster_id,
    bootstrap_site_id = clusters$bootstrap_cluster_id,
    draw_position = seq_len(nrow(clusters)),
    stringsAsFactors = FALSE
  )
  rows <- lapply(sort(unique(context$species_matrix$soort_id)), function(species_id) {
    species <- context$species_matrix[context$species_matrix$soort_id == species_id, , drop = FALSE]
    drawn <- apply_cluster_draw(species, identity_draw)
    pre_fit <- fit_first_working_trim_model(drawn[drawn$jaar %in% context$config$periods$pre, , drop = FALSE])
    post_fit <- fit_first_working_trim_model(drawn[drawn$jaar %in% context$config$periods$post, , drop = FALSE])
    pre_index <- bootstrap_model_index(pre_fit)
    post_index <- bootstrap_model_index(post_fit)
    bridge <- compute_bridge_variants(species, pre_index, post_index, identity_draw, context)
    primary <- bridge[bridge$bridge_variant == "primary_1986_1988", , drop = FALSE]
    factor <- if (nrow(primary)) primary$bridge_factor[[1L]] else NA_real_
    combined <- c(pre_index, if (is.finite(factor) && factor > 0) post_index * factor else post_index * NA_real_)
    valid_years <- as.integer(names(combined)[is.finite(combined) & combined > 0])
    estimate <- combined_pct_trend(pre_index, post_index, factor)
    data.frame(
      soort_id = as.integer(species_id),
      formal_primary = nrow(primary) == 1L && identical(primary$bridge_status[[1L]], "formele_brug") && is.finite(estimate),
      complete_primary = is.finite(estimate) && identical(sort(unique(valid_years)), sort(unique(as.integer(required_years)))),
      point_estimate_pct_per_year = estimate,
      bridge_reason = if (nrow(primary)) primary$bridge_reason[[1L]] else "primaire_brug_ontbreekt",
      stringsAsFactors = FALSE
    )
  })
  diagnostics <- do.call(rbind, rows)
  list(
    formal_species_ids = diagnostics$soort_id[diagnostics$formal_primary],
    complete_species_ids = diagnostics$soort_id[diagnostics$formal_primary & diagnostics$complete_primary],
    diagnostics = diagnostics
  )
}

read_bundle_key_values <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  fields <- strsplit(lines[grepl("=", lines, fixed = TRUE)], "=", fixed = TRUE)
  stats::setNames(vapply(fields, function(x) paste(x[-1L], collapse = "="), character(1)), vapply(fields, `[[`, character(1), 1L))
}

build_cluster_definition_from_basis <- function(basis, derive_bridge_plot_sets) {
  counted <- basis[basis$geteld %in% TRUE, , drop = FALSE]
  sets <- derive_bridge_plot_sets(basis, 1981:1983, 1986:1988)
  definition <- do.call(rbind, lapply(split(counted, counted$plot_id), function(df) {
    data.frame(
      plot_id = as.integer(df$plot_id[[1L]]),
      bootstrap_cluster_id = as.integer(df$plot_id[[1L]]),
      stratum = if (any(df$in_hist_kern %in% TRUE)) "historische_kern" else "later_netwerk",
      primary_bridge_plot = df$plot_id[[1L]] %in% sets$common_any_year,
      strict_bridge_plot = df$plot_id[[1L]] %in% sets$common_all_years,
      stringsAsFactors = FALSE
    )
  }))
  rownames(definition) <- NULL
  definition[order(definition$plot_id), , drop = FALSE]
}

restrict_species_matrix_to_bootstrap_clusters <- function(species_matrix, clusters) {
  excluded <- !species_matrix$plot_id %in% clusters$plot_id
  if (any(excluded & species_matrix$geteld %in% TRUE)) stop("Een getelde soortmatrixrij valt buiten de clusterdefinitie.", call. = FALSE)
  species_matrix[!excluded, , drop = FALSE]
}

bundle_argument <- function(args, name, required = TRUE, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit) || hit == length(args)) {
    if (required) stop("Ontbrekend argument ", name, ".", call. = FALSE)
    return(default)
  }
  args[[hit + 1L]]
}

build_trim_bootstrap_bundle_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
  repo <- normalizePath(file.path(dirname(script_file), ".."), mustWork = TRUE)
  sql_path <- normalizePath(bundle_argument(args, "--sql"), mustWork = TRUE)
  bundle_dir <- bundle_argument(args, "--bundle")
  end_year <- as.integer(bundle_argument(args, "--end-year"))
  planned <- as.integer(bundle_argument(args, "--planned-replicates"))
  run_id <- bundle_argument(args, "--run-id")
  run_seed <- as.integer(bundle_argument(args, "--run-seed", required = FALSE, default = "20260920"))
  if (!is.finite(end_year) || !is.finite(planned) || planned < 1L) stop("Ongeldig eindjaar of replicatieaantal.", call. = FALSE)

  analysis_env <- new.env(parent = globalenv())
  sys.source(file.path(repo, "R", "trim_soorten_en_msi_evg.R"), envir = analysis_env)
  runtime_env <- environment(select_formal_primary_species)
  sys.source(file.path(repo, "R", "trim_bootstrap_core.R"), envir = runtime_env)
  sys.source(file.path(repo, "R", "trim_bridge_core.R"), envir = runtime_env)
  sys.source(file.path(repo, "R", "audit_trim_bridge_windows.R"), envir = runtime_env)

  export_manifest_path <- paste0(sql_path, ".manifest")
  if (!file.exists(export_manifest_path)) stop("Exportmanifest naast SQL-bron ontbreekt.", call. = FALSE)
  export_manifest <- read_bundle_key_values(export_manifest_path)
  if (as.numeric(export_manifest[["sql_bytes"]]) != unname(file.info(sql_path)$size)) stop("SQL-grootte wijkt af van exportmanifest.", call. = FALSE)
  cache_path <- file.path(dirname(sql_path), export_manifest[["cache_file"]])
  cache_manifest_path <- file.path(dirname(sql_path), export_manifest[["cache_manifest"]])
  if (!file.exists(cache_path) || !file.exists(cache_manifest_path)) stop("Gekoppelde gevalideerde analysecache ontbreekt.", call. = FALSE)
  cache_manifest <- read_bundle_key_values(cache_manifest_path)
  if (!identical(cache_manifest[["sql_sha256"]], export_manifest[["sql_sha256"]])) stop("Cache- en exportmanifest verwijzen niet naar dezelfde bronhash.", call. = FALSE)
  cache <- readRDS(cache_path)
  if (!identical(as.character(cache$identity$sql_sha256), export_manifest[["sql_sha256"]])) stop("Cache-identiteit wijkt af.", call. = FALSE)

  tbls <- analysis_env$apply_meijendel_plot_scope(cache$data, character())
  tbls$plots$kavel_nummer <- analysis_env$normalize_kavel_nummer(tbls$plots$kavel_nummer)
  periods <- analysis_env$resolve_trim_periods(end_year)
  basis <- analysis_env$prepare_analysis_basis(tbls, end_year)
  species_matrix <- analysis_env$build_species_matrix(tbls, basis, end_year)
  clusters <- build_cluster_definition_from_basis(basis, derive_bridge_plot_sets)
  species_results <- analysis_env$analyse_species(species_matrix, periods)
  eligible_ids <- species_results$status$soort_id[
    species_results$status$analyse_categorie == "brugbare_tijdreeks"
  ]
  complete_existing_ids <- select_fixed_robust_species(species_results, periods$combined$years)
  context <- build_bootstrap_context(
    list(species_matrix = restrict_species_matrix_to_bootstrap_clusters(species_matrix, clusters)), clusters,
    list(
      run_seed = run_seed,
      periods = list(pre = periods$pre$years, post = periods$post$years),
      bridge_pre_years = periods$bridge$pre,
      primary_post_years = periods$bridge$primary_post
    )
  )
  formal_selection <- select_formal_primary_species(context, periods$combined$years)
  formal_ids <- intersect(eligible_ids, formal_selection$formal_species_ids)
  robust_ids <- Reduce(intersect, list(complete_existing_ids, formal_ids, formal_selection$complete_species_ids))
  if (!length(robust_ids)) stop("Geen soort heeft een formele primaire brug en volledige vaste indexreeks voor de robuuste groepsvariant.", call. = FALSE)
  context$formal_primary_species_ids <- formal_ids
  context$fixed_robust_species_ids <- robust_ids
  context$formal_selection_diagnostics <- formal_selection$diagnostics
  context$group_definitions <- build_bootstrap_group_definitions(
    analysis_env$build_group_mapping(tbls),
    analysis_env$build_functional_group_mapping(tbls),
    robust_ids
  )
  context$config$analysis_end_year <- end_year
  context$config$planned_replicates <- planned
  context$config$run_id <- run_id

  commit <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  config_hash <- digest::digest(context$config, algo = "sha256")
  identity <- list(
    run_id = run_id,
    source_hash = export_manifest[["sql_sha256"]],
    config_hash = config_hash,
    code_commit = commit[[1L]],
    software_id = paste0("R-", getRversion(), "_rtrim-", utils::packageVersion("rtrim"))
  )
  group_ids <- vapply(context$group_definitions, `[[`, character(1), "entity_id")
  selection <- list(
    plots = sort(unique(as.character(clusters$plot_id))),
    years = seq.int(1958L, end_year),
    species = sort(unique(as.character(species_matrix$soort_id))),
    groups = sort(unique(group_ids))
  )
  selection_hash <- digest::digest(jsonlite::toJSON(selection, auto_unbox = TRUE), algo = "sha256", serialize = FALSE)
  write_trim_bootstrap_bundle(
    context, identity, bundle_dir,
    metadata = list(
      analysis_end_year = end_year,
      planned_replicates = planned,
      publication_status = if (end_year < 2026L) "validatie_niet_publiceren" else "kandidaat_wacht_op_samenvatting",
      selection_hash = selection_hash,
      species_count = length(unique(species_matrix$soort_id)),
      cluster_count = nrow(clusters),
      primary_bridge_plot_count = sum(clusters$primary_bridge_plot),
      strict_bridge_plot_count = sum(clusters$strict_bridge_plot)
      , eligible_two_period_species_count = length(unique(eligible_ids)),
      formal_primary_species_count = length(formal_ids),
      fixed_robust_species_count = length(robust_ids),
      engine_sha256 = as.list(trim_bootstrap_engine_hashes(repo))
    )
  )
  cat("BUNDLE_STATUS=ready\nBUNDLE_RUN_ID=", run_id, "\n", sep = "")
}

if (sys.nframe() == 0L) build_trim_bootstrap_bundle_cli()
