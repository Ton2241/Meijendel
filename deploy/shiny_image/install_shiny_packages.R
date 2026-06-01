options(
  repos = c(CRAN = Sys.getenv("CRAN", "https://p3m.dev/cran/__linux__/noble/latest")),
  Ncpus = max(1L, parallel::detectCores(logical = TRUE) - 1L),
  timeout = 1200
)

package_groups <- list(
  core = c(
    "bslib",
    "DBI",
    "RSQLite",
    "rtrim"
  ),
  trim_lambda = c(
    "mgcv"
  ),
  gee = c(
    "broom",
    "geepack"
  ),
  glmm = c(
    "broom.mixed",
    "DHARMa",
    "glmmTMB",
    "lme4",
    "TMB"
  ),
  ordination = c(
    "vegan",
    "pls"
  ),
  changepoint = c(
    "changepoint",
    "strucchange"
  ),
  sem = c(
    "lavaan",
    "piecewiseSEM"
  ),
  beta_diversity = c(
    "betapart"
  ),
  occupancy = c(
    "unmarked"
  )
)

packages <- unique(unlist(package_groups, use.names = FALSE))
installed <- rownames(installed.packages())
missing <- setdiff(packages, installed)

if (length(missing)) {
  install.packages(missing)
}

still_missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(still_missing)) {
  stop("Ontbrekende R-packages na installatie: ", paste(still_missing, collapse = ", "))
}

cat("Shiny analysepackages beschikbaar:\n")
for (group_name in names(package_groups)) {
  cat(sprintf("- %s: %s\n", group_name, paste(package_groups[[group_name]], collapse = ", ")))
}
