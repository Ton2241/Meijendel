#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_DATA="$REMOTE_BASE/data"
STATE_DIR="${MEIJENDEL_BRONNEN_STATE_DIR:-$REMOTE_BASE/deploy-state}"
STATE_FILE="$STATE_DIR/Meijendel_bronnen.release"
GLOBAL_LOCK="$STATE_DIR/production.lock"
GATEWAY="${GATEWAY:-/usr/local/sbin/vwgm-admin}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCES_SQL_LOCAL="${SOURCES_SQL_LOCAL:-$LOCAL_REPO/meijendel_bronnen.sql}"
GATEWAY_RUNNER="${GATEWAY_RUNNER:-$SCRIPT_DIR/run_bronnen_gateway_job_vps.sh}"
MYSQL_BIN="${MYSQL_BIN:-$(command -v mysql 2>/dev/null || true)}"
RSYNC_BIN="${RSYNC_BIN:-$(command -v rsync 2>/dev/null || true)}"
SSH_BIN="${SSH_BIN:-$(command -v ssh 2>/dev/null || true)}"
CURL_BIN="${CURL_BIN:-$(command -v curl 2>/dev/null || true)}"
REQUIRED_MYSQL_VERSION="${REQUIRED_MYSQL_VERSION:-9.7.1}"

if [[ -z "$MYSQL_BIN" && -x /usr/local/mysql/bin/mysql ]]; then
  MYSQL_BIN="/usr/local/mysql/bin/mysql"
fi

APPLY=0
YES=0
LOCK_HELD=0
CANDIDATE_STAGED=0
RESTORE_DATABASE="Meijendel_bronnen_restore_$$"
MANIFEST_LOCAL="${TMPDIR:-/tmp}/meijendel_bronnen_$$.manifest"
SOURCES_SQL_CANDIDATE_FILE=""
SOURCES_MANIFEST_CANDIDATE_FILE=""

usage() {
  printf '%s\n' \
    'Gebruik:' \
    '  deploy/deploy_meijendel_bronnen_vps.sh' \
    '  deploy/deploy_meijendel_bronnen_vps.sh --apply --yes' \
    '' \
    'Zonder --apply: volledige bronpreflight en rsync-dry-run; productie blijft ongewijzigd.'
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }
need_executable() { [[ -x "$1" ]] || die "uitvoerbaar bestand ontbreekt: $1"; }
remote() { "$SSH_BIN" -i "$SSH_KEY" "$VPS" "$@"; }

release_lock() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    remote "rmdir '$GLOBAL_LOCK' 2>/dev/null || true" || true
    LOCK_HELD=0
  fi
}

cleanup() {
  if [[ -n "$MYSQL_BIN" ]]; then
    "$MYSQL_BIN" --login-path=meijendel_root -Nse \
      "DROP DATABASE IF EXISTS ${RESTORE_DATABASE}" >/dev/null 2>&1 || true
  fi
  rm -f "$MANIFEST_LOCAL"
  if [[ "$CANDIDATE_STAGED" -eq 1 ]]; then
    remote "rm -f '$SOURCES_SQL_CANDIDATE_FILE' '$SOURCES_MANIFEST_CANDIDATE_FILE'" || true
    CANDIDATE_STAGED=0
  fi
  release_lock
}
trap cleanup EXIT INT TERM

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done
[[ "$APPLY" -eq 0 || "$YES" -eq 1 ]] || die "--apply vereist --yes."
[[ "${MEIJENDEL_BRONNEN_TEST_MODE:-0}" != 1 || "$APPLY" -eq 0 ]] || \
  die "testmodus staat geen --apply toe."

need_executable "$MYSQL_BIN"
need_executable "$RSYNC_BIN"
need_executable "$SSH_BIN"
need_executable "$CURL_BIN"
need_executable "$GATEWAY_RUNNER"
[[ -f "$SOURCES_SQL_LOCAL" ]] || die "bron-dump ontbreekt: $SOURCES_SQL_LOCAL"

if [[ "${MEIJENDEL_BRONNEN_TEST_MODE:-0}" == 1 ]]; then
  LOCAL_COMMIT="1111111111111111111111111111111111111111"
else
  cd "$LOCAL_REPO"
  [[ -z "$(git status --porcelain)" ]] || die "werkboom is niet schoon."
  [[ "$(git branch --show-current)" == main ]] || die "productiedeploy mag alleen vanaf main."
  git fetch origin --prune
  LOCAL_COMMIT="$(git rev-parse HEAD)"
  [[ "$LOCAL_COMMIT" == "$(git rev-parse origin/main)" ]] || die "lokale main wijkt af van origin/main."
fi
[[ "$LOCAL_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "ongeldige lokale commit."

for required in \
  'CREATE TABLE `bron`' \
  'CREATE TABLE `literatuur`' \
  'VIEW `v_bron_catalogus`' \
  'VIEW `v_literatuur_overzicht`' \
  'VIEW `v_contextdataset_overzicht`'; do
  grep -Fq "$required" "$SOURCES_SQL_LOCAL" || die "bron-dump mist vereist object: $required"
done
if grep -Eq '/Users/|/Volumes/|file://' "$SOURCES_SQL_LOCAL"; then
  die "bron-dump bevat een lokaal bestandspad."
fi

local_mysql_version="$($MYSQL_BIN --login-path=meijendel_root -Nse 'SELECT VERSION()')"
[[ "$local_mysql_version" == "$REQUIRED_MYSQL_VERSION" ]] || \
  die "lokale MySQL is $local_mysql_version; vereist is $REQUIRED_MYSQL_VERSION."

log "Valideer bron-dump in tijdelijke database"
"$MYSQL_BIN" --login-path=meijendel_root -e \
  "DROP DATABASE IF EXISTS ${RESTORE_DATABASE}; CREATE DATABASE ${RESTORE_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
"$MYSQL_BIN" --login-path=meijendel_root "$RESTORE_DATABASE" < "$SOURCES_SQL_LOCAL"
IFS=$'\t' read -r literature_total literature_active literature_removed literature_active_with_tags <<<"$($MYSQL_BIN --login-path=meijendel_root -Nse \
  'SELECT COUNT(*) AS total, SUM(CASE WHEN zotero_status="actueel" THEN 1 ELSE 0 END) AS active, SUM(CASE WHEN zotero_status<>"actueel" THEN 1 ELSE 0 END) AS removed, SUM(CASE WHEN zotero_status="actueel" AND JSON_LENGTH(trefwoorden)>0 THEN 1 ELSE 0 END) AS active_with_tags FROM literatuur' \
  "$RESTORE_DATABASE")"
foreign_keys="$($MYSQL_BIN --login-path=meijendel_root -Nse \
  "SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='${RESTORE_DATABASE}'")"
views="$($MYSQL_BIN --login-path=meijendel_root -Nse \
  "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${RESTORE_DATABASE}' AND TABLE_NAME IN ('v_bron_catalogus','v_literatuur_overzicht','v_contextdataset_overzicht')" )"
for value in "$literature_total" "$literature_active" "$literature_removed" "$literature_active_with_tags" "$foreign_keys" "$views"; do
  [[ "$value" =~ ^[0-9]+$ ]] || die "lokale bronvalidatie leverde geen geldige telling."
done
[[ "$views" -eq 3 ]] || die "tijdelijke database bevat niet exact drie vereiste views."
[[ "$foreign_keys" -gt 0 ]] || die "tijdelijke database bevat geen foreign-keycontract."

sources_sha256="$(shasum -a 256 "$SOURCES_SQL_LOCAL" | awk '{print $1}')"
sources_bytes="$(stat -f '%z' "$SOURCES_SQL_LOCAL" 2>/dev/null || stat -c '%s' "$SOURCES_SQL_LOCAL")"
[[ "$sources_sha256" =~ ^[0-9a-f]{64}$ ]] || die "SHA-256 van bron-dump is ongeldig."
[[ "$sources_bytes" =~ ^[1-9][0-9]*$ ]] || die "bron-dump is leeg of heeft geen geldige grootte."
SOURCES_SQL_CANDIDATE_FILE="$REMOTE_DATA/Meijendel_bronnen.sql.candidate-$LOCAL_COMMIT-$sources_sha256"
SOURCES_MANIFEST_CANDIDATE_FILE="$SOURCES_SQL_CANDIDATE_FILE.manifest"
printf '%s\n' \
  'format=meijendel-bronnen-manifest-v2' \
  "commit=$LOCAL_COMMIT" \
  "sql_sha256=$sources_sha256" \
  "sql_bytes=$sources_bytes" \
  "literature_total=$literature_total" \
  "literature_active=$literature_active" \
  "literature_removed=$literature_removed" \
  "literature_active_with_tags=$literature_active_with_tags" > "$MANIFEST_LOCAL"

export VPS SSH_KEY GATEWAY SSH_BIN
set +e
gateway_preflight="$($GATEWAY_RUNNER preflight "$LOCAL_COMMIT" "$sources_sha256")"
gateway_preflight_rc=$?
set -e
printf '%s\n' "$gateway_preflight"
[[ "$gateway_preflight_rc" -eq 0 ]] || die "gesloten bronpreflight faalde met exitcode $gateway_preflight_rc."
grep -Fqx 'PREFLIGHT_STATUS=ready' <<<"$gateway_preflight" || die "gesloten bronpreflight is niet gereed."
grep -Fqx 'GATEWAY_JOB_STATUS=ready' <<<"$gateway_preflight" || die "bron-gatewayjob is niet gereed."

log "Controleer kandidaatkopie"
sync_candidate() {
  local mode="$1"
  local rsync_args=(-az --itemize-changes -e "$SSH_BIN -i $SSH_KEY")
  [[ "$mode" == apply ]] || rsync_args+=(--dry-run)
  "$RSYNC_BIN" "${rsync_args[@]}" "$SOURCES_SQL_LOCAL" "$VPS:$SOURCES_SQL_CANDIDATE_FILE"
  "$RSYNC_BIN" "${rsync_args[@]}" "$MANIFEST_LOCAL" "$VPS:$SOURCES_MANIFEST_CANDIDATE_FILE"
}
sync_candidate dry

source_route_smoke() {
  local route_code
  route_code="$($CURL_BIN -ksS -o /dev/null -w '%{http_code}' https://www.vwg-m.nl/Meijendel_bronnen.sql)"
  [[ "$route_code" == 403 || "$route_code" == 404 || "$route_code" == 303 ]] || \
    die "afgeschermde bronroute gaf onverwacht HTTP $route_code."
}
source_route_smoke

if [[ "$APPLY" -eq 0 ]]; then
  printf 'Preflight klaar; productie is niet aangepast.\n'
  exit 0
fi

remote "mkdir -p '$STATE_DIR' && mkdir '$GLOBAL_LOCK'" || \
  die "een andere productie-deploy houdt de globale lock vast: $GLOBAL_LOCK"
LOCK_HELD=1
sync_candidate apply
CANDIDATE_STAGED=1
remote_sha256="$(remote "sha256sum '$SOURCES_SQL_CANDIDATE_FILE' | awk '{print \$1}'")"
[[ "$remote_sha256" == "$sources_sha256" ]] || die "remote kandidaat-hash wijkt af."
set +e
gateway_apply="$($GATEWAY_RUNNER apply "$LOCAL_COMMIT" "$sources_sha256")"
gateway_apply_rc=$?
set -e
printf '%s\n' "$gateway_apply"
[[ "$gateway_apply_rc" -eq 0 ]] || die "bronrelease faalde met exitcode $gateway_apply_rc."
grep -Fqx 'SOURCES_STATUS=ready' <<<"$gateway_apply" || die "bronrelease gaf geen gereedstatus."
grep -Fqx 'GATEWAY_JOB_STATUS=ready' <<<"$gateway_apply" || die "bron-gatewayjob faalde."
source_route_smoke
printf 'Meijendel_bronnen-release gereed: %s\n' "$LOCAL_COMMIT"
