broedvogel_model_repo <- function() {
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

.broedvogel_repo <- broedvogel_model_repo()
source(file.path(.broedvogel_repo, "R", "meijendel_cache_contract.R"))

require_fields <- function(data, fields, name) {
  if (!is.data.frame(data)) stop(name, " ontbreekt of is geen tabel.", call. = FALSE)
  missing <- setdiff(fields, names(data))
  if (length(missing)) {
    stop(name, " mist verplichte velden: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  }
}

build_broedvogel_analysis_matrix <- function(
    data,
    year_min = 1958L,
    year_max = 2025L,
    include_out_of_scope_kavels = character()) {
  if (!is.list(data)) stop("Analyse-invoer moet een lijst met tabellen zijn.", call. = FALSE)
  year_min <- as.integer(year_min)
  year_max <- as.integer(year_max)
  if (length(year_min) != 1L || length(year_max) != 1L ||
      is.na(year_min) || is.na(year_max) || year_min > year_max) {
    stop("De analyseperiode is ongeldig.", call. = FALSE)
  }

  require_fields(data$plots, c("plot_id", "plot_naam", "kavel_nummer"), "plots")
  require_fields(data$plot_analyse_scope, c("scope_code", "plot_id", "in_scope", "reden"), "plot_analyse_scope")
  require_fields(data$soorten, c("id", "euring_code", "soort_naam"), "soorten")
  require_fields(data$plot_jaar_oppervlak, c("plot_id", "jaar", "oppervlakte_km2"), "plot_jaar_oppervlak")
  require_fields(data$plot_jaar_teller, c("plot_id", "jaar", "teller_id"), "plot_jaar_teller")
  require_fields(data$territoria, c("plot_id", "soort_id", "jaar", "territoria", "bron_id"), "territoria")
  require_fields(data$bronnen, c("id", "code"), "bronnen")
  require_fields(data$sovon_bmp_plotjaar, c("plot_id", "jaar", "beoordelingsstatus"), "sovon_bmp_plotjaar")

  data <- apply_meijendel_plot_scope(data, include_out_of_scope_kavels)
  territory_reference <- data$territoria
  territory_reference$plot_id <- as.integer(territory_reference$plot_id)
  territory_reference$soort_id <- as.integer(territory_reference$soort_id)
  territory_reference$jaar <- as.integer(territory_reference$jaar)
  territory_reference$territoria <- as.numeric(territory_reference$territoria)
  territory_reference$bron_id <- as.integer(territory_reference$bron_id)

  territories <- territory_reference[
    territory_reference$jaar >= year_min & territory_reference$jaar <= year_max,
    ,
    drop = FALSE
  ]
  territory_key <- paste(territories$soort_id, territories$plot_id, territories$jaar, sep = ":")
  if (anyDuplicated(territory_key)) {
    stop(
      "territoria bevat meer dan één bronregel voor dezelfde soort-plot-jaarcel",
      call. = FALSE
    )
  }
  if (!nrow(territories)) stop("Geen territorium-plotjaren binnen de analyseperiode.", call. = FALSE)

  # Alleen plotjaren met een territoriumbronregel vormen de meetbasis. Een losse
  # tellerregistratie mag dus geen nieuw geanalyseerd plotjaar creëren.
  basis_key <- unique(territories[c("plot_id", "jaar")])
  basis_key <- basis_key[order(basis_key$jaar, basis_key$plot_id), , drop = FALSE]

  area <- data$plot_jaar_oppervlak[c("plot_id", "jaar", "oppervlakte_km2")]
  area$plot_id <- as.integer(area$plot_id)
  area$jaar <- as.integer(area$jaar)
  area$oppervlakte_km2 <- as.numeric(area$oppervlakte_km2)
  area_key <- paste(area$plot_id, area$jaar, sep = ":")
  if (anyDuplicated(area_key)) stop("plot_jaar_oppervlak bevat dubbele plotjaren.", call. = FALSE)

  plot_lookup <- unique(data$plots[c("plot_id", "plot_naam", "kavel_nummer")])
  plot_lookup$plot_id <- as.integer(plot_lookup$plot_id)
  if (anyDuplicated(plot_lookup$plot_id)) stop("plots bevat dubbele plot-id's.", call. = FALSE)

  tellers <- unique(data$plot_jaar_teller[c("plot_id", "jaar", "teller_id")])
  tellers$plot_id <- as.integer(tellers$plot_id)
  tellers$jaar <- as.integer(tellers$jaar)
  tellers$teller_id <- as.integer(tellers$teller_id)
  teller_split <- split(tellers$teller_id, paste(tellers$plot_id, tellers$jaar, sep = ":"))
  teller_summary <- data.frame(
    teller_key = names(teller_split),
    aantal_tellers = as.integer(vapply(teller_split, function(x) length(unique(x)), integer(1))),
    tellerteam_sleutel = vapply(
      teller_split,
      function(x) paste(sort(unique(x)), collapse = "+"),
      character(1)
    ),
    stringsAsFactors = FALSE
  )
  teller_summary$plot_id <- as.integer(sub(":.*$", "", teller_summary$teller_key))
  teller_summary$jaar <- as.integer(sub("^.*:", "", teller_summary$teller_key))
  teller_summary$teller_key <- NULL

  basis <- merge(basis_key, area, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
  basis <- merge(basis, plot_lookup, by = "plot_id", all.x = TRUE, sort = FALSE)
  basis <- merge(basis, teller_summary, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
  basis <- basis[order(basis$jaar, basis$plot_id), , drop = FALSE]
  if (any(!is.finite(basis$oppervlakte_km2) | basis$oppervlakte_km2 <= 0)) {
    stop("Niet ieder territorium-plotjaar heeft één positieve oppervlakte.", call. = FALSE)
  }
  if (any(is.na(basis$kavel_nummer) | !nzchar(basis$kavel_nummer))) {
    stop("Niet ieder territorium-plotjaar is aan een kavel gekoppeld.", call. = FALSE)
  }
  basis$plotjaar_geteld <- TRUE
  basis$tellerregistratie_bekend <- !is.na(basis$aantal_tellers) & basis$aantal_tellers > 0L
  basis$aantal_tellers[!basis$tellerregistratie_bekend] <- 0L
  rownames(basis) <- NULL

  species_ids <- accepted_positive_species_ids(
    territories,
    data$bronnen,
    data$sovon_bmp_plotjaar,
    plot_year_scope = basis_key
  )
  if (!length(species_ids)) stop("Geen soort met een geaccepteerd positief territorium.", call. = FALSE)
  species_lookup <- unique(data$soorten[c("id", "euring_code", "soort_naam")])
  species_lookup$id <- as.integer(species_lookup$id)
  if (anyDuplicated(species_lookup$id)) stop("soorten bevat dubbele soort-id's.", call. = FALSE)
  species <- species_lookup[species_lookup$id %in% species_ids, , drop = FALSE]
  names(species)[names(species) == "id"] <- "soort_id"
  species <- species[match(species_ids, species$soort_id), , drop = FALSE]
  if (any(is.na(species$soort_id))) stop("Niet iedere geaccepteerde soort staat in soorten.", call. = FALSE)
  rownames(species) <- NULL

  grid <- merge(species[c("soort_id")], basis, all = TRUE, sort = FALSE)
  source_values <- territories[c("plot_id", "soort_id", "jaar", "territoria", "bron_id")]
  grid <- merge(grid, source_values, by = c("plot_id", "soort_id", "jaar"), all.x = TRUE, sort = FALSE)
  grid <- merge(grid, species, by = "soort_id", all.x = TRUE, sort = FALSE)
  matrix <- apply_territory_observation_gate(
    grid,
    data$bronnen,
    data$sovon_bmp_plotjaar,
    territoria_reference = territory_reference
  )
  matrix$territoria_per_km2 <- matrix$count_raw / matrix$oppervlakte_km2
  matrix$log_oppervlakte_km2 <- log(matrix$oppervlakte_km2)
  matrix <- matrix[order(matrix$soort_id, matrix$jaar, matrix$plot_id), , drop = FALSE]
  rownames(matrix) <- NULL

  matrix_key <- paste(matrix$soort_id, matrix$plot_id, matrix$jaar, sep = ":")
  if (anyDuplicated(matrix_key)) stop("De analysematrix bevat dubbele soort-plot-jaarcellen.", call. = FALSE)
  expected <- nrow(basis) * nrow(species)
  if (nrow(matrix) != expected) stop("De analysematrix is niet rechthoekig.", call. = FALSE)

  list(
    matrix = matrix,
    basis = basis,
    species = species,
    year_min = year_min,
    year_max = year_max,
    included_out_of_scope_kavels = include_out_of_scope_kavels
  )
}

summarise_broedvogel_analysis_matrix <- function(result) {
  matrix <- result$matrix
  basis <- result$basis
  species <- result$species
  values <- c(
    plots = length(unique(basis$plot_id)),
    plotjaren = nrow(basis),
    plotjaren_met_teller = sum(basis$tellerregistratie_bekend),
    plotjaren_zonder_teller = sum(!basis$tellerregistratie_bekend),
    soorten = nrow(species),
    jaar_min = min(basis$jaar),
    jaar_max = max(basis$jaar),
    matrixcellen = nrow(matrix),
    geaccepteerde_cellen = sum(matrix$geteld, na.rm = TRUE),
    positieve_cellen = sum(matrix$territorium_vastgesteld, na.rm = TRUE),
    echte_nullen = sum(matrix$echte_nul, na.rm = TRUE),
    letterlijke_nullen = sum(matrix$nulstatus == "letterlijke_nul", na.rm = TRUE),
    afgeleide_jaarverslagnullen = sum(matrix$nulstatus == "afgeleide_jaarverslagnul", na.rm = TRUE),
    formeel_afgekeurde_cellen = sum(matrix$nulstatus == "formeel_afgekeurd", na.rm = TRUE),
    ontbrekende_soortregels = sum(matrix$nulstatus == "ontbrekende_soortregel", na.rm = TRUE)
  )
  data.frame(metric = names(values), value = as.numeric(values), row.names = NULL)
}

sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("R-pakket digest is nodig voor SHA256-controle.", call. = FALSE)
  }
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

write_broedvogel_analysis_outputs <- function(result, output_dir, metadata) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("R-pakket jsonlite is nodig voor het manifest.", call. = FALSE)
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  matrix_path <- file.path(output_dir, "analysematrix.csv.gz")
  summary_path <- file.path(output_dir, "analysematrix_samenvatting.csv")
  manifest_path <- file.path(output_dir, "analysematrix_manifest.json")

  summary <- summarise_broedvogel_analysis_matrix(result)
  connection <- gzfile(matrix_path, open = "wt", encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  utils::write.csv(result$matrix, connection, row.names = FALSE, na = "")
  close(connection)
  on.exit(NULL, add = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE, na = "")

  metric_values <- as.list(stats::setNames(summary$value, summary$metric))
  manifest <- c(
    metadata,
    list(
      matrix = metric_values,
      outputs = list(
        matrix = list(
          file = basename(matrix_path),
          bytes = unname(file.info(matrix_path)$size),
          sha256 = sha256_file(matrix_path)
        ),
        summary = list(
          file = basename(summary_path),
          bytes = unname(file.info(summary_path)$size),
          sha256 = sha256_file(summary_path)
        )
      )
    )
  )
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)

  list(matrix = matrix_path, summary = summary_path, manifest = manifest_path)
}

read_broedvogel_extract <- function(input_dir) {
  table_names <- c(
    "plots",
    "plot_analyse_scope",
    "soorten",
    "plot_jaar_oppervlak",
    "plot_jaar_teller",
    "territoria",
    "bronnen",
    "sovon_bmp_plotjaar"
  )
  paths <- stats::setNames(file.path(input_dir, paste0(table_names, ".tsv")), table_names)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop("Extract mist bestand(en): ", paste(basename(missing), collapse = ", "), ".", call. = FALSE)
  }

  data <- lapply(paths, function(path) {
    utils::read.delim(
      path,
      header = TRUE,
      sep = "\t",
      na.strings = "NULL",
      quote = "",
      comment.char = "",
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })
  source_files <- lapply(paths, function(path) {
    list(
      file = basename(path),
      rows = max(0L, length(readLines(path, warn = FALSE)) - 1L),
      bytes = unname(file.info(path)$size),
      sha256 = sha256_file(path)
    )
  })
  fingerprint <- paste(vapply(source_files, `[[`, character(1), "sha256"), collapse = "")
  list(
    data = data,
    source_files = source_files,
    source_fingerprint_sha256 = digest::digest(fingerprint, algo = "sha256", serialize = FALSE)
  )
}

run_broedvogel_model_data <- function(input_dir, output_dir, metadata) {
  extract <- read_broedvogel_extract(input_dir)
  result <- build_broedvogel_analysis_matrix(extract$data, 1958L, 2025L)
  metadata$source_fingerprint_sha256 <- extract$source_fingerprint_sha256
  metadata$source_files <- extract$source_files
  write_broedvogel_analysis_outputs(result, output_dir, metadata)
}

if (sys.nframe() == 0L) {
  cli_args <- commandArgs(trailingOnly = TRUE)
  if (length(cli_args) != 6L) {
    stop(
      "Gebruik: Rscript broedvogel_model_data.R INPUT_DIR OUTPUT_DIR RUN_ID GIT_COMMIT DATABASE_NAME MYSQL_VERSION",
      call. = FALSE
    )
  }
  output_paths <- run_broedvogel_model_data(
    input_dir = cli_args[[1L]],
    output_dir = cli_args[[2L]],
    metadata = list(
      run_id = cli_args[[3L]],
      executed_at_utc = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
      git_commit = cli_args[[4L]],
      database_name = cli_args[[5L]],
      mysql_version = cli_args[[6L]]
    )
  )
  cat(output_paths$manifest, "\n", sep = "")
}
