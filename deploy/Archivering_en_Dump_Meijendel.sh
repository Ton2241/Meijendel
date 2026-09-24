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
MYSQL_SOURCES_DATABASE="${MEIJENDEL_SOURCES_MYSQL_DATABASE:-Meijendel_bronnen}"

if [[ -d /usr/local/mysql/bin ]]; then
  PATH="/usr/local/mysql/bin:$PATH"
fi

DUMP_DIR="${DUMP_DIR:-/Volumes/T7 Data/Home_Ton/Prive/Hobbies/IT/Meijendel Database/Archief/SQL exports}"
ARCHIVE_DUMP_FILE="$DUMP_DIR/meijendel_$(date +%Y%m%d_%H%M%S).sql"
ARCHIVE_SOURCES_DUMP_FILE="$DUMP_DIR/meijendel_bronnen_$(date +%Y%m%d_%H%M%S).sql"
REPO_DUMP_FILE="$REPO_DIR/meijendel.sql"
REPO_SOURCES_DUMP_FILE="$REPO_DIR/meijendel_bronnen.sql"

"$REPO_DIR/scripts/check_local_workspace.sh"
"$REPO_DIR/scripts/check_mysql_version.sh"

if [ ! -d "$DUMP_DIR" ]; then
  printf 'FOUT: dumpmap bestaat niet of externe schijf is niet gekoppeld: %s\n' "$DUMP_DIR" >&2
  exit 1
fi

dump_database() {
  local database="$1"
  local output_file="$2"

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
    "$database" > "$output_file"
}

validate_sources_schema() {
  local dump_file="$1"
  local required
  for required in \
    'CREATE TABLE `bron`' \
    'CREATE TABLE `literatuur`' \
    'VIEW `v_bron_catalogus`' \
    'VIEW `v_literatuur_overzicht`' \
    'VIEW `v_contextdataset_overzicht`'; do
    grep -qF "$required" "$dump_file" || {
      printf 'FOUT: vereist bronobject ontbreekt in %s: %s\n' "$dump_file" "$required" >&2
      return 1
    }
  done
}

validate_tellers_schema() {
  LC_ALL=C awk '
    /^CREATE TABLE `tellers`/ { in_tellers = 1; seen = 1 }
    in_tellers && /`id` int/ { has_id = 1 }
    in_tellers && /`tellercode` varchar/ { has_code = 1 }
    in_tellers && /`(voornaam|tussenvoegsel|achternaam|straat|huisnummer|postcode|woonplaats|telefoon_vast|telefoon_mobiel|email|soort_lid|bandnummer)`/ { bad = 1 }
    in_tellers && /ENGINE=InnoDB/ { done = 1; exit }
    END { if (!seen || !done || !has_id || !has_code || bad) exit 1 }
  ' "$1" || {
    printf 'FOUT: tellers ontbreekt of bevat meer dan id en tellercode: %s\n' "$1" >&2
    return 1
  }
}

printf 'Actualiseer repo-dump...\n'
dump_database "$MYSQL_DATABASE" "$REPO_DUMP_FILE"
validate_tellers_schema "$REPO_DUMP_FILE"
printf 'Repo-dump geschreven: %s\n' "$REPO_DUMP_FILE"
shasum -a 256 "$REPO_DUMP_FILE"

printf 'Actualiseer afzonderlijke bron-dump...\n'
dump_database "$MYSQL_SOURCES_DATABASE" "$REPO_SOURCES_DUMP_FILE"
validate_sources_schema "$REPO_SOURCES_DUMP_FILE"
printf 'Bron-dump geschreven: %s\n' "$REPO_SOURCES_DUMP_FILE"
shasum -a 256 "$REPO_SOURCES_DUMP_FILE"

printf 'Archiveer repo-dump op T7...\n'
cp -p "$REPO_DUMP_FILE" "$ARCHIVE_DUMP_FILE"
printf 'Archiefdump geschreven: %s\n' "$ARCHIVE_DUMP_FILE"
shasum -a 256 "$ARCHIVE_DUMP_FILE"

printf 'Archiveer bron-dump afzonderlijk op T7...\n'
cp -p "$REPO_SOURCES_DUMP_FILE" "$ARCHIVE_SOURCES_DUMP_FILE"
printf 'Bron-archiefdump geschreven: %s\n' "$ARCHIVE_SOURCES_DUMP_FILE"
shasum -a 256 "$ARCHIVE_SOURCES_DUMP_FILE"
