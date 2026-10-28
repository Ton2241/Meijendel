pq_gradient_levels <- function() {
  c(
    "open_pionier",
    "duingrasland_mos_korstmos",
    "nat_riet",
    "struweel_ruigte",
    "bomen_bos"
  )
}

require_pq_gradient_fields <- function(data, fields, label) {
  missing <- setdiff(fields, names(data))
  if (length(missing)) {
    stop(sprintf(
      "%s mist kolommen: %s", label, paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
}

normalise_pq_taxon_name <- function(value) {
  value <- tolower(trimws(as.character(value)))
  value <- gsub("[[:space:]]+", " ", value)
  value[!nzchar(value)] <- NA_character_
  value
}

pq_taxon_binomial <- function(value) {
  value <- normalise_pq_taxon_name(value)
  value <- sub("[[:space:]]+(subsp\\.|ssp\\.|var\\.|s\\.)[[:space:]].*$", "", value)
  value <- sub("[[:space:]]+s\\.l\\.$", "", value)
  value <- sub("[[:space:]]+s\\.s\\.$", "", value)
  pieces <- strsplit(value, " ", fixed = TRUE)
  vapply(pieces, function(item) {
    item <- item[nzchar(item)]
    if (length(item) < 2L || grepl("[/×x]", item[[2L]])) return(NA_character_)
    paste(item[1:2], collapse = " ")
  }, character(1))
}

synbiosys_taxon_matches <- function(taxa, aliases, ecodbase) {
  require_pq_gradient_fields(
    taxa,
    c("taxon_id", "naam_zonder_auteur", "wetenschappelijke_naam"),
    "PQ-taxa"
  )
  require_pq_gradient_fields(
    aliases, c("taxon_id", "bron_wetenschappelijke_naam"), "taxonaliassen"
  )
  require_pq_gradient_fields(ecodbase, "WETNAAM", "SynBioSys EcoDbase")
  if (anyDuplicated(taxa$taxon_id)) {
    stop("PQ-taxa bevatten dubbele taxon_id's.", call. = FALSE)
  }
  eco_name <- normalise_pq_taxon_name(ecodbase$WETNAAM)
  if (anyDuplicated(eco_name[!is.na(eco_name)])) {
    stop("SynBioSys bevat dubbele genormaliseerde wetenschappelijke namen.", call. = FALSE)
  }
  lookup <- setNames(seq_len(nrow(ecodbase)), eco_name)
  matched_row <- rep(NA_integer_, nrow(taxa))
  method <- rep(NA_character_, nrow(taxa))
  for (field in c("naam_zonder_auteur", "wetenschappelijke_naam")) {
    candidate <- unname(lookup[normalise_pq_taxon_name(taxa[[field]])])
    take <- is.na(matched_row) & !is.na(candidate)
    matched_row[take] <- candidate[take]
    method[take] <- if (field == "naam_zonder_auteur") {
      "synbiosys_exact"
    } else {
      "synbiosys_wetenschappelijke_naam"
    }
  }
  alias_match <- unname(lookup[
    normalise_pq_taxon_name(aliases$bron_wetenschappelijke_naam)
  ])
  usable <- !is.na(alias_match) & aliases$taxon_id %in% taxa$taxon_id
  alias_rows <- split(alias_match[usable], aliases$taxon_id[usable])
  alias_first <- vapply(alias_rows, function(value) value[[1L]], integer(1))
  candidate <- unname(alias_first[as.character(taxa$taxon_id)])
  take <- is.na(matched_row) & !is.na(candidate)
  matched_row[take] <- candidate[take]
  method[take] <- "alias_bronkoppeling"
  eco_binomial <- pq_taxon_binomial(ecodbase$WETNAAM)
  binomial_rows <- split(seq_len(nrow(ecodbase)), eco_binomial)
  binomial_rows <- binomial_rows[!is.na(names(binomial_rows))]
  select_binomial_row <- function(rows) {
    if (length(rows) == 1L) return(rows)
    broad <- rows[grepl(" s\\.l\\.$", normalise_pq_taxon_name(ecodbase$WETNAAM[rows]))]
    if (length(broad) == 1L) broad else NA_integer_
  }
  binomial_first <- vapply(binomial_rows, select_binomial_row, integer(1))
  taxon_binomial <- pq_taxon_binomial(taxa$naam_zonder_auteur)
  candidate <- unname(binomial_first[taxon_binomial])
  take <- is.na(matched_row) & !is.na(candidate)
  matched_row[take] <- candidate[take]
  method[take] <- "synbiosys_binomial"
  data.frame(
    taxon_id = taxa$taxon_id,
    synbiosys_row = matched_row,
    match_method = method,
    stringsAsFactors = FALSE
  )
}

add_gradient_evidence <- function(store, gradient, evidence) {
  if (is.na(gradient) || !nzchar(gradient)) return(store)
  store[[gradient]] <- unique(c(store[[gradient]], evidence))
  store
}

synbiosys_row_gradients <- function(row) {
  evidence <- setNames(vector("list", length(pq_gradient_levels())), pq_gradient_levels())
  ecotope_fields <- grep("^ECOTP_[0-9]+$", names(row), value = TRUE)
  ecotopes <- unique(na.omit(as.character(unlist(row[ecotope_fields], use.names = FALSE))))
  ecotopes <- ecotopes[nzchar(ecotopes)]
  for (code in ecotopes) {
    structure_code <- substr(sub("^[zb]", "", code), 1L, 1L)
    gradient <- switch(
      structure_code,
      P = "open_pionier",
      G = "duingrasland_mos_korstmos",
      V = "nat_riet",
      W = "nat_riet",
      R = "struweel_ruigte",
      H = "bomen_bos",
      NA_character_
    )
    evidence <- add_gradient_evidence(evidence, gradient, paste0("ECOTP:", code))
  }
  for (field in intersect(c("SOC_GRP_ND", "SOC_GRP_DG"), names(row))) {
    code <- as.character(row[[field]])
    if (is.na(code) || !nzchar(code)) next
    gradient <- if (grepl("^P", code)) {
      "open_pionier"
    } else if (grepl("^(Gk|Gc|Gf|Ga|Gp)$", code)) {
      "duingrasland_mos_korstmos"
    } else if (grepl("^(Md|Mn|Ms|Mp|Gm|W)$", code)) {
      "nat_riet"
    } else if (code %in% c("R", "Z")) {
      "struweel_ruigte"
    } else if (code == "B") {
      "bomen_bos"
    } else {
      NA_character_
    }
    evidence <- add_gradient_evidence(
      evidence, gradient, paste0(field, ":", code)
    )
  }
  life_fields <- intersect(c("LV_VORM1", "LV_VORM2", "LV_VORM3"), names(row))
  life <- unique(na.omit(as.character(unlist(row[life_fields], use.names = FALSE))))
  if (any(life %in% c("A", "B"))) {
    evidence <- add_gradient_evidence(
      evidence, "nat_riet", paste0("LV_VORM:", paste(life[life %in% c("A", "B")], collapse = "+"))
    )
  }
  growth_fields <- intersect(c("GR_VORM1", "GR_VORM2", "GR_VORM3"), names(row))
  growth <- suppressWarnings(as.integer(unlist(row[growth_fields], use.names = FALSE)))
  growth <- unique(growth[is.finite(growth)])
  if (any(growth >= 70L & growth < 80L)) {
    evidence <- add_gradient_evidence(
      evidence, "struweel_ruigte",
      paste0("GR_VORM:", paste(growth[growth >= 70L & growth < 80L], collapse = "+"))
    )
  }
  if (any(growth >= 80L & growth < 90L)) {
    evidence <- add_gradient_evidence(
      evidence, "bomen_bos",
      paste0("GR_VORM:", paste(growth[growth >= 80L & growth < 90L], collapse = "+"))
    )
  }
  evidence[lengths(evidence) > 0L]
}

build_pq_taxon_gradient_mapping <- function(taxa, aliases, ecodbase) {
  require_pq_gradient_fields(
    taxa,
    c(
      "taxon_id", "wetenschappelijke_naam", "naam_zonder_auteur",
      "weergavenaam", "groep_naam"
    ),
    "PQ-taxa"
  )
  matches <- synbiosys_taxon_matches(taxa, aliases, ecodbase)
  rows <- vector("list", nrow(taxa))
  for (index in seq_len(nrow(taxa))) {
    item <- taxa[index, , drop = FALSE]
    evidence <- setNames(vector("list", length(pq_gradient_levels())), pq_gradient_levels())
    source_method <- character()
    source_name <- NA_character_
    eco_row <- matches$synbiosys_row[index]
    if (!is.na(eco_row)) {
      source_evidence <- synbiosys_row_gradients(ecodbase[eco_row, , drop = FALSE])
      for (gradient in names(source_evidence)) {
        evidence[[gradient]] <- unique(c(evidence[[gradient]], source_evidence[[gradient]]))
      }
      source_method <- matches$match_method[index]
      source_name <- as.character(ecodbase$WETNAAM[eco_row])
    }
    group_name <- as.character(item$groep_naam)
    if (!is.na(group_name) && group_name %in% c(
      "Mossen en levermossen", "Korstmossen"
    )) {
      evidence <- add_gradient_evidence(
        evidence, "duingrasland_mos_korstmos", paste0("taxongroep:", group_name)
      )
      source_method <- unique(c(source_method, "taxongroepregel"))
    }
    if (!is.na(group_name) && group_name == "Kranswieren, wieren en algen") {
      evidence <- add_gradient_evidence(
        evidence, "nat_riet", paste0("taxongroep:", group_name)
      )
      source_method <- unique(c(source_method, "taxongroepregel"))
    }
    if (identical(as.character(item$weergavenaam), "Kaal land")) {
      evidence <- add_gradient_evidence(evidence, "open_pionier", "operationele_eenheid:Kaal land")
      source_method <- unique(c(source_method, "operationele_eenheid"))
    }
    if (identical(as.character(item$weergavenaam), "Moslaag")) {
      evidence <- add_gradient_evidence(
        evidence, "duingrasland_mos_korstmos", "operationele_eenheid:Moslaag"
      )
      source_method <- unique(c(source_method, "operationele_eenheid"))
    }
    if (identical(as.character(item$weergavenaam), "Draadwier (Flap)")) {
      evidence <- add_gradient_evidence(
        evidence, "nat_riet", "operationele_eenheid:Draadwier (Flap)"
      )
      source_method <- unique(c(source_method, "operationele_eenheid"))
    }
    if (identical(as.character(item$weergavenaam), "Alg droog")) {
      evidence <- add_gradient_evidence(
        evidence, "duingrasland_mos_korstmos", "operationele_eenheid:Alg droog"
      )
      source_method <- unique(c(source_method, "operationele_eenheid"))
    }
    evidence <- evidence[lengths(evidence) > 0L]
    if (!length(evidence)) next
    gradients <- names(evidence)
    rows[[index]] <- data.frame(
      taxon_id = rep(item$taxon_id, length(gradients)),
      taxon_name = rep(item$weergavenaam, length(gradients)),
      taxon_group = rep(item$groep_naam, length(gradients)),
      gradient = gradients,
      weight = rep(1 / length(gradients), length(gradients)),
      match_method = rep(paste(source_method, collapse = "+"), length(gradients)),
      synbiosys_name = rep(source_name, length(gradients)),
      evidence = vapply(evidence, paste, character(1), collapse = ";"),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows[lengths(rows) > 0L])
  if (is.null(out)) {
    return(data.frame(
      taxon_id = integer(), taxon_name = character(), taxon_group = character(),
      gradient = character(), weight = numeric(), match_method = character(),
      synbiosys_name = character(), evidence = character()
    ))
  }
  out$gradient <- factor(out$gradient, levels = pq_gradient_levels())
  out <- out[order(out$taxon_id, out$gradient), , drop = FALSE]
  out$gradient <- as.character(out$gradient)
  rownames(out) <- NULL
  out
}

build_pq_gradient_scores <- function(
  opname, waarneming, opname_plot, mapping, min_mapped_share = .8
) {
  require_pq_gradient_fields(opname, c("opname_id", "jaar"), "PQ-opnamen")
  require_pq_gradient_fields(
    waarneming,
    c("opname_id", "taxon_id", "abundantie_percentage"),
    "PQ-waarnemingen"
  )
  require_pq_gradient_fields(opname_plot, c("opname_id", "plot_id"), "PQ-plotkoppeling")
  require_pq_gradient_fields(mapping, c("taxon_id", "gradient", "weight"), "taxonmapping")
  if (anyDuplicated(opname$opname_id) || anyDuplicated(opname_plot$opname_id)) {
    stop("Iedere PQ-opname moet exact één opname- en plotregel hebben.", call. = FALSE)
  }
  if (anyDuplicated(paste(mapping$taxon_id, mapping$gradient, sep = ":"))) {
    stop("Taxonmapping bevat dubbele taxon-gradiëntregels.", call. = FALSE)
  }
  if (!is.numeric(min_mapped_share) || length(min_mapped_share) != 1L ||
      min_mapped_share < 0 || min_mapped_share > 1) {
    stop("min_mapped_share moet tussen 0 en 1 liggen.", call. = FALSE)
  }
  metadata <- merge(opname[c("opname_id", "jaar")], opname_plot, by = "opname_id")
  n_opnamen <- aggregate(
    opname_id ~ plot_id + jaar, metadata, function(value) length(unique(value))
  )
  names(n_opnamen)[names(n_opnamen) == "opname_id"] <- "n_opnamen"
  values <- merge(waarneming, metadata, by = "opname_id")
  values$abundantie_percentage <- as.numeric(values$abundantie_percentage)
  if (any(!is.finite(values$abundantie_percentage) | values$abundantie_percentage < 0)) {
    stop("PQ-bedekking moet eindig en niet-negatief zijn.", call. = FALSE)
  }
  taxon_cover <- aggregate(
    abundantie_percentage ~ plot_id + jaar + taxon_id, values, sum
  )
  taxon_cover <- merge(taxon_cover, n_opnamen, by = c("plot_id", "jaar"))
  taxon_cover$mean_cover <- taxon_cover$abundantie_percentage / taxon_cover$n_opnamen
  total <- aggregate(mean_cover ~ plot_id + jaar, taxon_cover, sum)
  names(total)[names(total) == "mean_cover"] <- "total_cover"
  n_taxa <- aggregate(taxon_id ~ plot_id + jaar, taxon_cover, function(value) length(unique(value)))
  names(n_taxa)[names(n_taxa) == "taxon_id"] <- "n_taxa_total"
  mapped <- merge(taxon_cover, mapping[c("taxon_id", "gradient", "weight")], by = "taxon_id")
  mapped$contribution <- mapped$mean_cover * mapped$weight
  gradient_cover <- aggregate(
    contribution ~ plot_id + jaar + gradient, mapped, sum
  )
  mapped_taxa <- aggregate(
    taxon_id ~ plot_id + jaar, mapped, function(value) length(unique(value))
  )
  names(mapped_taxa)[names(mapped_taxa) == "taxon_id"] <- "n_taxa_mapped"
  base <- Reduce(
    function(x, y) merge(x, y, by = c("plot_id", "jaar"), all = TRUE),
    list(n_opnamen, total, n_taxa, mapped_taxa)
  )
  base$n_taxa_mapped[is.na(base$n_taxa_mapped)] <- 0L
  for (gradient in pq_gradient_levels()) {
    subset <- gradient_cover[gradient_cover$gradient == gradient, c("plot_id", "jaar", "contribution")]
    names(subset)[3L] <- paste0(gradient, "_cover")
    base <- merge(base, subset, by = c("plot_id", "jaar"), all = TRUE)
    cover_field <- paste0(gradient, "_cover")
    base[[cover_field]][is.na(base[[cover_field]])] <- 0
  }
  cover_fields <- paste0(pq_gradient_levels(), "_cover")
  base$mapped_cover <- rowSums(base[cover_fields])
  base$mapped_cover_share <- ifelse(
    base$total_cover > 0, base$mapped_cover / base$total_cover, NA_real_
  )
  base$score_valid <- is.finite(base$mapped_cover_share) &
    base$mapped_cover_share >= min_mapped_share & base$mapped_cover > 0
  for (gradient in pq_gradient_levels()) {
    base[[paste0(gradient, "_share")]] <- ifelse(
      base$mapped_cover > 0,
      base[[paste0(gradient, "_cover")]] / base$mapped_cover,
      NA_real_
    )
  }
  base$min_mapped_share <- min_mapped_share
  base <- base[order(base$plot_id, base$jaar), , drop = FALSE]
  rownames(base) <- NULL
  base
}

build_pq_gradient_intervals <- function(scores) {
  share_fields <- paste0(pq_gradient_levels(), "_share")
  require_pq_gradient_fields(
    scores, c("plot_id", "jaar", "score_valid", share_fields), "PQ-gradiëntscores"
  )
  scores <- scores[order(scores$plot_id, scores$jaar), , drop = FALSE]
  rows <- list()
  cursor <- 1L
  for (plot in unique(scores$plot_id)) {
    block <- scores[scores$plot_id == plot, , drop = FALSE]
    if (nrow(block) < 2L) next
    for (index in seq_len(nrow(block) - 1L)) {
      years <- block$jaar[index + 1L] - block$jaar[index]
      if (!is.finite(years) || years <= 0L) {
        stop("PQ-jaren moeten per plot uniek en oplopend zijn.", call. = FALSE)
      }
      if (!isTRUE(block$score_valid[index]) ||
          !isTRUE(block$score_valid[index + 1L])) next
      row <- data.frame(
        plot_id = plot,
        start_year = block$jaar[index],
        end_year = block$jaar[index + 1L],
        interval_years = as.integer(years),
        stringsAsFactors = FALSE
      )
      for (gradient in pq_gradient_levels()) {
        field <- paste0(gradient, "_share")
        row[[paste0(gradient, "_start")]] <- block[[field]][index]
        row[[paste0(gradient, "_end")]] <- block[[field]][index + 1L]
        row[[paste0(gradient, "_change_per_year")]] <-
          (block[[field]][index + 1L] - block[[field]][index]) / years
      }
      rows[[cursor]] <- row
      cursor <- cursor + 1L
    }
  }
  if (!length(rows)) {
    fields <- c("plot_id", "start_year", "end_year", "interval_years")
    out <- as.data.frame(setNames(replicate(length(fields), integer(), simplify = FALSE), fields))
    for (gradient in pq_gradient_levels()) {
      out[[paste0(gradient, "_start")]] <- numeric()
      out[[paste0(gradient, "_end")]] <- numeric()
      out[[paste0(gradient, "_change_per_year")]] <- numeric()
    }
    return(out)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

summarise_pq_gradient_intervals <- function(intervals) {
  require_pq_gradient_fields(
    intervals, c("plot_id", "interval_years"), "PQ-gradiëntintervallen"
  )
  if (!nrow(intervals)) {
    return(data.frame(
      interval_years = integer(), n_intervals = integer(), n_plots = integer()
    ))
  }
  count <- aggregate(plot_id ~ interval_years, intervals, length)
  names(count)[2L] <- "n_intervals"
  plots <- aggregate(plot_id ~ interval_years, intervals, function(value) length(unique(value)))
  names(plots)[2L] <- "n_plots"
  out <- merge(count, plots, by = "interval_years")
  out[order(out$interval_years), , drop = FALSE]
}

summarise_pq_gradient_changes <- function(intervals, tolerance = 1e-12) {
  rows <- lapply(pq_gradient_levels(), function(gradient) {
    field <- paste0(gradient, "_change_per_year")
    require_pq_gradient_fields(
      intervals, c("plot_id", field), "PQ-gradiëntintervallen"
    )
    value <- intervals[[field]]
    finite <- is.finite(value)
    nonzero <- finite & abs(value) > tolerance
    data.frame(
      gradient = gradient,
      n_intervals = sum(finite),
      n_nonzero = sum(nonzero),
      n_plots_nonzero = length(unique(intervals$plot_id[nonzero])),
      median_change_per_year = if (any(finite)) median(value[finite]) else NA_real_,
      q25_change_per_year = if (any(finite)) unname(quantile(value[finite], .25)) else NA_real_,
      q75_change_per_year = if (any(finite)) unname(quantile(value[finite], .75)) else NA_real_,
      min_change_per_year = if (any(finite)) min(value[finite]) else NA_real_,
      max_change_per_year = if (any(finite)) max(value[finite]) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

summarise_pq_interval_response_coverage <- function(
  intervals, bird_plotyears, lags = 0:15
) {
  require_pq_gradient_fields(
    intervals, c("plot_id", "end_year"), "PQ-gradiëntintervallen"
  )
  require_pq_gradient_fields(
    bird_plotyears, c("plot_id", "jaar"), "vogelplotjaren"
  )
  if (anyDuplicated(paste(bird_plotyears$plot_id, bird_plotyears$jaar, sep = ":"))) {
    stop("Vogelplotjaren moeten uniek zijn.", call. = FALSE)
  }
  rows <- lapply(as.integer(lags), function(lag) {
    candidate <- intervals[c("plot_id", "end_year")]
    candidate$jaar <- candidate$end_year + lag
    linked <- merge(candidate, bird_plotyears, by = c("plot_id", "jaar"))
    data.frame(
      lag_years = lag,
      n_intervals = nrow(linked),
      n_plots = length(unique(linked$plot_id)),
      first_response_year = if (nrow(linked)) min(linked$jaar) else NA_integer_,
      last_response_year = if (nrow(linked)) max(linked$jaar) else NA_integer_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

pq_gradient_taxon_status <- function(taxa, mapping, observations) {
  require_pq_gradient_fields(
    taxa,
    c("taxon_id", "weergavenaam", "wetenschappelijke_naam", "groep_naam"),
    "PQ-taxa"
  )
  require_pq_gradient_fields(
    observations, c("taxon_id", "abundantie_percentage"), "PQ-waarnemingen"
  )
  observed <- aggregate(
    abundantie_percentage ~ taxon_id, observations,
    function(value) sum(as.numeric(value), na.rm = TRUE)
  )
  names(observed)[2L] <- "summed_source_cover"
  mapped <- if (nrow(mapping)) {
    aggregate(
      gradient ~ taxon_id, mapping,
      function(value) paste(value, collapse = ";")
    )
  } else {
    data.frame(taxon_id = integer(), gradient = character())
  }
  names(mapped)[2L] <- "gradients"
  out <- merge(taxa, observed, by = "taxon_id", all.x = TRUE)
  out <- merge(out, mapped, by = "taxon_id", all.x = TRUE)
  out$mapped <- !is.na(out$gradients) & nzchar(out$gradients)
  out$n_gradients <- ifelse(out$mapped, lengths(strsplit(out$gradients, ";", fixed = TRUE)), 0L)
  out <- out[order(!out$mapped, -out$summed_source_cover, out$taxon_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

if (sys.nframe() == 0L) {
  cli <- commandArgs(trailingOnly = TRUE)
  if (length(cli) != 9L) {
    stop(paste(
      "Gebruik: Rscript pq_ecologische_gradienten.R INPUT_DIR ECODBASE_XLSX",
      "RUN_DIR RUN_ID GIT_COMMIT DATABASE MYSQL_VERSION RESULT_DIR SOURCE_SHA256"
    ), call. = FALSE)
  }
  input_dir <- cli[[1L]]
  ecodbase_path <- cli[[2L]]
  run_dir <- cli[[3L]]
  compact_results_dir <- cli[[8L]]
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
  repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
  source(file.path(
    repo, "analyses", "broedvogel_vegetatie_power", "scripts",
    "run_broedvogel_vegetatiesamenstelling.R"
  ))

  table_names <- c(
    "plots", "plot_analyse_scope", "soorten", "plot_jaar_oppervlak",
    "plot_jaar_teller", "territoria", "bronnen", "sovon_bmp_plotjaar",
    "pq_vegetatie_opname", "pq_vegetatie_opname_plot",
    "pq_vegetatie_waarneming", "pq_taxa", "pq_taxon_aliases"
  )
  data <- setNames(lapply(table_names, function(name) {
    read_tsv_required(input_dir, name)
  }), table_names)
  ecodbase <- readxl::read_excel(ecodbase_path)

  mapping <- build_pq_taxon_gradient_mapping(
    data$pq_taxa, data$pq_taxon_aliases, ecodbase
  )
  scores <- build_pq_gradient_scores(
    data$pq_vegetatie_opname,
    data$pq_vegetatie_waarneming,
    data$pq_vegetatie_opname_plot,
    mapping,
    min_mapped_share = .8
  )
  intervals <- build_pq_gradient_intervals(scores)
  interval_summary <- summarise_pq_gradient_intervals(intervals)
  change_summary <- summarise_pq_gradient_changes(intervals)
  matrix_result <- build_broedvogel_analysis_matrix(data, 1958L, 2025L)
  bird_plotyears <- unique(matrix_result$basis[c("plot_id", "jaar")])
  response_coverage <- summarise_pq_interval_response_coverage(
    intervals, bird_plotyears, 0:15
  )
  taxon_status <- pq_gradient_taxon_status(
    data$pq_taxa, mapping, data$pq_vegetatie_waarneming
  )

  outputs <- list(
    pq_gradient_taxonmapping = mapping,
    pq_gradient_taxonstatus = taxon_status,
    pq_gradient_plotjaar = scores,
    pq_gradient_intervallen = intervals,
    pq_gradient_intervalverdeling = interval_summary,
    pq_gradient_veranderingsdekking = change_summary,
    pq_gradient_responsdekking = response_coverage
  )
  output_metadata <- list()
  for (name in names(outputs)) {
    path <- file.path(run_dir, paste0(name, ".csv"))
    write_csv_atomic(outputs[[name]], path)
    compact_path <- file.path(compact_results_dir, paste0(name, "_laatste.csv"))
    if (!file.copy(path, compact_path, overwrite = TRUE)) {
      stop("Kon compact resultaat niet schrijven: ", compact_path, call. = FALSE)
    }
    output_metadata[[name]] <- list(
      file = basename(path), rows = nrow(outputs[[name]]), sha256 = sha256_file(path)
    )
  }
  source_files <- collect_tsv_metadata(input_dir)
  metadata <- list(
    run_id = cli[[4L]],
    git_commit = cli[[5L]],
    database_name = cli[[6L]],
    mysql_version = cli[[7L]],
    executed_at_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    scope = "v_meijendel_analyseplot_actueel; M66 en M91 uitgesloten",
    score_validity = "minimaal 80% van de totale bronbedekking aan een gradiënt gekoppeld",
    gradient_definitions = list(
      open_pionier = "Runhaar P; sociologische P; operationele eenheid Kaal land",
      duingrasland_mos_korstmos = paste(
        "Runhaar G; droge/natte duingraslandgroepen;",
        "bestaande taxongroepen Mossen en levermossen en Korstmossen; Moslaag"
      ),
      nat_riet = paste(
        "Runhaar V/W, hydrofyten en helofyten, natte sociologische groepen;",
        "bestaande taxongroep Kranswieren, wieren en algen"
      ),
      struweel_ruigte = "Runhaar R, zoom/ruigte en groeivorm struik",
      bomen_bos = "Runhaar H, bos/struweelgroep en groeivorm boom"
    ),
    synbiosys_source = list(
      url = "https://www.synbiosys.alterra.nl/synbiosysnl/downloads/ecodbase.zip",
      zip_sha256 = cli[[9L]],
      workbook = "EcoDbase.xlsx",
      source_fields = c(
        "WETNAAM", "TYPE", "ECOTP_01-10", "SOC_GRP_ND", "SOC_GRP_DG",
        "LV_VORM1-3", "GR_VORM1-3"
      )
    ),
    source_files = source_files,
    pq = list(
      observations = nrow(data$pq_vegetatie_opname),
      taxon_rows = nrow(data$pq_vegetatie_waarneming),
      taxa = nrow(data$pq_taxa),
      mapped_taxa = sum(taxon_status$mapped),
      linked_plots = length(unique(data$pq_vegetatie_opname_plot$plot_id)),
      plotyears = nrow(scores),
      valid_plotyears = sum(scores$score_valid),
      first_year = min(scores$jaar),
      last_year = max(scores$jaar),
      intervals = nrow(intervals)
    ),
    outputs = output_metadata
  )
  manifest_path <- file.path(run_dir, "pq_ecologische_gradienten_manifest.json")
  jsonlite::write_json(
    metadata, manifest_path, auto_unbox = TRUE, pretty = TRUE,
    null = "null", digits = NA
  )
  if (!file.copy(
    manifest_path,
    file.path(compact_results_dir, "pq_ecologische_gradienten_laatste_manifest.json"),
    overwrite = TRUE
  )) stop("Kon compact manifest niet schrijven.", call. = FALSE)
  cat(manifest_path, "\n", sep = "")
}
