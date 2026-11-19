args <- commandArgs(TRUE)
candidate <- args[1]
context_path <- args[2]
destination <- args[3]
omission_sha256 <- args[4]

sha256 <- function(path) strsplit(system2("/usr/bin/shasum", c("-a", "256", shQuote(path)),
                                          stdout = TRUE), " ")[[1]][1]
source_path <- file.path(candidate, "runtime", "aantalsindex.R")
inputs <- file.path(candidate, "outputs")
manifest_path <- file.path(inputs, "kandidaatmanifest.json")
manifest <- jsonlite::fromJSON(manifest_path)
stopifnot(sha256(context_path) == manifest$context_sha256,
          sha256(source_path) == manifest$rekenroute_sha256,
          sha256(file.path(inputs, "weglating-per-soort.csv")) == omission_sha256,
          sha256(file.path(inputs, "soorten-156.csv")) == manifest$bestanden[["soorten-156.csv"]])
# Load only the original estimators. The full script runs 36,000 unrelated fits.
for (expression in parse(source_path)) {
  if (is.call(expression) && identical(expression[[1]], as.name("<-")) &&
      as.character(expression[[2]])[1] %in% c("fit_year_index", "make_index")) {
    eval(expression)
  }
}

context <- readRDS(context_path)
cells <- subset(context$species_matrix, geteld %in% TRUE & is.finite(count_raw))
stopifnot(!anyDuplicated(cells[c("soort_id", "plot_id", "jaar")]),
          all(is.finite(cells$oppervlakte_km2) & cells$oppervlakte_km2 > 0))
birds <- read.csv(file.path(inputs, "soorten-156.csv"))
plot_ids <- context$clusters$plot_id
curves <- list()
for (period in names(context$config$periods)) {
  years <- context$config$periods[[period]]
  curves[[period]] <- setNames(lapply(birds$soort_id, function(id) {
    obs <- cells[cells$soort_id == id & cells$jaar %in% years, ]
    pos <- cbind(match(obs$plot_id, plot_ids), match(obs$jaar, years))
    stopifnot(!anyNA(pos))
    Y <- E <- matrix(0, length(plot_ids), length(years))
    Y[pos] <- obs$count_raw
    E[pos] <- obs$oppervlakte_km2
    fit <- fit_year_index(Y, E)
    list(years = unname(make_index(fit)), status = fit$status)
  }), birds$soort_id)
}
jsonlite::write_json(list(candidate_sha256 = sha256(manifest_path),
                         omission_sha256 = omission_sha256,
                         curves = curves),
                     destination, auto_unbox = TRUE, na = "null", digits = 10)
