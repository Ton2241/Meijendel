#!/usr/bin/env bash
# Runtime-only release: preserves app/data release identifiers and old data.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
VWG_M_REPO="${VWG_M_REPO:-$HOME/Documents/GitHub/VWG_M}"
VWG_PROJECT_REPO="${VWG_PROJECT_REPO:-$HOME/Documents/GitHub/VWG_Project}"
APPLY=0
YES=0
RETRY_ROLLED_BACK=0
CHECK_ONLY=0
REMOTE_STAGE=''
LOCAL_STAGE=''
REMOTE_STARTED=0
while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --yes) YES=1 ;;
    --retry-rolled-back) RETRY_ROLLED_BACK=1 ;;
    -h|--help) echo 'Gebruik: deploy/switch_mysql_974_vps.sh [--apply --yes | --check-only] [--retry-rolled-back]'; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done
source "$SCRIPT_DIR/production_guard.sh"
finish() {
  result=$?
  trap - EXIT
  quiescent=1
  if [[ "$REMOTE_STARTED" == 1 ]]; then
    completion="$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$VPS" "cat '$DEPLOY_GLOBAL_LOCK/mysql974-finished'" 2>/dev/null || true)"
    if [[ "$completion" != 'helper-finished' ]]; then
      quiescent=0
      echo 'BLOKKADE: remote-uitkomst onbekend; productieslot en bronmap blijven behouden totdat beëindiging is vastgesteld.' >&2
    fi
  fi
  if [[ "$quiescent" == 1 ]]; then
    if [[ -n "$REMOTE_STAGE" ]]; then
      ssh -i "$SSH_KEY" "$VPS" "rm -f '$REMOTE_STAGE/switch_mysql_974_vps_remote.py' '$REMOTE_STAGE/backup_baremetal_vps.py' '$REMOTE_STAGE/restore_new_vps.sh' '$REMOTE_STAGE/container-audit' '$REMOTE_STAGE/sources.json'; rmdir '$REMOTE_STAGE'" || true
    fi
    if [[ "$REMOTE_STARTED" == 1 ]]; then
      ssh -i "$SSH_KEY" "$VPS" "rm -f '$DEPLOY_GLOBAL_LOCK/mysql974-finished'" || true
    fi
    guard_release_lock
  fi
  [[ -z "$LOCAL_STAGE" ]] || rm -rf -- "$LOCAL_STAGE"
  exit "$result"
}
trap finish EXIT
guard_baseline
crossrepo() {
  local repo="$1" state="$2" previous
  "$repo/scripts/check_local_workspace.sh"
  [[ -z "$(git -C "$repo" status --porcelain)" && "$(git -C "$repo" branch --show-current)" == main ]] || guard_die "supportrepo is niet schoon op main: $repo"
  git -C "$repo" fetch origin --prune
  [[ "$(git -C "$repo" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)" ]] || guard_die "supportmain loopt achter: $repo"
  previous="$(guard_remote "cat '$DEPLOY_STATE_DIR/$state.commit'")"
  [[ "$previous" =~ ^[0-9a-f]{40}$ ]] || guard_die 'ongeldige supportproductiestatus'
  git -C "$repo" merge-base --is-ancestor "$previous" HEAD || guard_die 'supportproductie is geen voorouder'
  CROSS_PREVIOUS="$previous"
}
crossrepo "$VWG_M_REPO" VWG_M
APP_PREVIOUS="$CROSS_PREVIOUS"
crossrepo "$VWG_PROJECT_REPO" security-monitor
MONITOR_PREVIOUS="$CROSS_PREVIOUS"
[[ "$APP_PREVIOUS" =~ ^[0-9a-f]{40}$ && "$MONITOR_PREVIOUS" =~ ^[0-9a-f]{40}$ ]] || guard_die 'supportpreflight mislukt'
python3 "$LOCAL_REPO/scripts/test_mysql_974_cutover.py"
python3 "$LOCAL_REPO/scripts/test_mysql_candidate_versions.py"
if [[ "$CHECK_ONLY" == 1 ]]; then
  echo 'ALLEEN VPS-CONTROLE: geen installatie, schrijfblokkade of containerwissel.'
else
  echo 'OMSCHAKELING: geteste image c58c7a7ee443, aparte 9.7.4-datamap, bronvergelijking en automatische terugval.'
fi
echo 'Support: versieafhankelijke back-up/herstel en audit. App- en Meijendel-datarelease blijven gelijk.'
[[ "$APPLY" == 0 || "$CHECK_ONLY" == 0 ]] || guard_die '--apply en --check-only sluiten elkaar uit'
[[ "$APPLY" == 1 || "$CHECK_ONLY" == 1 ]] || { echo 'Preflight klaar; productie is niet aangepast.'; exit 0; }
[[ "$APPLY" == 0 || "$YES" == 1 ]] || guard_die '--apply vereist --yes'
guard_acquire_lock
[[ "$(guard_remote "cat '$DEPLOY_STATE_DIR/VWG_M.commit'")" == "$APP_PREVIOUS" && "$(guard_remote "cat '$DEPLOY_STATE_DIR/security-monitor.commit'")" == "$MONITOR_PREVIOUS" ]] || guard_die 'supportrelease veranderde tijdens preflight'
LOCAL_STAGE="$(mktemp -d /tmp/vwgm-mysql974-switch-local-XXXXXXXX)"
cp "$SCRIPT_DIR/switch_mysql_974_vps_remote.py" "$LOCAL_STAGE/"
cp "$VWG_M_REPO/website/vwg-m-linux-app/scripts/backup_baremetal_vps.py" "$LOCAL_STAGE/"
cp "$VWG_M_REPO/website/vwg-m-linux-app/scripts/restore_new_vps.sh" "$LOCAL_STAGE/"
cp "$VWG_PROJECT_REPO/scripts/vulnerability_audit_vps_remote.sh" "$LOCAL_STAGE/container-audit"
python3 - "$LOCAL_STAGE" "$DEPLOY_LOCAL_COMMIT" "$(git -C "$VWG_M_REPO" rev-parse HEAD)" "$(git -C "$VWG_PROJECT_REPO" rev-parse HEAD)" "$DEPLOY_PREVIOUS_COMMIT" "$APP_PREVIOUS" "$MONITOR_PREVIOUS" "$RETRY_ROLLED_BACK" "$CHECK_ONLY" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
manifest=dict(retry_rolled_back=sys.argv[8]=='1',check_only=sys.argv[9]=='1',sources=dict(zip(['Meijendel','VWG_M','VWG_Project'],sys.argv[2:5])),
              production=dict(zip(['Meijendel','VWG_M','security-monitor'],sys.argv[5:8])),
              files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.iterdir()})
(root/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
MANIFEST_HASH="$(shasum -a 256 "$LOCAL_STAGE/sources.json" | awk '{print $1}')"
REMOTE_STAGE="$(guard_remote 'mktemp -d /tmp/vwgm-mysql974-switch-stage-XXXXXXXX')"
[[ "$REMOTE_STAGE" =~ ^/tmp/vwgm-mysql974-switch-stage-[a-zA-Z0-9]+$ ]] || guard_die 'ongeldige tijdelijke map'
scp -i "$SSH_KEY" "$LOCAL_STAGE/"* "$VPS:$REMOTE_STAGE/"
BOOTSTRAP="$(cat <<'PY'
import hashlib,json,os,pathlib,subprocess,sys,tempfile
source=pathlib.Path(sys.argv[1])
manifest_bytes=(source/'sources.json').read_bytes()
if hashlib.sha256(manifest_bytes).hexdigest()!=sys.argv[2]: raise ValueError('bronmanifest gewijzigd')
manifest=json.loads(manifest_bytes)
names={'switch_mysql_974_vps_remote.py','backup_baremetal_vps.py','restore_new_vps.sh','container-audit'}
if set(manifest['files'])!=names: raise ValueError('onverwachte bestanden')
with tempfile.TemporaryDirectory(prefix='vwgm-mysql974-switch-root-',dir='/var/tmp') as work:
 root=pathlib.Path(work)
 for name in names:
  data=(source/name).read_bytes()
  if hashlib.sha256(data).hexdigest()!=manifest['files'][name]: raise ValueError('bronhash wijkt af:'+name)
  (root/name).write_bytes(data)
 (root/'sources.json').write_bytes(manifest_bytes)
 result=subprocess.run(['/usr/bin/python3','-I',str(root/'switch_mysql_974_vps_remote.py'),work])
# Only after the child has exited AND its temporary root directory is gone.
marker=pathlib.Path('/srv/vwgm/deploy-state/production.lock/mysql974-finished')
fd=os.open(marker,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o644)
os.fchmod(fd,0o644)
with os.fdopen(fd,'w') as stream:
 stream.write('helper-finished\n')
 stream.flush()
 os.fsync(stream.fileno())
sys.exit(result.returncode)
PY
)"
printf -v BOOTSTRAP_QUOTED '%q' "$BOOTSTRAP"
REMOTE_STARTED=1
ssh -tt -o ServerAliveInterval=30 -o ServerAliveCountMax=20 -i "$SSH_KEY" "$VPS" \
  "sudo /usr/bin/python3 -I -c $BOOTSTRAP_QUOTED '$REMOTE_STAGE' '$MANIFEST_HASH'"
if [[ "$CHECK_ONLY" == 1 ]]; then
  echo 'VPS-controle afgerond; geen database-, container- of configuratiewijzigingen uitgevoerd.'
  exit 0
fi
VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$VWG_M_REPO/website/vwg-m-linux-app/scripts/smoke_vps.sh"
echo 'MySQL9.7.4 VPS-omschakeling geslaagd; NAS-pull en beschermd snapshot nog controleren.'
