#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/caddy/Caddyfile.template"
REMOTE_TMP="/tmp/Caddyfile.vwgm.$$"
APPLY=0
YES=0

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help) echo "Gebruik: deploy/deploy_caddy_vps.sh [--apply --yes]"; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

source "$SCRIPT_DIR/production_guard.sh"
trap guard_release_lock EXIT INT TERM
[[ -f "$TEMPLATE" ]] || guard_die "bestand ontbreekt: $TEMPLATE"
guard_baseline

echo "== Caddy-manifest en remote validatie =="
echo "deploy/caddy/Caddyfile.template -> /etc/caddy/Caddyfile"
ssh -i "$SSH_KEY" "$VPS" "tmp='$REMOTE_TMP'; trap 'rm -f \"\$tmp\"' EXIT; cat > \"\$tmp\"; sudo chmod 644 \"\$tmp\"; sudo caddy validate --config \"\$tmp\"; sudo -u caddy caddy adapt --config \"\$tmp\" >/dev/null" < "$TEMPLATE"

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; Caddy is niet gewijzigd. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "Caddy-deploy vereist --apply --yes."
guard_acquire_lock

scp -i "$SSH_KEY" "$TEMPLATE" "$VPS:$REMOTE_TMP" >/dev/null
ssh -i "$SSH_KEY" "$VPS" "REMOTE_TMP='$REMOTE_TMP' bash -s" <<'REMOTE'
set -euo pipefail
trap 'rm -f "$REMOTE_TMP"' EXIT
backup="/etc/caddy/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)"
sudo chmod 644 "$REMOTE_TMP"
sudo caddy validate --config "$REMOTE_TMP"
sudo -u caddy caddy adapt --config "$REMOTE_TMP" >/dev/null
sudo cp -p /etc/caddy/Caddyfile "$backup"
sudo cp "$REMOTE_TMP" /etc/caddy/Caddyfile
sudo chown root:root /etc/caddy/Caddyfile
sudo chmod 644 /etc/caddy/Caddyfile
sudo systemctl reload caddy
systemctl is-active caddy
for path in /welkom/index.asp /soorten/index.asp /kavels/index.asp; do
  code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  [[ "$code" == "200" ]] || { echo "FOUT: $path gaf $code" >&2; exit 1; }
done
for path in /bmp_meijendel_index.html /Meijendel.sql /shiny_meijendel/; do
  code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  [[ "$code" == "401" ]] || { echo "FOUT: $path gaf $code" >&2; exit 1; }
done
echo "Backup: $backup"
REMOTE
guard_write_state
echo "Caddy-deploy afgerond; productiecommit geregistreerd: $DEPLOY_LOCAL_COMMIT"
