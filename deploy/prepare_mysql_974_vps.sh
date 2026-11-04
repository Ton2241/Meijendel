#!/usr/bin/env bash
# Reviewed preparation only; no production container switch.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
APPLY=0
YES=0
REMOTE_STAGE=''
while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help) echo 'Gebruik: deploy/prepare_mysql_974_vps.sh [--apply --yes] (uitsluitend kandidaat)'; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done
source "$SCRIPT_DIR/production_guard.sh"
finish() {
  result=$?
  trap - EXIT
  if [[ -n "$REMOTE_STAGE" ]]; then
    ssh -i "$SSH_KEY" "$VPS" "rm -f '$REMOTE_STAGE/Dockerfile.9.7.4' '$REMOTE_STAGE/prepare_mysql_974_vps_remote.sh' '$REMOTE_STAGE/validate_mysql_uid_migration_vps_remote.sh'; rmdir '$REMOTE_STAGE'" || true
  fi
  guard_release_lock
  exit "$result"
}
trap finish EXIT
guard_baseline
python3 "$LOCAL_REPO/scripts/test_mysql_candidate_versions.py"
python3 "$LOCAL_REPO/scripts/test_mysql_974_candidate.py"
old_image="$(ssh -i "$SSH_KEY" -o BatchMode=yes "$VPS" sudo -n /usr/local/sbin/vwgm-admin container-status meijendel-mysql)"
IFS='|' read -r name image status <<< "$old_image"
[[ "$name" == /meijendel-mysql && "$image" == sha256:787656985cc0d4ba01768aab80976b3ad7a2ce0b870fb5a64b37cc80b08c99b2 && "$status" == running ]] || guard_die 'actieve uitgangssituatie wijkt af'
echo "KANDIDAAT: MySQL9.7.4, UID/GID1999, aparte datamap, 0HIGH/0CRITICAL en volledige proefimport verplicht."
echo "Productie blijft9.7.1; datarelease blijft $DEPLOY_PREVIOUS_COMMIT."
[[ "$APPLY" == 1 ]] || { echo 'Preflight klaar; nog niets op de VPS gewijzigd.'; exit 0; }
[[ "$YES" == 1 ]] || guard_die '--apply vereist --yes'
guard_acquire_lock
REMOTE_STAGE="$(ssh -i "$SSH_KEY" "$VPS" 'mktemp -d /tmp/vwgm-mysql974-stage-XXXXXXXX')"
[[ "$REMOTE_STAGE" =~ ^/tmp/vwgm-mysql974-stage-[a-zA-Z0-9]+$ ]] || guard_die 'ongeldige tijdelijke map'
names=(Dockerfile.9.7.4 prepare_mysql_974_vps_remote.sh validate_mysql_uid_migration_vps_remote.sh)
paths=("$SCRIPT_DIR/mysql_image/${names[0]}" "$SCRIPT_DIR/${names[1]}" "$SCRIPT_DIR/${names[2]}")
hashes=()
for path in "${paths[@]}"; do hashes+=("$(shasum -a 256 "$path" | awk '{print $1}')"); done
scp -i "$SSH_KEY" "${paths[@]}" "$VPS:$REMOTE_STAGE/"
# Read each input once after sudo, verify exactly those bytes, then execute
# the immutable-in-this-session root-owned snapshot; no ton-owned rootcode.
BOOTSTRAP="$(cat <<'PY'
import hashlib,pathlib,subprocess,sys,tempfile
source=pathlib.Path(sys.argv[1])
names=['Dockerfile.9.7.4','prepare_mysql_974_vps_remote.sh','validate_mysql_uid_migration_vps_remote.sh']
with tempfile.TemporaryDirectory(prefix='vwgm-mysql974-root-',dir='/var/tmp') as work:
 for name,expected in zip(names,sys.argv[2:5]):
  data=(source/name).read_bytes()
  assert hashlib.sha256(data).hexdigest()==expected, 'bronhash wijkt af'
  path=pathlib.Path(work)/name
  path.write_bytes(data)
  path.chmod(0o600)
 subprocess.run(['/bin/bash',str(pathlib.Path(work)/names[1]),work,*sys.argv[5:]],check=True)
PY
)"
printf -v BOOTSTRAP_QUOTED '%q' "$BOOTSTRAP"
ssh -tt -o ServerAliveInterval=30 -o ServerAliveCountMax=20 -i "$SSH_KEY" "$VPS" \
  "sudo /usr/bin/python3 -I -c $BOOTSTRAP_QUOTED '$REMOTE_STAGE' '${hashes[0]}' '${hashes[1]}' '${hashes[2]}' '$DEPLOY_LOCAL_COMMIT' '$image' '$DEPLOY_PREVIOUS_COMMIT'"
echo 'Kandidaatvoorbereiding afgerond; beoordeel het manifest vóór een afzonderlijke productiewissel.'
