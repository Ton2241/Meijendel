#!/usr/bin/env bash
set -euo pipefail

stage="${1:-}"
release_commit="${2:-}"
release_sha256="${3:-}"
REMOTE_BASE="${MEIJENDEL_REMOTE_BASE:-/srv/vwgm}"
REMOTE_DATA="$REMOTE_BASE/data"
STATE_DIR="$REMOTE_BASE/deploy-state"
GLOBAL_LOCK="$STATE_DIR/production.lock"
STATE_FILE="$STATE_DIR/Meijendel_bronnen.release"
BACKUP_DIR="$REMOTE_BASE/backups/meijendel-bronnen-mysql"
CONTAINER="${MEIJENDEL_MYSQL_CONTAINER:-meijendel-mysql}"
SOURCES_DATABASE="Meijendel_bronnen"
SOURCES_SQL_FILE="$REMOTE_DATA/Meijendel_bronnen.sql"
SOURCES_SQL_CANDIDATE_FILE="$REMOTE_DATA/Meijendel_bronnen.sql.candidate-$release_commit-$release_sha256"
SOURCES_MANIFEST_CANDIDATE_FILE="$SOURCES_SQL_CANDIDATE_FILE.manifest"

success=0
import_started=0
activation_started=0
had_sources_database=0
had_sources_sql=0
backup_file=""
rollback_sources_sql="$REMOTE_DATA/Meijendel_bronnen.sql.rollback-$release_commit-$release_sha256"
expected_literature_total=""
expected_literature_active=""
expected_literature_removed=""
expected_literature_active_with_tags=""

die() { printf 'BLOKKADE|meijendel-bronnen-release|%s\n' "$*" >&2; exit 1; }

manifest_value() {
  local key="$1" file="$2" count value
  count="$(awk -F= -v key="$key" '$1 == key {count++} END {print count+0}' "$file")"
  [[ "$count" -eq 1 ]] || die "manifestveld $key ontbreekt of komt meermaals voor"
  value="$(awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print}' "$file")"
  [[ -n "$value" ]] || die "manifestveld $key is leeg"
  printf '%s\n' "$value"
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

file_bytes() {
  stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1"
}

root_mysql() {
  docker exec "$CONTAINER" sh -lc \
    'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$@"' sh "$@"
}

restore_sources_backup() {
  printf 'ROLLBACK|meijendel-bronnen-release|database=%s\n' "${backup_file:-not-present}" >&2
  if [[ "$had_sources_database" -eq 1 ]]; then
    [[ -s "$backup_file" ]] || return 1
    gzip -t "$backup_file"
    { printf 'SET SESSION sql_log_bin=0;\n'; gzip -dc "$backup_file"; } |
      docker exec -i "$CONTAINER" sh -lc 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
  else
    root_mysql -e "DROP DATABASE IF EXISTS ${SOURCES_DATABASE}"
  fi
}

restore_sources_file() {
  [[ "$activation_started" -eq 1 ]] || return 0
  rm -f "$SOURCES_SQL_FILE"
  if [[ "$had_sources_sql" -eq 1 ]]; then mv "$rollback_sources_sql" "$SOURCES_SQL_FILE"; fi
}

cleanup_candidates() {
  rm -f "$SOURCES_SQL_CANDIDATE_FILE" "$SOURCES_MANIFEST_CANDIDATE_FILE"
}

finish() {
  local status=$? rollback_ok=1
  trap - EXIT INT TERM
  if [[ "$success" -ne 1 && "$import_started" -eq 1 ]]; then
    restore_sources_backup || rollback_ok=0
    restore_sources_file || rollback_ok=0
    if [[ "$rollback_ok" -eq 1 ]]; then
      printf 'ROLLBACK_STATUS=ready\n'
      cleanup_candidates
    else
      printf 'URGENT|meijendel-bronnen-release|automatische bronrollback mislukt\n' >&2
    fi
  elif [[ "$success" -ne 1 ]]; then
    cleanup_candidates
  fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

validate_manifest() {
  local expected_bytes
  [[ -f "$SOURCES_SQL_CANDIDATE_FILE" && ! -L "$SOURCES_SQL_CANDIDATE_FILE" && -s "$SOURCES_SQL_CANDIDATE_FILE" ]] || \
    die "bron-dumpkandidaat ontbreekt, is leeg of is een symlink"
  [[ -f "$SOURCES_MANIFEST_CANDIDATE_FILE" && ! -L "$SOURCES_MANIFEST_CANDIDATE_FILE" && -s "$SOURCES_MANIFEST_CANDIDATE_FILE" ]] || \
    die "bronmanifestkandidaat ontbreekt, is leeg of is een symlink"
  [[ "$(manifest_value format "$SOURCES_MANIFEST_CANDIDATE_FILE")" == meijendel-bronnen-manifest-v2 ]] || \
    die "ongeldig bronmanifestformaat"
  [[ "$(manifest_value commit "$SOURCES_MANIFEST_CANDIDATE_FILE")" == "$release_commit" ]] || \
    die "bronmanifest hoort bij een andere commit"
  [[ "$(manifest_value sql_sha256 "$SOURCES_MANIFEST_CANDIDATE_FILE")" == "$release_sha256" ]] || \
    die "bronmanifest hoort bij een andere SHA-256"
  expected_bytes="$(manifest_value sql_bytes "$SOURCES_MANIFEST_CANDIDATE_FILE")"
  [[ "$expected_bytes" =~ ^[1-9][0-9]*$ ]] || die "ongeldige dumpomvang in bronmanifest"
  [[ "$(file_sha256 "$SOURCES_SQL_CANDIDATE_FILE")" == "$release_sha256" ]] || die "bron-dumphash wijkt af"
  [[ "$(file_bytes "$SOURCES_SQL_CANDIDATE_FILE")" == "$expected_bytes" ]] || die "bron-dumpomvang wijkt af"
  expected_literature_total="$(manifest_value literature_total "$SOURCES_MANIFEST_CANDIDATE_FILE")"
  expected_literature_active="$(manifest_value literature_active "$SOURCES_MANIFEST_CANDIDATE_FILE")"
  expected_literature_removed="$(manifest_value literature_removed "$SOURCES_MANIFEST_CANDIDATE_FILE")"
  expected_literature_active_with_tags="$(manifest_value literature_active_with_tags "$SOURCES_MANIFEST_CANDIDATE_FILE")"
  for value in "$expected_literature_total" "$expected_literature_active" "$expected_literature_removed" "$expected_literature_active_with_tags"; do
    [[ "$value" =~ ^[0-9]+$ ]] || die "ongeldige literatuurtelling in bronmanifest"
  done
  [[ $((expected_literature_active + expected_literature_removed)) -eq "$expected_literature_total" && "$expected_literature_active_with_tags" -le "$expected_literature_active" ]] || die "inconsistente literatuurtellingen in bronmanifest"
  for required in \
    'CREATE TABLE `bron`' \
    'CREATE TABLE `literatuur`' \
    'VIEW `v_bron_catalogus`' \
    'VIEW `v_literatuur_overzicht`' \
    'VIEW `v_contextdataset_overzicht`'; do
    grep -Fq "$required" "$SOURCES_SQL_CANDIDATE_FILE" || die "bron-dump mist vereist object: $required"
  done
  if grep -Eq '/Users/|/Volumes/|file://' "$SOURCES_SQL_CANDIDATE_FILE"; then
    die "bron-dump bevat een lokaal bestandspad"
  fi
}

apply_view_grants() {
  local website_user schema_grants object_name
  website_user="$(docker exec "$CONTAINER" sh -lc 'printf %s "$MYSQL_USER"')"
  [[ "$website_user" =~ ^[A-Za-z0-9_]+$ ]] || die "onveilige websitegebruikersnaam"
  schema_grants="$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39), '$website_user', CHAR(39), '@', CHAR(39), '%', CHAR(39)) AND TABLE_SCHEMA = '$SOURCES_DATABASE'")"
  if [[ "$schema_grants" -gt 0 ]]; then
    root_mysql -e "REVOKE ALL PRIVILEGES ON \`$SOURCES_DATABASE\`.* FROM \`$website_user\`@\`%\`"
  fi
  while IFS= read -r object_name; do
    [[ -n "$object_name" ]] || continue
    root_mysql -e "REVOKE ALL PRIVILEGES ON \`$SOURCES_DATABASE\`.\`$object_name\` FROM \`$website_user\`@\`%\`"
  done < <(root_mysql -NBe "SELECT DISTINCT TABLE_NAME FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39), '$website_user', CHAR(39), '@', CHAR(39), '%', CHAR(39)) AND TABLE_SCHEMA = '$SOURCES_DATABASE'")
  root_mysql -e "GRANT SELECT ON \`Meijendel_bronnen\`.\`v_bron_catalogus\` TO \`$website_user\`@\`%\`"
  root_mysql -e "GRANT SELECT ON \`Meijendel_bronnen\`.\`v_literatuur_overzicht\` TO \`$website_user\`@\`%\`"
  root_mysql -e "GRANT SELECT ON \`Meijendel_bronnen\`.\`v_contextdataset_overzicht\` TO \`$website_user\`@\`%\`"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39), '$website_user', CHAR(39), '@', CHAR(39), '%', CHAR(39)) AND TABLE_SCHEMA = '$SOURCES_DATABASE'")" -eq 0 ]] || die "brede bron-schemarechten aanwezig"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39), '$website_user', CHAR(39), '@', CHAR(39), '%', CHAR(39)) AND TABLE_SCHEMA = '$SOURCES_DATABASE' AND PRIVILEGE_TYPE = 'SELECT'")" -eq 3 ]] || die "bron-viewrechten zijn niet exact drie SELECT-grants"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.TABLE_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39), '$website_user', CHAR(39), '@', CHAR(39), '%', CHAR(39)) AND TABLE_SCHEMA = '$SOURCES_DATABASE' AND TABLE_NAME NOT IN ('v_bron_catalogus','v_literatuur_overzicht','v_contextdataset_overzicht')")" -eq 0 ]] || die "ruwe brontabellen zijn leesbaar"
}

validate_sources_database() {
  local table_name result actual_total actual_active actual_removed actual_tagged
  while IFS= read -r table_name; do
    [[ -n "$table_name" ]] || continue
    result="$(root_mysql -NBe "CHECK TABLE \`$SOURCES_DATABASE\`.\`$table_name\` EXTENDED")"
    grep -Eq 'status[[:space:]]+OK$' <<<"$result" || die "CHECK TABLE faalde voor $table_name"
  done < <(root_mysql -NBe "SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = '$SOURCES_DATABASE' AND table_type = 'BASE TABLE' ORDER BY TABLE_NAME")
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = '$SOURCES_DATABASE'")" -gt 0 ]] || die "bron-database mist foreign keys"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM \`$SOURCES_DATABASE\`.v_bron_catalogus")" -gt 0 ]] || die "broncatalogus is leeg"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM \`$SOURCES_DATABASE\`.v_literatuur_overzicht")" -gt 0 ]] || die "literatuuroverzicht is leeg"
  [[ "$(root_mysql -NBe "SELECT COUNT(*) FROM \`$SOURCES_DATABASE\`.v_contextdataset_overzicht")" -gt 0 ]] || die "contextdatasetoverzicht is leeg"
  IFS=$'\t' read -r actual_total actual_active actual_removed actual_tagged <<<"$(root_mysql -NBe \
    'SELECT COUNT(*) AS total, SUM(CASE WHEN zotero_status="actueel" THEN 1 ELSE 0 END) AS active, SUM(CASE WHEN zotero_status<>"actueel" THEN 1 ELSE 0 END) AS removed, SUM(CASE WHEN zotero_status="actueel" AND JSON_LENGTH(trefwoorden)>0 THEN 1 ELSE 0 END) AS active_with_tags FROM Meijendel_bronnen.literatuur')"
  [[ "$actual_total" == "$expected_literature_total" && \
     "$actual_active" == "$expected_literature_active" && \
     "$actual_removed" == "$expected_literature_removed" && \
     "$actual_tagged" == "$expected_literature_active_with_tags" ]] || \
    die "geïmporteerde literatuurtellingen wijken af van het bronmanifest"
}

validate_replication_absent() {
  local replica_connections registered_replicas binlog_dump_threads
  replica_connections="$(root_mysql -NBe "SELECT COUNT(*) FROM performance_schema.replication_connection_status")"
  registered_replicas="$(root_mysql -NBe "SHOW REPLICAS")"
  binlog_dump_threads="$(root_mysql -NBe 'SELECT COUNT(*) FROM information_schema.processlist WHERE COMMAND IN ("Binlog Dump","Binlog Dump GTID")')"
  [[ "$replica_connections" == 0 && -z "$registered_replicas" && "$binlog_dump_threads" == 0 ]] || \
    die "bronimport zonder binlog is geblokkeerd omdat replicatie actief kan zijn"
}

validate_current_state() {
  [[ -e "$STATE_FILE" ]] || return 0
  [[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] || die "huidige bronstatus is geen regulier bestand"
  [[ "$(manifest_value format "$STATE_FILE")" == meijendel-bronnen-release-v1 ]] || die "huidige bronstatus heeft een onbekend formaat"
  [[ "$(manifest_value commit "$STATE_FILE")" =~ ^[0-9a-f]{40}$ ]] || die "huidige bronstatus bevat geen geldige commit"
  [[ "$(manifest_value sql_sha256 "$STATE_FILE")" =~ ^[0-9a-f]{64}$ ]] || die "huidige bronstatus bevat geen geldige SHA-256"
  manifest_value released_at "$STATE_FILE" >/dev/null
}

write_sources_state() {
  local state_next="$STATE_FILE.next.$$"
  printf '%s\n' \
    'format=meijendel-bronnen-release-v1' \
    "commit=$release_commit" \
    "sql_sha256=$release_sha256" \
    "released_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$state_next"
  chmod 600 "$state_next"
  mv "$state_next" "$STATE_FILE"
}

[[ "$stage" == preflight || "$stage" == apply ]] || die "onbekende fase"
[[ "$release_commit" =~ ^[0-9a-f]{40}$ ]] || die "commit vereist exact 40 lowercase hextekens"
[[ "$release_sha256" =~ ^[0-9a-f]{64}$ ]] || die "SHA-256 vereist exact 64 lowercase hextekens"
docker inspect --format '{{.State.Status}}' "$CONTAINER" | grep -qx running || die "MySQL-container draait niet"
mysql_version="$(docker exec "$CONTAINER" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -NBe "SELECT VERSION()"')"
printf 'MYSQL_VERSION=%s\n' "$mysql_version"
[[ "$mysql_version" == 9.7.1 ]] || die "MySQL-versie is $mysql_version; vereist 9.7.1"
[[ -d "$BACKUP_DIR" && -w "$BACKUP_DIR" ]] || die "bronback-upmap ontbreekt of is niet schrijfbaar"
df -Pk "$BACKUP_DIR" | awk 'NR == 2 { if ($4 < 1048576) exit 1 }' || die "minder dan 1 GiB vrije bronback-upruimte"
validate_current_state
validate_replication_absent

if [[ "$stage" == preflight ]]; then
  success=1
  printf 'PREFLIGHT_STATUS=ready\n'
  exit 0
fi

[[ -d "$GLOBAL_LOCK" && ! -L "$GLOBAL_LOCK" ]] || die "globale productie-lock ontbreekt"
validate_manifest
had_sources_database="$(root_mysql -NBe "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$SOURCES_DATABASE'")"
[[ "$had_sources_database" == 0 || "$had_sources_database" == 1 ]] || die "bron-databasestatus is ongeldig"
if [[ "$had_sources_database" -eq 1 ]]; then
  backup_file="$BACKUP_DIR/meijendel_bronnen_before_${release_commit}_${release_sha256}_$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
  docker exec "$CONTAINER" sh -lc '
    exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --no-tablespaces --single-transaction \
      --set-gtid-purged=OFF --routines --triggers --events --add-drop-database --databases Meijendel_bronnen
  ' | gzip -c > "$backup_file.tmp"
  gzip -t "$backup_file.tmp" || die "bronback-up is beschadigd"
  [[ "$(gzip -dc "$backup_file.tmp" | wc -c | tr -d '[:space:]')" -gt 0 ]] ||
    die "bronback-up is inhoudelijk leeg"
  mv "$backup_file.tmp" "$backup_file"
  chmod 600 "$backup_file"
  printf 'SOURCES_DATABASE_BACKUP=%s\n' "$backup_file"
else
  printf 'SOURCES_DATABASE_BACKUP=not-present\n'
fi

import_started=1
root_mysql -e "DROP DATABASE IF EXISTS Meijendel_bronnen; CREATE DATABASE Meijendel_bronnen CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
{ printf 'SET SESSION sql_log_bin=0;\n'; cat "$SOURCES_SQL_CANDIDATE_FILE"; } |
  docker exec -i "$CONTAINER" sh -lc 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" Meijendel_bronnen'
apply_view_grants
validate_sources_database

activation_started=1
if [[ -f "$SOURCES_SQL_FILE" && ! -L "$SOURCES_SQL_FILE" ]]; then
  mv "$SOURCES_SQL_FILE" "$rollback_sources_sql"
  had_sources_sql=1
fi
mv "$SOURCES_SQL_CANDIDATE_FILE" "$SOURCES_SQL_FILE"
chmod 600 "$SOURCES_SQL_FILE"
rm -f "$SOURCES_MANIFEST_CANDIDATE_FILE"
rm -f "$rollback_sources_sql"
write_sources_state
success=1
printf 'SOURCES_STATUS=ready\n'
