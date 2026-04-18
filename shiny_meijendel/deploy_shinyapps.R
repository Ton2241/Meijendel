if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Package 'rsconnect' is niet geinstalleerd. Installeer het eerst met install.packages('rsconnect').")
}

app_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
root_dir <- normalizePath(file.path(app_dir, ".."), winslash = "/", mustWork = TRUE)
root_sql <- file.path(root_dir, "Meijendel.sql")

if (!file.exists(root_sql)) {
  stop(sprintf("Root-SQL niet gevonden: %s", root_sql))
}

bundle_dir <- file.path(tempdir(), "shiny_meijendel_bundle")
if (dir.exists(bundle_dir)) {
  unlink(bundle_dir, recursive = TRUE, force = TRUE)
}
dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)

bundle_files <- c(
  "app.R",
  "helpers.R",
  "evg_selctie_T0soort_T0msi.csv"
)

copied <- file.copy(
  from = file.path(app_dir, bundle_files),
  to = bundle_dir,
  overwrite = TRUE
)

if (!all(copied)) {
  stop("Niet alle appbestanden konden naar de tijdelijke deploy-map worden gekopieerd.")
}

if (!file.copy(root_sql, file.path(bundle_dir, "Meijendel.sql"), overwrite = TRUE)) {
  stop("Kon de root-SQL niet naar de tijdelijke deploy-map kopieren.")
}

message(sprintf("Deploybundle gemaakt in: %s", bundle_dir))
message(sprintf("SQL-bron in bundle: %s", root_sql))

rsconnect::deployApp(
  appDir = bundle_dir,
  appName = "shiny_meijendel",
  account = "mbsk",
  launch.browser = FALSE
)
