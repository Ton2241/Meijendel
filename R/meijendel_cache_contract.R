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
