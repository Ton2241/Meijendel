if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Package 'rsconnect' is niet geinstalleerd. Installeer het eerst met install.packages('rsconnect').")
}

required_packages <- c(
  "shiny",
  "bslib",
  "DBI",
  "RSQLite",
  "rtrim",
  "mgcv",
  "broom",
  "geepack",
  "broom.mixed",
  "DHARMa",
  "glmmTMB",
  "lme4",
  "TMB",
  "vegan",
  "pls",
  "changepoint",
  "strucchange",
  "lavaan",
  "piecewiseSEM",
  "betapart",
  "unmarked"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop(
    "Deze packages ontbreken lokaal en worden door shinyapps.io ook nodig: ",
    paste(missing_packages, collapse = ", "),
    "\nInstalleer ze eerst lokaal; rsconnect gebruikt de lokale package metadata voor de deploy."
  )
}

if (!nzchar(Sys.which("perl"))) {
  stop("Perl is lokaal niet beschikbaar. De occupancy-parser gebruikt perl; installeer perl of gebruik een vooraf verwerkte occupancy-datatabel.")
}

app_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
root_dir <- normalizePath(file.path(app_dir, ".."), winslash = "/", mustWork = TRUE)
root_sql <- file.path(root_dir, "Meijendel.sql")

if (!file.exists(root_sql)) {
  stop(sprintf("Root-SQL niet gevonden: %s", root_sql))
}

filter_sql_for_deploy <- function(input, output) {
  awk_program <- "
    function sensitive(line) {
      return line ~ /`tellers`/
    }
    function section_start(line) {
      return line ~ /^-- (Table structure for table|Dumping data for table|Temporary view structure for view|Final view structure for view) /
    }
    {
      if (section_start($0)) {
        skip = sensitive($0)
      }
      if (!skip) {
        print
      }
    }
  "

  awk_file <- tempfile(fileext = ".awk")
  on.exit(unlink(awk_file), add = TRUE)
  writeLines(awk_program, awk_file, useBytes = TRUE)

  cmd <- sprintf(
    "LC_ALL=C awk -f %s %s > %s",
    shQuote(awk_file),
    shQuote(input),
    shQuote(output)
  )
  status <- system(cmd)
  if (!identical(status, 0L)) {
    stop("Kon SQL niet filteren voor shinyapps.io.")
  }
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

dependency_file <- file.path(bundle_dir, "shinyapps_dependencies.R")
writeLines(
  c(
    "# Expliciete package-verwijzingen voor rsconnect/shinyapps.io.",
    "# Dit bestand wordt niet door de app gesourced, maar helpt dependency-detectie.",
    sprintf("library(%s)", required_packages)
  ),
  dependency_file,
  useBytes = TRUE
)

bundle_sql <- file.path(bundle_dir, "Meijendel.sql")
filter_sql_for_deploy(root_sql, bundle_sql)

message(sprintf("Deploybundle gemaakt in: %s", bundle_dir))
message(sprintf("SQL-bron in bundle zonder tabel tellers: %s", root_sql))
message(sprintf("Perl lokaal beschikbaar: %s", Sys.which("perl")))
message("R-package dependencies in deploybundle:")
print(rsconnect::appDependencies(appDir = bundle_dir))

rsconnect::deployApp(
  appDir = bundle_dir,
  appName = "shiny_meijendel",
  account = "mbsk",
  forceUpdate = TRUE,
  launch.browser = FALSE
)
