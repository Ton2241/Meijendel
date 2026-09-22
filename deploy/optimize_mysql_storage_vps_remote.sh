#!/usr/bin/env bash
set -euo pipefail

stage="${1:-}"
CONTAINER="meijendel-mysql"
BACKUP_DIR="/srv/vwgm/backups/vwg-m-baremetal"
BACKUP_ARCHIVE="$BACKUP_DIR/vwg-m-baremetal-latest.tar.gz"
MYSQL_BACKUP_DIR="/srv/vwgm/backups/meijendel-mysql"
STALE_SQL="/srv/vwgm/shiny/meijendel.sql"
EXPECTED_BINLOG_RETENTION=259200
EXPECTED_REDO_CAPACITY=536870912
MAX_BACKUP_AGE=129600

fail() { printf 'BLOKKADE|mysql-opslag|%s\n' "$*" >&2; exit 1; }

mysql_query() {
  docker exec "$CONTAINER" sh -c \
    'exec mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$1"' sh "$1"
}

validate_backup() {
  local age
  [[ -s "$BACKUP_ARCHIVE" && -s "$BACKUP_ARCHIVE.sha256" ]] ||
    fail "actuele bare-metalback-up of checksum ontbreekt"
  age=$(( $(date +%s) - $(stat -c %Y "$BACKUP_ARCHIVE") ))
  (( age >= 0 && age <= MAX_BACKUP_AGE )) || fail "bare-metalback-up is ouder dan 36 uur"
  (cd "$BACKUP_DIR" && sha256sum -c vwg-m-baremetal-latest.tar.gz.sha256) ||
    fail "bare-metalchecksum faalde"
  /srv/vwgm/vwg-m-linux-app/scripts/restore_check_backup.sh "$BACKUP_ARCHIVE" ||
    fail "bare-metalherstelcontrole faalde"
}

validate_cleanup_targets() {
  local file expected_hash expected_size actual_hash
  while IFS='|' read -r file expected_size expected_hash; do
    [[ -f "$file" && ! -L "$file" ]] || fail "opruimdoel ontbreekt of is symlink: $file"
    [[ "$(stat -c %s "$file")" == "$expected_size" ]] || fail "omvang wijkt af: $file"
    gzip -t "$file" || fail "gzipcontrole faalde: $file"
    actual_hash="$(gzip -dc "$file" | sha256sum | awk '{print $1}')"
    [[ "$actual_hash" == "$expected_hash" ]] || fail "inhoudshash wijkt af: $file"
  done <<EOF
$MYSQL_BACKUP_DIR/meijendel_before_4d68ffc79047b412c58f7e38974a8d1dedb7a4aa_20260920T185054Z.sql.gz|10897010|15ec41838e4cff2b9a344064e201d2f6063a039473ad9af78e63049bcea369c1
$MYSQL_BACKUP_DIR/meijendel_before_4d68ffc79047b412c58f7e38974a8d1dedb7a4aa_20260920T193410Z.sql.gz|198382934|c0824c50f319b86a1cc05e88d2d376d162faba67b495d9463021696a72108ebe
$MYSQL_BACKUP_DIR/meijendel_before_7fac53274cb06162870f4db7f1453dcb15ae4423_20260920T221324Z.sql.gz|10897010|15ec41838e4cff2b9a344064e201d2f6063a039473ad9af78e63049bcea369c1
EOF
  [[ -f "$STALE_SQL" && ! -L "$STALE_SQL" ]] || fail "ongebruikte lowercase SQL ontbreekt of is symlink"
  [[ "$(stat -c %s "$STALE_SQL")" == 82674275 ]] || fail "lowercase SQL-omvang wijkt af"
  [[ "$(sha256sum "$STALE_SQL" | awk '{print $1}')" == 087bd35db85918588c27e3c75bd7275fc78ded65be8f7df063220b843ae74cb4 ]] ||
    fail "lowercase SQL-hash wijkt af"
  ! docker inspect "$CONTAINER" shiny_meijendel | grep -Fq "$STALE_SQL" ||
    fail "lowercase SQL is nog als containermount in gebruik"
  [[ -s "$MYSQL_BACKUP_DIR/meijendel_before_891ca4e9bd51a2d9bfd825a733c79bb61473b4ee_20260921T113001Z.sql.gz" ]] ||
    fail "te behouden actuele logische back-up ontbreekt"
  gzip -t "$MYSQL_BACKUP_DIR/meijendel_before_891ca4e9bd51a2d9bfd825a733c79bb61473b4ee_20260921T113001Z.sql.gz" ||
    fail "te behouden actuele logische back-up is beschadigd"
  [[ "$(gzip -dc "$MYSQL_BACKUP_DIR/meijendel_before_891ca4e9bd51a2d9bfd825a733c79bb61473b4ee_20260921T113001Z.sql.gz" | sha256sum | awk '{print $1}')" == c0824c50f319b86a1cc05e88d2d376d162faba67b495d9463021696a72108ebe ]] ||
    fail "te behouden actuele logische back-up heeft onverwachte inhoud"
}

verify_runtime() {
  local version replica_connections replica_status registered_replicas binlog_dump_threads active_log persisted_load
  docker inspect --format '{{.State.Status}}' "$CONTAINER" | grep -qx running ||
    fail "MySQL-container draait niet"
  version="$(mysql_query 'SELECT VERSION()')"
  [[ "$version" == 9.7.1 ]] || fail "MySQL-versie wijkt af: $version"
  mysql_query 'SELECT 1' | grep -qx 1 || fail "MySQL-query faalde"
  replica_connections="$(mysql_query 'SELECT COUNT(*) FROM performance_schema.replication_connection_status')"
  [[ "$replica_connections" == 0 ]] || fail "replicatieverbinding actief"
  replica_status="$(mysql_query 'SHOW REPLICA STATUS')"
  [[ -z "$replica_status" ]] || fail "replicastatus is niet leeg"
  registered_replicas="$(mysql_query 'SHOW REPLICAS')"
  [[ -z "$registered_replicas" ]] || fail "geregistreerde replica aanwezig"
  binlog_dump_threads="$(mysql_query "SELECT COUNT(*) FROM information_schema.processlist WHERE COMMAND IN ('Binlog Dump','Binlog Dump GTID')")"
  [[ "$binlog_dump_threads" == 0 ]] || fail "binlog-dumpverbinding actief"
  persisted_load="$(mysql_query 'SELECT @@GLOBAL.persisted_globals_load')"
  [[ "$persisted_load" == 1 ]] || fail "persistent laden van MySQL-instellingen staat uit"
  active_log="$(mysql_query 'SHOW BINARY LOG STATUS' | awk 'NR==1 {print $1}')"
  [[ "$active_log" =~ ^binlog\.[0-9]{6}$ ]] || fail "actief binlog is ongeldig"
  validate_backup
  validate_cleanup_targets
  printf 'GROEN|mysql-opslag|startgate|backup-en-restore=groen|replicatie=afwezig|actief-binlog=%s\n' "$active_log"
}

apply_changes() {
  local active_log before_bytes after_bytes retention redo redo_resize_status
  verify_runtime
  active_log="$(mysql_query 'SHOW BINARY LOG STATUS' | awk 'NR==1 {print $1}')"
  before_bytes="$(mysql_query 'SHOW BINARY LOGS' | awk '{sum += $2} END {print sum+0}')"

  mysql_query "SET PERSIST binlog_expire_logs_seconds=$EXPECTED_BINLOG_RETENTION; SET PERSIST innodb_redo_log_capacity=$EXPECTED_REDO_CAPACITY"
  retention="$(mysql_query 'SELECT @@GLOBAL.binlog_expire_logs_seconds')"
  redo="$(mysql_query 'SELECT @@GLOBAL.innodb_redo_log_capacity')"
  [[ "$retention" == "$EXPECTED_BINLOG_RETENTION" ]] || fail "binlogretentie werd niet actief"
  [[ "$redo" == "$EXPECTED_REDO_CAPACITY" ]] || fail "redocapaciteit werd niet actief"
  redo_resize_status="$(mysql_query "SHOW STATUS LIKE 'Innodb_redo_log_resize_status'" | awk '{print $2}')"
  [[ "$redo_resize_status" == OK ]] || fail "redo-resize is niet gereed: $redo_resize_status"

  mysql_query "PURGE BINARY LOGS TO '$active_log'"
  after_bytes="$(mysql_query 'SHOW BINARY LOGS' | awk '{sum += $2} END {print sum+0}')"
  (( after_bytes <= before_bytes )) || fail "binlogopslag groeide tijdens purge"

  rm -f -- \
    "$MYSQL_BACKUP_DIR/meijendel_before_4d68ffc79047b412c58f7e38974a8d1dedb7a4aa_20260920T185054Z.sql.gz" \
    "$MYSQL_BACKUP_DIR/meijendel_before_4d68ffc79047b412c58f7e38974a8d1dedb7a4aa_20260920T193410Z.sql.gz" \
    "$MYSQL_BACKUP_DIR/meijendel_before_7fac53274cb06162870f4db7f1453dcb15ae4423_20260920T221324Z.sql.gz" \
    "$STALE_SQL"

  mysql_query 'SELECT 1' | grep -qx 1 || fail "MySQL-nacontrole faalde"
  curl -fsS --max-time 20 https://www.vwg-m.nl/welkom/index.asp >/dev/null ||
    fail "publieke rooktest faalde"
  /usr/local/sbin/vwgm-baremetal-backup >/dev/null
  validate_backup
  printf 'GROEN|mysql-opslag|structureel-opgelost|retentie=%s|redo=%s|binlog-voor=%s|binlog-na=%s\n' \
    "$retention" "$redo" "$before_bytes" "$after_bytes"
  printf 'GRENS|mysql-opslag|geen-docker-prune|geen-andere-backups-of-bestanden\n'
}

case "$stage" in
  verify) verify_runtime ;;
  apply) apply_changes ;;
  *) fail "gebruik verify of apply" ;;
esac
