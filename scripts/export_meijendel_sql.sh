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
NEXT_DUMP="${DUMP_FILE}.next.$$"
NEXT_MANIFEST="${MANIFEST_FILE}.next.$$"
CANDIDATE_SCHEMA="codex_meijendel_export_check_$$"
candidate_created=0

die() {
  printf 'BLOKKADE: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  rm -f "$NEXT_DUMP" "$NEXT_MANIFEST"
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
[[ -x "$WORKSPACE_GUARD" && -x "$MYSQL_VERSION_GUARD" && -x "$VALIDATOR" ]] || die "vereiste exporthelper ontbreekt of is niet uitvoerbaar."

"$WORKSPACE_GUARD"
"$MYSQL_VERSION_GUARD"

"$MYSQLDUMP_BIN" --login-path="$MYSQL_LOGIN_PATH" \
  --no-tablespaces \
  --complete-insert \
  --single-transaction \
  --set-gtid-purged=OFF \
  --protocol=tcp \
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  --routines \
  --triggers \
  --events \
  "$MYSQL_DATABASE" > "$NEXT_DUMP"

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
chmod 644 "$NEXT_MANIFEST"
mv "$NEXT_DUMP" "$DUMP_FILE"
mv "$NEXT_MANIFEST" "$MANIFEST_FILE"

printf 'SQL_EXPORT=%s\n' "$DUMP_FILE"
printf 'SQL_MANIFEST=%s\n' "$MANIFEST_FILE"
printf 'SQL_SHA256=%s\n' "$(shasum -a 256 "$DUMP_FILE" | awk '{print $1}')"
printf 'EXPORT_STATUS=ready\n'
