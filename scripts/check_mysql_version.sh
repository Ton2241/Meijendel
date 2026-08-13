#!/usr/bin/env bash
set -euo pipefail

REQUIRED_MYSQL_VERSION="9.7.1"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_LOGIN_PATH="${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}"

die() {
  printf 'BLOKKADE: %s\n' "$*" >&2
  exit 1
}

extract_tool_version() {
  sed -nE 's/.* Ver ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

if [[ "${1:-}" == "--required-version" ]]; then
  printf '%s\n' "$REQUIRED_MYSQL_VERSION"
  exit 0
fi
[[ $# -eq 0 ]] || die "onbekende optie: $1"

MYSQL_BIN="$(command -v mysql 2>/dev/null || true)"
MYSQLDUMP_BIN="$(command -v mysqldump 2>/dev/null || true)"
if [[ -z "$MYSQL_BIN" && -x /usr/local/mysql/bin/mysql ]]; then
  MYSQL_BIN="/usr/local/mysql/bin/mysql"
fi
if [[ -z "$MYSQLDUMP_BIN" && -x /usr/local/mysql/bin/mysqldump ]]; then
  MYSQLDUMP_BIN="/usr/local/mysql/bin/mysqldump"
fi
[[ -n "$MYSQL_BIN" ]] || die "mysql-client ontbreekt in PATH en /usr/local/mysql/bin."
[[ -n "$MYSQLDUMP_BIN" ]] || die "mysqldump ontbreekt in PATH en /usr/local/mysql/bin."

mysql_version="$("$MYSQL_BIN" --no-defaults --version | extract_tool_version)"
mysqldump_version="$("$MYSQLDUMP_BIN" --no-defaults --version | extract_tool_version)"
[[ -n "$mysql_version" ]] || die "versie van mysql-client kon niet worden bepaald."
[[ -n "$mysqldump_version" ]] || die "versie van mysqldump kon niet worden bepaald."
[[ "$mysql_version" == "$REQUIRED_MYSQL_VERSION" ]] || \
  die "mysql-client is $mysql_version; vereist is exact $REQUIRED_MYSQL_VERSION."
[[ "$mysqldump_version" == "$REQUIRED_MYSQL_VERSION" ]] || \
  die "mysqldump is $mysqldump_version; vereist is exact $REQUIRED_MYSQL_VERSION."

server_version="$(
  "$MYSQL_BIN" --no-defaults \
    --login-path="$MYSQL_LOGIN_PATH" \
    --protocol=tcp \
    --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --batch \
    --skip-column-names \
    -e 'SELECT VERSION()' 2>/dev/null
)" || die "lokale MySQL-server is niet bereikbaar via login-path $MYSQL_LOGIN_PATH op $MYSQL_HOST:$MYSQL_PORT."
[[ "$server_version" == "$REQUIRED_MYSQL_VERSION" ]] || \
  die "lokale MySQL-server is $server_version; vereist is exact $REQUIRED_MYSQL_VERSION."

printf 'OK: MySQL lokaal exact %s (server, mysql en mysqldump).\n' "$REQUIRED_MYSQL_VERSION"
