#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORTER="$REPO_DIR/scripts/export_meijendel_sql.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TEST_DIR/bin"

cat > "$TEST_DIR/bin/ok" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

cat > "$TEST_DIR/bin/mysqldump" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' 'CREATE TABLE `voorbeeld` (`id` int);' '-- Dump completed on 2026-09-20 22:42:46'
SCRIPT

cat > "$TEST_DIR/bin/mysql" <<'SCRIPT'
#!/usr/bin/env bash
cat >/dev/null || true
SCRIPT

cat > "$TEST_DIR/bin/validator-fail" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT

cat > "$TEST_DIR/bin/validator-ok" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "--write-manifest" ]]
dump="$2"
manifest="$3"
candidate="$4"
[[ -s "$dump" && "$candidate" =~ ^codex_meijendel_export_check_[0-9]+$ ]]
hash="$(shasum -a 256 "$dump" | awk '{print $1}')"
bytes="$(stat -f '%z' "$dump")"
cat > "$manifest" <<EOF
format=meijendel-export-v1
source_database=Meijendel
sql_sha256=$hash
sql_bytes=$bytes
candidate=$candidate
EOF
SCRIPT

cat > "$TEST_DIR/bin/cache-builder-fail" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT

cat > "$TEST_DIR/bin/cache-builder-ok" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 4 ]]
Rscript - "$2" "$3" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
lines <- readLines(args[[1L]], warn = FALSE)
manifest <- stats::setNames(sub("^[^=]*=", "", lines), sub("=.*$", "", lines))
cache <- list(
  format = "meijendel-shiny-cache-v1",
  identity = list(
    format = "meijendel-shiny-cache-v1",
    sql_sha256 = manifest[["sql_sha256"]],
    sql_bytes = manifest[["sql_bytes"]],
    parser_version = "9"
  ),
  data = list(plots = data.frame())
)
saveRDS(cache, args[[2L]], version = 3)
RSCRIPT
cat <<'EOF'
CACHE_PARSER_VERSION=9
CACHE_R_VERSION=4.6.1
CACHE_SERIALIZATION_VERSION=3
CACHE_CREATED_AT=2026-09-21T12:00:00+0200
CACHE_SOURCE_COMMIT=uncommitted
EOF
SCRIPT

chmod +x "$TEST_DIR/bin/"*
dump="$TEST_DIR/Meijendel.sql"
manifest="$TEST_DIR/Meijendel.sql.manifest"
printf 'oude dump\n' > "$dump"
printf 'oud manifest\n' > "$manifest"

if PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-fail" \
  "$EXPORTER" "$dump" "$manifest" >/dev/null 2>&1; then
  fail "export met falende proefvalidatie werd geaccepteerd."
fi
[[ "$(cat "$dump")" == "oude dump" ]] || fail "oude dump werd vóór validatie overschreven."
[[ "$(cat "$manifest")" == "oud manifest" ]] || fail "oud manifest werd vóór validatie overschreven."

if PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-ok" \
  MEIJENDEL_CACHE_BUILDER="$TEST_DIR/bin/cache-builder-fail" \
  "$EXPORTER" "$dump" "$manifest" >/dev/null 2>&1; then
  fail "export met falende cachebouw werd geaccepteerd."
fi
[[ "$(cat "$dump")" == "oude dump" ]] || fail "falende cachebouw overschreef oude dump."
[[ "$(cat "$manifest")" == "oud manifest" ]] || fail "falende cachebouw overschreef oud manifest."
compgen -G "$TEST_DIR/meijendel_tables_cache-p*.rds" >/dev/null && fail "falende cachebouw liet een gepubliceerde cache achter."

PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-ok" \
  MEIJENDEL_CACHE_BUILDER="$TEST_DIR/bin/cache-builder-ok" \
  "$EXPORTER" "$dump" "$manifest" >/dev/null

grep -q 'Dump completed' "$dump" || fail "gevalideerde nieuwe dump werd niet geactiveerd."
grep -q 'candidate=codex_meijendel_export_check_' "$manifest" || fail "nieuw manifest werd niet geactiveerd."
cache_file="$(awk -F= '$1 == "cache_file" {print $2}' "$manifest")"
cache_manifest="$(awk -F= '$1 == "cache_manifest" {print $2}' "$manifest")"
[[ "$cache_file" =~ ^meijendel_tables_cache-p9-[0-9a-f]{64}\.rds$ ]] || fail "cachebestand heeft geen veilige inhoudsgebonden naam."
[[ "$cache_manifest" == "${cache_file%.rds}.manifest" ]] || fail "cachemanifestnaam past niet bij cachebestand."
[[ -s "$TEST_DIR/$cache_file" ]] || fail "gepubliceerde cache ontbreekt."
[[ -s "$TEST_DIR/$cache_manifest" ]] || fail "gepubliceerd cachemanifest ontbreekt."
grep -Fq "cache_sha256=$(shasum -a 256 "$TEST_DIR/$cache_file" | awk '{print $1}')" "$TEST_DIR/$cache_manifest" || fail "cachehash ontbreekt of wijkt af."
compgen -G "$TEST_DIR/Meijendel.sql.next.*" >/dev/null && fail "tijdelijke dump bleef achter."
compgen -G "$TEST_DIR/*.next.*" >/dev/null && fail "tijdelijk exportartefact bleef achter."

stale_hash="$(printf 'c%.0s' {1..64})"
stale_cache="$TEST_DIR/meijendel_tables_cache-p8-$stale_hash.rds"
stale_manifest="$TEST_DIR/meijendel_tables_cache-p8-$stale_hash.manifest"
printf 'verouderde cache\n' > "$stale_cache"
printf 'verouderd manifest\n' > "$stale_manifest"

reuse_output="$(PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-ok" \
  MEIJENDEL_CACHE_BUILDER="$TEST_DIR/bin/cache-builder-fail" \
  "$EXPORTER" "$dump" "$manifest")" || fail "geldige bestaande cache werd niet hergebruikt."
[[ "$reuse_output" == *"CACHE_REUSED=TRUE"* ]] || fail "export meldde hergebruik van geldige cache niet."
[[ ! -e "$stale_cache" && ! -e "$stale_manifest" ]] || fail "export behield niet-actuele lokale cacheartefacten."

printf 'beschadigd\n' > "$TEST_DIR/$cache_file"
rebuild_output="$(PATH="$TEST_DIR/bin:$PATH" \
  MEIJENDEL_WORKSPACE_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_VERSION_GUARD="$TEST_DIR/bin/ok" \
  MEIJENDEL_MYSQL_BIN="$TEST_DIR/bin/mysql" \
  MEIJENDEL_MYSQLDUMP_BIN="$TEST_DIR/bin/mysqldump" \
  MEIJENDEL_EXPORT_VALIDATOR="$TEST_DIR/bin/validator-ok" \
  MEIJENDEL_CACHE_BUILDER="$TEST_DIR/bin/cache-builder-ok" \
  "$EXPORTER" "$dump" "$manifest")"
[[ "$rebuild_output" == *"CACHE_REUSED=FALSE"* ]] || fail "beschadigde cache werd niet opnieuw gebouwd."
Rscript -e 'readRDS(commandArgs(TRUE)[[1]])' "$TEST_DIR/$cache_file" >/dev/null || fail "herbouwde cache is geen leesbare RDS."

printf 'OK: export publiceert dump, manifest en gevalideerde Shiny-cache pas als gekoppelde set.\n'
