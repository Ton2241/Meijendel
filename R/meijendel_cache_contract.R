MEIJENDEL_CACHE_FORMAT <- "meijendel-shiny-cache-v1"
MEIJENDEL_DEFAULT_PLOT_SCOPE <- "meijendel_natura2000"

normalize_meijendel_kavel <- function(x) {
  x <- trimws(as.character(x))
  x <- ifelse(nzchar(x) & !grepl("^M", x, ignore.case = TRUE), paste0("M", x), x)
  toupper(x)
}

meijendel_out_of_scope_from_env <- function(
  value = Sys.getenv("MEIJENDEL_INCLUDE_OUT_OF_SCOPE_PLOTS", unset = "")
) {
  value <- trimws(value)
  if (!nzchar(value)) return(character())
  unique(normalize_meijendel_kavel(strsplit(value, ",", fixed = TRUE)[[1L]]))
}

apply_meijendel_plot_scope <- function(
  data,
  include_out_of_scope_kavels = character(),
  scope_code = MEIJENDEL_DEFAULT_PLOT_SCOPE
) {
  if (!is.list(data) || !is.data.frame(data$plots) || !is.data.frame(data$plot_analyse_scope)) {
    stop("Analysegegevens missen plots of plot_analyse_scope.", call. = FALSE)
  }
  required_plot <- c("plot_id", "kavel_nummer")
  required_scope <- c("scope_code", "plot_id", "in_scope", "reden")
  if (length(setdiff(required_plot, names(data$plots)))) {
    stop("plots mist plot_id of kavel_nummer.", call. = FALSE)
  }
  if (length(setdiff(required_scope, names(data$plot_analyse_scope)))) {
    stop("plot_analyse_scope mist verplichte velden.", call. = FALSE)
  }

  plots <- data$plots
  plots$plot_id <- as.integer(plots$plot_id)
  plots$kavel_nummer <- normalize_meijendel_kavel(plots$kavel_nummer)
  scope <- data$plot_analyse_scope[data$plot_analyse_scope$scope_code == scope_code, , drop = FALSE]
  scope$plot_id <- as.integer(scope$plot_id)
  scope$in_scope <- as.integer(scope$in_scope)

  if (anyDuplicated(scope$plot_id)) {
    stop("plot_analyse_scope bevat een dubbele plotstatus voor ", scope_code, ".", call. = FALSE)
  }
  missing_scope <- setdiff(plots$plot_id, scope$plot_id)
  if (length(missing_scope)) {
    missing_kavels <- plots$kavel_nummer[match(missing_scope, plots$plot_id)]
    stop(
      "Plot mist een expliciete scopestatus: ",
      paste(missing_kavels, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (any(!scope$in_scope %in% c(0L, 1L))) {
    stop("plot_analyse_scope bevat een andere waarde dan 0 of 1.", call. = FALSE)
  }

  requested <- unique(normalize_meijendel_kavel(include_out_of_scope_kavels))
  requested <- requested[nzchar(requested)]
  excluded_ids <- scope$plot_id[scope$in_scope == 0L]
  excluded_kavels <- plots$kavel_nummer[match(excluded_ids, plots$plot_id)]
  unknown <- setdiff(requested, excluded_kavels)
  if (length(unknown)) {
    stop(
      "Kavel is niet als uitgesloten kavel geregistreerd: ",
      paste(unknown, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  included_ids <- scope$plot_id[scope$in_scope == 1L]
  if (length(requested)) {
    included_ids <- unique(c(included_ids, plots$plot_id[plots$kavel_nummer %in% requested]))
  }

  for (name in names(data)) {
    value <- data[[name]]
    if (identical(name, "plot_analyse_scope") || !is.data.frame(value) || !"plot_id" %in% names(value)) next
    value$plot_id <- as.integer(value$plot_id)
    data[[name]] <- value[value$plot_id %in% included_ids, , drop = FALSE]
  }
  attr(data, "meijendel_plot_scope") <- scope_code
  attr(data, "included_out_of_scope_kavels") <- requested
  data
}

normalize_sovon_plotjaar_status <- function(sovon_plotjaar) {
  required <- c("plot_id", "jaar", "beoordelingsstatus")
  if (!is.data.frame(sovon_plotjaar) || length(setdiff(required, names(sovon_plotjaar)))) {
    stop("sovon_bmp_plotjaar mist plot_id, jaar of beoordelingsstatus.", call. = FALSE)
  }
  status <- unique(sovon_plotjaar[, required, drop = FALSE])
  status$plot_id <- as.integer(status$plot_id)
  status$jaar <- as.integer(status$jaar)
  status$beoordelingsstatus <- as.character(status$beoordelingsstatus)
  key <- paste(status$plot_id, status$jaar, sep = ":")
  if (anyDuplicated(key)) {
    stop("sovon_bmp_plotjaar bevat conflicterende statussen voor hetzelfde plotjaar.", call. = FALSE)
  }
  status
}

year_report_zero_context <- function(territoria_reference, bronnen) {
  required <- c("plot_id", "soort_id", "jaar", "territoria", "bron_id")
  if (!is.data.frame(territoria_reference) || length(setdiff(required, names(territoria_reference)))) {
    stop("Referentie voor jaarverslagnullen mist verplichte territoriumvelden.", call. = FALSE)
  }
  bron_lookup <- unique(bronnen[, c("id", "code"), drop = FALSE])
  bron_lookup$id <- as.integer(bron_lookup$id)
  bron_lookup$code <- as.character(bron_lookup$code)
  reference <- territoria_reference[, required, drop = FALSE]
  reference$plot_id <- as.integer(reference$plot_id)
  reference$soort_id <- as.integer(reference$soort_id)
  reference$jaar <- as.integer(reference$jaar)
  reference$territoria <- as.numeric(reference$territoria)
  reference$bron_id <- as.integer(reference$bron_id)
  reference <- merge(reference, bron_lookup, by.x = "bron_id", by.y = "id", all.x = TRUE, sort = FALSE)
  unresolved <- !is.na(reference$bron_id) & (is.na(reference$code) | !nzchar(reference$code))
  if (any(unresolved)) {
    stop("Referentie voor jaarverslagnullen bevat een onbekend bron-id.", call. = FALSE)
  }
  is_year_report <- !is.na(reference$code) &
    reference$code == "jrvslg_m" &
    reference$jaar >= 1958L &
    reference$jaar <= 2025L &
    is.finite(reference$territoria)
  reference <- reference[is_year_report, , drop = FALSE]

  list(
    plotjaar_sleutels = unique(paste(reference$plot_id, reference$jaar, sep = ":")),
    soort_ids = sort(unique(reference$soort_id[reference$territoria > 0]))
  )
}

apply_territory_observation_gate <- function(
    grid,
    bronnen,
    sovon_plotjaar,
    territoria_reference = NULL) {
  required_grid <- c("plot_id", "jaar", "territoria", "bron_id")
  if (!is.data.frame(grid) || length(setdiff(required_grid, names(grid)))) {
    stop("Territoriummatrix mist plot_id, jaar, territoria of bron_id.", call. = FALSE)
  }
  if (!is.null(territoria_reference) && !"soort_id" %in% names(grid)) {
    stop("Territoriummatrix mist soort_id voor afgeleide jaarverslagnullen.", call. = FALSE)
  }
  if (!"plotjaar_geteld" %in% names(grid)) {
    if (!"geteld" %in% names(grid)) {
      stop("Territoriummatrix mist de plotjaarstatus geteld.", call. = FALSE)
    }
    grid$plotjaar_geteld <- as.logical(grid$geteld)
  } else {
    grid$plotjaar_geteld <- as.logical(grid$plotjaar_geteld)
  }
  if (!is.data.frame(bronnen) || length(setdiff(c("id", "code"), names(bronnen)))) {
    stop("bronnen mist id of code.", call. = FALSE)
  }

  bron_lookup <- unique(bronnen[, c("id", "code"), drop = FALSE])
  bron_lookup$id <- as.integer(bron_lookup$id)
  bron_lookup$code <- as.character(bron_lookup$code)
  if (anyDuplicated(bron_lookup$id)) {
    stop("bronnen bevat een dubbel bron-id.", call. = FALSE)
  }
  grid$plot_id <- as.integer(grid$plot_id)
  grid$jaar <- as.integer(grid$jaar)
  grid$bron_id <- as.integer(grid$bron_id)
  grid$territoria <- as.numeric(grid$territoria)
  if ("soort_id" %in% names(grid)) grid$soort_id <- as.integer(grid$soort_id)
  grid$.gate_row_order <- seq_len(nrow(grid))
  grid <- merge(
    grid,
    bron_lookup,
    by.x = "bron_id",
    by.y = "id",
    all.x = TRUE,
    sort = FALSE
  )
  names(grid)[names(grid) == "code"] <- "bron_code"
  unresolved <- !is.na(grid$bron_id) & (is.na(grid$bron_code) | !nzchar(grid$bron_code))
  if (any(unresolved)) {
    stop("Territoriummatrix bevat een onbekend bron-id.", call. = FALSE)
  }

  status <- normalize_sovon_plotjaar_status(sovon_plotjaar)
  grid <- merge(grid, status, by = c("plot_id", "jaar"), all.x = TRUE, sort = FALSE)
  grid <- grid[order(grid$.gate_row_order), , drop = FALSE]
  grid$.gate_row_order <- NULL

  has_source_row <- !is.na(grid$bron_id)
  finite_count <- is.finite(grid$territoria)
  is_sovon_source <- has_source_row & grepl("^sovon_", grid$bron_code)
  grid$sovon_formeel_afgekeurd <- !is.na(grid$beoordelingsstatus) &
    grid$beoordelingsstatus == "formeel_afgekeurd"
  blocked_sovon <- grid$sovon_formeel_afgekeurd & is_sovon_source
  independent_after_rejection <- grid$sovon_formeel_afgekeurd &
    has_source_row & !is_sovon_source & finite_count
  accepted <- has_source_row & finite_count & !blocked_sovon

  grid$geteld <- accepted
  grid$count_raw <- ifelse(accepted, grid$territoria, NA_real_)
  grid$observatie_status <- ifelse(
    independent_after_rejection,
    "onafhankelijke_bron_ondanks_sovon_afkeur",
    ifelse(
      grid$sovon_formeel_afgekeurd,
      "formeel_afgekeurd",
      ifelse(
        accepted & grid$count_raw == 0,
        "letterlijke_nul",
        ifelse(
          accepted & grid$count_raw > 0,
          "territorium_vastgesteld",
          ifelse(grid$plotjaar_geteld, "ontbrekende_soortregel", "niet_geteld")
        )
      )
    )
  )
  grid$analyse_bron_code <- ifelse(accepted, grid$bron_code, NA_character_)

  if (!is.null(territoria_reference)) {
    context <- year_report_zero_context(territoria_reference, bronnen)
    row_plotjaar_key <- paste(grid$plot_id, grid$jaar, sep = ":")
    row_value_key <- paste(grid$plot_id, grid$jaar, grid$soort_id, sep = ":")
    accepted_value_keys <- unique(row_value_key[grid$geteld])
    eligible <- row_plotjaar_key %in% context$plotjaar_sleutels &
      grid$soort_id %in% context$soort_ids &
      !row_value_key %in% accepted_value_keys
    derived_rows <- which(eligible)
    derived_rows <- derived_rows[!duplicated(row_value_key[derived_rows])]
    if (length(derived_rows)) {
      grid$geteld[derived_rows] <- TRUE
      grid$count_raw[derived_rows] <- 0
      grid$observatie_status[derived_rows] <- "afgeleide_jaarverslagnul"
      grid$analyse_bron_code[derived_rows] <- "jrvslg_m"
    }
  }

  grid$nulstatus <- grid$observatie_status
  grid$bewijsgrond <- ifelse(
    grid$observatie_status == "territorium_vastgesteld",
    "aanwezige_geaccepteerde_bronregel",
    ifelse(
      grid$observatie_status == "letterlijke_nul",
      "letterlijke_nul_in_bron",
      ifelse(
        grid$observatie_status == "afgeleide_jaarverslagnul",
        "ontbreekt_in_geteld_jaarverslagplot_binnen_jaarverslagsoortpool",
        ifelse(
          grid$observatie_status == "onafhankelijke_bron_ondanks_sovon_afkeur",
          "aanwezige_onafhankelijke_bronregel",
          "geen_geaccepteerde_analysewaarde"
        )
      )
    )
  )
  grid$is_missing <- !grid$geteld
  grid$territorium_vastgesteld <- grid$geteld & grid$count_raw > 0
  grid$echte_nul <- grid$geteld & grid$count_raw == 0
  grid$waargenomen_zonder_territorium <- NA
  rownames(grid) <- NULL
  grid
}

accepted_territory_rows <- function(territoria, bronnen, sovon_plotjaar) {
  if (!is.data.frame(territoria) || !nrow(territoria)) return(territoria)
  territoria$plotjaar_geteld <- TRUE
  gated <- apply_territory_observation_gate(territoria, bronnen, sovon_plotjaar)
  gated[gated$geteld, , drop = FALSE]
}

accepted_positive_species_ids <- function(
    territoria,
    bronnen,
    sovon_plotjaar,
    plot_year_scope = NULL,
    plot_ids = NULL,
    year_min = NULL,
    year_max = NULL) {
  if (!is.null(plot_year_scope)) {
    required_scope <- c("plot_id", "jaar")
    if (!is.data.frame(plot_year_scope) || length(setdiff(required_scope, names(plot_year_scope)))) {
      stop("plot_year_scope mist plot_id of jaar.", call. = FALSE)
    }
    scope <- unique(plot_year_scope[, required_scope, drop = FALSE])
    scope$plot_id <- as.integer(scope$plot_id)
    scope$jaar <- as.integer(scope$jaar)
    territoria <- merge(territoria, scope, by = required_scope, all = FALSE, sort = FALSE)
  }
  if (!is.null(plot_ids)) {
    territoria <- territoria[territoria$plot_id %in% as.integer(plot_ids), , drop = FALSE]
  }
  if (!is.null(year_min)) {
    territoria <- territoria[territoria$jaar >= as.integer(year_min), , drop = FALSE]
  }
  if (!is.null(year_max)) {
    territoria <- territoria[territoria$jaar <= as.integer(year_max), , drop = FALSE]
  }
  accepted <- accepted_territory_rows(territoria, bronnen, sovon_plotjaar)
  if (!is.data.frame(accepted) || !nrow(accepted)) return(integer())
  sort(unique(as.integer(accepted$soort_id[is.finite(accepted$count_raw) & accepted$count_raw > 0])))
}

validate_sha256 <- function(value, field) {
  value <- as.character(value)
  if (length(value) != 1L || is.na(value) || !grepl("^[0-9a-f]{64}$", value)) {
    stop(field, " moet exact 64 lowercase hextekens bevatten.", call. = FALSE)
  }
  value
}

validate_positive_integer <- function(value, field) {
  value <- as.character(value)
  if (length(value) != 1L || is.na(value) || !grepl("^[0-9]+$", value) || grepl("^0+$", value)) {
    stop(field, " moet een positief geheel getal zijn.", call. = FALSE)
  }
  sub("^0+([0-9])", "\\1", value)
}

read_meijendel_manifest <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(lines)]
  if (!length(lines) || any(!grepl("^[^=]+=[^=]*$", lines))) {
    stop("Manifest bevat een ongeldige key=value-regel: ", path, call. = FALSE)
  }
  keys <- sub("=.*$", "", lines)
  if (anyDuplicated(keys)) {
    stop("Manifest bevat een dubbele sleutel: ", keys[duplicated(keys)][[1L]], call. = FALSE)
  }
  values <- sub("^[^=]*=", "", lines)
  stats::setNames(values, keys)
}

meijendel_cache_identity <- function(sql_sha256, sql_bytes, parser_version) {
  list(
    format = MEIJENDEL_CACHE_FORMAT,
    sql_sha256 = validate_sha256(sql_sha256, "sql_sha256"),
    sql_bytes = validate_positive_integer(sql_bytes, "sql_bytes"),
    parser_version = validate_positive_integer(parser_version, "parser_version")
  )
}

meijendel_cache_identity_from_manifest <- function(manifest, parser_version) {
  if (length(manifest) == 1L && is.character(manifest) && is.null(names(manifest))) {
    manifest <- read_meijendel_manifest(manifest)
  }
  required <- c("sql_sha256", "sql_bytes")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop("Dumpmanifest mist cache-identiteitsveld: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  meijendel_cache_identity(manifest[["sql_sha256"]], manifest[["sql_bytes"]], parser_version)
}

validate_meijendel_cache <- function(cache, expected_identity, required_data = character()) {
  if (!is.list(cache) || !identical(cache$format, MEIJENDEL_CACHE_FORMAT)) {
    stop("Cacheformaat wijkt af.", call. = FALSE)
  }
  if (!is.list(cache$identity)) {
    stop("Cache-identiteit ontbreekt.", call. = FALSE)
  }
  for (field in c("format", "sql_sha256", "sql_bytes", "parser_version")) {
    if (!identical(cache$identity[[field]], expected_identity[[field]])) {
      stop("Cache-identiteit wijkt af voor ", field, ".", call. = FALSE)
    }
  }
  if (is.null(cache$data) || !is.list(cache$data)) {
    stop("Cachedata ontbreekt.", call. = FALSE)
  }
  missing_data <- setdiff(required_data, names(cache$data))
  if (length(missing_data)) {
    stop("Cachedata mist: ", paste(missing_data, collapse = ", "), call. = FALSE)
  }
  TRUE
}
