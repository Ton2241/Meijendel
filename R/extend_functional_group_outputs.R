# Extend the historical release from its archived TRIM indices, without refitting.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, dir.exists(args[[1L]]))
script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
repo <- dirname(dirname(normalizePath(script_path)))
# Source the calculation in its own environment so its command-line main does
# not run and its configuration resolves relative to the regular R directory.
calc <- new.env()
source(file.path(repo, "R", "trim_soorten_en_msi_evg.R"), local = calc)
mapping <- calc$build_functional_group_mapping(list(
  functional_group_definition = data.frame(
    id = integer(), group_code = character(), group_version = character(),
    naam_nl = character(), minimum_exploratief = integer(),
    minimum_hoofdindicator = integer(), minimum_robuust = integer(), status = character()),
  functional_group_membership = data.frame(
    functional_group_definition_id = integer(), soort_id = integer(),
    binary_membership = integer(), membership_weight = numeric(), classification = character())
))
index_files <- c(volledig = "soortindices_per_jaar.csv", robuust = "soortindices_bruikbare_tijdreeks.csv")
parts <- list()
for (variant in names(index_files)) {
  indices <- read.csv(file.path(repo, "trim", "soorten", index_files[[variant]]))
  stopifnot(max(indices$jaar) == 2025L)
  for (mode in c("binair", "gewogen")) {
    parts[[paste(mode, variant)]] <- calc$analyse_functional_groups(indices, mapping, mode, variant)
  }
}
files <- c(composition = "functionele_groepssamenstelling.csv",
           msi = "functionele_msi_per_groep_per_jaar.csv",
           trends = "functionele_trendoverzicht_msi_groepen.csv",
           loso = "functionele_loso_trendgevoeligheid.csv")
for (key in names(files)) {
  previous <- read.csv(file.path(repo, "trim_msi_evg", files[[key]]))
  existing <- previous[!previous$group_code %in% mapping$group_code, ]
  added <- do.call(rbind, lapply(parts, function(part) part[[key]]))
  stopifnot(setequal(added$group_code, mapping$group_code))
  write.csv(rbind(existing, added), file.path(args[[1L]], files[[key]]), row.names = FALSE)
}
