# Export the exact model population from a saved bundle without fitting models.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Gebruik: Rscript R/export_trim_bootstrap_selection.R BUNDLE OUTPUT_JSON")
manifest <- jsonlite::read_json(file.path(args[[1]], "bundle_manifest.json"), simplifyVector = TRUE)
path <- file.path(args[[1]], "context.rds")
if (!identical(digest::digest(file = path, algo = "sha256"), manifest$context_sha256)) stop("Context-hash wijkt af")
x <- readRDS(path)
selection <- list(plot_ids = sort(x$clusters$plot_id), species_ids = sort(unique(x$species_matrix$soort_id)),
  year_from = 1958L, year_to = manifest$analysis_end_year, context_sha256 = manifest$context_sha256)
jsonlite::write_json(selection, args[[2]], auto_unbox = TRUE, pretty = TRUE)
