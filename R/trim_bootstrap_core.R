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
