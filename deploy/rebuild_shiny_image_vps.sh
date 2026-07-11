#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_SHINY="${REMOTE_SHINY:-$REMOTE_BASE/shiny}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_IMAGE_DIR="$LOCAL_REPO/deploy/shiny_image"
APPLY=0
YES=0

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help) echo "Gebruik: deploy/rebuild_shiny_image_vps.sh [--apply --yes]"; exit 0 ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

source "$SCRIPT_DIR/production_guard.sh"
trap guard_release_lock EXIT INT TERM
[[ -d "$LOCAL_IMAGE_DIR" ]] || guard_die "map ontbreekt: $LOCAL_IMAGE_DIR"
guard_baseline

echo "== Shiny-image manifest en rsync dry-run =="
echo "deploy/shiny_image/ -> $REMOTE_SHINY/"
rsync -az --checksum --delay-updates --itemize-changes --dry-run -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_SHINY/"
ssh -i "$SSH_KEY" "$VPS" "curl -fsSI http://127.0.0.1:3838/ >/dev/null"

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; image is niet gewijzigd. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "image-rebuild vereist --apply --yes."
guard_acquire_lock

rsync -az --checksum --delay-updates --itemize-changes -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_SHINY/"
ssh -i "$SSH_KEY" "$VPS" "REMOTE_SHINY='$REMOTE_SHINY' bash -s" <<'REMOTE'
set -euo pipefail
cd "$REMOTE_SHINY"
mkdir -p "$REMOTE_SHINY/shiny_meijendel/app_cache/sass"
if ! grep -q '/app_cache:rw' docker-compose.yml; then
  perl -0pi -e 's#(      - /srv/vwgm/shiny/shiny_meijendel:/srv/shiny-server/shiny_meijendel:ro\n)#$1      - /srv/vwgm/shiny/shiny_meijendel/app_cache:/srv/shiny-server/shiny_meijendel/app_cache:rw\n#' docker-compose.yml
fi
docker compose build shiny
docker compose up -d shiny
for attempt in $(seq 1 30); do
  if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
    echo "Shiny gereed na poging $attempt"
    break
  fi
  [[ "$attempt" -lt 30 ]] || { docker logs --tail 120 shiny_meijendel >&2; exit 1; }
  sleep 2
done
docker exec shiny_meijendel Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
  print(data.frame(package = pkgs, beschikbaar = unname(ok)))
  if (!all(ok)) stop("Niet alle analysepackages zijn beschikbaar.")
'
REMOTE
guard_write_state
echo "Image-rebuild afgerond; productiecommit geregistreerd: $DEPLOY_LOCAL_COMMIT"
