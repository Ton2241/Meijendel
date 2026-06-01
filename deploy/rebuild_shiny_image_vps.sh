#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_SHINY="${REMOTE_SHINY:-/srv/vwgm/shiny}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_IMAGE_DIR="$LOCAL_REPO/deploy/shiny_image"

if [ ! -d "$LOCAL_IMAGE_DIR" ]; then
  printf 'FOUT: map ontbreekt: %s\n' "$LOCAL_IMAGE_DIR" >&2
  exit 1
fi

rsync -az --checksum -e "ssh -i $SSH_KEY" \
  "$LOCAL_IMAGE_DIR/" \
  "$VPS:$REMOTE_SHINY/"

ssh -i "$SSH_KEY" "$VPS" "
  set -euo pipefail
  cd '$REMOTE_SHINY'
  docker compose build shiny
  docker compose up -d shiny

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
    pkgs <- c(\"geepack\", \"glmmTMB\", \"vegan\", \"pls\", \"changepoint\", \"strucchange\", \"lavaan\", \"piecewiseSEM\", \"betapart\", \"unmarked\")
    ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
    print(data.frame(package = pkgs, beschikbaar = unname(ok)))
    if (!all(ok)) stop(\"Niet alle analysepackages zijn beschikbaar.\")
    perl <- Sys.which(\"perl\")
    print(data.frame(system_tool = \"perl\", beschikbaar = nzchar(perl), pad = unname(perl)))
    if (!nzchar(perl)) stop(\"Perl ontbreekt in de Shiny-container.\")
  '
"
