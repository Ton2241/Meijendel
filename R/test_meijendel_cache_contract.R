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

scope_fixture <- list(
  plots = data.frame(
    plot_id = c(1L, 3503L, 3514L),
    kavel_nummer = c("M1", "M66", "M91"),
    stringsAsFactors = FALSE
  ),
  plot_analyse_scope = data.frame(
    scope_code = rep("meijendel_natura2000", 3L),
    plot_id = c(1L, 3503L, 3514L),
    in_scope = c(1L, 0L, 0L),
    reden = c(
      "Onderdeel van Natura 2000-analysegebied.",
      "Geen onderdeel van Natura 2000-analysegebied.",
      "Geen onderdeel van Natura 2000-analysegebied."
    ),
    stringsAsFactors = FALSE
  ),
  territoria = data.frame(
    plot_id = c(1L, 3503L, 3514L),
    soort_id = 1L,
    jaar = 2025L,
    territoria = c(2, 3, 4)
  ),
  plot_jaar_oppervlak = data.frame(
    plot_id = c(1L, 3503L, 3514L),
    jaar = 2025L,
    oppervlakte_km2 = c(1, 1, 1)
  ),
  soorten = data.frame(id = 1L, soort_naam = "Testsoort")
)

scope_default <- apply_meijendel_plot_scope(scope_fixture)
stopifnot(
  identical(scope_default$plots$kavel_nummer, "M1"),
  identical(scope_default$territoria$plot_id, 1L),
  nrow(scope_default$plot_analyse_scope) == 3L
)

scope_m66 <- apply_meijendel_plot_scope(scope_fixture, "M66")
stopifnot(
  identical(scope_m66$plots$kavel_nummer, c("M1", "M66")),
  identical(scope_m66$territoria$plot_id, c(1L, 3503L))
)

scope_all <- apply_meijendel_plot_scope(scope_fixture, c("M66", "M91"))
stopifnot(
  identical(scope_all$plots$kavel_nummer, c("M1", "M66", "M91")),
  identical(scope_all$territoria$plot_id, c(1L, 3503L, 3514L))
)

expect_error(
  apply_meijendel_plot_scope(scope_fixture, "M999"),
  "niet als uitgesloten kavel geregistreerd"
)

scope_onvolledig <- scope_fixture
scope_onvolledig$plot_analyse_scope <- scope_onvolledig$plot_analyse_scope[-3L, ]
expect_error(
  apply_meijendel_plot_scope(scope_onvolledig),
  "mist een expliciete scopestatus"
)

territory_gate_fixture <- data.frame(
  plot_id = rep(1L, 5L),
  soort_id = seq_len(5L),
  jaar = c(2024L, 2024L, 2025L, 2025L, 2025L),
  territoria = c(0, NA, 3, NA, 4),
  bron_id = c(1L, NA, 1L, NA, 2L),
  plotjaar_geteld = TRUE,
  stringsAsFactors = FALSE
)
territory_gate_bronnen <- data.frame(
  id = c(1L, 2L),
  code = c("sovon_m", "jrvslg_m"),
  stringsAsFactors = FALSE
)
territory_gate_plotjaar <- data.frame(
  plot_id = c(1L, 1L),
  jaar = c(2024L, 2025L),
  beoordelingsstatus = c("goedgekeurd", "formeel_afgekeurd"),
  stringsAsFactors = FALSE
)
territory_gate_result <- apply_territory_observation_gate(
  territory_gate_fixture,
  territory_gate_bronnen,
  territory_gate_plotjaar
)
stopifnot(
  identical(territory_gate_result$count_raw, c(0, NA, NA, NA, 4)),
  identical(territory_gate_result$geteld, c(TRUE, FALSE, FALSE, FALSE, TRUE)),
  identical(
    territory_gate_result$observatie_status,
    c(
      "letterlijke_nul",
      "ontbrekende_soortregel",
      "formeel_afgekeurd",
      "formeel_afgekeurd",
      "onafhankelijke_bron_ondanks_sovon_afkeur"
    )
  ),
  identical(
    territory_gate_result$sovon_formeel_afgekeurd,
    c(FALSE, FALSE, TRUE, TRUE, TRUE)
  )
)
stopifnot(identical(
  accepted_positive_species_ids(
    territory_gate_fixture,
    territory_gate_bronnen,
    territory_gate_plotjaar
  ),
  5L
))
period_fixture <- rbind(
  territory_gate_fixture,
  data.frame(
    plot_id = 1L,
    soort_id = 6L,
    jaar = 2026L,
    territoria = 2,
    bron_id = 2L,
    plotjaar_geteld = TRUE
  )
)
period_fixture <- rbind(
  period_fixture,
  data.frame(
    plot_id = 2L,
    soort_id = 7L,
    jaar = 2024L,
    territoria = 3,
    bron_id = 2L,
    plotjaar_geteld = TRUE
  )
)
stopifnot(identical(
  accepted_positive_species_ids(
    period_fixture,
    territory_gate_bronnen,
    territory_gate_plotjaar,
    plot_year_scope = data.frame(plot_id = 1L, jaar = c(2024L, 2025L))
  ),
  5L
))

identity <- meijendel_cache_identity(strrep("a", 64), 123L, 13L)
cache <- list(
  format = "meijendel-shiny-cache-v1",
  identity = identity,
  data = list(plots = data.frame())
)
stopifnot(validate_meijendel_cache(cache, identity))
stopifnot(identical(identity, meijendel_cache_identity(strrep("a", 64), 123L, 13L)))

wrong_hash <- meijendel_cache_identity(strrep("b", 64), 123L, 13L)
expect_error(validate_meijendel_cache(cache, wrong_hash), "sql_sha256")

wrong_size <- meijendel_cache_identity(strrep("a", 64), 124L, 13L)
expect_error(validate_meijendel_cache(cache, wrong_size), "sql_bytes")

wrong_parser <- meijendel_cache_identity(strrep("a", 64), 123L, 14L)
expect_error(validate_meijendel_cache(cache, wrong_parser), "parser_version")

expect_error(meijendel_cache_identity("ABC", 123L, 13L), "sql_sha256")
expect_error(meijendel_cache_identity(strrep("a", 64), 0L, 13L), "sql_bytes")

tmp <- tempfile("meijendel-cache-contract-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
manifest <- file.path(tmp, "meijendel.sql.manifest")
writeLines(c(
  "format=meijendel-export-v1",
  paste0("sql_sha256=", strrep("a", 64)),
  "sql_bytes=123",
  paste0("cache_file=meijendel_tables_cache-p13-", strrep("a", 64), ".rds"),
  paste0("cache_manifest=meijendel_tables_cache-p13-", strrep("a", 64), ".manifest")
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
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 13L),
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 13L)
))

source(file.path(repo, "shiny_meijendel", "helpers.R"))
complete_count_fixture <- data.frame(
  plot_id = rep(1L, 5L),
  jaar = c(2024L, 2024L, 2025L, 2025L, 2025L),
  soort_id = c(1L, 2L, 1L, 2L, 2L),
  count_raw = c(0, NA, 0, NA, 4),
  geteld = c(TRUE, FALSE, TRUE, FALSE, TRUE),
  stringsAsFactors = FALSE
)
complete_counts <- aggregate_complete_species_counts(complete_count_fixture, c(1L, 2L))
stopifnot(
  nrow(complete_counts) == 1L,
  identical(complete_counts$jaar, 2025L),
  identical(complete_counts$count, 4)
)
helpers_source <- readLines(file.path(repo, "shiny_meijendel", "helpers.R"), warn = FALSE)
stopifnot(
  !any(grepl("plots <- plots[plots$in_gebruik == 1L", helpers_source, fixed = TRUE)),
  any(grepl("accepted_positive_species_ids", helpers_source, fixed = TRUE))
)
batch_gate_files <- c(
  file.path(repo, "R", "trim_soorten_en_msi_evg.R"),
  file.path(repo, "R", "trim_sandra_soorten_en_msi_evg.R"),
  file.path(repo, "R", "gee_soorttrend_meijendel.R")
)
stopifnot(vapply(
  batch_gate_files,
  function(path) any(grepl("apply_territory_observation_gate", readLines(path, warn = FALSE), fixed = TRUE)),
  logical(1)
))

source(file.path(repo, "R", "analyse_ecologische_groepen.R"))
alternative_tbls <- list(
  plots = data.frame(plot_id = 1L, kavel_nummer = "1a", stringsAsFactors = FALSE),
  soorten = data.frame(
    id = c(1L, 2L),
    soort_naam = c("Testsoort een", "Testsoort twee"),
    stringsAsFactors = FALSE
  ),
  evg_vogel_landschapgroep = data.frame(
    groepsnummer = c(100L, 100L),
    vogel_id = c(1L, 2L),
    stringsAsFactors = FALSE
  ),
  evg_vogelgroepen = data.frame(
    groepsnummer = 100L,
    landschap_groep = "Testgroep",
    stringsAsFactors = FALSE
  ),
  plot_jaar_oppervlak = data.frame(
    plot_id = 1L,
    jaar = 2025L,
    oppervlakte_km2 = 1,
    stringsAsFactors = FALSE
  ),
  territoria = data.frame(
    plot_id = c(1L, 1L, 1L),
    soort_id = c(1L, 1L, 2L),
    jaar = 2025L,
    territoria = c(3, 4, 0),
    bron_id = c(1L, 2L, 1L),
    stringsAsFactors = FALSE
  ),
  bronnen = territory_gate_bronnen,
  sovon_bmp_plotjaar = data.frame(
    plot_id = 1L,
    jaar = 2025L,
    beoordelingsstatus = "formeel_afgekeurd",
    stringsAsFactors = FALSE
  )
)
alternative_base <- prepare_base_data(alternative_tbls)
stopifnot(
  identical(alternative_base$annual_species$territoria, 4),
  identical(alternative_base$annual_species$soort_id, 1L)
)

zero_index_fixture <- data.frame(
  groep_100 = c(100L, 100L),
  jaar = c(2025L, 2025L),
  soort_id = c(1L, 2L),
  index_spliced = c(0, 100),
  log_index_spliced = c(-Inf, log(100)),
  stringsAsFactors = FALSE
)
zero_group <- build_group_msi(
  zero_index_fixture,
  data.frame(groep_100 = 100L, korte_beschrijving = "Testgroep"),
  data.frame(groep_100 = 100L, jaar = 2025L, density_per_km2 = 1)
)
stopifnot(
  nrow(zero_group) == 1L,
  isTRUE(all.equal(zero_group$msi, sqrt(101) - 1, tolerance = 1e-12)),
  identical(zero_group$n_nulindices, 1L),
  identical(zero_group$msi_methode, "verschoven_geometrisch_gemiddelde_index_plus_1")
)

shiny_tbls <- list(
  territoria = territory_gate_fixture[!is.na(territory_gate_fixture$bron_id), c("plot_id", "soort_id", "jaar", "territoria", "bron_id")],
  bronnen = territory_gate_bronnen,
  sovon_bmp_plotjaar = territory_gate_plotjaar
)
shiny_basis <- data.frame(
  plot_id = c(1L, 1L),
  jaar = c(2024L, 2025L),
  kavel_nummer = c("1", "1"),
  oppervlakte_km2 = c(1, 1),
  geteld = c(TRUE, TRUE),
  referentie_oppervlakte_km2 = c(1, 1),
  oppervlakte_factor = c(1, 1),
  analyse_reeks = c("test", "test"),
  stringsAsFactors = FALSE
)
shiny_selection <- data.frame(
  id = seq_len(5L),
  euring_code = seq_len(5L),
  soort_naam = paste("Soort", seq_len(5L)),
  engelse_naam = paste("Species", seq_len(5L)),
  in_selectie = TRUE,
  stringsAsFactors = FALSE
)
shiny_gate_result <- build_species_matrix_subset(shiny_tbls, shiny_basis, shiny_selection, 2024L, 2025L)
shiny_gate_result <- shiny_gate_result[
  (shiny_gate_result$soort_id == 1L & shiny_gate_result$jaar == 2024L) |
    (shiny_gate_result$soort_id == 2L & shiny_gate_result$jaar == 2024L) |
    (shiny_gate_result$soort_id %in% 3:5 & shiny_gate_result$jaar == 2025L),
  ,
  drop = FALSE
]
shiny_gate_result <- shiny_gate_result[order(shiny_gate_result$soort_id), , drop = FALSE]
stopifnot(
  identical(shiny_gate_result$count_raw, c(0, NA, NA, NA, 4)),
  identical(shiny_gate_result$geteld, c(TRUE, FALSE, FALSE, FALSE, TRUE)),
  identical(
    shiny_gate_result$observatie_status,
    c(
      "letterlijke_nul",
      "ontbrekende_soortregel",
      "formeel_afgekeurd",
      "formeel_afgekeurd",
      "onafhankelijke_bron_ondanks_sovon_afkeur"
    )
  )
)

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
  "plots", "plot_analyse_scope", "bronnen", "sovon_bmp_plotjaar",
  "richtlijnen", "soort_richtlijn", "functional_group_definition",
  "functional_group_membership", "soorten_kenmerken",
  "soorten_kenmerken_datadictionary", "soorten_kenmerken_hoofdcategorien",
  "soorten_kenmerken_vogeltypering", "habitattypen", "plot_jaar_habitat",
  "plot_jaar_ahn_dtm", "plot_jaar_stikstof", "plot_jaar_infra",
  "plot_jaar_toegankelijkheid", "pq_plot_jaar_vegetatie", "weer_analyse_jaar"
)
cache_fixture_data <- function() {
  data <- stats::setNames(lapply(required_names, function(name) data.frame()), required_names)
  data$plots <- data.frame(plot_id = 1L, kavel_nummer = "M1", stringsAsFactors = FALSE)
  data$plot_analyse_scope <- data.frame(
    scope_code = "meijendel_natura2000",
    plot_id = 1L,
    in_scope = 1L,
    reden = "Onderdeel van Natura 2000-analysegebied.",
    stringsAsFactors = FALSE
  )
  data
}
parse_meijendel_tables <- function(path) {
  cache_fixture_data()
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

active_cache <- file.path(tmp, paste0("meijendel_tables_cache-p13-", strrep("a", 64), ".rds"))
active_cache_object <- list(
  format = MEIJENDEL_CACHE_FORMAT,
  identity = identity,
  data = cache_fixture_data()
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
  "parser_version=13"
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
