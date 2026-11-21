#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VWG_PROJECT="${VWG_PROJECT:-/Users/ton/Documents/GitHub/VWG_Project}"
VWG_M="${VWG_M:-/Users/ton/Documents/GitHub/VWG_M}"
SMOKE_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh"
DOCKERFILE="$SCRIPT_DIR/mysql_image/Dockerfile.9.7.4"
REMOTE_HELPER="$SCRIPT_DIR/rebuild_mysql_974_security_vps_remote.sh"
VALIDATE_HELPER="$SCRIPT_DIR/validate_mysql_uid_migration_vps_remote.sh"
ACTIVE_CONTAINER="meijendel-mysql"
APPLY=0
YES=0
FINALIZE=0
REMOTE_STAGE=""
REMOTE_EXECUTION_STARTED=0
REMOTE_EXECUTION_COMPLETE=0

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --finalize) APPLY=1; FINALIZE=1 ;;
    --yes) YES=1 ;;
    -h|--help)
      echo "Gebruik: deploy/rebuild_mysql_974_security_vps.sh [--apply --yes | --finalize --yes]"
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
    "rm -f '$REMOTE_STAGE/Dockerfile.9.7.4' '$REMOTE_STAGE/rebuild-mysql-974-security' '$REMOTE_STAGE/validate-mysql'; rmdir '$REMOTE_STAGE' 2>/dev/null || true" || true
}

finish() {
  local status=$?
  trap - EXIT INT TERM
  if [[ "$REMOTE_EXECUTION_STARTED" -eq 1 && "$REMOTE_EXECUTION_COMPLETE" -ne 1 ]]; then
    printf 'BLOKKADE: remote onderhoudsuitkomst is onbekend; stagingmap %s en productielock blijven staan voor proces- en toestandscontrole.\n' "$REMOTE_STAGE" >&2
    exit "$status"
  fi
  cleanup_stage
  guard_release_lock
  exit "$status"
}
trap finish EXIT INT TERM

[[ -f "$DOCKERFILE" ]] || guard_die "MySQL 9.7.4-Dockerfile ontbreekt."
[[ -x "$REMOTE_HELPER" ]] || guard_die "remote 9.7.4-beveiligingshelper ontbreekt."
[[ -x "$VALIDATE_HELPER" ]] || guard_die "MySQL-validator ontbreekt."
[[ -x "$SMOKE_SCRIPT" ]] || guard_die "rooktest ontbreekt."
[[ -f "$SSH_KEY" ]] || guard_die "SSH-sleutel ontbreekt."

guard_baseline
"$LOCAL_REPO/scripts/test_container_image_definitions.sh"
"$LOCAL_REPO/scripts/test_rebuild_mysql_974_security.sh"

queue_state="$(ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" \
  'if test -e /etc/vwgm/vps-queue-required; then echo VPS_QUEUE=required; else echo VPS_QUEUE=legacy; fi')"
printf '%s\n' "$queue_state"
[[ "$queue_state" == "VPS_QUEUE=legacy" ]] ||
  guard_die "de beheerde VPS-wachtrij is verplicht; deze onderhoudsactie heeft nog geen toegestane wachtrij-ingang."

container_line="$(ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" \
  sudo -n /usr/local/sbin/vwgm-admin container-status "$ACTIVE_CONTAINER")"
IFS='|' read -r container_name old_image_id container_state <<< "$container_line"
[[ "$container_name" == "/$ACTIVE_CONTAINER" ]] || guard_die "actieve MySQL-container wijkt af."
[[ "$old_image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "actieve MySQL-image-ID is ongeldig."
[[ "$container_state" == "running" ]] || guard_die "actieve MySQL-container draait niet."

dockerfile_hash="$(shasum -a 256 "$DOCKERFILE" | awk '{print $1}')"
helper_hash="$(shasum -a 256 "$REMOTE_HELPER" | awk '{print $1}')"
validator_hash="$(shasum -a 256 "$VALIDATE_HELPER" | awk '{print $1}')"

echo "== Begrensd MySQL 9.7.4-beveiligingsmanifest =="
printf '%s\n' \
  "BRON|deploy/mysql_image/Dockerfile.9.7.4|sha256=$dockerfile_hash" \
  "HELPER|deploy/rebuild_mysql_974_security_vps_remote.sh|sha256=$helper_hash" \
  "VALIDATOR|deploy/validate_mysql_uid_migration_vps_remote.sh|sha256=$validator_hash" \
  "ACTIEF|container=$ACTIVE_CONTAINER|image=$old_image_id" \
  "DOEL|MySQL=9.7.4|UID:GID=1999:1999|libxml2>=2.9.13-18.el9_9.1|curl/libcurl>=7.76.1-44.el9_9.1|krb5-libs>=1.21.1-10.0.1.el9_9.2|high=0|critical=0" \
  "DATARELEASE|ongewijzigd=$DEPLOY_PREVIOUS_COMMIT|imagebron=$DEPLOY_LOCAL_COMMIT" \
  'GRENS|datamount-op-afstand-gebonden|geen-datamapmigratie|geen-docker-prune|exacte-rollback-behouden'

echo "== Read-only startgate =="
ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" sudo -n /usr/local/sbin/vwgm-admin mysql-health
ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" sudo -n /usr/local/sbin/vwgm-admin backup-status
VWG_ADMIN_GATEWAY=1 "$VWG_M/website/vwg-m-linux-app/scripts/check_caddy_mysql_isolation_vps.sh"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; image, container en databases zijn niet gewijzigd. Gebruik --apply --yes na afzonderlijk akkoord."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "onderhoud vereist --apply --yes of --finalize --yes."

guard_acquire_lock
REMOTE_STAGE="$(ssh -i "$SSH_KEY" "$VPS" 'mktemp -d /tmp/vwgm-mysql974-security-stage-XXXXXXXX')"
[[ "$REMOTE_STAGE" =~ ^/tmp/vwgm-mysql974-security-stage-[A-Za-z0-9]+$ ]] || guard_die "ongeldige tijdelijke VPS-map."
scp -i "$SSH_KEY" "$DOCKERFILE" "$VPS:$REMOTE_STAGE/Dockerfile.9.7.4"
scp -i "$SSH_KEY" "$REMOTE_HELPER" "$VPS:$REMOTE_STAGE/rebuild-mysql-974-security"
scp -i "$SSH_KEY" "$VALIDATE_HELPER" "$VPS:$REMOTE_STAGE/validate-mysql"

# Root leest de ton-eigendom stagingbestanden exact eenmaal, controleert de hashes
# en voert daarna uitsluitend de root-eigendom momentopname uit.
BOOTSTRAP="$(cat <<'PY'
import hashlib,pathlib,subprocess,sys,tempfile
source=pathlib.Path(sys.argv[1])
names=['Dockerfile.9.7.4','rebuild-mysql-974-security','validate-mysql']
with tempfile.TemporaryDirectory(prefix='vwgm-mysql974-security-root-',dir='/var/tmp') as work:
    root=pathlib.Path(work)
    for name,expected in zip(names,sys.argv[2:5]):
        data=(source/name).read_bytes()
        assert hashlib.sha256(data).hexdigest()==expected, 'bronhash wijkt af'
        target=root/name
        target.write_bytes(data)
        target.chmod(0o700 if name != 'Dockerfile.9.7.4' else 0o600)
    subprocess.run(['/bin/bash',str(root/'rebuild-mysql-974-security'),work,*sys.argv[5:]],check=True)
PY
)"
printf -v BOOTSTRAP_QUOTED '%q' "$BOOTSTRAP"
REMOTE_EXECUTION_STARTED=1
set +e
ssh -tt -o ServerAliveInterval=30 -o ServerAliveCountMax=20 -i "$SSH_KEY" "$VPS" \
  "sudo /usr/bin/python3 -I -c $BOOTSTRAP_QUOTED '$REMOTE_STAGE' '$dockerfile_hash' '$helper_hash' '$validator_hash' '$DEPLOY_LOCAL_COMMIT' '$old_image_id' '$DEPLOY_PREVIOUS_COMMIT' '$FINALIZE'"
remote_status=$?
set -e
[[ "$remote_status" -eq 0 ]] || guard_die "remote onderhoud eindigde zonder bevestigde uitkomst; controleer eerst proces, lock en containerstatus."
REMOTE_EXECUTION_COMPLETE=1

echo "== Onafhankelijke nacontrole =="
VWG_ADMIN_GATEWAY=1 "$VWG_M/website/vwg-m-linux-app/scripts/check_caddy_mysql_isolation_vps.sh"
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"
remote_state="$(ssh -i "$SSH_KEY" "$VPS" "cat '$DEPLOY_STATE_FILE'")"
[[ "$remote_state" == "$DEPLOY_PREVIOUS_COMMIT" ]] || guard_die "Meijendel-datarelease is tijdens image-onderhoud gewijzigd."

echo "MySQL 9.7.4-beveiligingsonderhoud afgerond; datarelease ongewijzigd: $DEPLOY_PREVIOUS_COMMIT"
