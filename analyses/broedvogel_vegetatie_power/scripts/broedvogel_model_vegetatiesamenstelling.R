composition_repo <- function() {
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

.composition_repo <- composition_repo()
source(file.path(
  .composition_repo,
  "analyses", "broedvogel_vegetatie_power", "scripts",
  "broedvogel_model_vegetatie_data.R"
))

ipi_group_contract <- function() {
  list(
    open = c(211L, 214L),
    nat_water = c(213L, 352L),
    struweel = c(150L, 151L, 155L),
    bos = c(111L, 121L, 124L, 130L, 131L, 132L, 140L, 143L, 192L, 193L)
  )
}

ipi_group_for_code <- function(code) {
  code <- as.integer(code)
  contract <- ipi_group_contract()
  lookup <- unlist(lapply(names(contract), function(group) {
    stats::setNames(rep(group, length(contract[[group]])), contract[[group]])
  }))
  result <- unname(lookup[as.character(code)])
  if (anyNA(result)) {
    stop(
      "PQ-opnamen bevatten een onbekende IPI-code: ",
      paste(sort(unique(code[is.na(result)])), collapse = ", "),
      call. = FALSE
    )
  }
  result
}

validate_pq_composition_inputs <- function(opnamen, waarnemingen, opname_plot) {
  require_prepare_fields(
    opnamen, c("opname_id", "pq_nummer", "jaar", "ipi_code", "ipi_naam"),
    "pq_vegetatie_opname"
  )
  require_prepare_fields(
    waarnemingen,
    c(
      "opname_id", "taxon_id", "taxon_naam", "taxonrang", "taxonvorm",
      "abundantie_percentage"
    ),
    "pq_vegetatie_waarneming"
  )
  require_prepare_fields(opname_plot, c("opname_id", "plot_id"), "pq_vegetatie_opname_plot")
  if (anyDuplicated(opnamen$opname_id)) {
    stop("PQ-opnamen bevatten een dubbele opname-ID.", call. = FALSE)
  }
  if (anyDuplicated(opname_plot$opname_id)) {
    stop("Een PQ-opname is aan meer dan een vogelplot gekoppeld.", call. = FALSE)
  }
  key <- paste(waarnemingen$opname_id, waarnemingen$taxon_id, sep = ":")
  if (anyDuplicated(key)) {
    stop("PQ-waarnemingen bevatten een dubbele opname-taxonregel.", call. = FALSE)
  }
  abundance <- as.numeric(waarnemingen$abundantie_percentage)
  if (any(!is.finite(abundance)) || any(abundance < 0)) {
    stop("PQ-waarnemingen bevatten een ongeldige bedekking.", call. = FALSE)
  }
  invisible(TRUE)
}

orient_pca_deterministically <- function(pca) {
  for (axis in seq_len(ncol(pca$rotation))) {
    pivot <- which.max(abs(pca$rotation[, axis]))
    if (pca$rotation[pivot, axis] < 0) {
      pca$rotation[, axis] <- -pca$rotation[, axis]
      pca$x[, axis] <- -pca$x[, axis]
    }
  }
  pca
}

build_pq_composition_features <- function(
    opnamen, waarnemingen, opname_plot, n_axes = 3L) {
  validate_pq_composition_inputs(opnamen, waarnemingen, opname_plot)
  n_axes <- as.integer(n_axes)
  if (length(n_axes) != 1L || is.na(n_axes) || n_axes < 1L) {
    stop("Het aantal compositieassen moet een positief geheel getal zijn.", call. = FALSE)
  }

  mapped <- merge(
    opname_plot[c("opname_id", "plot_id")],
    opnamen[c("opname_id", "pq_nummer", "jaar")],
    by = "opname_id", all.x = TRUE, sort = FALSE
  )
  if (anyNA(mapped$jaar)) stop("Een plotgekoppelde PQ-opname ontbreekt in de opnametabel.", call. = FALSE)
  mapped$plot_id <- as.integer(mapped$plot_id)
  mapped$jaar <- as.integer(mapped$jaar)
  mapped$row_key <- paste(mapped$plot_id, mapped$jaar, sep = ":")
  n_opnamen <- aggregate(mapped$opname_id, list(row_key = mapped$row_key), length)
  names(n_opnamen)[2L] <- "n_opnamen"

  observations <- merge(
    waarnemingen,
    mapped[c("opname_id", "plot_id", "jaar", "row_key")],
    by = "opname_id", all = FALSE, sort = FALSE
  )
  if (!nrow(observations)) stop("Geen plotgekoppelde PQ-taxonregels beschikbaar.", call. = FALSE)
  observations$abundantie_percentage <- as.numeric(observations$abundantie_percentage)
  observations$taxon_key <- as.character(observations$taxon_id)
  summed <- aggregate(
    observations$abundantie_percentage,
    list(row_key = observations$row_key, taxon_key = observations$taxon_key),
    sum
  )
  names(summed)[3L] <- "bedekking_som"
  summed <- merge(summed, n_opnamen, by = "row_key", all.x = TRUE)
  summed$bedekking_gem <- summed$bedekking_som / summed$n_opnamen

  matrix_cover <- stats::xtabs(bedekking_gem ~ row_key + taxon_key, data = summed)
  matrix_cover <- as.matrix(matrix_cover)
  row_totals <- rowSums(matrix_cover)
  if (any(!is.finite(row_totals)) || any(row_totals <= 0)) {
    stop("Minstens een PQ-plotjaar heeft geen positieve totale bedekking.", call. = FALSE)
  }
  hellinger <- sqrt(matrix_cover / row_totals)
  max_axes <- min(nrow(hellinger) - 1L, ncol(hellinger))
  if (n_axes > max_axes) stop("Te veel compositieassen voor de beschikbare matrix.", call. = FALSE)
  pca <- orient_pca_deterministically(stats::prcomp(hellinger, center = TRUE, scale. = FALSE))

  keys <- do.call(rbind, strsplit(rownames(pca$x), ":", fixed = TRUE))
  features <- data.frame(
    plot_id = as.integer(keys[, 1L]),
    jaar = as.integer(keys[, 2L]),
    stringsAsFactors = FALSE
  )
  for (axis in seq_len(n_axes)) {
    features[[paste0("compositie_pc", axis)]] <- unname(pca$x[, axis])
  }
  features$n_opnamen <- n_opnamen$n_opnamen[
    match(rownames(pca$x), n_opnamen$row_key)
  ]

  explained <- pca$sdev^2 / sum(pca$sdev^2)
  variance <- data.frame(
    as = paste0("PC", seq_len(n_axes)),
    verklaarde_variantie = explained[seq_len(n_axes)],
    cumulatieve_variantie = cumsum(explained)[seq_len(n_axes)],
    stringsAsFactors = FALSE
  )
  taxon_lookup <- unique(observations[c("taxon_id", "taxon_naam", "taxonrang", "taxonvorm")])
  loadings <- do.call(rbind, lapply(seq_len(n_axes), function(axis) {
    out <- data.frame(
      taxon_id = as.integer(rownames(pca$rotation)),
      as = paste0("PC", axis),
      lading = unname(pca$rotation[, axis]),
      stringsAsFactors = FALSE
    )
    merge(out, taxon_lookup, by = "taxon_id", all.x = TRUE, sort = FALSE)
  }))
  list(
    features = features[order(features$jaar, features$plot_id), , drop = FALSE],
    variance = variance,
    loadings = loadings[order(loadings$as, -abs(loadings$lading)), , drop = FALSE],
    pca = pca,
    quality = list(
      n_opnamen = nrow(mapped),
      n_plotyears = nrow(matrix_cover),
      n_plots = length(unique(mapped$plot_id)),
      n_taxa = ncol(matrix_cover),
      first_year = min(mapped$jaar),
      last_year = max(mapped$jaar)
    )
  )
}

build_ipi_plotyear_features <- function(opnamen, opname_plot) {
  require_prepare_fields(opnamen, c("opname_id", "jaar", "ipi_code"), "pq_vegetatie_opname")
  require_prepare_fields(opname_plot, c("opname_id", "plot_id"), "pq_vegetatie_opname_plot")
  mapped <- merge(
    opname_plot[c("opname_id", "plot_id")],
    opnamen[c("opname_id", "jaar", "ipi_code")],
    by = "opname_id", all.x = TRUE, sort = FALSE
  )
  if (anyNA(mapped$jaar) || anyNA(mapped$ipi_code)) {
    stop("Een plotgekoppelde PQ-opname mist jaar of IPI-code.", call. = FALSE)
  }
  mapped$ipi_groep <- ipi_group_for_code(mapped$ipi_code)
  counts <- stats::xtabs(~ plot_id + jaar + ipi_groep, data = mapped)
  rows <- as.data.frame.table(counts, responseName = "n", stringsAsFactors = FALSE)
  rows <- rows[rows$n > 0, , drop = FALSE]
  totals <- aggregate(rows$n, rows[c("plot_id", "jaar")], sum)
  names(totals)[3L] <- "n_ipi_opnamen"
  out <- unique(rows[c("plot_id", "jaar")])
  out$plot_id <- as.integer(as.character(out$plot_id))
  out$jaar <- as.integer(as.character(out$jaar))
  for (group in names(ipi_group_contract())) {
    current <- rows[rows$ipi_groep == group, c("plot_id", "jaar", "n")]
    current$plot_id <- as.integer(as.character(current$plot_id))
    current$jaar <- as.integer(as.character(current$jaar))
    names(current)[3L] <- paste0("ipi_", group, "_n")
    out <- merge(out, current, by = c("plot_id", "jaar"), all.x = TRUE)
    count_field <- paste0("ipi_", group, "_n")
    out[[count_field]][is.na(out[[count_field]])] <- 0
  }
  out <- merge(out, totals, by = c("plot_id", "jaar"), all.x = TRUE)
  for (group in names(ipi_group_contract())) {
    out[[paste0("ipi_", group)]] <- out[[paste0("ipi_", group, "_n")]] / out$n_ipi_opnamen
  }
  out[order(out$jaar, out$plot_id), c(
    "plot_id", "jaar", "n_ipi_opnamen",
    paste0("ipi_", names(ipi_group_contract()))
  )]
}

split_multivariate_plotyear_features <- function(features, fields) {
  require_prepare_fields(features, c("plot_id", "jaar", fields), "plotjaar-kenmerken")
  key <- paste(features$plot_id, features$jaar, sep = ":")
  if (anyDuplicated(key)) stop("Kenmerken bevatten dubbele plot-jaarrijen.", call. = FALSE)
  out <- features
  for (field in fields) {
    values <- as.numeric(out[[field]])
    if (any(!is.finite(values))) stop("Kenmerk bevat ontbrekende of niet-eindige waarden: ", field, call. = FALSE)
    plot_mean <- ave(values, out$plot_id, FUN = mean)
    out[[paste0(field, "_between")]] <- plot_mean
    out[[paste0(field, "_within")]] <- values - plot_mean
    out[[paste0(field, "_between_z")]] <- pq_standardize(plot_mean)
    out[[paste0(field, "_within_z")]] <- pq_standardize(values - plot_mean)
  }
  out
}

landcover_class_contract <- function() {
  c(
    struik = "shrub", bos = "forest", boomgroep = "grove", laag = "low",
    riet = "reed", zand = "sand", water = "water"
  )
}

normalize_supplement_plot_code <- function(value) {
  value <- trimws(as.character(value))
  # OR2 toont deze kavelcode als 10_12_76, maar bewaart haar als Excel-datum
  # serienummer 28045. De zichtbare broncode en de lokale SOVON-code zijn
  # leidend; een generieke datumweergave zou dag en maand omdraaien.
  value[value == "28045"] <- "10_12_76"
  numeric_value <- suppressWarnings(as.numeric(value))
  excel_date <- !is.na(numeric_value) & numeric_value > 10000
  if (any(excel_date)) {
    date <- as.Date(numeric_value[excel_date], origin = "1899-12-30")
    value[excel_date] <- format(date, "%d_%m_%y")
    value[excel_date] <- sub("^0", "", value[excel_date])
  }
  value
}

parse_landcover_or2 <- function(raw) {
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  if (nrow(raw) < 7L || ncol(raw) < 23L) {
    stop("Online Resource 2 heeft niet de verwachte tabelvorm.", call. = FALSE)
  }
  columns <- list(
    struik = c(3L, 4L),
    bos = c(6L, 7L),
    boomgroep = c(9L, 10L),
    laag = c(12L, 14L),
    riet = c(16L, 17L),
    zand = c(19L, 20L),
    water = c(22L, 23L)
  )
  plot_code <- normalize_supplement_plot_code(raw[[1L]])
  keep <- seq_len(nrow(raw)) >= 7L & !is.na(plot_code) & nzchar(plot_code) & plot_code != "Total"
  out <- data.frame(
    supplement_plot = plot_code[keep],
    plot_area_ha = as.numeric(raw[[2L]][keep]),
    stringsAsFactors = FALSE
  )
  for (class in names(columns)) {
    out[[paste0(class, "_2001_ha")]] <- as.numeric(raw[[columns[[class]][1L]]][keep])
    out[[paste0(class, "_2022_ha")]] <- as.numeric(raw[[columns[[class]][2L]]][keep])
  }
  numeric_fields <- setdiff(names(out), "supplement_plot")
  if (any(!is.finite(as.matrix(out[numeric_fields])))) {
    stop("Online Resource 2 bevat ontbrekende of niet-numerieke landbedekking.", call. = FALSE)
  }
  out
}

normalize_landcover_supplement <- function(source, plots) {
  classes <- names(landcover_class_contract())
  required <- c(
    "supplement_plot", "plot_area_ha",
    unlist(lapply(classes, function(class) paste0(class, c("_2001_ha", "_2022_ha"))))
  )
  require_prepare_fields(source, required, "Schmidt-Tauscher Online Resource 2")
  require_prepare_fields(plots, c("plot_id", "kavel_nummer"), "plots")
  if (anyDuplicated(source$supplement_plot)) stop("Supplement bevat dubbele plotcodes.", call. = FALSE)
  normalized <- gsub("_", "-", as.character(source$supplement_plot), fixed = TRUE)
  source$kavel_nummer <- paste0("M", normalized)
  joined <- merge(source, plots[c("plot_id", "kavel_nummer")], by = "kavel_nummer", all.x = TRUE)
  if (anyNA(joined$plot_id)) {
    stop(
      "Niet alle supplementplots koppelen aan plots: ",
      paste(joined$supplement_plot[is.na(joined$plot_id)], collapse = ", "),
      call. = FALSE
    )
  }
  rows <- lapply(c(2001L, 2022L), function(year) {
    out <- joined[c("plot_id", "kavel_nummer", "supplement_plot", "plot_area_ha")]
    out$jaar <- year
    for (class in classes) {
      hectares <- as.numeric(joined[[paste0(class, "_", year, "_ha")]])
      out[[paste0(class, "_ha")]] <- hectares
    }
    class_hectares <- out[paste0(classes, "_ha")]
    out$geclassificeerd_ha <- rowSums(class_hectares)
    out$geclassificeerd_aandeel_plot <- out$geclassificeerd_ha / as.numeric(joined$plot_area_ha)
    for (class in classes) {
      out[[paste0(class, "_aandeel")]] <- out[[paste0(class, "_ha")]] / out$geclassificeerd_ha
    }
    out
  })
  out <- do.call(rbind, rows)
  shares <- out[paste0(classes, "_aandeel")]
  if (any(abs(rowSums(shares) - 1) > 1e-10)) {
    stop("Genormaliseerde landbedekkingsaandelen tellen niet op tot een.", call. = FALSE)
  }
  if (any(out$geclassificeerd_aandeel_plot < 0.95 | out$geclassificeerd_aandeel_plot > 1.05)) {
    stop("Het geclassificeerde oppervlak wijkt meer dan vijf procent af van het plotoppervlak.", call. = FALSE)
  }
  out[order(out$jaar, out$plot_id), , drop = FALSE]
}
