#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="vwgm-shiny:phase8-local"
sbom="${TMPDIR:-/tmp}/vwgm-shiny-phase8-local.cdx.json"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --tag)
      [[ "$#" -ge 2 ]] || exit 2
      tag="$2"
      shift 2
      ;;
    --sbom)
      [[ "$#" -ge 2 ]] || exit 2
      sbom="$2"
      shift 2
      ;;
    -h|--help)
      printf 'Gebruik: scripts/build_shiny_image_local.sh [--tag IMAGE] [--sbom PAD]\n'
      exit 0
      ;;
    *)
      printf 'Onbekende optie: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

"$repo/scripts/test_shiny_reproducibility.sh"
docker info >/dev/null
if docker image inspect "$tag" >/dev/null 2>&1; then
  printf 'BLOKKADE: lokale kandidaattag bestaat al: %s\n' "$tag" >&2
  exit 1
fi
[[ ! -e "$sbom" ]] || {
  printf 'BLOKKADE: SBOM-uitvoer bestaat al: %s\n' "$sbom" >&2
  exit 1
}

context="$(mktemp -d "${TMPDIR:-/tmp}/vwgm-shiny-build.XXXXXX")"
cleanup() {
  rm -rf -- "$context"
}
trap cleanup EXIT

cp "$repo/deploy/shiny_image/Dockerfile" \
  "$repo/deploy/shiny_image/install_shiny_packages.R" \
  "$repo/renv.lock" "$repo/DESCRIPTION" "$context/"

docker buildx build --platform linux/amd64 --pull --no-cache --load \
  --tag "$tag" "$context"
"$repo/scripts/test_shiny_reproducibility.sh" --image "$tag"
"$repo/scripts/generate_shiny_sbom.sh" "$tag" "$sbom"

image_id="$(docker image inspect --format '{{.Id}}' "$tag")"
printf 'GROEN: lokale kandidaat %s heeft image-ID %s en SBOM %s\n' \
  "$tag" "$image_id" "$sbom"
