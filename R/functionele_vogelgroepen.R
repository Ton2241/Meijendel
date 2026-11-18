functional_group_config <- function(path) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

functional_group_metadata <- function(config) {
  do.call(rbind, lapply(config, function(cluster) {
    do.call(rbind, lapply(cluster$groups, function(group) {
      data.frame(group_code = group$code, naam_nl = group$title,
                 cluster = cluster$label, chart = group$chart,
                 waarschuwing = if (is.null(group$text)) "" else group$text,
                 stringsAsFactors = FALSE)
    }))
  }))
}

functional_group_tables <- function(tables, config) {
  definitions <- tables$functional_group_definition
  memberships <- tables$functional_group_membership
  for (cluster in config) {
    for (group in cluster$groups) {
      if (is.null(group$primary)) next
      # The approved lists belong to the analysis configuration. Preserve any
      # matching database identifier and replace the corresponding selection.
      old <- which(definitions$group_code == group$code & definitions$group_version == "v1")
      if (length(old) > 1L) stop("Dubbele functionele groepsdefinitie: ", group$code)
      id <- if (length(old)) definitions$id[[old]] else
        max(c(0L, as.integer(definitions$id)), na.rm = TRUE) + 1L
      if (!length(old)) {
        definition <- data.frame(
          id = id, group_code = group$code, group_version = "v1", naam_nl = group$title,
          minimum_exploratief = 5L, minimum_hoofdindicator = 10L,
          minimum_robuust = 20L, status = "approved")
        definitions <- rbind(definitions[, names(definition)], definition)
      }
      primary <- as.integer(unlist(group$primary))
      secondary <- as.integer(unlist(group$secondary))
      ids <- c(primary, secondary)
      if (anyDuplicated(ids)) stop("Dubbel lidmaatschap binnen ", group$code)
      member <- data.frame(
        functional_group_definition_id = id, soort_id = ids, binary_membership = 1L,
        membership_weight = rep(c(1, 0.5), c(length(primary), length(secondary))),
        classification = rep(c("primary", "secondary"), c(length(primary), length(secondary))))
      memberships <- rbind(
        memberships[memberships$functional_group_definition_id != id, names(member), drop = FALSE],
        member)
    }
  }
  tables$functional_group_definition <- definitions
  tables$functional_group_membership <- memberships
  tables
}
