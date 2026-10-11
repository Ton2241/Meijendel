args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), mustWork = TRUE)
source(file.path(repo, "analyses", "broedvogel_vegetatie_power", "scripts", "run_broedvogel_vegetatie_model.R"))

validation <- data.frame(
  validatie = rep(c("ruimte", "tijd"), each = 3),
  fold_id = paste0("f", 1:6),
  metric = rep(c("soortenrijkdom", "shannon", "bedekking"), 2),
  n = 100L,
  delta_mean_log_score = c(.1, -.1, 0, .2, .1, -.2),
  delta_mae = c(.2, -.2, 0, .3, .1, -.1),
  delta_rmse = c(.3, -.3, 0, .4, .2, -.2),
  stringsAsFactors = FALSE
)
summary <- summarise_vegetation_validation(validation)
stopifnot(nrow(summary) == 6L)
stopifnot(all(summary$aantal_blokken == 1L))
stopifnot(all(summary$aandeel_betere_logscore %in% c(0, 1)))

coverage <- data.frame(lag_years = 0:3, rows = 10:13, plotyears = 4:7, plots = 2L, species = 3L)
validate_vegetation_coverage(coverage, expected_plots = 2L)
bad <- coverage
bad$plots[1] <- 1L
message <- tryCatch({ validate_vegetation_coverage(bad, 2L); "" }, error = conditionMessage)
stopifnot(grepl("plotdekking", message, fixed = TRUE))

cat("OK: vegetatiepijplijncontracten\n")
