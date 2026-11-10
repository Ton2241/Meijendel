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
    plot_id = c(1L, 3503L, 3515L),
    kavel_nummer = c("M1", "M66", "M91"),
    stringsAsFactors = FALSE
  ),
  plot_analyse_scope = data.frame(
    scope_code = rep("meijendel_natura2000", 3L),
    plot_id = c(1L, 3503L, 3515L),
    in_scope = c(1L, 0L, 0L),
    reden = c(
      "Onderdeel van Natura 2000-analysegebied.",
      "Geen onderdeel van Natura 2000-analysegebied.",
      "Geen onderdeel van Natura 2000-analysegebied."
    ),
    stringsAsFactors = FALSE
  ),
  territoria = data.frame(
    plot_id = c(1L, 3503L, 3515L),
    soort_id = 1L,
    jaar = 2025L,
    territoria = c(2, 3, 4)
  ),
  plot_jaar_oppervlak = data.frame(
    plot_id = c(1L, 3503L, 3515L),
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
  identical(scope_all$territoria$plot_id, c(1L, 3503L, 3515L))
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

year_report_reference <- data.frame(
  plot_id = c(1L, 2L, 2L, 1L),
  soort_id = c(1L, 2L, 3L, 4L),
  jaar = c(2024L, 2023L, 2023L, 2024L),
  territoria = c(2, 1, 1, 0),
  bron_id = c(2L, 2L, 1L, 1L),
  stringsAsFactors = FALSE
)
year_report_grid <- data.frame(
  plot_id = rep(1L, 4L),
  soort_id = 1:4,
  jaar = rep(2024L, 4L),
  territoria = c(2, NA, NA, 0),
  bron_id = c(2L, NA, NA, 1L),
  plotjaar_geteld = TRUE,
  stringsAsFactors = FALSE
)
year_report_result <- apply_territory_observation_gate(
  year_report_grid,
  territory_gate_bronnen,
  territory_gate_plotjaar,
  territoria_reference = year_report_reference
)
expect_error(
  apply_territory_observation_gate(
    year_report_grid[, setdiff(names(year_report_grid), "soort_id"), drop = FALSE],
    territory_gate_bronnen,
    territory_gate_plotjaar,
    territoria_reference = year_report_reference
  ),
  "Territoriummatrix mist soort_id voor afgeleide jaarverslagnullen."
)
stopifnot(
  identical(year_report_result$count_raw, c(2, 0, NA, 0)),
  identical(year_report_result$geteld, c(TRUE, TRUE, FALSE, TRUE)),
  identical(
    year_report_result$observatie_status,
    c(
      "territorium_vastgesteld",
      "afgeleide_jaarverslagnul",
      "ontbrekende_soortregel",
      "letterlijke_nul"
    )
  ),
  identical(year_report_result$analyse_bron_code, c("jrvslg_m", "jrvslg_m", NA, "sovon_m")),
  identical(
    year_report_result$bewijsgrond,
    c(
      "aanwezige_geaccepteerde_bronregel",
      "ontbreekt_in_geteld_jaarverslagplot_binnen_jaarverslagsoortpool",
      "geen_geaccepteerde_analysewaarde",
      "letterlijke_nul_in_bron"
    )
  )
)

unknown_year_report_reference <- year_report_reference
unknown_year_report_reference$bron_id[1L] <- 999L
expect_error(
  apply_territory_observation_gate(
    year_report_grid,
    territory_gate_bronnen,
    territory_gate_plotjaar,
    territoria_reference = unknown_year_report_reference
  ),
  "Referentie voor jaarverslagnullen bevat een onbekend bron-id."
)

future_year_report_reference <- rbind(
  year_report_reference,
  data.frame(plot_id = 1L, soort_id = 3L, jaar = 2026L, territoria = 1, bron_id = 2L)
)
future_year_report_result <- apply_territory_observation_gate(
  year_report_grid,
  territory_gate_bronnen,
  territory_gate_plotjaar,
  territoria_reference = future_year_report_reference
)
stopifnot(
  is.na(future_year_report_result$count_raw[future_year_report_result$soort_id == 3L]),
  future_year_report_result$observatie_status[future_year_report_result$soort_id == 3L] == "ontbrekende_soortregel"
)
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

identity <- meijendel_cache_identity(strrep("a", 64), 123L, 16L)
cache <- list(
  format = "meijendel-shiny-cache-v1",
  identity = identity,
  data = list(plots = data.frame())
)
stopifnot(validate_meijendel_cache(cache, identity))
stopifnot(identical(identity, meijendel_cache_identity(strrep("a", 64), 123L, 16L)))

wrong_hash <- meijendel_cache_identity(strrep("b", 64), 123L, 16L)
expect_error(validate_meijendel_cache(cache, wrong_hash), "sql_sha256")

wrong_size <- meijendel_cache_identity(strrep("a", 64), 124L, 16L)
expect_error(validate_meijendel_cache(cache, wrong_size), "sql_bytes")

wrong_parser <- meijendel_cache_identity(strrep("a", 64), 123L, 15L)
expect_error(validate_meijendel_cache(cache, wrong_parser), "parser_version")

expect_error(meijendel_cache_identity("ABC", 123L, 16L), "sql_sha256")
expect_error(meijendel_cache_identity(strrep("a", 64), 0L, 16L), "sql_bytes")

tmp <- tempfile("meijendel-cache-contract-")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
manifest <- file.path(tmp, "meijendel.sql.manifest")
writeLines(c(
  "format=meijendel-export-v1",
  paste0("sql_sha256=", strrep("a", 64)),
  "sql_bytes=123",
  paste0("cache_file=meijendel_tables_cache-p16-", strrep("a", 64), ".rds"),
  paste0("cache_manifest=meijendel_tables_cache-p16-", strrep("a", 64), ".manifest")
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
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 16L),
  meijendel_cache_identity(parsed[["sql_sha256"]], parsed[["sql_bytes"]], 16L)
))

source(file.path(repo, "shiny_meijendel", "helpers.R"))

binary_plot_fixture <- tempfile(fileext = ".sql")
plot_prefix <- paste0(
  "INSERT INTO `plots` (`plot_id`, `plot_nr`, `plot_wv`, `plot_naam`, ",
  "`kavel_nummer`, `geom`, `in_gebruik`, `geom_bron_import_id`, `geom_sha256`) VALUES ",
  "(3490,491,'ZH13363','Meijendel k 33','M33',_binary '"
)
plot_suffix <- "',1,NULL,'testhash');\n"
writeBin(
  c(charToRaw(plot_prefix), as.raw(0xfa), charToRaw(plot_suffix)),
  binary_plot_fixture
)
binary_plots <- read_plots_cache_table(binary_plot_fixture)
stopifnot(
  identical(names(binary_plots), c("plot_id", "plot_naam", "kavel_nummer", "in_gebruik")),
  identical(binary_plots$plot_id, "3490"),
  identical(binary_plots$kavel_nummer, "M33")
)
unlink(binary_plot_fixture)

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
  !any(grepl("pjtg$jaar <-", helpers_source, fixed = TRUE)),
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
gee_source <- readLines(file.path(repo, "R", "gee_soorttrend_meijendel.R"), warn = FALSE)
stopifnot(
  any(grepl("build_model_dataset <- function(basis, counts, territoria_reference, bronnen, sovon_plotjaar)", gee_source, fixed = TRUE)),
  any(grepl("territoria_reference = territoria_reference", gee_source, fixed = TRUE)),
  any(grepl("tbls$territoria,", gee_source, fixed = TRUE))
)

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

partial_migration <- tempfile(fileext=".sql")
writeLines("CREATE TABLE `maatregel_plot_jaar_registratie` (",partial_migration)
expect_error(parse_meijendel_tables(partial_migration),"Vereist registratieschema ontbreekt")
unlink(partial_migration)

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
  "toegankelijkheidsgebied", "toegankelijkheidsgebied_versie",
  "toegankelijkheidsgebied_plot_afleiding", "pq_plot_jaar_vegetatie", "weer_analyse_jaar"
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

active_cache <- file.path(tmp, paste0("meijendel_tables_cache-p", MEIJENDEL_PARSER_CACHE_VERSION, "-", strrep("a", 64), ".rds"))
active_identity <- meijendel_cache_identity(strrep("a", 64), 123L, MEIJENDEL_PARSER_CACHE_VERSION)
active_cache_object <- list(
  format = MEIJENDEL_CACHE_FORMAT,
  identity = active_identity,
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
  paste0("parser_version=", MEIJENDEL_PARSER_CACHE_VERSION)
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

# Gebiedsversies gelden vanaf 1 januari 1955 totdat geldig_tot is ingevuld.
time_input <- data.frame(plot_id=c(1L,1L,1L,2L,3L),jaar=c(1954L,1955L,2026L,2026L,2026L))
time_source <- data.frame(
  plot_id=c(1L,1L,2L,3L),
  status_code=c('afgesloten','toegankelijk_met_toegangskaart','toegankelijk','toegankelijk_buiten_broedseizoen'),
  aandeel_pct=c(60,20,100,100),
  geldig_vanaf=as.Date(c('1955-01-01','1955-01-01','1955-01-01','1955-01-01')),
  geldig_tot=as.Date(c(NA,NA,NA,NA))
)
time_result <- add_toegankelijkheid_covariates(time_input,time_source)
stopifnot(identical(as.character(time_result$toegankelijkheid_status),c('onbekend','gemengd','gemengd','toegankelijk','toegankelijk_buiten_broedseizoen')))
stopifnot(identical(time_result$toegankelijkheid_aandeel_afgesloten,c(0,60,60,0,0)))
stopifnot(identical(time_result$toegankelijkheid_aandeel_toegangskaart,c(0,20,20,0,0)))
stopifnot(identical(time_result$toegankelijkheid_aandeel_toegankelijk,c(0,0,0,100,0)))
stopifnot(identical(time_result$toegankelijkheid_aandeel_buiten_broedseizoen,c(0,0,0,0,100)))
stopifnot(identical(time_result$toegankelijkheid_aandeel_onbekend,c(100,20,20,0,0)))
expect_error(
  add_toegankelijkheid_covariates(time_input,rbind(time_source,transform(time_source[1,],aandeel_pct=50))),
  'meer dan 100 procent'
)
