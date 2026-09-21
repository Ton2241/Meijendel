args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "R/test_meijendel_cache_contract.R"
repo <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

source(file.path(repo, "R", "meijendel_cache_contract.R"))

expect_error <- function(expr, pattern) {
  error <- tryCatch({
    force(expr)
    NULL
  }, error = function(condition) condition)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error), fixed = TRUE))
}

identity <- meijendel_cache_identity(strrep("a", 64), 123L, 9L)
cache <- list(
  format = "meijendel-shiny-cache-v1",
  identity = identity,
  data = list(plots = data.frame())
)
stopifnot(validate_meijendel_cache(cache, identity))
stopifnot(identical(identity, meijendel_cache_identity(strrep("a", 64), 123L, 9L)))

wrong_hash <- meijendel_cache_identity(strrep("b", 64), 123L, 9L)
expect_error(validate_meijendel_cache(cache, wrong_hash), "sql_sha256")

wrong_size <- meijendel_cache_identity(strrep("a", 64), 124L, 9L)
expect_error(validate_meijendel_cache(cache, wrong_size), "sql_bytes")

wrong_parser <- meijendel_cache_identity(strrep("a", 64), 123L, 10L)
expect_error(validate_meijendel_cache(cache, wrong_parser), "parser_version")

expect_error(meijendel_cache_identity("ABC", 123L, 9L), "sql_sha256")
expect_error(meijendel_cache_identity(strrep("a", 64), 0L, 9L), "sql_bytes")

tmp <- tempfile("meijendel-cache-contract-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
manifest <- file.path(tmp, "meijendel.sql.manifest")
writeLines(c(
  "format=meijendel-export-v1",
  paste0("sql_sha256=", strrep("a", 64)),
  "sql_bytes=123",
  paste0("cache_file=meijendel_tables_cache-p9-", strrep("a", 64), ".rds"),
  paste0("cache_manifest=meijendel_tables_cache-p9-", strrep("a", 64), ".manifest")
), manifest)
parsed <- read_meijendel_manifest(manifest)
stopifnot(identical(unname(parsed[["sql_bytes"]]), "123"))

duplicate_manifest <- file.path(tmp, "duplicate.manifest")
writeLines(c("sql_bytes=123", "sql_bytes=124"), duplicate_manifest)
expect_error(read_meijendel_manifest(duplicate_manifest), "dubbele sleutel")

dir.create(file.path(tmp, "eerste"))
dir.create(file.path(tmp, "tweede"))
sql_one <- file.path(tmp, "eerste", "meijendel.sql")
sql_two <- file.path(tmp, "tweede", "meijendel.sql")
writeBin(charToRaw("dezelfde dumpbytes"), sql_one)
stopifnot(file.copy(sql_one, sql_two))
stopifnot(!identical(normalizePath(sql_one), normalizePath(sql_two)))
stopifnot(identical(
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 9L),
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 9L)
))

source(file.path(repo, "shiny_meijendel", "helpers.R"))
parse_called <- FALSE
parse_meijendel_tables <- function(path) {
  parse_called <<- TRUE
  stop("parser had niet aangeroepen mogen worden")
}
missing_cache <- file.path(tmp, "ontbrekend.rds")
expect_error(
  load_meijendel_tables_cached(
    sql_one,
    cache_path = missing_cache,
    sql_manifest_path = manifest,
    require_prebuilt = TRUE
  ),
  "Vooraf gebouwde Meijendel-cache ontbreekt of past niet"
)
stopifnot(!parse_called)

required_names <- c(
  "richtlijnen", "soort_richtlijn", "functional_group_definition",
  "functional_group_membership", "soorten_kenmerken",
  "soorten_kenmerken_datadictionary", "soorten_kenmerken_hoofdcategorien",
  "soorten_kenmerken_vogeltypering", "habitattypen", "plot_jaar_habitat",
  "plot_jaar_ahn_dtm", "plot_jaar_stikstof", "plot_jaar_infra",
  "plot_jaar_toegankelijkheid", "pq_plot_jaar_vegetatie", "weer_analyse_jaar"
)
parse_meijendel_tables <- function(path) {
  stats::setNames(lapply(required_names, function(name) data.frame()), required_names)
}
saved_paths <- character()
saveRDS <- function(object, file, ...) {
  saved_paths <<- c(saved_paths, file)
  base::saveRDS(object, file, ...)
}
local_cache <- file.path(tmp, "lokale-cache.rds")
local_result <- load_meijendel_tables_cached(
  sql_one,
  cache_path = local_cache,
  sql_manifest_path = manifest,
  require_prebuilt = FALSE
)
stopifnot(!local_result$from_cache, file.exists(local_cache))
stopifnot(any(grepl(paste0("\\.next\\.", Sys.getpid(), "$"), saved_paths)))
stopifnot(!any(file.exists(paste0(local_cache, ".next.", Sys.getpid()))))

active_cache <- file.path(tmp, paste0("meijendel_tables_cache-p9-", strrep("a", 64), ".rds"))
active_cache_object <- list(
  format = MEIJENDEL_CACHE_FORMAT,
  identity = identity,
  data = stats::setNames(lapply(required_names, function(name) data.frame()), required_names)
)
base::saveRDS(active_cache_object, active_cache, version = 3)
active_manifest <- file.path(tmp, "meijendel_tables_cache.active.manifest")
writeLines(c(
  "format=meijendel-shiny-cache-manifest-v1",
  paste0("cache_file=", basename(active_cache)),
  paste0("cache_sha256=", sha256_file(active_cache)),
  paste0("cache_bytes=", file.info(active_cache)$size),
  paste0("sql_sha256=", strrep("a", 64)),
  "sql_bytes=123",
  "parser_version=9"
), active_manifest)
manifest_result <- load_meijendel_tables_cached(
  sql_one,
  sql_manifest_path = manifest,
  cache_manifest_path = active_manifest,
  require_prebuilt = TRUE
)
stopifnot(
  manifest_result$from_cache,
  identical(manifest_result$cache_path, normalizePath(active_cache, winslash = "/", mustWork = TRUE))
)

cat("OK: Meijendel-cachecontract is padonafhankelijk en productie faalt gesloten.\n")
