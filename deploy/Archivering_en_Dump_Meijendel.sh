#!/usr/bin/env bash
set -euo pipefail

# Archivering_en_Dump Meijendel.sql
# Actualiseert eerst de repo-dump meijendel.sql vanuit de lokale database.
# Archiveert daarna diezelfde dump met timestamp op de Samsung T7.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_DATABASE="${MYSQL_DATABASE:-meijendel}"

DUMP_DIR="${DUMP_DIR:-/Volumes/T7 Data/Home_Ton/Prive/Hobbies/IT/Meijendel Database/Archief/SQL exports}"
ARCHIVE_DUMP_FILE="$DUMP_DIR/meijendel_$(date +%Y%m%d_%H%M%S).sql"
REPO_DUMP_FILE="$REPO_DIR/meijendel.sql"

if [ ! -d "$DUMP_DIR" ]; then
  printf 'FOUT: dumpmap bestaat niet of externe schijf is niet gekoppeld: %s\n' "$DUMP_DIR" >&2
  exit 1
fi

dump_database() {
  local output_file="$1"

  mysqldump --no-defaults \
    --no-tablespaces \
    --complete-insert \
    --single-transaction \
    --set-gtid-purged=OFF \
    --protocol=tcp \
    --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    -u"$MYSQL_USER" -p \
    --routines \
    --triggers \
    --events \
    "$MYSQL_DATABASE" > "$output_file"
}

printf 'Actualiseer repo-dump...\n'
dump_database "$REPO_DUMP_FILE"
printf 'Repo-dump geschreven: %s\n' "$REPO_DUMP_FILE"
shasum -a 256 "$REPO_DUMP_FILE"

printf 'Archiveer repo-dump op T7...\n'
cp -p "$REPO_DUMP_FILE" "$ARCHIVE_DUMP_FILE"
printf 'Archiefdump geschreven: %s\n' "$ARCHIVE_DUMP_FILE"
shasum -a 256 "$ARCHIVE_DUMP_FILE"
