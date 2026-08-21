args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L || !args[[3L]] %in% c("restore", "validate")) {
  stop("Gebruik: install_shiny_packages.R LOCKFILE DESCRIPTION restore|validate")
}

lockfile <- normalizePath(args[[1L]], mustWork = TRUE)
description <- normalizePath(args[[2L]], mustWork = TRUE)
mode <- args[[3L]]
expected_r <- "4.6.1"
expected_repo <- "https://p3m.dev/cran/__linux__/noble/2026-08-18"
target_library <- "/usr/local/lib/R/site-library"

options(
  repos = c(CRAN = expected_repo),
  Ncpus = max(1L, parallel::detectCores(logical = TRUE) - 1L),
  timeout = 1200
)
Sys.setenv(RENV_CONFIG_REPOS_OVERRIDE = expected_repo)

lock <- jsonlite::read_json(lockfile, simplifyVector = FALSE)
if (!identical(lock$R$Version, expected_r)) {
  stop("Lockfile gebruikt R ", lock$R$Version, "; verwacht ", expected_r)
}
if (!identical(as.character(getRversion()), expected_r)) {
  stop("Runtime gebruikt R ", getRversion(), "; verwacht ", expected_r)
}

lock_repositories <- vapply(lock$R$Repositories, `[[`, character(1L), "URL")
if (!identical(unname(lock_repositories), expected_repo)) {
  stop("Lockfile gebruikt niet exact de vastgepinde P3M-snapshot")
}

lock_versions <- vapply(lock$Packages, `[[`, character(1L), "Version")
description_fields <- read.dcf(description)
imports <- trimws(strsplit(description_fields[1L, "Imports"], ",", fixed = TRUE)[[1L]])
imports <- sub("[[:space:]]*\\(.*$", "", imports)
missing_from_lock <- setdiff(imports, names(lock_versions))
if (length(missing_from_lock)) {
  stop("DESCRIPTION-packages ontbreken in renv.lock: ", paste(missing_from_lock, collapse = ", "))
}

if (mode == "restore") {
  existing_site_packages <- list.files(
    target_library,
    all.files = TRUE,
    full.names = TRUE,
    no.. = TRUE
  )
  unlink(existing_site_packages, recursive = TRUE, force = TRUE)
  remaining_site_packages <- list.files(
    target_library,
    all.files = TRUE,
    no.. = TRUE
  )
  if (length(remaining_site_packages)) {
    stop(
      "Site-library kon niet volledig worden opgeschoond: ",
      paste(remaining_site_packages, collapse = ", ")
    )
  }
  bootstrap_library <- "/tmp/renv-bootstrap"
  dir.create(bootstrap_library, recursive = TRUE, showWarnings = FALSE)
  install.packages("renv", lib = bootstrap_library, repos = expected_repo)
  old_library_paths <- .libPaths()
  .libPaths(c(bootstrap_library, old_library_paths))
  on.exit(.libPaths(old_library_paths), add = TRUE)
  renv::restore(
    lockfile = lockfile,
    library = target_library,
    prompt = FALSE,
    clean = TRUE
  )
  .libPaths(old_library_paths)
}

installed_versions <- character()
for (library in rev(.libPaths())) {
  library_packages <- installed.packages(lib.loc = library, noCache = TRUE)
  installed_versions[rownames(library_packages)] <- library_packages[, "Version"]
}
site_packages <- installed.packages(lib.loc = target_library, noCache = TRUE)
site_versions <- site_packages[, "Version"]
missing <- setdiff(names(lock_versions), names(installed_versions))
mismatched <- intersect(names(lock_versions), names(installed_versions))
mismatched <- mismatched[lock_versions[mismatched] != installed_versions[mismatched]]
extra <- setdiff(names(site_versions), names(lock_versions))

if (length(missing)) {
  stop("Lockpackages ontbreken: ", paste(missing, collapse = ", "))
}
if (length(mismatched)) {
  details <- paste0(
    mismatched, "=", installed_versions[mismatched], " (lock ",
    lock_versions[mismatched], ")"
  )
  stop("Packageversies wijken af: ", paste(details, collapse = ", "))
}
if (length(extra)) {
  stop("Niet-vergrendelde site-librarypackages aanwezig: ", paste(extra, collapse = ", "))
}

unavailable <- imports[!vapply(imports, requireNamespace, logical(1L), quietly = TRUE)]
if (length(unavailable)) {
  stop("DESCRIPTION-packages zijn niet laadbaar: ", paste(unavailable, collapse = ", "))
}

cat(sprintf(
  "GROEN: R %s, snapshot %s en %d lockpackages zijn exact.\n",
  expected_r,
  expected_repo,
  length(lock_versions)
))
