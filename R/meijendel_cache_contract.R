MEIJENDEL_CACHE_FORMAT <- "meijendel-shiny-cache-v1"

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
