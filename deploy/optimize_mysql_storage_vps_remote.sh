#!/usr/bin/env bash
set -euo pipefail

stage="${1:-}"
CONTAINER="meijendel-mysql"
BACKUP_DIR="/srv/vwgm/backups/vwg-m-baremetal"
BACKUP_ARCHIVE="$BACKUP_DIR/vwg-m-baremetal-latest.tar.gz"
EXPECTED_BINLOG_RETENTION=259200
EXPECTED_REDO_CAPACITY=536870912
MAX_BACKUP_AGE=129600

fail() { printf 'BLOKKADE|mysql-opslag|%s\n' "$*" >&2; exit 1; }

make_baremetal_backup() {
  /usr/local/sbin/vwgm-baremetal-backup >/dev/null
}

smoke_public() {
  curl -fsS --max-time 20 https://www.vwg-m.nl/welkom/index.asp >/dev/null
}

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

  mysql_query 'SELECT 1' | grep -qx 1 || fail "MySQL-nacontrole faalde"
  smoke_public ||
    fail "publieke rooktest faalde"
  make_baremetal_backup
  validate_backup
  printf 'GROEN|mysql-opslag|structureel-opgelost|retentie=%s|redo=%s|binlog-voor=%s|binlog-na=%s\n' \
    "$retention" "$redo" "$before_bytes" "$after_bytes"
  printf 'GRENS|mysql-opslag|geen-bestandsverwijdering|geen-docker-prune|alle-sql-reserves-bewaard\n'
}

if [[ "${VWGM_MYSQL_STORAGE_LIBRARY_ONLY:-0}" == 1 ]]; then
  [[ "${BASH_SOURCE[0]}" != "$0" && "$EUID" -ne 0 ]] ||
    fail "testbibliotheekmodus is uitsluitend niet-root en sourced toegestaan"
  return 0
fi

case "$stage" in
  verify) verify_runtime ;;
  apply) apply_changes ;;
  *) fail "gebruik verify of apply" ;;
esac
