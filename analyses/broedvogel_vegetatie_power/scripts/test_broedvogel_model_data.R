args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
test_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_data.R"
repo <- normalizePath(file.path(dirname(test_path), "..", "..", ".."), mustWork = TRUE)

Sys.setenv(MEIJENDEL_REPO = repo)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_data.R"))

expect_error <- function(expr, pattern) {
  error <- tryCatch({
    force(expr)
    NULL
  }, error = function(condition) condition)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error), fixed = TRUE))
}

fixture <- list(
  plots = data.frame(
    plot_id = c(1L, 2L, 3503L),
    plot_naam = c("Plot 1", "Plot 2", "Haagsche Golf Club"),
    kavel_nummer = c("M1", "M2", "M66"),
    stringsAsFactors = FALSE
  ),
  plot_analyse_scope = data.frame(
    scope_code = rep("meijendel_natura2000", 3L),
    plot_id = c(1L, 2L, 3503L),
    in_scope = c(1L, 1L, 0L),
    reden = c(
      "Onderdeel van Natura 2000-analysegebied.",
      "Onderdeel van Natura 2000-analysegebied.",
      "Geen onderdeel van Natura 2000-analysegebied."
    ),
    stringsAsFactors = FALSE
  ),
  soorten = data.frame(
    id = 1:4,
    euring_code = 101:104,
    soort_naam = c("Soort A", "Soort B", "Soort C", "Nulsoort"),
    stringsAsFactors = FALSE
  ),
  plot_jaar_oppervlak = data.frame(
    plot_id = c(1L, 1L, 1L, 1L, 2L, 2L, 3503L),
    jaar = c(2022L, 2023L, 2024L, 2025L, 2023L, 2024L, 2023L),
    oppervlakte_km2 = c(1, 1, 1, 1, 2, 2, 3),
    stringsAsFactors = FALSE
  ),
  plot_jaar_teller = data.frame(
    plot_id = c(1L, 1L, 2L),
    jaar = c(2022L, 2023L, 2023L),
    teller_id = c(10L, 11L, 12L),
    stringsAsFactors = FALSE
  ),
  territoria = data.frame(
    plot_id = c(1L, 2L, 1L, 1L, 2L, 1L, 1L, 3503L),
    soort_id = c(1L, 2L, 2L, 3L, 2L, 1L, 4L, 1L),
    jaar = c(2023L, 2023L, 2024L, 2024L, 2024L, 2025L, 2025L, 2023L),
    territoria = c(2, 1, 3, 4, 5, 0, 0, 7),
    bron_id = c(2L, 2L, 1L, 2L, 1L, 1L, 1L, 2L),
    stringsAsFactors = FALSE
  ),
  bronnen = data.frame(
    id = c(1L, 2L),
    code = c("sovon_m", "jrvslg_m"),
    stringsAsFactors = FALSE
  ),
  sovon_bmp_plotjaar = data.frame(
    plot_id = c(1L, 1L, 2L),
    jaar = c(2024L, 2025L, 2024L),
    beoordelingsstatus = c("formeel_afgekeurd", "goedgekeurd", "formeel_afgekeurd"),
    stringsAsFactors = FALSE
  )
)

result <- build_broedvogel_analysis_matrix(fixture, 1958L, 2025L)
matrix <- result$matrix

# Breuk die dit vangt: tellerregistraties zonder territoriumdata worden ten
# onrechte als geteld plotjaar toegevoegd.
stopifnot(
  nrow(result$basis) == 5L,
  !2022L %in% result$basis$jaar,
  identical(sort(unique(result$basis$plot_id)), c(1L, 2L)),
  !3503L %in% matrix$plot_id,
  sum(result$basis$tellerregistratie_bekend) == 2L,
  sum(!result$basis$tellerregistratie_bekend) == 3L
)

# Breuk die dit vangt: nul-only-soorten worden analysekandidaat of een cel
# wordt door een onbedoelde join vermenigvuldigd.
stopifnot(
  identical(sort(result$species$soort_id), 1:3),
  nrow(matrix) == 15L,
  !anyDuplicated(matrix[c("soort_id", "plot_id", "jaar")])
)

cell <- function(species_id, plot_id, year) {
  matrix[
    matrix$soort_id == species_id & matrix$plot_id == plot_id & matrix$jaar == year,
    ,
    drop = FALSE
  ]
}

# Breuk die dit vangt: een ontbrekende jaarverslagsoort wordt NA in plaats van
# een afgeleide jaarverslagnul.
derived <- cell(2L, 1L, 2023L)
stopifnot(
  nrow(derived) == 1L,
  identical(derived$count_raw, 0),
  identical(derived$nulstatus, "afgeleide_jaarverslagnul")
)

# Breuk die dit vangt: een letterlijke SOVON-nul en een ontbrekende soortregel
# krijgen dezelfde betekenis.
literal_zero <- cell(1L, 1L, 2025L)
missing <- cell(2L, 1L, 2025L)
stopifnot(
  identical(literal_zero$count_raw, 0),
  identical(literal_zero$nulstatus, "letterlijke_nul"),
  is.na(missing$count_raw),
  identical(missing$nulstatus, "ontbrekende_soortregel")
)

# Breuk die dit vangt: een formeel afgekeurde SOVON-waarde wordt gebruikt of
# een geldige onafhankelijke jaarverslagwaarde in zo'n plotjaar verdwijnt.
rejected <- cell(2L, 2L, 2024L)
independent <- cell(3L, 1L, 2024L)
stopifnot(
  is.na(rejected$count_raw),
  identical(rejected$nulstatus, "formeel_afgekeurd"),
  identical(independent$count_raw, 4),
  identical(independent$nulstatus, "onafhankelijke_bron_ondanks_sovon_afkeur")
)

summary <- summarise_broedvogel_analysis_matrix(result)
summary_value <- function(metric) summary$value[match(metric, summary$metric)]
stopifnot(
  identical(summary_value("plotjaren"), 5),
  identical(summary_value("plotjaren_met_teller"), 2),
  identical(summary_value("plotjaren_zonder_teller"), 3),
  identical(summary_value("soorten"), 3),
  identical(summary_value("matrixcellen"), 15),
  identical(summary_value("positieve_cellen"), 3),
  identical(summary_value("letterlijke_nullen"), 1),
  identical(summary_value("afgeleide_jaarverslagnullen"), 6),
  identical(summary_value("formeel_afgekeurde_cellen"), 3),
  identical(summary_value("ontbrekende_soortregels"), 2)
)

duplicate_fixture <- fixture
duplicate_fixture$territoria <- rbind(duplicate_fixture$territoria, duplicate_fixture$territoria[1L, ])
expect_error(
  build_broedvogel_analysis_matrix(duplicate_fixture, 1958L, 2025L),
  "territoria bevat meer dan één bronregel voor dezelfde soort-plot-jaarcel"
)

tmp <- tempfile("broedvogel-matrix-test-")
dir.create(tmp)
metadata <- list(
  run_id = "test-run",
  executed_at_utc = "2026-10-09T12:00:00Z",
  git_commit = strrep("a", 40L),
  database_name = "Meijendel",
  mysql_version = "9.7.1",
  source_fingerprint_sha256 = strrep("b", 64L),
  source_files = list(territoria = list(sha256 = strrep("c", 64L), rows = 8L))
)
paths <- write_broedvogel_analysis_outputs(result, tmp, metadata)
stopifnot(
  file.exists(paths$matrix),
  file.exists(paths$summary),
  file.exists(paths$manifest),
  identical(jsonlite::read_json(paths$manifest)$run_id, "test-run"),
  identical(as.integer(jsonlite::read_json(paths$manifest)$matrix$matrixcellen), 15L)
)

extract_dir <- file.path(tmp, "extract")
dir.create(extract_dir)
for (table_name in names(fixture)) {
  utils::write.table(
    fixture[[table_name]],
    file.path(extract_dir, paste0(table_name, ".tsv")),
    sep = "\t",
    row.names = FALSE,
    quote = FALSE,
    na = "NULL"
  )
}
loaded <- read_broedvogel_extract(extract_dir)
stopifnot(
  identical(sort(names(loaded$data)), sort(names(fixture))),
  loaded$source_files$territoria$rows == 8L,
  grepl("^[0-9a-f]{64}$", loaded$source_files$territoria$sha256)
)
run_dir <- file.path(tmp, "run")
run_paths <- run_broedvogel_model_data(
  extract_dir,
  run_dir,
  metadata[c("run_id", "executed_at_utc", "git_commit", "database_name", "mysql_version")]
)
run_manifest <- jsonlite::read_json(run_paths$manifest)
stopifnot(
  file.exists(run_paths$matrix),
  identical(as.integer(run_manifest$matrix$plotjaren), 5L),
  identical(run_manifest$source_fingerprint_sha256, loaded$source_fingerprint_sha256),
  identical(run_manifest$outputs$matrix$sha256, sha256_file(run_paths$matrix))
)

unlink(tmp, recursive = TRUE)
cat("OK: broedvogel-analysematrix bewaart scope, nulbetekenis, afkeur en manifest.\n")
