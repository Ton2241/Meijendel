#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_BIN="${AHN_PYTHON_BIN:-$REPO_DIR/.venv_ahn/bin/python}"
PLOTS="${AHN_PLOTS:-$REPO_DIR/Plots_2025/avimap_252_diversen__gebieden.shp}"
RESULTS_ROOT="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten/runs"
INDEX_ROOT='https://basisdata.nl/hwh-portal/20230609_tmp/links/nationaal/Nederland'

usage() {
  cat <<'EOF'
Gebruik: run_ahn_vegetatiestructuur.sh [UITVOERMAP]

Haalt de officiële, opnieuw afgeleide 1x1-km-kaartbladen van AHN2, AHN3, AHN4
en AHN5 op. Deze volgen zo veel mogelijk dezelfde AHN6-specificatie. Alle vier
cycli worden met dezelfde afleidingsmethode naar exact hetzelfde raster van
2 meter gebracht. De werkelijke inwinningsdatum per plot komt uit de officiële
vlieglijnen. Rasters en grote tussenbestanden blijven buiten Git.
EOF
}

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ -x "$PYTHON_BIN" ]] || { printf 'BLOKKADE: Pythonomgeving ontbreekt: %s\n' "$PYTHON_BIN" >&2; exit 1; }
[[ -f "$PLOTS" ]] || { printf 'BLOKKADE: plotbestand ontbreekt: %s\n' "$PLOTS" >&2; exit 1; }
for tool in curl gdalbuildvrt gdalwarp gdalinfo shasum; do
  command -v "$tool" >/dev/null || { printf 'BLOKKADE: hulpmiddel ontbreekt: %s\n' "$tool" >&2; exit 1; }
done

RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-ahn-harmonized-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)"
RUN_DIR="${1:-$RESULTS_ROOT/$RUN_ID}"
mkdir -p "$RUN_DIR"

# Exact gedeeld RD-grid voor alle cycli: 3.440 x 3.018 pixels van 2 meter.
MIN_X=79596
MIN_Y=458356
MAX_X=86476
MAX_Y=464392
WIDTH=3440
HEIGHT=3018
PIXEL_SIZE=2
HARMONISATIE='officiele_KM05_AHN6_specificatie_gemiddeld_naar_2m'

printf 'cyclus,product,index_url,bestand,url,omvang_bytes,verwachte_sha256,feitelijke_sha256\n' \
  > "$RUN_DIR/ahn_bronbestanden.csv"

download_product() {
  local cycle="$1" product="$2"
  local cycle_lower product_lower
  cycle_lower="$(printf '%s' "$cycle" | tr '[:upper:]' '[:lower:]')"
  product_lower="$(printf '%s' "$product" | tr '[:upper:]' '[:lower:]')"
  local stem="${cycle}_KM_${product}05"
  local index_url="$INDEX_ROOT/${stem}.json"
  local index_file="$RUN_DIR/${stem}.json"
  local selection="$RUN_DIR/${stem}_selectie.csv"
  local tile_dir="$RUN_DIR/${stem}_tiles"
  local output="$RUN_DIR/${cycle_lower}_${product_lower}_2m.tif"
  mkdir -p "$tile_dir"

  curl -L --fail --silent --show-error "$index_url" -o "$index_file"
  "$PYTHON_BIN" "$SCRIPT_DIR/ahn_selecteer_kaartbladen.py" \
    --index "$index_file" --plots "$PLOTS" --output "$selection"

  while IFS=, read -r bestand url omvang sha256; do
    [[ "$bestand" == "bestand" ]] && continue
    local target="$tile_dir/$bestand"
    if [[ ! -f "$target" ]] || [[ "$(shasum -a 256 "$target" | awk '{print $1}')" != "$sha256" ]]; then
      curl -L --fail --silent --show-error "$url" -o "$target"
    fi
    local actual
    actual="$(shasum -a 256 "$target" | awk '{print $1}')"
    [[ "$actual" == "$sha256" ]] || {
      printf 'BLOKKADE: SHA-256 wijkt af voor %s\n' "$target" >&2
      exit 1
    }
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "$cycle" "$product" "$index_url" "$bestand" "$url" "$omvang" "$sha256" "$actual" \
      >> "$RUN_DIR/ahn_bronbestanden.csv"
  done < "$selection"

  gdalbuildvrt -q "$tile_dir/mosaic.vrt" "$tile_dir"/*.TIF
  gdalwarp -q -overwrite -r average -tap \
    -te "$MIN_X" "$MIN_Y" "$MAX_X" "$MAX_Y" -tr "$PIXEL_SIZE" "$PIXEL_SIZE" \
    -dstnodata -9999 -co COMPRESS=DEFLATE -co TILED=YES \
    "$tile_dir/mosaic.vrt" "$output"
  gdalinfo "$output" | grep -q "Size is $WIDTH, $HEIGHT" || {
    printf 'BLOKKADE: onverwachte rasterafmeting in %s\n' "$output" >&2
    exit 1
  }
}

for cycle in AHN2 AHN3 AHN4 AHN5; do
  download_product "$cycle" DSM
  download_product "$cycle" DTM
done

"$PYTHON_BIN" "$SCRIPT_DIR/ahn_vegetatiestructuur.py" \
  --plots "$PLOTS" --dsm "$RUN_DIR/ahn2_dsm_2m.tif" \
  --dtm "$RUN_DIR/ahn2_dtm_2m.tif" --cycle AHN2 \
  --acquisition-year 2008 --acquisition-period 2008 \
  --structure-moment 2008 --response-start-year 2009 \
  --bronproduct 'AHN2_KM_DSM05_en_DTM05' --harmonisatie "$HARMONISATIE" \
  --output "$RUN_DIR/ahn2_vegetatiestructuur.csv"

for cycle in AHN3 AHN4 AHN5; do
  cycle_lower="$(printf '%s' "$cycle" | tr '[:upper:]' '[:lower:]')"
  flightlines="$RUN_DIR/${cycle}.gpkg"
  case "$cycle" in
    AHN3) flightline_name='AHN3_clip.gpkg' ;;
    AHN4) flightline_name='AHN4.gpkg' ;;
    AHN5) flightline_name='AHN5_clip.gpkg' ;;
  esac
  curl -L --fail --silent --show-error \
    "https://basisdata.nl/hwh-ahn/AUX/vlieglijnen/${flightline_name}" -o "$flightlines"
  "$PYTHON_BIN" "$SCRIPT_DIR/ahn_vegetatiestructuur.py" \
    --plots "$PLOTS" --dsm "$RUN_DIR/${cycle_lower}_dsm_2m.tif" \
    --dtm "$RUN_DIR/${cycle_lower}_dtm_2m.tif" --cycle "$cycle" \
    --flightlines "$flightlines" --date-field datum \
    --bronproduct "${cycle}_KM_DSM05_en_DTM05" --harmonisatie "$HARMONISATIE" \
    --output "$RUN_DIR/${cycle_lower}_vegetatiestructuur.csv"
done

awk 'FNR == 1 && NR != 1 { next } { print }' \
  "$RUN_DIR/ahn2_vegetatiestructuur.csv" \
  "$RUN_DIR/ahn3_vegetatiestructuur.csv" \
  "$RUN_DIR/ahn4_vegetatiestructuur.csv" \
  "$RUN_DIR/ahn5_vegetatiestructuur.csv" \
  > "$RUN_DIR/ahn_vegetatiestructuur.csv"

"$PYTHON_BIN" "$SCRIPT_DIR/controleer_ahn_harmonisatie.py" \
  --input "$RUN_DIR/ahn_vegetatiestructuur.csv" \
  --output "$RUN_DIR/ahn_harmonisatie_controle.csv"

"$PYTHON_BIN" "$SCRIPT_DIR/analyseer_ahn_harmonisatie.py" \
  --input "$RUN_DIR/ahn_vegetatiestructuur.csv" \
  --output-cycles "$RUN_DIR/ahn_harmonisatie_cycli.csv" \
  --output-transitions "$RUN_DIR/ahn_harmonisatie_overgangen.csv"

printf '%s\n' "$RUN_DIR/ahn_vegetatiestructuur.csv"
