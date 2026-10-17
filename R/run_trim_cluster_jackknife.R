run_trim_cluster_jackknife <- function(context) {
  if (is.null(context$clusters) || !all(c("bootstrap_cluster_id", "stratum") %in% names(context$clusters))) {
    stop("Jackknifecontext mist clusterdefinitie.", call. = FALSE)
  }
  estimator <- context$jackknife_estimator
  if (!is.function(estimator)) stop("Jackknifecontext mist jackknife_estimator.", call. = FALSE)
  clusters <- context$clusters[order(context$clusters$bootstrap_cluster_id), , drop = FALSE]
  rows <- lapply(seq_len(nrow(clusters)), function(i) {
    omitted <- clusters$bootstrap_cluster_id[[i]]
    reduced <- context
    reduced$clusters <- clusters[clusters$bootstrap_cluster_id != omitted, , drop = FALSE]
    if (!is.null(reduced$species_matrix) && "bootstrap_cluster_id" %in% names(reduced$species_matrix)) {
      reduced$species_matrix <- reduced$species_matrix[reduced$species_matrix$bootstrap_cluster_id != omitted, , drop = FALSE]
    }
    estimate <- tryCatch(estimator(reduced, omitted), error = function(e) {
      data.frame(
        entity_type = NA_character_, entity_id = NA_character_, period = NA_character_,
        estimate = NA_real_, error_status = conditionMessage(e), stringsAsFactors = FALSE
      )
    })
    cbind(
      data.frame(omitted_cluster_id = omitted, stratum = clusters$stratum[[i]], stringsAsFactors = FALSE),
      estimate
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
