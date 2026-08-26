#!/usr/bin/env bash
set -euo pipefail

VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
REMOTE_BASE="${REMOTE_BASE:-/srv/vwgm}"
REMOTE_SHINY="${REMOTE_SHINY:-$REMOTE_BASE/shiny}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_IMAGE_DIR="$LOCAL_REPO/deploy/shiny_image"
LOCAL_LOCKFILE="$LOCAL_REPO/renv.lock"
LOCAL_DESCRIPTION="$LOCAL_REPO/DESCRIPTION"
VWG_PROJECT="${VWG_PROJECT:-$LOCAL_REPO/../VWG_Project}"
VWG_M="${VWG_M:-$LOCAL_REPO/../VWG_M}"
AUDIT_SCRIPT="$VWG_PROJECT/scripts/vulnerability_audit_vps.sh"
SMOKE_SCRIPT="$VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh"
APPLY=0
YES=0
CANDIDATE_ONLY=0
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
    --candidate-only) CANDIDATE_ONLY=1 ;;
    -h|--help)
      echo "Gebruik: deploy/rebuild_shiny_image_vps.sh [--candidate-only] [--apply --yes]"
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
if [[ -d "$CANDIDATE_CACHE" ]]; then
  docker run --rm -v "$CANDIDATE_CACHE:/app_cache" "$CANDIDATE_ID" \
    chown -R "$(id -u):$(id -g)" /app_cache >/dev/null 2>&1 || true
fi
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
[[ -f "$LOCAL_LOCKFILE" ]] || guard_die "lockfile ontbreekt: $LOCAL_LOCKFILE"
[[ -f "$LOCAL_DESCRIPTION" ]] || guard_die "DESCRIPTION ontbreekt: $LOCAL_DESCRIPTION"
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
rsync -az --checksum --delay-updates --itemize-changes --dry-run \
  -e "ssh -i $SSH_KEY" "$LOCAL_LOCKFILE" "$LOCAL_DESCRIPTION" "$VPS:$REMOTE_SHINY/"
ssh -i "$SSH_KEY" "$VPS" "curl -fsSI http://127.0.0.1:3838/ >/dev/null"

echo "== Baseline container-image-audit =="
set +e
baseline_output="$("$AUDIT_SCRIPT" --containers-only 2>&1)"
baseline_status=$?
set -e
printf '%s\n' "$baseline_output"
if [[ "$baseline_status" -ne 0 ]] && \
   ! grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=43|fix_beschikbaar=0|zonder_fix=43' <<<"$baseline_output"; then
  guard_die "baseline-audit bevat andere HIGH/CRITICAL-bevindingen dan de gedocumenteerde oude Shiny-baseline."
fi

if [[ "$APPLY" -ne 1 ]]; then
  if [[ "$CANDIDATE_ONLY" -eq 1 ]]; then
    echo "Preflight klaar; image is niet gewijzigd. Gebruik --candidate-only --apply --yes na beoordeling."
  else
    echo "Preflight klaar; image is niet gewijzigd. Gebruik --apply --yes na beoordeling."
  fi
  exit 0
fi
[[ "$YES" -eq 1 ]] || guard_die "image-rebuild vereist --apply --yes."
guard_acquire_lock

rsync -az --checksum --delay-updates --itemize-changes \
  -e "ssh -i $SSH_KEY" "$LOCAL_IMAGE_DIR/" "$VPS:$REMOTE_SHINY/"
rsync -az --checksum --delay-updates --itemize-changes \
  -e "ssh -i $SSH_KEY" "$LOCAL_LOCKFILE" "$LOCAL_DESCRIPTION" "$VPS:$REMOTE_SHINY/"

if [[ "$CANDIDATE_ONLY" -eq 1 ]]; then
  echo "== Bouw, scan en test kandidaat zonder productieactivering =="
  candidate_remote_script="$(base64 <<'REMOTE' | tr -d '\n'
set -euo pipefail

ACTIVE_CONTAINER="shiny_meijendel"
BUILDER_NAME="vwgm-shiny-candidate-${MEIJENDEL_COMMIT:0:12}"
EVIDENCE_DIR="$REMOTE_SHINY/evidence/phase8-${MEIJENDEL_COMMIT}"
WORK_DIR="$(mktemp -d /tmp/vwgm-shiny-candidate.XXXXXX)"
CANDIDATE_ID=""
ACTIVE_IMAGE_ID="$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")"

cleanup() {
  status=$?
  trap - EXIT INT TERM
  docker rm -f "$CANDIDATE_CONTAINER" >/dev/null 2>&1 || true
  rm -rf -- "$CANDIDATE_CACHE" "$WORK_DIR"
  docker buildx rm "$BUILDER_NAME" >/dev/null 2>&1 || true
  docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
  if [[ "$status" -ne 0 && -n "$CANDIDATE_ID" ]]; then
    docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true
    if [[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER" 2>/dev/null || true)" != "$CANDIDATE_ID" ]]; then
      docker image rm "$CANDIDATE_ID" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$EVIDENCE_DIR"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

[[ "$ACTIVE_IMAGE_ID" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(docker inspect --format '{{.State.Status}}' "$ACTIVE_CONTAINER")" == "running" ]]
test ! -e "$CANDIDATE_CACHE"
test ! -e "$EVIDENCE_DIR"
if docker image inspect "$CANDIDATE_TAG" >/dev/null 2>&1; then
  echo "BLOKKADE: kandidaattag bestaat al: $CANDIDATE_TAG" >&2
  exit 1
fi

cd "$REMOTE_SHINY"
docker buildx create --name "$BUILDER_NAME" --driver docker-container >/dev/null
docker buildx build --builder "$BUILDER_NAME" --platform linux/amd64 \
  --pull --no-cache --load --tag "$CANDIDATE_TAG" .
CANDIDATE_ID="$(docker image inspect --format '{{.Id}}' "$CANDIDATE_TAG")"
[[ "$CANDIDATE_ID" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$CANDIDATE_ID" != "$ACTIVE_IMAGE_ID" ]]
printf 'KANDIDAAT|phase8|commit=%s|image=%s|actief_ongewijzigd=%s\n' \
  "$MEIJENDEL_COMMIT" "$CANDIDATE_ID" "$ACTIVE_IMAGE_ID"

set +e
AUDIT_OUTPUT="$(/usr/local/libexec/vwgm-admin/vulnerability-audit-root --image "$CANDIDATE_ID" 2>&1)"
AUDIT_STATUS=$?
set -e
printf '%s\n' "$AUDIT_OUTPUT"
CANDIDATE_SHORT="${CANDIDATE_ID#sha256:}"
grep -Fq "SAMENVATTING|kandidaat-${CANDIDATE_SHORT:0:12}|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0" \
  <<<"$AUDIT_OUTPUT"
! grep -Eq '^(URGENT|BLOKKADE)\|' <<<"$AUDIT_OUTPUT"
if [[ "$AUDIT_STATUS" -ne 0 ]]; then
  EXPECTED_TAG="AANDACHT|container-hygiene|onverwachte-imagetag=$CANDIDATE_TAG"
  UNEXPECTED_TAGS="$(grep '^AANDACHT|container-hygiene|onverwachte-imagetag=' <<<"$AUDIT_OUTPUT" || true)"
  [[ "$UNEXPECTED_TAGS" == "$EXPECTED_TAG" ]]
fi

mkdir -p "$CANDIDATE_CACHE/sass"
docker run --rm -v "$CANDIDATE_CACHE:/app_cache" "$CANDIDATE_ID" \
  chown -R shiny:shiny /app_cache
docker run -d --name "$CANDIDATE_CONTAINER" --restart no \
  -p 127.0.0.1:3839:3838 \
  --mount type=bind,src="$REMOTE_SHINY/shiny_meijendel",dst=/srv/shiny-server/shiny_meijendel,readonly \
  --mount type=bind,src="$CANDIDATE_CACHE",dst=/srv/shiny-server/shiny_meijendel/app_cache \
  --mount type=bind,src="$REMOTE_SHINY/Meijendel.sql",dst=/srv/shiny-server/Meijendel.sql,readonly \
  --mount type=bind,src="$REMOTE_SHINY/R",dst=/srv/shiny-server/R,readonly \
  --mount type=bind,src="$REMOTE_SHINY/shiny_meijendel",dst=/workspace/shiny_meijendel,readonly \
  --mount type=bind,src="$CANDIDATE_CACHE",dst=/workspace/shiny_meijendel/app_cache \
  --mount type=bind,src="$REMOTE_SHINY/R",dst=/workspace/R,readonly \
  --mount type=bind,src="$REMOTE_SHINY/Meijendel.sql",dst=/workspace/meijendel.sql,readonly \
  --mount type=bind,src="$(dirname "$REMOTE_SHINY")/www/trim_msi_evg",dst=/workspace/trim_msi_evg,readonly \
  "$CANDIDATE_ID" >/dev/null
for attempt in $(seq 1 30); do
  if curl -fsSI http://127.0.0.1:3839/ >/dev/null; then
    printf 'GROEN|phase8-kandidaat|readiness=poging-%s\n' "$attempt"
    break
  fi
  [[ "$attempt" -lt 30 ]] || {
    docker logs --tail 120 "$CANDIDATE_CONTAINER" >&2
    exit 1
  }
  sleep 2
done

docker exec "$CANDIDATE_CONTAINER" Rscript \
  /opt/vwgm-build/install_shiny_packages.R \
  /opt/vwgm-build/renv.lock /opt/vwgm-build/DESCRIPTION validate
docker exec "$CANDIDATE_CONTAINER" sh -lc '
  for package in build-essential cmake g++ gcc gfortran make r-base-dev libc6-dev linux-libc-dev libcurl4-openssl-dev libglpk-dev libgmp3-dev libssl-dev libudunits2-dev libxml2-dev; do
    ! dpkg-query -s "$package" 2>/dev/null | grep -q "^Status: install ok installed$"
  done
  ! find /usr/local/lib/R/site-library -type f -name "*.so" -exec env LD_LIBRARY_PATH=/usr/local/lib/R/lib ldd {} \; | grep -F "not found"
'
find "$CANDIDATE_CACHE" -mindepth 1 -maxdepth 1 ! -name sass -exec rm -rf -- {} +
docker exec -u shiny "$CANDIDATE_CONTAINER" sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); first <- load_meijendel_tables_cached(path); second <- load_meijendel_tables_cached(path); stopifnot(!isTRUE(first[[\"from_cache\"]]), isTRUE(second[[\"from_cache\"]]), file.exists(second[[\"cache_path\"]])); cat(\"GROEN|phase8-kandidaat|cache=eerste-load-en-hergebruik\\n\")"'
docker exec -u shiny "$CANDIDATE_CONTAINER" Rscript \
  /workspace/R/check_shiny_dashboard_parity.R \
  /workspace /workspace/meijendel.sql \
  /workspace/trim_msi_evg/msi_per_groep_per_jaar.csv 1958 2025

docker run --rm --entrypoint sh "$CANDIDATE_ID" -lc \
  'dpkg-query -W -f="${binary:Package}\t${Version}\n"' > "$WORK_DIR/os-packages.tsv"
docker run --rm --entrypoint Rscript "$CANDIDATE_ID" -e '
  packages <- installed.packages()
  write.table(packages[, c("Package", "Version"), drop = FALSE], stdout(),
    sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
' > "$WORK_DIR/r-packages.tsv"
docker run --rm --entrypoint cat "$CANDIDATE_ID" \
  /opt/vwgm-build/renv.lock > "$WORK_DIR/renv.lock"

mkdir -p "$EVIDENCE_DIR"
python3 - "$WORK_DIR/os-packages.tsv" "$WORK_DIR/r-packages.tsv" \
  "$WORK_DIR/renv.lock" "$EVIDENCE_DIR/candidate.cdx.json" \
  "$CANDIDATE_ID" "$MEIJENDEL_COMMIT" <<'PY'
import datetime
import json
import sys
import urllib.parse
import uuid

os_path, r_path, lock_path, output_path, image_id, commit = sys.argv[1:]
with open(lock_path, encoding="utf-8") as handle:
    lock = json.load(handle)

components = [
    {
        "type": "container",
        "bom-ref": image_id,
        "name": "vwgm-shiny-phase8-candidate",
        "version": image_id.removeprefix("sha256:")[:12],
        "properties": [
            {"name": "vwg:image-id", "value": image_id},
            {"name": "vwg:meijendel-commit", "value": commit},
        ],
    }
]

def add_packages(path, ecosystem, purl_prefix):
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            name, version = line.rstrip("\n").split("\t", 1)
            purl = f"{purl_prefix}/{urllib.parse.quote(name, safe='')}@{urllib.parse.quote(version, safe='')}"
            components.append(
                {
                    "type": "library",
                    "bom-ref": purl,
                    "name": name,
                    "version": version,
                    "purl": purl,
                    "properties": [{"name": "vwg:ecosystem", "value": ecosystem}],
                }
            )

add_packages(os_path, "Ubuntu", "pkg:deb/ubuntu")
add_packages(r_path, "R", "pkg:cran")
present_r = {
    (component["name"], component["version"])
    for component in components
    if component["properties"][0]["value"] == "R"
}
locked = {(name, record["Version"]) for name, record in lock["Packages"].items()}
missing = sorted(locked - present_r)
if missing:
    raise SystemExit("Lockpackages ontbreken in SBOM: " + repr(missing))
if len(lock["Packages"]) != 190:
    raise SystemExit("Lockfile bevat niet exact 190 packages")

bom = {
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "serialNumber": f"urn:uuid:{uuid.UUID(image_id.removeprefix('sha256:')[:32])}",
    "version": 1,
    "metadata": {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "component": components[0],
        "properties": [
            {"name": "vwg:renv-lock-count", "value": "190"},
            {"name": "vwg:renv-repository", "value": lock["R"]["Repositories"][0]["URL"]},
        ],
    },
    "components": components[1:],
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(bom, handle, ensure_ascii=False, indent=2, sort_keys=True)
    handle.write("\n")
print(f"GROEN|phase8-sbom|componenten={len(components)}|lockpackages=190")
PY
printf '%s\n' "$AUDIT_OUTPUT" > "$EVIDENCE_DIR/vulnerability-scan.txt"
sha256sum "$EVIDENCE_DIR/candidate.cdx.json" \
  "$EVIDENCE_DIR/vulnerability-scan.txt" > "$EVIDENCE_DIR/SHA256SUMS"
cat > "$EVIDENCE_DIR/manifest.txt" <<EOF
commit=$MEIJENDEL_COMMIT
candidate_image=$CANDIDATE_ID
candidate_tag=$CANDIDATE_TAG
active_image_unchanged=$ACTIVE_IMAGE_ID
production_activated=no
EOF
chmod 0644 "$EVIDENCE_DIR"/*

docker rm -f "$CANDIDATE_CONTAINER" >/dev/null
rm -rf -- "$CANDIDATE_CACHE"
[[ "$(docker inspect --format '{{.Image}}' "$ACTIVE_CONTAINER")" == "$ACTIVE_IMAGE_ID" ]]
[[ "$(docker inspect --format '{{.State.Status}}' "$ACTIVE_CONTAINER")" == "running" ]]
docker buildx rm "$BUILDER_NAME" >/dev/null
docker image rm moby/buildkit:buildx-stable-1 >/dev/null 2>&1 || true
printf 'GROEN|phase8-kandidaat|image=%s|productie=ongewijzigd|bewijs=%s\n' \
  "$CANDIDATE_ID" "$EVIDENCE_DIR"
docker system df
REMOTE
)"
  remote_candidate_helper="/tmp/vwgm-shiny-candidate-${short_commit}-$$.sh"
  ssh -tt -i "$SSH_KEY" "$VPS" \
    "umask 077; printf '%s' '$candidate_remote_script' | base64 -d > '$remote_candidate_helper'; chmod 0700 '$remote_candidate_helper'; sudo env REMOTE_SHINY='$REMOTE_SHINY' CANDIDATE_TAG='$CANDIDATE_TAG' CANDIDATE_CONTAINER='$CANDIDATE_CONTAINER' CANDIDATE_CACHE='$CANDIDATE_CACHE' MEIJENDEL_COMMIT='$DEPLOY_LOCAL_COMMIT' bash '$remote_candidate_helper'; status=\$?; rm -f '$remote_candidate_helper'; exit \$status"
  SUCCESS=1
  echo "Kandidaat gebouwd, gescand en geïsoleerd getest; productie is niet geactiveerd."
  exit 0
fi

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
  unexpected_tags="$(grep '^AANDACHT|container-hygiene|onverwachte-imagetag=' <<<"$candidate_audit" || true)"
  expected_candidate_tag="AANDACHT|container-hygiene|onverwachte-imagetag=$CANDIDATE_TAG"
  if grep -Fq 'SAMENVATTING|shiny_meijendel|critical=0|high=43|fix_beschikbaar=0|zonder_fix=43' \
      <<<"$candidate_audit"; then
    : # Alleen de gedocumenteerde oude productie-image mag nog 0/43 opleveren.
  elif [[ "$unexpected_tags" == "$expected_candidate_tag" ]] &&
       ! grep -Eq '^SAMENVATTING\|.*\|(critical|high)=[1-9][0-9]*' <<<"$candidate_audit" &&
       ! grep -Eq '^(URGENT|BLOKKADE)\|' <<<"$candidate_audit"; then
    : # De expliciet gescande tijdelijke kandidaattag staat bewust niet in de productie-allowlist.
  else
    guard_die "kandidaataudit faalde buiten de bekende oude Shiny-baseline of de ene expliciete kandidaattag."
  fi
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
docker exec "$CANDIDATE_CONTAINER" Rscript \
  /opt/vwgm-build/install_shiny_packages.R \
  /opt/vwgm-build/renv.lock /opt/vwgm-build/DESCRIPTION validate
docker exec "$CANDIDATE_CONTAINER" sh -lc '
  for package in build-essential cmake g++ gcc gfortran make r-base-dev libc6-dev linux-libc-dev libcurl4-openssl-dev libglpk-dev libgmp3-dev libssl-dev libudunits2-dev libxml2-dev; do
    ! dpkg-query -s "$package" 2>/dev/null | grep -q "^Status: install ok installed$"
  done
  ! find /usr/local/lib/R/site-library -type f -name "*.so" -exec env LD_LIBRARY_PATH=/usr/local/lib/R/lib ldd {} \; | grep -F "not found"
'
docker exec -u shiny "$CANDIDATE_CONTAINER" sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); stopifnot(file.exists(x[[\"cache_path\"]])); print(x[c(\"from_cache\", \"cache_path\")])"'
docker rm -f "$CANDIDATE_CONTAINER" >/dev/null
docker run --rm -v "$CANDIDATE_CACHE:/app_cache" "$CANDIDATE_ID" \
  chown -R "$(id -u):$(id -g)" /app_cache >/dev/null
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
docker exec shiny_meijendel Rscript \
  /opt/vwgm-build/install_shiny_packages.R \
  /opt/vwgm-build/renv.lock /opt/vwgm-build/DESCRIPTION validate
docker exec -u shiny shiny_meijendel sh -lc 'cd /srv/shiny-server/shiny_meijendel && Rscript -e "source(\"helpers.R\"); path <- resolve_meijendel_sql_path(); stopifnot(identical(path, \"/srv/shiny-server/Meijendel.sql\")); x <- load_meijendel_tables_cached(path); stopifnot(file.exists(x[[\"cache_path\"]])); print(x[c(\"from_cache\", \"cache_path\")])"'
REMOTE

VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl "$SMOKE_SCRIPT"

echo "== Verwijder exact de taakartefacten en oude niet-aangewezen Shiny-image =="
# Productie is nu functioneel bewezen. Een fout in de uitsluitend administratieve
# opruiming mag vanaf dit punt geen rollback naar de oude image meer starten.
SWITCH_STARTED=0
ssh -i "$SSH_KEY" "$VPS" \
  "CANDIDATE_ID='$CANDIDATE_ID' OLD_IMAGE_ID='$OLD_IMAGE_ID' CANDIDATE_TAG='$CANDIDATE_TAG' PREVIOUS_TAG='$PREVIOUS_TAG' bash -s" <<'REMOTE'
set -euo pipefail
[[ "$(docker inspect --format '{{.Image}}' shiny_meijendel)" == "$CANDIDATE_ID" ]]
docker image rm "$CANDIDATE_TAG"
docker image rm "$PREVIOUS_TAG"
if docker image inspect "$OLD_IMAGE_ID" >/dev/null 2>&1; then
  docker image rm "$OLD_IMAGE_ID"
fi
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
