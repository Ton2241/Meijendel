#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy_meijendel_vps.sh"
REMOTE_HELPER="$SCRIPT_DIR/deploy_meijendel_release_vps_remote.sh"
GATEWAY_RUNNER="$SCRIPT_DIR/run_gateway_job_vps.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

assert_before() {
  local file="$1" first="$2" second="$3" first_line second_line
  first_line="$(grep -nF "$first" "$file" | tail -n 1 | cut -d: -f1)"
  second_line="$(grep -nF "$second" "$file" | tail -n 1 | cut -d: -f1)"
  [[ "$first_line" =~ ^[0-9]+$ && "$second_line" =~ ^[0-9]+$ && "$first_line" -lt "$second_line" ]] || \
    fail "onjuiste volgorde: $first moet vóór $second staan in $(basename "$file")"
}

[[ -x "$REMOTE_HELPER" ]] || fail "gesloten remote releasehelper ontbreekt of is niet uitvoerbaar"
bash -n "$DEPLOY_SCRIPT" "$REMOTE_HELPER"

for fragment in \
  'GATEWAY="/usr/local/sbin/vwgm-admin"' \
  'GATEWAY_RUNNER=' \
  'EXPORT_VALIDATOR=' \
  'RSYNC_BIN=' \
  'SSH_BIN=' \
  'gateway_preflight="$("$GATEWAY_RUNNER" preflight "$LOCAL_COMMIT")"' \
  'gateway_apply="$("$GATEWAY_RUNNER" apply "$LOCAL_COMMIT")"' \
  '"$EXPORT_VALIDATOR" --with-cache' \
  'CACHE_CANDIDATE_FILE=' \
  'CACHE_MANIFEST_CANDIDATE_FILE=' \
  'SOURCES_SQL_CANDIDATE_FILE=' \
  'MYSQL_VERSION=' \
  'DATABASE_BACKUP=' \
  'CACHE_CANDIDATE_STATUS=ready' \
  'MEIJENDEL_REQUIRE_PREBUILT_CACHE=1' \
  'SQL_CACHE=TRUE' \
  'SHINY_STATUS=ready'; do
  grep -Fq "$fragment" "$DEPLOY_SCRIPT" || fail "lokaal deployscript mist gatewaycontract: $fragment"
done

grep -Fq 'meijendel-release "$stage" "$commit"' "$GATEWAY_RUNNER" || \
  fail "gatewayrunner roept de gesloten Meijendel-actie niet aan"

if grep -Eq 'remote ".*docker|docker (exec|ps|run|compose|stats)' "$DEPLOY_SCRIPT"; then
  fail "lokaal deployscript bevat nog rechtstreekse Docker-aanroepen"
fi

assert_before "$DEPLOY_SCRIPT" '"$EXPORT_VALIDATOR" --with-cache' 'sync_release'
assert_before "$DEPLOY_SCRIPT" 'SYNC_MODE="apply"' 'gateway_apply='
assert_before "$DEPLOY_SCRIPT" 'gateway_apply=' 'canonical_data_smoke'
assert_before "$DEPLOY_SCRIPT" 'production_smoke' 'write_state "$LOCAL_COMMIT"'
assert_before "$REMOTE_HELPER" 'CACHE_CANDIDATE_STATUS=ready' 'DATABASE_BACKUP='
assert_before "$REMOTE_HELPER" 'DATABASE_BACKUP=' 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
assert_before "$REMOTE_HELPER" 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' 'restart_shiny'
grep -Fq 'ROLLBACK_STATUS=ready' "$REMOTE_HELPER" || fail "rollback mist expliciete herstelstatus"
grep -Fq 'release_lock' "$DEPLOY_SCRIPT" || fail "globale releaselock wordt niet via cleanup vrijgegeven"
if grep -Fq 'remote "sudo -n' "$DEPLOY_SCRIPT"; then
  fail "lokaal deployscript roept de gateway nog rechtstreeks via SSH aan"
fi

for fragment in \
  'STAGES=(preflight apply)' \
  'CONTAINER="meijendel-mysql"' \
  'SHINY_CONTAINER="shiny_meijendel"' \
  'SOURCES_DATABASE="Meijendel_bronnen"' \
  'SOURCES_DATABASE_BACKUP=' \
  'SOURCES_STATUS=ready' \
  'restore_backup' \
  'first_cache_migration=0' \
  'install_first_migration_artifacts' \
  'row_counts_sha256' \
  'table_checksums_sha256' \
  'ROLLBACK_ARTIFACT_STATUS=deterministic-equivalent' \
  'trap finish EXIT' \
  'trap '\''exit 130'\'' INT' \
  'trap '\''exit 143'\'' TERM' \
  '[[ ! -L "$CANDIDATE_FILE" ]]' \
  '[[ ! -L "$CACHE_CANDIDATE_FILE" ]]' \
  '[[ ! -L "$CACHE_MANIFEST_CANDIDATE_FILE" ]]' \
  'stat -c '\''%U:%a'\'' "$CANDIDATE_FILE"' \
  'SELECT VERSION()' \
  'CHECK TABLE' \
  'docker compose up -d --force-recreate shiny' \
  'trim/soorten/soorten_trendoverzicht.csv' \
  'trim/sandra/soorten/soorten_trendoverzicht.csv'; do
  grep -Fq "$fragment" "$REMOTE_HELPER" || fail "remote helper mist veiligheidscontract: $fragment"
done

assert_before "$REMOTE_HELPER" 'table_checksums_sha256' 'DATABASE_BACKUP='
assert_before "$REMOTE_HELPER" 'row_counts_sha256' 'DATABASE_BACKUP='

cache_status_line="$(grep -nF 'CACHE_CANDIDATE_STATUS=ready' "$REMOTE_HELPER" | head -n 1 | cut -d: -f1 || true)"
backup_line="$(grep -nF 'DATABASE_BACKUP=' "$REMOTE_HELPER" | head -n 1 | cut -d: -f1 || true)"
import_line="$(grep -nF 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' "$REMOTE_HELPER" | tail -n 1 | cut -d: -f1 || true)"
[[ "$cache_status_line" =~ ^[0-9]+$ && "$backup_line" =~ ^[0-9]+$ && "$import_line" =~ ^[0-9]+$ ]] || \
  fail "volgorde van kandidaatcontrole, back-up en import kon niet worden vastgesteld"
(( cache_status_line < backup_line && cache_status_line < import_line )) || \
  fail "kandidaatcache wordt niet vóór databaseback-up en import bewezen"

if grep -Fq 'parse_meijendel_tables' "$REMOTE_HELPER"; then
  fail "remote helper mag de SQL-dump niet opnieuw parsen"
fi

printf 'OK: Meijendel-deploy gebruikt uitsluitend de gesloten, rollbackbare gatewayactie.\n'
