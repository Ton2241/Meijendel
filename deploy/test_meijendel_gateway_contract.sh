#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy_meijendel_vps.sh"
REMOTE_HELPER="$SCRIPT_DIR/deploy_meijendel_release_vps_remote.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

[[ -x "$REMOTE_HELPER" ]] || fail "gesloten remote releasehelper ontbreekt of is niet uitvoerbaar"
bash -n "$DEPLOY_SCRIPT" "$REMOTE_HELPER"

for fragment in \
  'GATEWAY="/usr/local/sbin/vwgm-admin"' \
  'meijendel-release preflight' \
  'meijendel-release apply' \
  'MYSQL_VERSION=' \
  'DATABASE_BACKUP=' \
  'SHINY_STATUS=ready'; do
  grep -Fq "$fragment" "$DEPLOY_SCRIPT" || fail "lokaal deployscript mist gatewaycontract: $fragment"
done

if grep -Eq 'remote ".*docker|docker (exec|ps|run|compose|stats)' "$DEPLOY_SCRIPT"; then
  fail "lokaal deployscript bevat nog rechtstreekse Docker-aanroepen"
fi

for fragment in \
  'STAGES=(preflight apply)' \
  'CONTAINER="meijendel-mysql"' \
  'SHINY_CONTAINER="shiny_meijendel"' \
  'restore_backup' \
  'trap finish EXIT' \
  'trap '\''exit 130'\'' INT' \
  'trap '\''exit 143'\'' TERM' \
  '[[ ! -L "$CANDIDATE_FILE" ]]' \
  'stat -c '\''%U:%a'\'' "$CANDIDATE_FILE"' \
  'SELECT VERSION()' \
  'CHECK TABLE' \
  'docker compose up -d --force-recreate shiny' \
  'trim/soorten/soorten_trendoverzicht.csv' \
  'trim/sandra/soorten/soorten_trendoverzicht.csv'; do
  grep -Fq "$fragment" "$REMOTE_HELPER" || fail "remote helper mist veiligheidscontract: $fragment"
done

printf 'OK: Meijendel-deploy gebruikt uitsluitend de gesloten, rollbackbare gatewayactie.\n'
