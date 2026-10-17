normalize_kavel_identity <- function(x) {
  x <- trimws(as.character(x))
  x <- sub("^[mM](?=[0-9])", "", x, perl = TRUE)
  tolower(gsub("[[:space:]]+", "", x))
}

replicate_seed <- function(run_seed, replicate_id) {
  if (length(run_seed) != 1L || is.na(run_seed) || run_seed != as.integer(run_seed)) {
    stop("run_seed moet één geheel getal zijn.", call. = FALSE)
  }
  if (length(replicate_id) != 1L || is.na(replicate_id) || replicate_id < 1L || replicate_id != as.integer(replicate_id)) {
    stop("replicate_id moet een positief geheel getal zijn.", call. = FALSE)
  }
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG")
  set.seed(as.integer(run_seed))
  seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (replicate_id > 1L) {
    for (i in seq_len(as.integer(replicate_id) - 1L)) seed <- parallel::nextRNGStream(seed)
  }
  as.integer(seed)
}

with_replicate_seed <- function(run_seed, replicate_id, code) {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG")
  assign(".Random.seed", replicate_seed(run_seed, replicate_id), envir = .GlobalEnv)
  force(code)
}

make_stratified_cluster_draw <- function(clusters, replicate_id, run_seed) {
  required <- c("bootstrap_cluster_id", "stratum", "primary_bridge_plot", "strict_bridge_plot")
  missing <- setdiff(required, names(clusters))
  if (length(missing)) stop("Clusterdefinitie mist: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  if (anyDuplicated(clusters$bootstrap_cluster_id)) stop("bootstrap_cluster_id is niet uniek.", call. = FALSE)
  if (any(is.na(clusters$stratum)) || any(!nzchar(clusters$stratum))) stop("Iedere cluster moet één stratum hebben.", call. = FALSE)
  clusters <- clusters[order(clusters$stratum, clusters$bootstrap_cluster_id), , drop = FALSE]

  with_replicate_seed(run_seed, replicate_id, {
    parts <- lapply(split(clusters, clusters$stratum, drop = TRUE), function(part) {
      selected <- sample(part$bootstrap_cluster_id, size = nrow(part), replace = TRUE)
      source_rows <- part[match(selected, part$bootstrap_cluster_id), , drop = FALSE]
      source_rows$source_cluster_id <- source_rows$bootstrap_cluster_id
      source_rows
    })
    draw <- do.call(rbind, parts)
    rownames(draw) <- NULL
    draw$draw_position <- seq_len(nrow(draw))
    draw$bootstrap_site_id <- as.integer(replicate_id) * 100000L + draw$draw_position
    draw[, c("source_cluster_id", "bootstrap_site_id", "draw_position", setdiff(names(draw), c("source_cluster_id", "bootstrap_site_id", "draw_position", "bootstrap_cluster_id"))), drop = FALSE]
  })
}

apply_cluster_draw <- function(data, draw, cluster_col = "bootstrap_cluster_id") {
  if (!cluster_col %in% names(data)) stop("Data mist clusterkolom ", cluster_col, ".", call. = FALSE)
  required_draw <- c("source_cluster_id", "bootstrap_site_id", "draw_position")
  missing <- setdiff(required_draw, names(draw))
  if (length(missing)) stop("Trekking mist: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  parts <- lapply(seq_len(nrow(draw)), function(i) {
    rows <- data[data[[cluster_col]] == draw$source_cluster_id[[i]], , drop = FALSE]
    rows$source_cluster_id <- draw$source_cluster_id[[i]]
    rows$bootstrap_site_id <- draw$bootstrap_site_id[[i]]
    rows$draw_position <- draw$draw_position[[i]]
    if ("plot_id" %in% names(rows)) rows$plot_id <- draw$bootstrap_site_id[[i]]
    rows
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

fit_first_working_trim_model <- function(df, configs = NULL) {
  required <- c("plot_id", "jaar", "geteld", "count_adjusted")
  missing <- setdiff(required, names(df))
  if (length(missing)) return(list(ok = FALSE, model = NULL, reason = paste("mist", paste(missing, collapse = ","))))
  df <- df[df$geteld %in% TRUE & is.finite(df$count_adjusted), , drop = FALSE]
  if (!nrow(df) || length(unique(df$jaar)) < 3L || length(unique(df$plot_id)) < 2L) {
    return(list(ok = FALSE, model = NULL, reason = "te_weinig_modeldata"))
  }
  years <- sort(unique(df$jaar))
  year_map <- data.frame(jaar = years, trim_year = seq_along(years))
  df <- merge(df, year_map, by = "jaar", all.x = TRUE)
  fit_data <- data.frame(site = df$plot_id, year = df$trim_year, count = df$count_adjusted)
  if (is.null(configs)) {
    configs <- list(
      list(model = 3, overdisp = TRUE, serialcor = FALSE, label = "model3_overdisp"),
      list(model = 3, overdisp = FALSE, serialcor = FALSE, label = "model3_basis"),
      list(model = 2, overdisp = FALSE, serialcor = FALSE, label = "model2_basis")
    )
  }
  attempts <- character()
  for (cfg in configs) {
    warnings <- character()
    fit <- tryCatch(
      withCallingHandlers(
        rtrim::trim(
          fit_data, model = cfg$model, overdisp = cfg$overdisp,
          serialcor = cfg$serialcor, autodelete = TRUE, conv_crit = 1e-5, max_iter = 400
        ),
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) e
    )
    if (!inherits(fit, "error")) {
      attempts <- c(attempts, paste0(cfg$label, ":ok"))
      return(list(
        ok = TRUE, model = fit, config = cfg$label, year_map = year_map,
        attempts = attempts, warnings = unique(warnings),
        site_ids = sort(unique(df$plot_id)), reason = NA_character_
      ))
    }
    attempts <- c(attempts, paste0(cfg$label, ":", conditionMessage(fit)))
  }
  list(ok = FALSE, model = NULL, reason = tail(attempts, 1L), attempts = attempts)
}

bootstrap_model_index <- function(fit) {
  if (!isTRUE(fit$ok)) return(NULL)
  idx <- rtrim::index(fit$model, which = "imputed")
  years <- fit$year_map$jaar[match(idx$time, fit$year_map$trim_year)]
  values <- as.numeric(idx$imputed)
  first <- values[which(is.finite(values) & values > 0)[1L]]
  if (!is.finite(first) || first <= 0) return(NULL)
  stats::setNames(100 * values / first, as.character(years))
}

bridge_common_plots <- function(species_matrix, pre_years, post_years) {
  counted <- unique(species_matrix[
    species_matrix$geteld %in% TRUE & species_matrix$jaar %in% c(pre_years, post_years),
    c("bootstrap_cluster_id", "jaar"), drop = FALSE
  ])
  pre <- unique(counted$bootstrap_cluster_id[counted$jaar %in% pre_years])
  post <- unique(counted$bootstrap_cluster_id[counted$jaar %in% post_years])
  sort(intersect(pre, post))
}

build_bootstrap_context <- function(tbls, cluster_definition, config) {
  species_matrix <- tbls$species_matrix
  if (is.null(species_matrix)) stop("build_bootstrap_context vereist tbls$species_matrix.", call. = FALSE)
  if (!"bootstrap_cluster_id" %in% names(species_matrix)) {
    species_matrix <- merge(
      species_matrix,
      cluster_definition[, c("plot_id", "bootstrap_cluster_id")],
      by = "plot_id", all.x = TRUE
    )
  }
  if (any(is.na(species_matrix$bootstrap_cluster_id))) stop("Soortmatrix bevat ongekoppelde plots.", call. = FALSE)
  pre_years <- config$bridge_pre_years
  primary_post <- config$primary_post_years
  variants <- list(
    primary_1986_1988 = list(
      pre_years = pre_years, post_years = primary_post,
      plot_ids = bridge_common_plots(species_matrix, pre_years, primary_post)
    ),
    alternative_1987_1989 = list(
      pre_years = pre_years, post_years = 1987:1989,
      plot_ids = bridge_common_plots(species_matrix, pre_years, 1987:1989)
    ),
    alternative_1988_1990 = list(
      pre_years = pre_years, post_years = 1988:1990,
      plot_ids = bridge_common_plots(species_matrix, pre_years, 1988:1990)
    ),
    strict_all_six = list(
      pre_years = pre_years, post_years = primary_post,
      plot_ids = cluster_definition$bootstrap_cluster_id[cluster_definition$strict_bridge_plot %in% TRUE]
    ),
    historical_continuity_1984_1986 = list(
      pre_years = pre_years, post_years = 1984:1986,
      plot_ids = bridge_common_plots(species_matrix, pre_years, 1984:1986),
      allow_transition_years = TRUE
    )
  )
  list(
    species_matrix = species_matrix,
    clusters = cluster_definition,
    config = config,
    bridge_variants = variants,
    historical_cluster_ids = cluster_definition$bootstrap_cluster_id[cluster_definition$stratum == "historische_kern"]
  )
}

draw_hash_text <- function(draw) {
  paste(paste(draw$draw_position, draw$source_cluster_id, draw$bootstrap_site_id, sep = ":"), collapse = "|")
}

combined_pct_trend <- function(pre_index, post_index, bridge_factor) {
  if (is.null(pre_index) || is.null(post_index) || !is.finite(bridge_factor) || bridge_factor <= 0) return(NA_real_)
  series <- c(pre_index, post_index * bridge_factor)
  years <- as.integer(names(series))
  keep <- is.finite(series) & series > 0 & is.finite(years)
  if (sum(keep) < 3L) return(NA_real_)
  slope <- unname(stats::coef(stats::lm(log(series[keep]) ~ years[keep]))[[2L]])
  100 * (exp(slope) - 1)
}

run_trim_bootstrap_replicate <- function(context, replicate_id) {
  draw <- make_stratified_cluster_draw(context$clusters, replicate_id, context$config$run_seed)
  draw_hash <- draw_hash_text(draw)
  coverage_sets <- list(
    volledig_netwerk = context$clusters$bootstrap_cluster_id,
    historische_kern = context$historical_cluster_ids
  )
  result_rows <- list()
  diagnostic_main <- list()
  diagnostic_calibration <- list()
  counter <- 0L

  for (coverage_name in names(coverage_sets)) {
    coverage_ids <- coverage_sets[[coverage_name]]
    coverage_matrix <- context$species_matrix[context$species_matrix$bootstrap_cluster_id %in% coverage_ids, , drop = FALSE]
    coverage_draw <- draw[draw$source_cluster_id %in% coverage_ids, , drop = FALSE]
    variants <- context$bridge_variants
    for (name in names(variants)) variants[[name]]$plot_ids <- intersect(variants[[name]]$plot_ids, coverage_ids)
    if (coverage_name == "historische_kern") variants <- variants["primary_1986_1988"]

    for (species_id in sort(unique(coverage_matrix$soort_id))) {
      species_original <- coverage_matrix[coverage_matrix$soort_id == species_id, , drop = FALSE]
      species_drawn <- apply_cluster_draw(species_original, coverage_draw)
      pre_df <- species_drawn[species_drawn$jaar %in% context$config$periods$pre, , drop = FALSE]
      post_df <- species_drawn[species_drawn$jaar %in% context$config$periods$post, , drop = FALSE]
      pre_fit <- fit_first_working_trim_model(pre_df)
      post_fit <- fit_first_working_trim_model(post_df)
      pre_index <- bootstrap_model_index(pre_fit)
      post_index <- bootstrap_model_index(post_fit)
      bridge_rows <- compute_bridge_variants(
        species_original, pre_index, post_index, coverage_draw,
        list(bridge_variants = variants)
      )
      for (i in seq_len(nrow(bridge_rows))) {
        counter <- counter + 1L
        result_rows[[counter]] <- data.frame(
          replicate_id = as.integer(replicate_id),
          soort_id = species_id,
          coverage_variant = coverage_name,
          draw_hash = draw_hash,
          pre_model = pre_fit$config %||% NA_character_,
          post_model = post_fit$config %||% NA_character_,
          bridge_rows[i, , drop = FALSE],
          estimate_pct_per_year = combined_pct_trend(pre_index, post_index, bridge_rows$bridge_factor[[i]]),
          stringsAsFactors = FALSE
        )
      }
      primary <- bridge_rows[bridge_rows$bridge_variant == "primary_1986_1988", , drop = FALSE]
      diagnostic_main[[length(diagnostic_main) + 1L]] <- sort(unique(species_drawn$bootstrap_site_id))
      calibration_ids <- if (nrow(primary) && nzchar(primary$calibration_site_ids[[1L]])) {
        as.integer(strsplit(primary$calibration_site_ids[[1L]], ";", fixed = TRUE)[[1L]])
      } else integer()
      diagnostic_calibration[[length(diagnostic_calibration) + 1L]] <- calibration_ids
    }
  }
  list(
    replicate_id = as.integer(replicate_id),
    draw = draw,
    species = do.call(rbind, result_rows),
    diagnostics = list(main_site_ids = diagnostic_main, calibration_site_ids = diagnostic_calibration)
  )
}

geometric_group_mean <- function(values) {
  values <- values[is.finite(values) & values > 0]
  if (!length(values)) NA_real_ else exp(mean(log(values)))
}

binary_group_mean <- function(values, membership) {
  keep <- is.finite(values) & values > 0 & is.finite(membership) & membership > 0
  if (!any(keep)) NA_real_ else exp(mean(log(values[keep])))
}

weighted_group_mean <- function(values, weights) {
  keep <- is.finite(values) & values > 0 & is.finite(weights) & weights > 0
  if (!any(keep) || sum(weights[keep]) <= 0) NA_real_ else exp(sum(weights[keep] * log(values[keep])) / sum(weights[keep]))
}

aggregate_bootstrap_group <- function(indices, fixed_group, variant = c("robuust", "volledig"), aggregation = c("geometrisch", "binair", "gewogen")) {
  variant <- match.arg(variant)
  aggregation <- match.arg(aggregation)
  required_indices <- c("soort_id", "jaar", "index_value", "bridge_variant", "coverage_variant")
  required_group <- c("soort_id")
  missing <- c(setdiff(required_indices, names(indices)), setdiff(required_group, names(fixed_group)))
  if (length(missing)) stop("Groepsinvoer mist: ", paste(unique(missing), collapse = ", "), ".", call. = FALSE)
  expected <- sort(unique(fixed_group$soort_id))
  indices <- indices[indices$soort_id %in% expected, , drop = FALSE]
  keys <- unique(indices[, c("bridge_variant", "coverage_variant", "jaar"), drop = FALSE])
  keys <- keys[order(keys$coverage_variant, keys$bridge_variant, keys$jaar), , drop = FALSE]

  cell_species <- lapply(seq_len(nrow(keys)), function(i) {
    cell <- indices[
      indices$bridge_variant == keys$bridge_variant[[i]] &
        indices$coverage_variant == keys$coverage_variant[[i]] &
        indices$jaar == keys$jaar[[i]] & is.finite(indices$index_value) & indices$index_value > 0,
      , drop = FALSE
    ]
    sort(unique(cell$soort_id))
  })
  if (variant == "robuust" && (length(cell_species) == 0L || any(vapply(cell_species, function(x) !identical(x, expected), logical(1))))) {
    return(list(status = "ongeldig_vaste_soort_ontbreekt", series = data.frame()))
  }

  rows <- lapply(seq_len(nrow(keys)), function(i) {
    cell <- indices[
      indices$bridge_variant == keys$bridge_variant[[i]] &
        indices$coverage_variant == keys$coverage_variant[[i]] &
        indices$jaar == keys$jaar[[i]] & is.finite(indices$index_value) & indices$index_value > 0,
      , drop = FALSE
    ]
    membership <- fixed_group[match(cell$soort_id, fixed_group$soort_id), , drop = FALSE]
    binary_weights <- if ("binary_membership" %in% names(membership)) membership$binary_membership else rep(1, nrow(membership))
    continuous_weights <- if ("membership_weight" %in% names(membership)) membership$membership_weight else rep(1, nrow(membership))
    value <- switch(
      aggregation,
      geometrisch = geometric_group_mean(cell$index_value),
      binair = binary_group_mean(cell$index_value, binary_weights),
      gewogen = weighted_group_mean(cell$index_value, continuous_weights)
    )
    present <- sort(unique(cell$soort_id))
    missing_species <- setdiff(expected, present)
    data.frame(
      bridge_variant = keys$bridge_variant[[i]],
      coverage_variant = keys$coverage_variant[[i]],
      jaar = keys$jaar[[i]],
      group_index = value,
      n_soorten = length(present),
      verwachte_soorten = length(expected),
      ontbrekende_soorten = paste(missing_species, collapse = ";"),
      som_gewichten = if (aggregation == "gewogen") sum(continuous_weights[is.finite(continuous_weights) & continuous_weights > 0]) else sum(binary_weights[is.finite(binary_weights) & binary_weights > 0]),
      aggregation = aggregation,
      stringsAsFactors = FALSE
    )
  })
  list(
    status = if (variant == "robuust") "geldig_vaste_samenstelling" else "geldig_wisselende_samenstelling",
    series = do.call(rbind, rows)
  )
}

run_unbridged_bootstrap_replicate <- function(context, replicate_id) {
  if (!identical(context$config$bridge, FALSE)) stop("Ongebrugde replicatie vereist bridge = FALSE.", call. = FALSE)
  period <- as.integer(context$config$period)
  if (length(period) != 2L || period[[1L]] > period[[2L]]) stop("Ongeldige ongebrugde analyseperiode.", call. = FALSE)
  draw <- make_stratified_cluster_draw(context$clusters, replicate_id, context$config$run_seed)
  drawn <- apply_cluster_draw(context$species_matrix, draw)
  rows <- lapply(sort(unique(drawn$soort_id)), function(species_id) {
    df <- drawn[
      drawn$soort_id == species_id & drawn$jaar >= period[[1L]] & drawn$jaar <= period[[2L]],
      , drop = FALSE
    ]
    fit <- fit_first_working_trim_model(df)
    index <- bootstrap_model_index(fit)
    estimate <- if (is.null(index) || length(index) < 3L) {
      NA_real_
    } else {
      years <- as.integer(names(index))
      keep <- is.finite(index) & index > 0
      slope <- unname(stats::coef(stats::lm(log(index[keep]) ~ years[keep]))[[2L]])
      100 * (exp(slope) - 1)
    }
    data.frame(
      replicate_id = as.integer(replicate_id),
      soort_id = species_id,
      period = paste(period, collapse = "-"),
      estimate_pct_per_year = estimate,
      model_status = if (isTRUE(fit$ok)) "geldig" else fit$reason,
      model = if (is.null(fit$config)) NA_character_ else fit$config,
      draw_hash = draw_hash_text(draw),
      stringsAsFactors = FALSE
    )
  })
  list(
    replicate_id = as.integer(replicate_id),
    draw = draw,
    species = do.call(rbind, rows),
    group_variants = context$config$group_variants
  )
}
