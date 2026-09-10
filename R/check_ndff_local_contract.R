#!/usr/bin/env Rscript

repo_root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))]), ".."), mustWork = FALSE)
if (!dir.exists(repo_root)) {
  repo_root <- normalizePath(".")
}
module_path <- file.path(repo_root, "shiny_meijendel", "ndff_local.R")
app_path <- file.path(repo_root, "shiny_meijendel", "app.R")

stopifnot(file.exists(module_path))
source(module_path, local = TRUE)

stopifnot(isTRUE(ndff_local_enabled(flag = "1", runtime = "local", working_directory = repo_root)))
stopifnot(isFALSE(ndff_local_enabled(flag = "0", runtime = "local", working_directory = repo_root)))

production_error <- tryCatch({
  ndff_local_enabled(flag = "1", runtime = "production", working_directory = "/srv/shiny-server")
  FALSE
}, error = function(condition) TRUE)
stopifnot(production_error)

expected_views <- c(
  "v_ndff_lokale_overzicht",
  "v_ndff_lokale_plot_jaar_taxon",
  "v_ndff_lokale_protocolstatus"
)
stopifnot(identical(ndff_local_allowed_views(), expected_views))
stopifnot(identical(ndff_mysql_connection_args(), c(
  "--protocol=tcp", "--host=127.0.0.1", "--port=3306"
)))

forbidden <- c(
  "exacte_geometrie", "bron_centrum_x_rd", "bron_centrum_y_rd",
  "ndff_identity", "open_identity_sha256", "raw_payload",
  "periode_start", "periode_stop"
)
stopifnot(!any(forbidden %in% ndff_local_safe_columns()))

app <- paste(readLines(app_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
stopifnot(grepl("source\\(\"ndff_local.R\"", app))
stopifnot(grepl("ndff_local_tab\\(\\)", app))
stopifnot(grepl("ndff_local_server\\(input, output, session\\)", app))
stopifnot(!grepl("downloadHandler", paste(readLines(module_path, warn = FALSE), collapse = "\n")))

cat("OK: lokaal NDFF-Shiny-contract\n")
