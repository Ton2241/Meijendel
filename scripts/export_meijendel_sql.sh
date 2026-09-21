#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DUMP_FILE="${1:-$REPO_DIR/meijendel.sql}"
MANIFEST_FILE="${2:-$REPO_DIR/meijendel.sql.manifest}"
MYSQL_DATABASE="${MEIJENDEL_MYSQL_DATABASE:-Meijendel}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_LOGIN_PATH="${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}"

if [[ -d /usr/local/mysql/bin ]]; then
  PATH="/usr/local/mysql/bin:$PATH"
fi

WORKSPACE_GUARD="${MEIJENDEL_WORKSPACE_GUARD:-$REPO_DIR/scripts/check_local_workspace.sh}"
MYSQL_VERSION_GUARD="${MEIJENDEL_MYSQL_VERSION_GUARD:-$REPO_DIR/scripts/check_mysql_version.sh}"
MYSQL_BIN="${MEIJENDEL_MYSQL_BIN:-$(command -v mysql)}"
MYSQLDUMP_BIN="${MEIJENDEL_MYSQLDUMP_BIN:-$(command -v mysqldump)}"
VALIDATOR="${MEIJENDEL_EXPORT_VALIDATOR:-$REPO_DIR/scripts/validate_meijendel_export.sh}"
CACHE_BUILDER="${MEIJENDEL_CACHE_BUILDER:-$REPO_DIR/scripts/build_meijendel_shiny_cache.R}"
CACHE_HELPERS="${MEIJENDEL_CACHE_HELPERS:-$REPO_DIR/shiny_meijendel/helpers.R}"
NEXT_DUMP="${DUMP_FILE}.next.$$"
NEXT_MANIFEST="${MANIFEST_FILE}.next.$$"
CANDIDATE_SCHEMA="codex_meijendel_export_check_$$"
candidate_created=0
NEXT_CACHE=""
NEXT_CACHE_MANIFEST=""
CACHE_STAGE_DIR=""

die() {
  printf 'BLOKKADE: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  rm -f "$NEXT_DUMP" "$NEXT_MANIFEST"
  [[ -z "$NEXT_CACHE" ]] || rm -f "$NEXT_CACHE"
  [[ -z "$NEXT_CACHE_MANIFEST" ]] || rm -f "$NEXT_CACHE_MANIFEST"
  [[ -z "$CACHE_STAGE_DIR" ]] || rmdir "$CACHE_STAGE_DIR" 2>/dev/null || true
  if [[ "$candidate_created" -eq 1 ]]; then
    "$MYSQL_BIN" --login-path="$MYSQL_LOGIN_PATH" --protocol=tcp \
      --host="$MYSQL_HOST" --port="$MYSQL_PORT" \
      -e "DROP DATABASE IF EXISTS \`$CANDIDATE_SCHEMA\`" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

[[ $# -le 2 ]] || die "gebruik: scripts/export_meijendel_sql.sh [DUMP [MANIFEST]]"
[[ "$MYSQL_DATABASE" == "Meijendel" ]] || die "canonieke brondatabase moet exact Meijendel heten."
[[ ! -L "$DUMP_FILE" && ! -L "$MANIFEST_FILE" ]] || die "dump en manifest mogen geen symlink zijn."
[[ -x "$WORKSPACE_GUARD" && -x "$MYSQL_VERSION_GUARD" && -x "$VALIDATOR" && -x "$CACHE_BUILDER" ]] || die "vereiste exporthelper ontbreekt of is niet uitvoerbaar."
[[ -f "$CACHE_HELPERS" ]] || die "Shiny-helpers ontbreken: $CACHE_HELPERS"

"$WORKSPACE_GUARD"
"$MYSQL_VERSION_GUARD"

"$MYSQLDUMP_BIN" --login-path="$MYSQL_LOGIN_PATH" \
  --no-tablespaces \
  --complete-insert \
  --single-transaction \
  --set-gtid-purged=OFF \
  --skip-dump-date \
  --protocol=tcp \
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  --routines \
  --triggers \
  --events \
  "$MYSQL_DATABASE" > "$NEXT_DUMP"

printf '\n-- Dump completed on deterministic export\n' >> "$NEXT_DUMP"
grep -q -- '-- Dump completed on ' "$NEXT_DUMP" || die "nieuwe dump mist de eindmarkering."
chmod 644 "$NEXT_DUMP"

"$MYSQL_BIN" --login-path="$MYSQL_LOGIN_PATH" --protocol=tcp \
  --host="$MYSQL_HOST" --port="$MYSQL_PORT" \
  -e "CREATE DATABASE \`$CANDIDATE_SCHEMA\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
candidate_created=1
"$MYSQL_BIN" --login-path="$MYSQL_LOGIN_PATH" --protocol=tcp \
  --host="$MYSQL_HOST" --port="$MYSQL_PORT" \
  "$CANDIDATE_SCHEMA" < "$NEXT_DUMP"

"$VALIDATOR" --write-manifest "$NEXT_DUMP" "$NEXT_MANIFEST" "$CANDIDATE_SCHEMA"

manifest_value() {
  local key="$1" file="$2" value
  value="$(awk -F= -v key="$key" '$1 == key {print substr($0, length(key) + 2)}' "$file")"
  [[ -n "$value" && "$(printf '%s\n' "$value" | wc -l | tr -d ' ')" -eq 1 ]] || \
    die "manifestveld ontbreekt of is niet uniek: $key"
  printf '%s\n' "$value"
}

SQL_SHA256="$(manifest_value sql_sha256 "$NEXT_MANIFEST")"
SQL_BYTES="$(manifest_value sql_bytes "$NEXT_MANIFEST")"
[[ "$SQL_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "dumpmanifest bevat geen geldige sql_sha256."
[[ "$SQL_BYTES" =~ ^[0-9]+$ && "$SQL_BYTES" -gt 0 ]] || die "dumpmanifest bevat geen geldige sql_bytes."
PARSER_VERSION="$(Rscript - "$CACHE_HELPERS" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
source(args[[1L]])
cat(MEIJENDEL_PARSER_CACHE_VERSION)
RSCRIPT
)"
[[ "$PARSER_VERSION" =~ ^[1-9][0-9]*$ ]] || die "ongeldige Shiny-parser-versie: $PARSER_VERSION"

DUMP_DIR="$(cd "$(dirname "$DUMP_FILE")" && pwd)"
CACHE_FILE="meijendel_tables_cache-p${PARSER_VERSION}-${SQL_SHA256}.rds"
CACHE_MANIFEST_FILE="${CACHE_FILE%.rds}.manifest"
CACHE_PATH="$DUMP_DIR/$CACHE_FILE"
CACHE_MANIFEST_PATH="$DUMP_DIR/$CACHE_MANIFEST_FILE"
CACHE_STAGE_DIR="$DUMP_DIR/.meijendel-cache-stage.$$"
mkdir -m 0700 "$CACHE_STAGE_DIR"
NEXT_CACHE="$CACHE_STAGE_DIR/$CACHE_FILE"
NEXT_CACHE_MANIFEST="$CACHE_STAGE_DIR/$CACHE_MANIFEST_FILE"
SOURCE_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || printf 'uncommitted')"

cache_reusable=0
if [[ -f "$CACHE_PATH" && ! -L "$CACHE_PATH" && -f "$CACHE_MANIFEST_PATH" && ! -L "$CACHE_MANIFEST_PATH" ]]; then
  expected_cache_hash="$(awk -F= '$1 == "cache_sha256" {print $2}' "$CACHE_MANIFEST_PATH")"
  recorded_sql_hash="$(awk -F= '$1 == "sql_sha256" {print $2}' "$CACHE_MANIFEST_PATH")"
  recorded_sql_bytes="$(awk -F= '$1 == "sql_bytes" {print $2}' "$CACHE_MANIFEST_PATH")"
  recorded_parser="$(awk -F= '$1 == "parser_version" {print $2}' "$CACHE_MANIFEST_PATH")"
  actual_cache_hash="$(shasum -a 256 "$CACHE_PATH" | awk '{print $1}')"
  if [[ "$expected_cache_hash" == "$actual_cache_hash" && "$recorded_sql_hash" == "$SQL_SHA256" && "$recorded_sql_bytes" == "$SQL_BYTES" && "$recorded_parser" == "$PARSER_VERSION" ]]; then
    if Rscript - "$CACHE_PATH" "$NEXT_MANIFEST" "$CACHE_HELPERS" >/dev/null <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
cache <- readRDS(args[[1L]])
source(args[[3L]])
identity <- meijendel_cache_identity_from_manifest(args[[2L]], MEIJENDEL_PARSER_CACHE_VERSION)
validate_meijendel_cache(cache, identity)
RSCRIPT
    then
      cache_reusable=1
    fi
  fi
fi

if [[ "$cache_reusable" -eq 1 ]]; then
  cp -p "$CACHE_PATH" "$NEXT_CACHE"
  cp -p "$CACHE_MANIFEST_PATH" "$NEXT_CACHE_MANIFEST"
  printf 'CACHE_REUSED=TRUE\n'
else
  builder_output="$(MEIJENDEL_SOURCE_COMMIT="$SOURCE_COMMIT" "$CACHE_BUILDER" "$NEXT_DUMP" "$NEXT_MANIFEST" "$NEXT_CACHE" "$CACHE_HELPERS")" || \
    die "lokale Shiny-cachebouw is mislukt."
  printf '%s\n' "$builder_output"
  CACHE_R_VERSION="$(printf '%s\n' "$builder_output" | sed -n 's/^CACHE_R_VERSION=//p')"
  CACHE_SERIALIZATION_VERSION="$(printf '%s\n' "$builder_output" | sed -n 's/^CACHE_SERIALIZATION_VERSION=//p')"
  CACHE_CREATED_AT="$(printf '%s\n' "$builder_output" | sed -n 's/^CACHE_CREATED_AT=//p')"
  CACHE_SOURCE_COMMIT="$(printf '%s\n' "$builder_output" | sed -n 's/^CACHE_SOURCE_COMMIT=//p')"
  [[ -n "$CACHE_R_VERSION" && "$CACHE_SERIALIZATION_VERSION" == "3" && -n "$CACHE_CREATED_AT" ]] || \
    die "cachebuilder gaf onvolledige metadata."
  CACHE_HASH="$(shasum -a 256 "$NEXT_CACHE" | awk '{print $1}')"
  CACHE_BYTES="$(stat -f '%z' "$NEXT_CACHE")"
  cat > "$NEXT_CACHE_MANIFEST" <<EOF
format=meijendel-shiny-cache-manifest-v1
sql_sha256=$SQL_SHA256
sql_bytes=$SQL_BYTES
parser_version=$PARSER_VERSION
cache_sha256=$CACHE_HASH
cache_bytes=$CACHE_BYTES
r_version=$CACHE_R_VERSION
serialization_version=$CACHE_SERIALIZATION_VERSION
created_at=$CACHE_CREATED_AT
source_commit=$CACHE_SOURCE_COMMIT
cache_file=$CACHE_FILE
EOF
  printf 'CACHE_REUSED=FALSE\n'
fi

printf 'cache_file=%s\ncache_manifest=%s\n' "$CACHE_FILE" "$CACHE_MANIFEST_FILE" >> "$NEXT_MANIFEST"
chmod 644 "$NEXT_MANIFEST"
chmod 644 "$NEXT_CACHE" "$NEXT_CACHE_MANIFEST"
"$VALIDATOR" --with-cache "$NEXT_DUMP" "$NEXT_MANIFEST" "$CACHE_STAGE_DIR"
mv "$NEXT_CACHE" "$CACHE_PATH"
NEXT_CACHE=""
mv "$NEXT_CACHE_MANIFEST" "$CACHE_MANIFEST_PATH"
NEXT_CACHE_MANIFEST=""
rmdir "$CACHE_STAGE_DIR"
CACHE_STAGE_DIR=""
mv "$NEXT_DUMP" "$DUMP_FILE"
mv "$NEXT_MANIFEST" "$MANIFEST_FILE"

while IFS= read -r -d '' old_cache_artifact; do
  old_basename="$(basename "$old_cache_artifact")"
  if [[ "$old_basename" != "$CACHE_FILE" && "$old_basename" != "$CACHE_MANIFEST_FILE" && \
        "$old_basename" =~ ^meijendel_tables_cache-p[1-9][0-9]*-[0-9a-f]{64}\.(rds|manifest)$ ]]; then
    rm -f -- "$old_cache_artifact"
  fi
done < <(find "$DUMP_DIR" -maxdepth 1 -type f \
  \( -name 'meijendel_tables_cache-p*.rds' -o -name 'meijendel_tables_cache-p*.manifest' \) -print0)

printf 'SQL_EXPORT=%s\n' "$DUMP_FILE"
printf 'SQL_MANIFEST=%s\n' "$MANIFEST_FILE"
printf 'SQL_SHA256=%s\n' "$(shasum -a 256 "$DUMP_FILE" | awk '{print $1}')"
printf 'CACHE_FILE=%s\n' "$CACHE_PATH"
printf 'CACHE_MANIFEST=%s\n' "$CACHE_MANIFEST_PATH"
printf 'EXPORT_STATUS=ready\n'
