#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER="$REPO_DIR/scripts/build_meijendel_shiny_cache.R"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

dump="$TEST_DIR/meijendel.sql"
manifest="$TEST_DIR/meijendel.sql.manifest"
cache="$TEST_DIR/cache.rds"
helpers="$TEST_DIR/helpers.R"
failing_helpers="$TEST_DIR/helpers-fail.R"

printf '%s\n' 'kleine SQL-fixture' > "$dump"
cat > "$manifest" <<EOF
format=meijendel-export-v1
sql_sha256=$(printf 'a%.0s' {1..64})
sql_bytes=20
EOF

cat > "$helpers" <<'RSCRIPT'
MEIJENDEL_CACHE_FORMAT <- "meijendel-shiny-cache-v1"
MEIJENDEL_PARSER_CACHE_VERSION <- 9L
read_meijendel_manifest <- function(path) {
  lines <- readLines(path, warn = FALSE)
  stats::setNames(sub("^[^=]*=", "", lines), sub("=.*$", "", lines))
}
meijendel_cache_identity <- function(sql_sha256, sql_bytes, parser_version) {
  list(
    format = MEIJENDEL_CACHE_FORMAT,
    sql_sha256 = as.character(sql_sha256),
    sql_bytes = as.character(sql_bytes),
    parser_version = as.character(parser_version)
  )
}
meijendel_cache_identity_from_manifest <- function(manifest, parser_version) {
  meijendel_cache_identity(manifest[["sql_sha256"]], manifest[["sql_bytes"]], parser_version)
}
validate_meijendel_cache <- function(cache, expected_identity, required_data = character()) {
  stopifnot(identical(cache$format, MEIJENDEL_CACHE_FORMAT))
  stopifnot(identical(cache$identity, expected_identity))
  stopifnot(is.list(cache$data), all(required_data %in% names(cache$data)))
  TRUE
}
parse_meijendel_tables <- function(path) {
  list(plots = data.frame(plot_id = 1L), sql_path = normalizePath(path))
}
RSCRIPT

cat > "$failing_helpers" <<'RSCRIPT'
source(Sys.getenv("WORKING_HELPERS"))
parse_meijendel_tables <- function(path) stop("bedoelde parserfout")
RSCRIPT

if [[ ! -x "$BUILDER" ]]; then
  fail "cachebuilder ontbreekt of is niet uitvoerbaar: $BUILDER"
fi

MEIJENDEL_SOURCE_COMMIT="$(printf 'b%.0s' {1..40})" \
  "$BUILDER" "$dump" "$manifest" "$cache" "$helpers" >/dev/null
[[ -s "$cache" ]] || fail "builder schreef geen RDS-cache"

Rscript - "$cache" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
cache <- readRDS(args[[1L]])
stopifnot(identical(cache$format, "meijendel-shiny-cache-v1"))
stopifnot(identical(cache$identity$sql_sha256, paste(rep("a", 64), collapse = "")))
stopifnot(identical(cache$identity$sql_bytes, "20"))
stopifnot(identical(cache$identity$parser_version, "9"))
stopifnot(identical(cache$source_commit, paste(rep("b", 40), collapse = "")))
stopifnot(identical(cache$serialization_version, 3L))
stopifnot(identical(cache$data$plots$plot_id, 1L))
RSCRIPT

before_hash="$(shasum -a 256 "$cache" | awk '{print $1}')"
if WORKING_HELPERS="$helpers" "$BUILDER" "$dump" "$manifest" "$cache" "$failing_helpers" >/dev/null 2>&1; then
  fail "builder accepteerde een falende parser"
fi
after_hash="$(shasum -a 256 "$cache" | awk '{print $1}')"
[[ "$after_hash" == "$before_hash" ]] || fail "falende builder overschreef bestaande cache"

printf 'OK: lokale Shiny-cachebuilder schrijft een gevalideerde RDS en bewaart bestaande cache bij fouten.\n'
