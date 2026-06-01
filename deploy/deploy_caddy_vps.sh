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

SESSION_SECRET="$(openssl rand -hex 32)"
sed "s/__VWG_SESSION_SECRET__/$SESSION_SECRET/g" "$TEMPLATE" > "$LOCAL_TMP"

log "Upload tijdelijke Caddyfile"
scp -i "$SSH_KEY" "$LOCAL_TMP" "$VPS:$REMOTE_TMP" >/dev/null

log "Installeer en valideer Caddy-config op VPS"
ssh -i "$SSH_KEY" "$VPS" "REMOTE_TMP='$REMOTE_TMP' bash -s" <<'REMOTE'
set -euo pipefail

AUTH_INCLUDE="/etc/caddy/vwg_basic_auth.caddy"
BACKUP="/etc/caddy/Caddyfile.bak-$(date +%Y%m%d-%H%M%S)"

if [ ! -s "$AUTH_INCLUDE" ]; then
  if sudo grep -q '^[[:space:]]*basic_auth[[:space:]]*{' /etc/caddy/Caddyfile; then
    sudo awk '
      /^[[:space:]]*basic_auth[[:space:]]*\{/ { capture = 1; depth = 0 }
      capture {
        print
        depth += gsub(/\{/, "{")
        depth -= gsub(/\}/, "}")
        if (depth == 0) exit
      }
    ' /etc/caddy/Caddyfile | sudo tee "$AUTH_INCLUDE" >/dev/null
    sudo chown root:caddy "$AUTH_INCLUDE"
    sudo chmod 640 "$AUTH_INCLUDE"
  else
    printf 'FOUT: %s ontbreekt en geen basic_auth-blok gevonden in /etc/caddy/Caddyfile\n' "$AUTH_INCLUDE" >&2
    exit 1
  fi
fi

sudo test -s "$AUTH_INCLUDE"
sudo chown root:caddy "$AUTH_INCLUDE"
sudo chmod 640 "$AUTH_INCLUDE"
sudo -u caddy test -r "$AUTH_INCLUDE"
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

SESSION_VALUE="$(sudo awk -F'vwg_session=' '/@vwg_session/ { split($2, a, "*"); print a[1] }' /etc/caddy/Caddyfile)"
for path in / /bmp_meijendel_index.html /Meijendel.sql /shiny_meijendel/; do
  code="$(curl -k -sS -o /dev/null -w '%{http_code}' --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  printf 'zonder sessie %s %s\n' "$code" "$path"
done
for path in / /bmp_meijendel_index.html /Meijendel.sql /shiny_meijendel/; do
  code="$(curl -k -sS -o /dev/null -w '%{http_code}' -H "Cookie: vwg_session=$SESSION_VALUE" --resolve app.vwg-m.nl:443:127.0.0.1 "https://app.vwg-m.nl$path")"
  printf 'met sessie %s %s\n' "$code" "$path"
done
REMOTE

log "Klaar"
