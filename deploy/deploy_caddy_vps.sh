#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/caddy/Caddyfile.template"

REMOTE_TMP="/tmp/Caddyfile.vwgm.$$"
LOCAL_TMP="${TMPDIR:-/tmp}/Caddyfile.vwgm.$$"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_file() {
  [ -f "$1" ] || {
    printf 'FOUT: bestand ontbreekt: %s\n' "$1" >&2
    exit 1
  }
}

need_file "$TEMPLATE"

trap 'rm -f "$LOCAL_TMP"' EXIT

cp "$TEMPLATE" "$LOCAL_TMP"

log "Upload tijdelijke Caddyfile"
scp -i "$SSH_KEY" "$LOCAL_TMP" "$VPS:$REMOTE_TMP" >/dev/null

log "Installeer en valideer Caddy-config op VPS"
ssh -i "$SSH_KEY" "$VPS" "REMOTE_TMP='$REMOTE_TMP' bash -s" <<'REMOTE'
set -euo pipefail

BACKUP="/etc/caddy/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)"
sudo chmod 644 "$REMOTE_TMP"
sudo caddy validate --config "$REMOTE_TMP"
sudo -u caddy caddy adapt --config "$REMOTE_TMP" >/dev/null
sudo cp -p /etc/caddy/Caddyfile "$BACKUP"
sudo cp "$REMOTE_TMP" /etc/caddy/Caddyfile
sudo chown root:root /etc/caddy/Caddyfile
sudo chmod 644 /etc/caddy/Caddyfile
sudo systemctl reload caddy
rm -f "$REMOTE_TMP"

printf 'Backup: %s\n' "$BACKUP"
systemctl is-active caddy

for path in / /welkom/index.asp /soorten/index.asp /kavels/index.asp /proef-vwg-m-app/welkom/index.asp; do
  code="$(curl -k -sS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  printf 'publiek %s %s\n' "$code" "$path"
done
for path in /bmp_meijendel_index.html /Meijendel.sql /meijendel.sql /shiny_meijendel/ /trim_msi_evg/trendoverzicht_msi_groepen.csv /output_ecologische_groepen/gam_interpretatie_per_groep.csv; do
  code="$(curl -k -sS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  printf 'leden-only %s %s\n' "$code" "$path"
done
REMOTE

log "Klaar"
