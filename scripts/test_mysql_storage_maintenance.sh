#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo/deploy/optimize_mysql_storage_vps_remote.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/mysql-storage-behavior.XXXXXX")"
trap '/bin/rm -rf "$tmp"' EXIT INT TERM
mutation_log="$tmp/mutations.log"

VWGM_MYSQL_STORAGE_LIBRARY_ONLY=1 source "$helper"

docker() {
  [[ "$1" == inspect ]]
  printf 'running\n'
}

validate_backup() { :; }
smoke_public() { :; }
make_baremetal_backup() { printf 'backup\n' >>"$mutation_log"; }

mysql_query() {
  case "$1" in
    'SELECT VERSION()') printf '9.7.1\n' ;;
    'SELECT 1') printf '1\n' ;;
    'SELECT COUNT(*) FROM performance_schema.replication_connection_status') printf '0\n' ;;
    'SHOW REPLICA STATUS'|'SHOW REPLICAS') : ;;
    *information_schema.processlist*) printf '0\n' ;;
    'SELECT @@GLOBAL.persisted_globals_load') printf '1\n' ;;
    'SHOW BINARY LOG STATUS') printf 'binlog.000028\t123\n' ;;
    'SHOW BINARY LOGS')
      if grep -Fq 'PURGE|' "$mutation_log" 2>/dev/null; then
        printf 'binlog.000028\t676739696\n'
      else
        printf 'binlog.000018\t1074427547\nbinlog.000028\t676739696\n'
      fi
      ;;
    SET\ PERSIST*) printf 'SET|%s\n' "$1" >>"$mutation_log" ;;
    'SELECT @@GLOBAL.binlog_expire_logs_seconds') printf '259200\n' ;;
    'SELECT @@GLOBAL.innodb_redo_log_capacity') printf '536870912\n' ;;
    "SHOW STATUS LIKE 'Innodb_redo_log_resize_status'") printf 'Innodb_redo_log_resize_status\tOK\n' ;;
    PURGE\ BINARY\ LOGS\ TO*) printf 'PURGE|%s\n' "$1" >>"$mutation_log" ;;
    *) printf 'onverwachte query: %s\n' "$1" >&2; return 1 ;;
  esac
}

# Verify mag geen SET, PURGE, verwijdering of nieuwe back-up uitvoeren.
: >"$mutation_log"
verify_runtime >/dev/null
[[ ! -s "$mutation_log" ]]

# Iedere falende gate stopt vóór de eerste mutatie.
: >"$mutation_log"
if (validate_backup() { fail 'nagebootste back-upfout'; }; apply_changes >/dev/null 2>&1); then
  printf 'FOUT: apply ging door na falende back-upgate.\n' >&2
  exit 1
fi
[[ ! -s "$mutation_log" ]]

# Groene apply gebruikt exact het live actieve log en verwijdert geen bestanden.
: >"$mutation_log"
apply_changes >/dev/null
grep -Fxq "SET|SET PERSIST binlog_expire_logs_seconds=259200; SET PERSIST innodb_redo_log_capacity=536870912" "$mutation_log"
grep -Fxq "PURGE|PURGE BINARY LOGS TO 'binlog.000028'" "$mutation_log"
! grep -Eq '^rm\||meijendel_before_|/srv/vwgm/shiny/meijendel.sql' "$mutation_log"
[[ "$(grep -c '^backup$' "$mutation_log")" -eq 1 ]]
! grep -Eiq 'docker.*prune|system prune|image prune|container prune' "$mutation_log"

printf 'OK: MySQL-opslaghelper stopt fail-closed en muteert uitsluitend de exacte doelen.\n'
