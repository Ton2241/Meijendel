#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VWG_PROJECT="${VWG_PROJECT:-/Users/ton/Documents/GitHub/VWG_Project}"
VWG_M="${VWG_M:-/Users/ton/Documents/GitHub/VWG_M}"
AUDIT_SCRIPT="$VWG_PROJECT/scripts/vulnerability_audit_vps.sh"
SMOKE_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh"
DOCKERFILE="$SCRIPT_DIR/mysql_image/Dockerfile.9.7.1"
REMOTE_HELPER="$SCRIPT_DIR/rebuild_mysql_image_vps_remote.sh"
VALIDATE_HELPER="$SCRIPT_DIR/validate_mysql_uid_migration_vps_remote.sh"
ACTIVE_CONTAINER="meijendel-mysql"
APPLY=0
YES=0
REMOTE_STAGE=""

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help)
      echo "Gebruik: deploy/rebuild_mysql_image_vps.sh [--apply --yes]"
      exit 0
      ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

source "$SCRIPT_DIR/production_guard.sh"

cleanup_stage() {
  [[ -n "$REMOTE_STAGE" ]] || return 0
  ssh -i "$SSH_KEY" "$VPS" \
    "rm -f '$REMOTE_STAGE/Dockerfile.9.7.1' '$REMOTE_STAGE/rebuild-mysql' '$REMOTE_STAGE/validate-mysql'; rmdir '$REMOTE_STAGE' 2>/dev/null || true" || true
}

finish() {
  status=$?
  trap - EXIT INT TERM
  cleanup_stage
  guard_release_lock
  exit "$status"
}
trap finish EXIT INT TERM

[[ -f "$DOCKERFILE" ]] || guard_die "MySQL-Dockerfile ontbreekt."
[[ -x "$REMOTE_HELPER" ]] || guard_die "remote MySQL-rebuildhelper ontbreekt."
[[ -x "$VALIDATE_HELPER" ]] || guard_die "MySQL-validator ontbreekt."
[[ -x "$AUDIT_SCRIPT" ]] || guard_die "kwetsbaarheidsaudit ontbreekt."
[[ -x "$SMOKE_SCRIPT" ]] || guard_die "rooktest ontbreekt."
[[ -f "$SSH_KEY" ]] || guard_die "SSH-sleutel ontbreekt."

guard_baseline
"$LOCAL_REPO/scripts/test_container_image_definitions.sh"
"$LOCAL_REPO/scripts/test_rebuild_mysql_image.sh"

short_commit="${DEPLOY_LOCAL_COMMIT:0:12}"
dockerfile_hash="$(shasum -a 256 "$DOCKERFILE" | awk '{print $1}')"
helper_hash="$(shasum -a 256 "$REMOTE_HELPER" | awk '{print $1}')"
validator_hash="$(shasum -a 256 "$VALIDATE_HELPER" | awk '{print $1}')"

container_line="$(ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" \
  sudo -n /usr/local/sbin/vwgm-admin container-status "$ACTIVE_CONTAINER")"
IFS='|' read -r container_name old_image_id container_state <<< "$container_line"
[[ "$container_name" == "/$ACTIVE_CONTAINER" ]] || guard_die "actieve MySQL-container wijkt af."
[[ "$old_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "actieve MySQL-image-ID is ongeldig."
[[ "$container_state" == "running" ]] || guard_die "actieve MySQL-container draait niet."

echo "== Begrensd MySQL-imagemanifest =="
printf '%s\n' \
  "BRON|deploy/mysql_image/Dockerfile.9.7.1|sha256=$dockerfile_hash" \
  "HELPER|deploy/rebuild_mysql_image_vps_remote.sh|sha256=$helper_hash" \
  "VALIDATOR|deploy/validate_mysql_uid_migration_vps_remote.sh|sha256=$validator_hash" \
  "ACTIEF|container=$ACTIVE_CONTAINER|image=$old_image_id" \
  "DOEL|MySQL=9.7.1|UID:GID=1999:1999|sqlite-libs=bijgewerkt" \
  'GRENS|geen-datamapmigratie|geen-docker-prune|geen-andere-container-of-image'

echo "== Read-only startgate =="
ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" \
  sudo -n /usr/local/sbin/vwgm-admin mysql-health
ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" \
  sudo -n /usr/local/sbin/vwgm-admin backup-status
VWG_ADMIN_GATEWAY=1 "$VWG_M/website/vwg-m-linux-app/scripts/check_caddy_mysql_isolation_vps.sh"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"

set +e
baseline_audit="$("$AUDIT_SCRIPT" --containers-only 2>&1)"
baseline_status=$?
set -e
printf '%s\n' "$baseline_audit"
[[ "$baseline_status" -eq 1 ]] || guard_die "uitgangsscan heeft niet uitsluitend de verwachte aandachtstatus."
grep -Fq 'SAMENVATTING|meijendel-mysql|critical=0|high=2|fix_beschikbaar=2|zonder_fix=0' \
  <<< "$baseline_audit" || guard_die "MySQL-uitgangsscan wijkt af van 0 CRITICAL/2 repareerbare HIGH."
grep -Fq 'pakket=sqlite-libs|installed=3.34.1-10.el9_8|fixed=3.34.1-11.el9_8' \
  <<< "$baseline_audit" || guard_die "sqlite-libs-uitgangsversie of fixversie wijkt af."
grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' \
  <<< "$baseline_audit" || guard_die "Shiny-uitgangsscan wijkt af."
! grep -Eq '^(URGENT|BLOKKADE)\|' <<< "$baseline_audit" ||
  guard_die "uitgangsscan bevat een urgente blokkade."

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; image en productie zijn niet gewijzigd. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "MySQL-image-update vereist --apply --yes."

guard_acquire_lock
REMOTE_STAGE="/tmp/vwgm-mysql-image-stage-$$"
ssh -i "$SSH_KEY" "$VPS" "mkdir -m 0700 '$REMOTE_STAGE'"
scp -i "$SSH_KEY" "$DOCKERFILE" "$VPS:$REMOTE_STAGE/Dockerfile.9.7.1"
scp -i "$SSH_KEY" "$REMOTE_HELPER" "$VPS:$REMOTE_STAGE/rebuild-mysql"
scp -i "$SSH_KEY" "$VALIDATE_HELPER" "$VPS:$REMOTE_STAGE/validate-mysql"

ssh -tt -i "$SSH_KEY" "$VPS" \
  "actual=\$(sha256sum '$REMOTE_STAGE/rebuild-mysql' | cut -d' ' -f1); test \"\$actual\" = '$helper_hash'; exec sudo env REMOTE_STAGE='$REMOTE_STAGE' DOCKERFILE_HASH='$dockerfile_hash' HELPER_HASH='$helper_hash' VALIDATOR_HASH='$validator_hash' EXPECTED_OLD_IMAGE='$old_image_id' NEW_COMMIT='$DEPLOY_LOCAL_COMMIT' SHORT_COMMIT='$short_commit' bash '$REMOTE_STAGE/rebuild-mysql'"

echo "== Onafhankelijke nacontrole =="
VWG_ADMIN_GATEWAY=1 "$VWG_M/website/vwg-m-linux-app/scripts/check_caddy_mysql_isolation_vps.sh"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"
"$AUDIT_SCRIPT" --containers-only
remote_state="$(ssh -i "$SSH_KEY" "$VPS" "cat '$DEPLOY_STATE_FILE'")"
[[ "$remote_state" == "$DEPLOY_LOCAL_COMMIT" ]] || guard_die "Meijendel-productiestatus is niet bijgewerkt."

echo "MySQL-image-update afgerond; productiecommit geregistreerd: $DEPLOY_LOCAL_COMMIT"
