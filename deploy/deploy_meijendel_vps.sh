#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_DATA="$REMOTE_BASE/data"
REMOTE_SHINY="$REMOTE_BASE/shiny"
REMOTE_WWW="$REMOTE_BASE/www"
REMOTE_APP="$REMOTE_BASE/vwg-m-linux-app"

SQL_LOCAL="$LOCAL_REPO/meijendel.sql"
SQL_DEPLOY="${TMPDIR:-/tmp}/meijendel_deploy_$$.sql"

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

trap 'rm -f "$SQL_DEPLOY"' EXIT

log "Maak VPS-dump zonder ledenadministratie/Appsmith-objecten en tellers"
LC_ALL=C awk '
  function sensitive(line) {
    return line ~ /`(appsmith_|pwa_)[^`]*`/ || line ~ /`tellers`/
  }
  function section_start(line) {
    return line ~ /^-- (Table structure for table|Dumping data for table|Temporary view structure for view|Final view structure for view) /
  }
  {
    if (section_start($0)) {
      skip = sensitive($0)
    }
    if (!skip) {
      print
    }
  }
' "$SQL_LOCAL" > "$SQL_DEPLOY"

log "Upload SQL naar canonieke dataplek"
ssh -i "$SSH_KEY" "$VPS" "
  set -euo pipefail
  mkdir -p '$REMOTE_DATA' '$REMOTE_SHINY' '$REMOTE_WWW' '$REMOTE_APP/data'
"
"${rsync_base[@]}" "$SQL_DEPLOY" "$VPS:$REMOTE_DATA/Meijendel.sql"
ssh -i "$SSH_KEY" "$VPS" "
  set -euo pipefail
  ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_SHINY/Meijendel.sql'
  ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_WWW/Meijendel.sql'
  ln -sfn '$REMOTE_DATA/Meijendel.sql' '$REMOTE_APP/data/Meijendel.sql'
"

log "Upload Shiny-app en gedeelde R-code"
if [ -d "$LOCAL_REPO/deploy/shiny_image" ]; then
  "${rsync_base[@]}" \
    "$LOCAL_REPO/deploy/shiny_image/" \
    "$VPS:$REMOTE_SHINY/"
fi

if [ -d "$LOCAL_REPO/shiny_meijendel" ]; then
  "${rsync_base[@]}" --delete \
    --exclude 'rsconnect/' \
    --exclude 'app_cache/' \
    "$LOCAL_REPO/shiny_meijendel/" \
    "$VPS:$REMOTE_SHINY/shiny_meijendel/"
fi

if [ -d "$LOCAL_REPO/R" ]; then
  "${rsync_base[@]}" --delete \
    "$LOCAL_REPO/R/" \
    "$VPS:$REMOTE_SHINY/R/"
fi

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

if [ -d "$LOCAL_REPO/groepen_grafieken" ]; then
  "${rsync_base[@]}" --delete \
    "$LOCAL_REPO/groepen_grafieken/" \
    "$VPS:$REMOTE_WWW/groepen_grafieken/"
fi

if [ -f "$LOCAL_REPO/app-home/index.html" ]; then
  log "Upload app-home"
  "${rsync_base[@]}" "$LOCAL_REPO/app-home/index.html" \
    "$VPS:$REMOTE_BASE/app-home/index.html"
fi

log "Herstart Shiny en controleer HTTP"
ssh -i "$SSH_KEY" "$VPS" "
	  set -euo pipefail

	  mkdir -p '$REMOTE_SHINY/shiny_meijendel/app_cache/sass'
	  docker run --rm -v '$REMOTE_SHINY/shiny_meijendel/app_cache:/app_cache' vwgm-shiny:latest \
	    chown -R shiny:shiny /app_cache

	  cd '$REMOTE_SHINY'
	  if ! grep -q '/app_cache:rw' docker-compose.yml; then
	    perl -0pi -e 's#(      - /srv/vwgm/shiny/shiny_meijendel:/srv/shiny-server/shiny_meijendel:ro\n)#\$1      - /srv/vwgm/shiny/shiny_meijendel/app_cache:/srv/shiny-server/shiny_meijendel/app_cache:rw\n#' docker-compose.yml
	  fi
	  docker compose up -d shiny >/dev/null

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

	  docker exec shiny_meijendel Rscript -e '
	    pkgs <- c(\"geepack\", \"glmmTMB\", \"vegan\", \"pls\", \"changepoint\", \"strucchange\", \"lavaan\", \"piecewiseSEM\", \"indicspecies\", \"betapart\", \"unmarked\")
	    ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
	    print(data.frame(package = pkgs, beschikbaar = unname(ok)))
	    if (!all(ok)) stop(\"Niet alle analysepackages zijn beschikbaar. Run eerst deploy/rebuild_shiny_image_vps.sh.\")
    perl <- Sys.which(\"perl\")
	    print(data.frame(system_tool = \"perl\", beschikbaar = nzchar(perl), pad = unname(perl)))
	    if (!nzchar(perl)) stop(\"Perl ontbreekt in de Shiny-container. Run eerst deploy/rebuild_shiny_image_vps.sh.\")
	  '

	  docker exec -u shiny shiny_meijendel sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e \"source(\\\"helpers.R\\\"); path <- \\\"/srv/shiny-server/Meijendel.sql\\\"; t <- system.time(x <- load_meijendel_tables_cached(path)); cat(sprintf(\\\"SQL cache: from_cache=%s elapsed=%.3f cache=%s\\\\n\\\", x[[\\\"from_cache\\\"]], unname(t[[\\\"elapsed\\\"]]), x[[\\\"cache_path\\\"]]))\"'

	  sha256sum \
	    '$REMOTE_DATA/Meijendel.sql' \
	    '$REMOTE_SHINY/Meijendel.sql' \
	    '$REMOTE_WWW/Meijendel.sql' \
	    '$REMOTE_APP/data/Meijendel.sql'
	  find '$REMOTE_BASE' -maxdepth 6 -name Meijendel.sql -type f -print
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
"

log "Klaar"
