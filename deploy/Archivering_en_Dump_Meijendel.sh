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
MYSQL_LOGIN_PATH="${MEIJENDEL_MYSQL_LOGIN_PATH:-meijendel_root}"
MYSQL_SOURCES_DATABASE="${MEIJENDEL_SOURCES_MYSQL_DATABASE:-Meijendel_bronnen}"

if [[ -d /usr/local/mysql/bin ]]; then
  PATH="/usr/local/mysql/bin:$PATH"
fi

DUMP_DIR="${DUMP_DIR:-/Volumes/T7 Data/Home_Ton/Prive/Hobbies/IT/Meijendel Database/Archief/SQL exports}"
ARCHIVE_DUMP_FILE="$DUMP_DIR/meijendel_$(date +%Y%m%d_%H%M%S).sql"
ARCHIVE_MANIFEST_FILE="${ARCHIVE_DUMP_FILE}.manifest"
ARCHIVE_SOURCES_DUMP_FILE="$DUMP_DIR/meijendel_bronnen_$(date +%Y%m%d_%H%M%S).sql"
REPO_DUMP_FILE="$REPO_DIR/meijendel.sql"
REPO_MANIFEST_FILE="$REPO_DIR/meijendel.sql.manifest"
REPO_SOURCES_DUMP_FILE="$REPO_DIR/meijendel_bronnen.sql"

"$REPO_DIR/scripts/check_local_workspace.sh"
"$REPO_DIR/scripts/check_mysql_version.sh"

if [ ! -d "$DUMP_DIR" ]; then
  printf 'FOUT: dumpmap bestaat niet of externe schijf is niet gekoppeld: %s\n' "$DUMP_DIR" >&2
  exit 1
fi

printf 'Actualiseer repo-dump...\n'
"$REPO_DIR/scripts/export_meijendel_sql.sh" "$REPO_DUMP_FILE" "$REPO_MANIFEST_FILE"
printf 'Repo-dump geschreven: %s\n' "$REPO_DUMP_FILE"
shasum -a 256 "$REPO_DUMP_FILE"

printf 'Actualiseer afzonderlijke bron-dump...\n'
mysqldump --login-path="$MYSQL_LOGIN_PATH" \
  --no-tablespaces --complete-insert --single-transaction \
  --set-gtid-purged=OFF --routines --triggers --events \
  "$MYSQL_SOURCES_DATABASE" > "$REPO_SOURCES_DUMP_FILE"
for required in \
  'CREATE TABLE `bron`' \
  'CREATE TABLE `literatuur`' \
  'VIEW `v_bron_catalogus`' \
  'VIEW `v_literatuur_overzicht`' \
  'VIEW `v_contextdataset_overzicht`'; do
  grep -qF "$required" "$REPO_SOURCES_DUMP_FILE" || {
    printf 'FOUT: vereist bronobject ontbreekt: %s\n' "$required" >&2
    exit 1
  }
done
printf 'Bron-dump geschreven: %s\n' "$REPO_SOURCES_DUMP_FILE"
shasum -a 256 "$REPO_SOURCES_DUMP_FILE"

printf 'Archiveer repo-dump op T7...\n'
cp -p "$REPO_DUMP_FILE" "$ARCHIVE_DUMP_FILE"
cp -p "$REPO_MANIFEST_FILE" "$ARCHIVE_MANIFEST_FILE"
printf 'Archiefdump geschreven: %s\n' "$ARCHIVE_DUMP_FILE"
shasum -a 256 "$ARCHIVE_DUMP_FILE"

printf 'Archiveer bron-dump afzonderlijk op T7...\n'
cp -p "$REPO_SOURCES_DUMP_FILE" "$ARCHIVE_SOURCES_DUMP_FILE"
printf 'Bron-archiefdump geschreven: %s\n' "$ARCHIVE_SOURCES_DUMP_FILE"
shasum -a 256 "$ARCHIVE_SOURCES_DUMP_FILE"
