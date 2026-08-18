#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_SHINY="${REMOTE_SHINY:-$REMOTE_BASE/shiny}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_IMAGE_DIR="$LOCAL_REPO/deploy/shiny_image"
VWG_PROJECT="${VWG_PROJECT:-$LOCAL_REPO/../VWG_Project}"
VWG_M="${VWG_M:-$LOCAL_REPO/../VWG_M}"
AUDIT_SCRIPT="$VWG_PROJECT/scripts/vulnerability_audit_vps.sh"
SMOKE_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh"
APPLY=0
YES=0
SUCCESS=0
SWITCH_STARTED=0
CANDIDATE_ID=""
OLD_IMAGE_ID=""
CANDIDATE_TAG=""
PREVIOUS_TAG=""
CANDIDATE_CONTAINER=""
CANDIDATE_CACHE=""

while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help)
      echo "Gebruik: deploy/rebuild_shiny_image_vps.sh [--apply --yes]"
      exit 0
      ;;
    *) echo "Onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

source "$SCRIPT_DIR/production_guard.sh"

remote_cleanup_or_rollback() {
  [[ -n "$CANDIDATE_ID" ]] || return 0
  ssh -i "$SSH_KEY" "$VPS" \
    "REMOTE_SHINY='$REMOTE_SHINY' CANDIDATE_ID='$CANDIDATE_ID' OLD_IMAGE_ID='$OLD_IMAGE_ID' CANDIDATE_TAG='$CANDIDATE_TAG' PREVIOUS_TAG='$PREVIOUS_TAG' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_CACHE='$CANDIDATE_CACHE' SWITCH_STARTED='$SWITCH_STARTED' bash -s" <<'REMOTE'
set -euo pipefail
docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
rm -rf -- "$CANDIDATE_CACHE"
if [[ "$SWITCH_STARTED" -eq 1 ]]; then
  docker tag "$OLD_IMAGE_ID" vwgm-shiny:latest
  cd "$REMOTE_SHINY"
  docker compose up -d --force-recreate shiny >/dev/null
  for attempt in $(seq 1 30); do
    curl -fsSI http://127.0.0.1:3838/ >/dev/null && break
    [[ "$attempt" -lt 30 ]] || exit 1
    sleep 2
  done
fi
docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true
docker image rm "$PREVIOUS_TAG" >/dev/null 2>&1 || true
if [[ "$(docker inspect --format '{{.Image}}' shiny_meijendel)" != "$CANDIDATE_ID" ]]; then
  docker image rm "$CANDIDATE_ID" >/dev/null 2>&1 || true
fi
docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
REMOTE
}

finish() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$SUCCESS" -ne 1 ]]; then
    remote_cleanup_or_rollback || \
      printf 'URGENT: automatische Shiny-rollback/opruiming faalde; controleer productie direct.\n' >&2
  fi
  guard_release_lock
  exit "$status"
}
trap finish EXIT INT TERM

[[ -d "$LOCAL_IMAGE_DIR" ]] || guard_die "map ontbreekt: $LOCAL_IMAGE_DIR"
[[ -x "$AUDIT_SCRIPT" ]] || guard_die "audit ontbreekt of is niet uitvoerbaar: $AUDIT_SCRIPT"
[[ -x "$SMOKE_SCRIPT" ]] || guard_die "rooktest ontbreekt of is niet uitvoerbaar: $SMOKE_SCRIPT"
guard_baseline
"$LOCAL_REPO/scripts/test_container_image_definitions.sh"

short_commit="${DEPLOY_LOCAL_COMMIT:0:12}"
CANDIDATE_TAG="vwgm-shiny:candidate-$short_commit"
PREVIOUS_TAG="vwgm-shiny:previous-$short_commit"
CANDIDATE_CONTAINER="shiny_meijendel_candidate_$short_commit"
CANDIDATE_CACHE="$REMOTE_SHINY/.candidate-cache-$short_commit"

echo "== Shiny-image manifest en rsync dry-run =="
echo "deploy/shiny_image/ -> $REMOTE_SHINY/"
rsync -az --checksum --delay-updates --itemize-changes --dry-run \
  -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_SHINY/"
ssh -i "$SSH_KEY" "$VPS" "curl -fsSI http://127.0.0.1:3838/ >/dev/null"

echo "== Baseline container-image-audit =="
set +e
baseline_output="$("$AUDIT_SCRIPT" --containers-only 2>&1)"
baseline_status=$?
set -e
printf '%s\n' "$baseline_output"
if [[ "$baseline_status" -ne 0 ]] && \
   ! grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=43|fix_beschikbaar=0|zonder_fix=43' <<<"$baseline_output"; then
  guard_die "baseline-audit wijkt af van de gedocumenteerde 0 CRITICAL/43 HIGH zonder fix."
fi

if [[ "$APPLY" -ne 1 ]]; then
  echo "Preflight klaar; image is niet gewijzigd. Gebruik --apply --yes na beoordeling."
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "image-rebuild vereist --apply --yes."
guard_acquire_lock

rsync -az --checksum --delay-updates --itemize-changes \
  -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_SHINY/"

OLD_IMAGE_ID="$(ssh -i "$SSH_KEY" "$VPS" \
  "docker inspect --format '{{.Image}}' shiny_meijendel")"
[[ "$OLD_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "ongeldige actieve Shiny-image-ID."

echo "== Bouw verse geïsoleerde kandidaat =="
build_output="$(ssh -i "$SSH_KEY" "$VPS" \
  "REMOTE_SHINY='$REMOTE_SHINY' CANDIDATE_TAG='$CANDIDATE_TAG' BUILDER_NAME='vwgm-shiny-$short_commit' bash -s" <<'REMOTE'
set -euo pipefail
cd "$REMOTE_SHINY"
if docker image inspect "$CANDIDATE_TAG" >/dev/null 2>&1; then
  echo "BLOKKADE: kandidaattag bestaat al: $CANDIDATE_TAG" >&2
  exit 1
fi
docker buildx create --name "$BUILDER_NAME" --driver docker-container >/dev/null
cleanup_builder() {
  docker buildx rm "$BUILDER_NAME" >/dev/null 2>&1 || true
  docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
}
trap cleanup_builder EXIT
docker buildx build --builder "$BUILDER_NAME" --platform linux/amd64 \
  --pull --no-cache --load --tag "$CANDIDATE_TAG" .
candidate_id="$(docker image inspect --format '{{.Id}}' "$CANDIDATE_TAG")"
[[ "$candidate_id" =~ ^sha256:[0-9a-f]{64}$ ]]
printf 'CANDIDATE_ID=%s\n' "$candidate_id"
REMOTE
)"
printf '%s\n' "$build_output"
CANDIDATE_ID="$(sed -n 's/^CANDIDATE_ID=//p' <<<"$build_output" | tail -n 1)"
[[ "$CANDIDATE_ID" =~ ^sha256:[0-9a-f]{64}$ ]] || guard_die "kandidaat-image-ID ontbreekt."

echo "== Scan exacte kandidaat-image-ID =="
set +e
candidate_audit="$("$AUDIT_SCRIPT" --containers-only --image "$CANDIDATE_ID" 2>&1)"
candidate_audit_status=$?
set -e
printf '%s\n' "$candidate_audit"
candidate_short="${CANDIDATE_ID#sha256:}"
candidate_label="kandidaat-${candidate_short:0:12}"
grep -Fq "SAMENVATTING|$candidate_label|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" \
  <<<"$candidate_audit" || guard_die "kandidaat heeft HIGH/CRITICAL-bevindingen of is niet exact gescand."
if [[ "$candidate_audit_status" -ne 0 ]]; then
  grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=43|fix_beschikbaar=0|zonder_fix=43' \
    <<<"$candidate_audit" || guard_die "kandidaataudit faalde buiten de bekende oude Shiny-baseline."
fi

echo "== Test kandidaat geïsoleerd op 127.0.0.1:3839 =="
ssh -i "$SSH_KEY" "$VPS" \
  "REMOTE_SHINY='$REMOTE_SHINY' CANDIDATE_ID='$CANDIDATE_ID' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_CACHE='$CANDIDATE_CACHE' bash -s" <<'REMOTE'
set -euo pipefail
test ! -e "$CANDIDATE_CACHE"
mkdir -p "$CANDIDATE_CACHE/sass"
docker run --rm -v "$CANDIDATE_CACHE:/app_cache" "$CANDIDATE_ID" chown -R shiny:shiny /app_cache
docker run -d --name "$CANDIDATE_CONTAINER" --restart no \
  -p 127.0.0.1:3839:3838 \
  --mount type=bind,src="$REMOTE_SHINY/shiny_meijendel",dst=/srv/shiny-server/shiny_meijendel,readonly \
  --mount type=bind,src="$CANDIDATE_CACHE",dst=/srv/shiny-server/shiny_meijendel/app_cache \
  --mount type=bind,src="$REMOTE_SHINY/Meijendel.sql",dst=/srv/shiny-server/Meijendel.sql,readonly \
  --mount type=bind,src="$REMOTE_SHINY/R",dst=/srv/shiny-server/R,readonly \
  "$CANDIDATE_ID" >/dev/null
for attempt in $(seq 1 30); do
  if curl -fsSI http://127.0.0.1:3839/ >/dev/null; then
    echo "Kandidaat gereed na poging $attempt"
    break
  fi
  [[ "$attempt" -lt 30 ]] || { docker logs --tail 120 "$CANDIDATE_CONTAINER" >&2; exit 1; }
  sleep 2
done
docker exec "$CANDIDATE_CONTAINER" Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  stopifnot(all(vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)))
  stopifnot(nzchar(Sys.which("perl")))
'
docker exec "$CANDIDATE_CONTAINER" sh -lc '
  for package in build-essential cmake g++ gcc gfortran make r-base-dev libc6-dev linux-libc-dev libcurl4-openssl-dev libglpk-dev libgmp3-dev libssl-dev libudunits2-dev libxml2-dev; do
    ! dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii'
  done
  ! find /usr/local/lib/R/site-library -type f -name "*.so" -exec ldd {} \; | grep -F "not found"
'
docker exec -u shiny "$CANDIDATE_CONTAINER" sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); stopifnot(file.exists(x[[\"cache_path\"]])); print(x[c(\"from_cache\", \"cache_path\")])"'
docker rm -f "$CANDIDATE_CONTAINER" >/dev/null
rm -rf -- "$CANDIDATE_CACHE"
REMOTE

echo "== Activeer kandidaat met automatische rollbackbeveiliging =="
SWITCH_STARTED=1
ssh -i "$SSH_KEY" "$VPS" \
  "REMOTE_SHINY='$REMOTE_SHINY' OLD_IMAGE_ID='$OLD_IMAGE_ID' CANDIDATE_ID='$CANDIDATE_ID' PREVIOUS_TAG='$PREVIOUS_TAG' bash -s" <<'REMOTE'
set -euo pipefail
docker tag "$OLD_IMAGE_ID" "$PREVIOUS_TAG"
docker tag "$CANDIDATE_ID" vwgm-shiny:latest
cd "$REMOTE_SHINY"
docker compose up -d --force-recreate shiny >/dev/null
for attempt in $(seq 1 30); do
  if curl -fsSI http://127.0.0.1:3838/ >/dev/null; then
    echo "Shiny gereed na poging $attempt"
    break
  fi
  [[ "$attempt" -lt 30 ]] || { docker logs --tail 120 shiny_meijendel >&2; exit 1; }
  sleep 2
done
[[ "$(docker inspect --format '{{.Image}}' shiny_meijendel)" == "$CANDIDATE_ID" ]]
docker exec shiny_meijendel Rscript -e '
  pkgs <- c("geepack", "glmmTMB", "vegan", "pls", "changepoint", "strucchange", "lavaan", "piecewiseSEM", "indicspecies", "betapart", "unmarked")
  stopifnot(all(vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)))
  stopifnot(nzchar(Sys.which("perl")))
'
docker exec -u shiny shiny_meijendel sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); stopifnot(file.exists(x[[\"cache_path\"]])); print(x[c(\"from_cache\", \"cache_path\")])"'
REMOTE

VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"

echo "== Verwijder exact de taakartefacten en oude niet-aangewezen Shiny-image =="
ssh -i "$SSH_KEY" "$VPS" \
  "CANDIDATE_ID='$CANDIDATE_ID' OLD_IMAGE_ID='$OLD_IMAGE_ID' CANDIDATE_TAG='$CANDIDATE_TAG' PREVIOUS_TAG='$PREVIOUS_TAG' bash -s" <<'REMOTE'
set -euo pipefail
[[ "$(docker inspect --format '{{.Image}}' shiny_meijendel)" == "$CANDIDATE_ID" ]]
docker image rm "$CANDIDATE_TAG"
docker image rm "$PREVIOUS_TAG"
docker image rm "$OLD_IMAGE_ID"
docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
test "$(docker ps -a --format '{{.Names}}' | wc -l)" -eq 3
test "$(docker images --format '{{.Repository}}:{{.Tag}}' | wc -l)" -eq 3
docker ps -a --no-trunc
docker images --no-trunc
docker system df
REMOTE

guard_write_state
SUCCESS=1
echo "Image-rebuild afgerond; productiecommit geregistreerd: $DEPLOY_LOCAL_COMMIT"
