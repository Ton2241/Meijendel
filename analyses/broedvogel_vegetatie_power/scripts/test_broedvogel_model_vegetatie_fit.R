args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "broedvogel_model_vegetatie_fit.R"))

formula_text <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")

for (metric in names(pq_metric_contract())) {
  formulas <- vegetation_model_formulas(metric)
  stopifnot(identical(names(formulas), c("basis", "pq")))
  base <- formula_text(formulas$basis)
  pq <- formula_text(formulas$pq)
  stopifnot(grepl("tellerteam_factor", base, fixed = TRUE))
  stopifnot(grepl("ervaring_plot_z", base, fixed = TRUE))
  stopifnot(grepl("ervaring_elders_z", base, fixed = TRUE))
  stopifnot(grepl("offset(log_oppervlakte_km2)", base, fixed = TRUE))
  stopifnot(!grepl(paste0(metric, "_between_z"), base, fixed = TRUE))
  stopifnot(grepl(paste0(metric, "_between_z"), pq, fixed = TRUE))
  stopifnot(grepl(paste0(metric, "_within_z"), pq, fixed = TRUE))
}

bad <- tryCatch({ vegetation_model_formulas("geen_metric"); "" }, error = conditionMessage)
stopifnot(grepl("Onbekende PQ-maat", bad, fixed = TRUE))

cat("OK: formules vegetatiemodellen\n")
