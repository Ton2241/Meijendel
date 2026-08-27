#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image=""

if [[ "$#" -gt 0 ]]; then
  [[ "$#" -eq 2 && "$1" == "--image" ]] || {
    printf 'Gebruik: scripts/test_shiny_reproducibility.sh [--image IMAGE]\n' >&2
    exit 2
  }
  image="$2"
fi

"$repo/scripts/check_local_workspace.sh" "$repo/renv.lock" "$repo/DESCRIPTION"

Rscript - "$repo/renv.lock" "$repo/DESCRIPTION" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
lock <- jsonlite::read_json(args[[1L]], simplifyVector = FALSE)
description_fields <- read.dcf(args[[2L]])
imports <- trimws(strsplit(description_fields[1L, "Imports"], ",", fixed = TRUE)[[1L]])
imports <- sub("[[:space:]]*\\(.*$", "", imports)
lock_versions <- vapply(lock$Packages, `[[`, character(1L), "Version")
stopifnot(identical(lock$R$Version, "4.6.1"))
stopifnot(identical(
  lock$R$Repositories[[1L]]$URL,
  "https://p3m.dev/cran/__linux__/noble/2026-08-18"
))
stopifnot(length(lock_versions) == 191L)
stopifnot(length(setdiff(imports, names(lock_versions))) == 0L)
runtime_required <- c(
  "geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange",
  "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked"
)
stopifnot(length(setdiff(runtime_required, imports)) == 0L)
stopifnot(all(vapply(lock$Packages, function(record) {
  identical(record$Source, "Repository") && identical(record$Repository, "CRAN")
}, logical(1L))))
cat("GROEN: lockfile, R-versie, snapshot en DESCRIPTION zijn consistent.\n")
RS

dockerfile="$repo/deploy/shiny_image/Dockerfile"
installer="$repo/deploy/shiny_image/install_shiny_packages.R"
! grep -Fq '/latest' "$dockerfile"
grep -Fq '2026-08-18' "$dockerfile"
grep -Fq 'renv::restore' "$installer"
grep -Fq 'clean = TRUE' "$installer"
grep -Fq 'Packageversies wijken af' "$installer"
grep -Fq 'Niet-vergrendelde site-librarypackages' "$installer"

bash -n "$repo/scripts/generate_shiny_sbom.sh"
bash -n "$repo/deploy/rebuild_shiny_image_vps.sh"

if [[ -n "$image" ]]; then
  [[ "$(docker image inspect --format '{{.Architecture}}' "$image")" == "amd64" ]]
  docker run --rm --platform linux/amd64 --entrypoint Rscript "$image" \
    /opt/vwgm-build/install_shiny_packages.R \
    /opt/vwgm-build/renv.lock /opt/vwgm-build/DESCRIPTION validate
  image_environment="$(docker image inspect --format '{{json .Config.Env}}' "$image")"
  grep -Fq 'RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/2026-08-18' \
    <<<"$image_environment"
  ! grep -Fq '/latest' <<<"$image_environment"
  printf 'GROEN: kandidaatimage %s gebruikt exact R, lock en snapshot.\n' "$image"
fi
