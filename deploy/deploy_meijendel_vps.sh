#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_SHINY="$REMOTE_BASE/shiny"
REMOTE_WWW="$REMOTE_BASE/www"
REMOTE_LEDEN="$REMOTE_BASE/ledenadministratie"

SQL_LOCAL="$LOCAL_REPO/meijendel.sql"

rsync_ssh=(ssh -i "$SSH_KEY")
rsync_base=(rsync -az --checksum -e "${rsync_ssh[*]}")

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_file() {
  [ -f "$1" ] || {
    printf 'FOUT: bestand ontbreekt: %s\n' "$1" >&2
    exit 1
  }
}

need_dir() {
  [ -d "$1" ] || {
    printf 'FOUT: map ontbreekt: %s\n' "$1" >&2
    exit 1
  }
}

need_file "$SQL_LOCAL"
need_dir "$LOCAL_REPO/pwa_ledenadministratie"

log "Upload SQL naar Shiny en www"
"${rsync_base[@]}" "$SQL_LOCAL" "$VPS:$REMOTE_SHINY/Meijendel.sql"
"${rsync_base[@]}" "$SQL_LOCAL" "$VPS:$REMOTE_WWW/Meijendel.sql"

log "Upload Shiny-app en gedeelde R-code"
if [ -d "$LOCAL_REPO/shiny_meijendel" ]; then
  "${rsync_base[@]}" --delete \
    --exclude 'rsconnect/' \
    "$LOCAL_REPO/shiny_meijendel/" \
    "$VPS:$REMOTE_SHINY/shiny_meijendel/"
fi

if [ -d "$LOCAL_REPO/R" ]; then
  "${rsync_base[@]}" --delete \
    "$LOCAL_REPO/R/" \
    "$VPS:$REMOTE_SHINY/R/"
fi

log "Upload ledenadministratie/PWA-code"
"${rsync_base[@]}" --delete \
  --exclude '.DS_Store' \
  --exclude '.env' \
  --exclude 'backups/' \
  --exclude 'deploy/sql/' \
  "$LOCAL_REPO/pwa_ledenadministratie/" \
  "$VPS:$REMOTE_LEDEN/"

log "Upload HTML-dashboard en outputbestanden"
if [ -f "$LOCAL_REPO/bmp_meijendel_index.html" ]; then
  "${rsync_base[@]}" "$LOCAL_REPO/bmp_meijendel_index.html" \
    "$VPS:$REMOTE_WWW/bmp_meijendel_index.html"
fi

if [ -f "$LOCAL_REPO/index.html" ]; then
  "${rsync_base[@]}" "$LOCAL_REPO/index.html" "$VPS:$REMOTE_WWW/index.html"
fi

if [ -d "$LOCAL_REPO/output_ecologische_groepen" ]; then
  "${rsync_base[@]}" --delete \
    "$LOCAL_REPO/output_ecologische_groepen/" \
    "$VPS:$REMOTE_WWW/output_ecologische_groepen/"
fi

if [ -d "$LOCAL_REPO/trim_msi_evg" ]; then
  "${rsync_base[@]}" --delete \
    "$LOCAL_REPO/trim_msi_evg/" \
    "$VPS:$REMOTE_WWW/trim_msi_evg/"
fi

if [ -f "$LOCAL_REPO/app-home/index.html" ]; then
  log "Upload app-home"
  "${rsync_base[@]}" "$LOCAL_REPO/app-home/index.html" \
    "$VPS:$REMOTE_BASE/app-home/index.html"
fi

log "Importeer SQL, ververs PWA-views, rebuild webcontainer en herstart Shiny"
ssh -i "$SSH_KEY" "$VPS" "
  set -euo pipefail
  cd '$REMOTE_LEDEN'

  docker compose --env-file .env -f deploy/docker-compose.yml up -d --build db web

  docker compose --env-file .env -f deploy/docker-compose.yml exec -T db sh -c \
    'mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" < /import/Meijendel.sql'

  docker compose --env-file .env -f deploy/docker-compose.yml exec -T db sh -c \
    'mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" < /import/01_views_ledenadministratie_pwa.sql'

  docker compose --env-file .env -f deploy/docker-compose.yml exec -T db sh -c \
    'mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" < /import/02_magic_link_auth.sql'

  docker restart shiny_meijendel >/dev/null

  curl -fsS http://127.0.0.1:8091/api/auth/status.php
  printf '\n'
  docker compose --env-file .env -f deploy/docker-compose.yml exec -T db sh -c \
    'mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" \"\$MYSQL_DATABASE\" -N -e \"SELECT COUNT(*) FROM pwa_teller_stats;\"'

  for attempt in \$(seq 1 30); do
    if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
      printf 'Shiny HTTP-check ok na poging %s\n' \"\$attempt\"
      break
    fi
    if [ \"\$attempt\" -eq 30 ]; then
      printf 'FOUT: Shiny gaf na 60 seconden nog geen HTTP 200 terug.\n' >&2
      docker ps --filter name=shiny_meijendel --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
      docker logs --tail 80 shiny_meijendel >&2
      exit 1
    fi
    sleep 2
  done

  sha256sum '$REMOTE_SHINY/Meijendel.sql' '$REMOTE_WWW/Meijendel.sql'
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
"

log "Klaar"
