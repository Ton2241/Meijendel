args <- commandArgs(trailingOnly = TRUE)

repo_dir <- normalizePath(if (length(args) >= 1L) args[[1]] else ".", mustWork = TRUE)
out_dir <- normalizePath(if (length(args) >= 2L) args[[2]] else file.path(repo_dir, "groepen_grafieken"), mustWork = TRUE)
source(file.path(repo_dir, "R", "species_name_synonyms.R"))

chart_path <- file.path(out_dir, "gam_dashboard_groepen.csv")
density_path <- file.path(out_dir, "groep_dichtheid.csv")
species_path <- file.path(out_dir, "groep_soorten.csv")
dashboard_path <- file.path(repo_dir, "bmp_meijendel_index.html")

required_chart_ids <- c(
  "100", "200", "300", "400", "500", "600", "700", "800", "900",
  "rode-lijst", "oranje-lijst", "vogelrichtlijn", "rode-en-oranje-lijst",
  "2110-embryonale-wandelende-duinen", "2120-witte-duinen", "2130-grijze-duinen",
  "2160-duindoornstruwelen", "2180-duinbossen", "2190-vochtige-duinvalleien",
  "3140-kranswierwateren", "6430-ruigten-en-zomen",
  "functioneel-bodem-insect-binair", "functioneel-bodem-insect-gewogen",
  "functioneel-lucht-binair", "functioneel-lucht-gewogen",
  "functioneel-grondbroed-binair", "functioneel-grondbroed-gewogen",
  "functioneel-holenbroed-binair", "functioneel-holenbroed-gewogen",
  "functioneel-lange-trek-binair", "functioneel-lange-trek-gewogen",
  "functioneel-zaad-binair", "functioneel-zaad-gewogen"
)

fail <- function(...) {
  stop(paste0(...), call. = FALSE)
}

read_required_csv <- function(path, columns) {
  if (!file.exists(path)) fail("Bestand ontbreekt: ", path)
  data <- read.csv(path, stringsAsFactors = FALSE)
  if (!nrow(data)) fail("Bestand is leeg: ", path)
  missing <- setdiff(columns, names(data))
  if (length(missing)) fail("Kolommen ontbreken in ", basename(path), ": ", paste(missing, collapse = ", "))
  data
}

chart <- read_required_csv(
  chart_path,
  c("chart_id", "chart_title", "serie", "jaar", "fit_1990", "lower_1990", "upper_1990")
)
density <- read_required_csv(
  density_path,
  c("chart_id", "chart_title", "jaar", "dichtheid", "territoria", "oppervlakte_km2")
)
species <- read_required_csv(
  species_path,
  c("chart_id", "chart_title", "soort_naam")
)

if (!file.exists(dashboard_path)) fail("Dashboard ontbreekt: ", dashboard_path)
dashboard <- paste(readLines(dashboard_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
required_dashboard_fragments <- c(
  'S.msiGroepen.push(...getFunctioneleGroepen())',
  'box.appendChild(renderMsiGroupSection("Functionele Vogelgroepen",getFunctioneleGroepen()))',
  'S.functionalMode==="gewogen"',
  'Number(r.membership_weight)'
)
missing_dashboard_fragments <- required_dashboard_fragments[
  !vapply(required_dashboard_fragments, grepl, logical(1), x = dashboard, fixed = TRUE)
]
if (length(missing_dashboard_fragments)) {
  fail("Functionele groepen zijn niet volledig beschikbaar in de dashboard-dichtheidsweergave.")
}

chart$chart_id <- as.character(chart$chart_id)
density$chart_id <- as.character(density$chart_id)
species$chart_id <- as.character(species$chart_id)
chart$jaar <- as.integer(chart$jaar)
density$jaar <- as.integer(density$jaar)

unexpected_aliases <- unique(species$soort_naam[
  tolower(species$soort_naam) %in% tolower(names(SPECIES_NAME_SYNONYMS))
])
if (length(unexpected_aliases)) {
  fail("Niet-gecanonicaliseerde soortnamen in groep_soorten.csv: ", paste(sort(unexpected_aliases), collapse = ", "))
}
missing_canonical_names <- setdiff(unname(SPECIES_NAME_SYNONYMS), unique(species$soort_naam))
if (length(missing_canonical_names)) {
  fail("Canonieke soortnamen ontbreken in groep_soorten.csv: ", paste(sort(missing_canonical_names), collapse = ", "))
}

missing_density <- setdiff(required_chart_ids, unique(density$chart_id))
missing_species <- setdiff(required_chart_ids, unique(species$chart_id))
missing_chart <- setdiff(required_chart_ids, unique(chart$chart_id))

if (length(missing_density)) fail("Chart-id ontbreekt in groep_dichtheid.csv: ", paste(missing_density, collapse = ", "))
if (length(missing_species)) fail("Chart-id ontbreekt in groep_soorten.csv: ", paste(missing_species, collapse = ", "))
if (length(missing_chart)) fail("Chart-id ontbreekt in gam_dashboard_groepen.csv: ", paste(missing_chart, collapse = ", "))

numeric_checks <- list(
  density = density$dichtheid,
  territoria = density$territoria,
  oppervlakte_km2 = density$oppervlakte_km2,
  fit_1990 = chart$fit_1990,
  lower_1990 = chart$lower_1990,
  upper_1990 = chart$upper_1990
)
for (name in names(numeric_checks)) {
  values <- suppressWarnings(as.numeric(numeric_checks[[name]]))
  if (any(!is.finite(values))) fail("Niet-numerieke of niet-finite waarden in kolom: ", name)
}

if (any(as.numeric(density$dichtheid) < 0)) fail("Negatieve dichtheden gevonden.")
if (any(as.numeric(density$oppervlakte_km2) <= 0)) fail("Niet-positieve oppervlaktes gevonden.")
if (any(as.numeric(chart$lower_1990) > as.numeric(chart$fit_1990))) fail("lower_1990 ligt boven fit_1990.")
if (any(as.numeric(chart$upper_1990) < as.numeric(chart$fit_1990))) fail("upper_1990 ligt onder fit_1990.")

density_years <- aggregate(jaar ~ chart_id, density, function(x) length(unique(x)))
names(density_years)[2] <- "n_years"
too_short <- density_years$chart_id[density_years$n_years < 10]
if (length(too_short)) fail("Te weinig jaren in groep_dichtheid.csv voor: ", paste(too_short, collapse = ", "))

if (!all(required_chart_ids %in% unique(density$chart_id[density$jaar == 2025]))) {
  missing_2025 <- setdiff(required_chart_ids, unique(density$chart_id[density$jaar == 2025]))
  fail("Geen 2025-dichtheidsrij voor: ", paste(missing_2025, collapse = ", "))
}

series_by_chart <- aggregate(serie ~ chart_id, chart, function(x) paste(sort(unique(x)), collapse = ","))
missing_meijendel <- series_by_chart$chart_id[!grepl("(^|,)meijendel(,|$)", series_by_chart$serie)]
if (length(missing_meijendel)) fail("Meijendel-serie ontbreekt in gam_dashboard_groepen.csv voor: ", paste(missing_meijendel, collapse = ", "))

cat("Dashboard/website parity-check OK\n")
cat("CSV-map:", out_dir, "\n")
cat("Chart-id's:", length(unique(density$chart_id)), "\n")
cat("Dichtheidsrijen:", nrow(density), "\n")
cat("GAM-rijen:", nrow(chart), "\n")
cat("Soortenrijen:", nrow(species), "\n")
