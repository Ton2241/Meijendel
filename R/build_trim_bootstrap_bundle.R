#!/usr/bin/env Rscript

bundle_sha256_file <- function(path) {
  output <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  hash <- if (length(output)) sub("[[:space:]].*$", "", output[[1L]]) else ""
  if (!grepl("^[0-9a-f]{64}$", hash)) stop("Bundlehash kon niet worden bepaald.", call. = FALSE)
  hash
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
  source(file.path(repo, "R", "trim_bootstrap_core.R"), local = TRUE)
  source(file.path(repo, "R", "trim_bridge_core.R"), local = TRUE)
  source(file.path(repo, "R", "audit_trim_bridge_windows.R"), local = TRUE)

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
  robust_ids <- species_results$status$soort_id[species_results$status$analyse_categorie == "brugbare_tijdreeks"]
  context <- build_bootstrap_context(
    list(species_matrix = restrict_species_matrix_to_bootstrap_clusters(species_matrix, clusters)), clusters,
    list(
      run_seed = run_seed,
      periods = list(pre = periods$pre$years, post = periods$post$years),
      bridge_pre_years = periods$bridge$pre,
      primary_post_years = periods$bridge$primary_post
    )
  )
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
    )
  )
  cat("BUNDLE_STATUS=ready\nBUNDLE_RUN_ID=", run_id, "\n", sep = "")
}

if (sys.nframe() == 0L) build_trim_bootstrap_bundle_cli()
