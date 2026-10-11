#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_BIN="${AHN_PYTHON_BIN:-$REPO_DIR/.venv_ahn/bin/python}"
PLOTS="${AHN_PLOTS:-$REPO_DIR/Plots_2025/avimap_252_diversen__gebieden.shp}"
RESULTS_ROOT="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten/runs"

usage() {
  cat <<'EOF'
Gebruik: run_ahn_vegetatiestructuur.sh [UITVOERMAP]

Haalt AHN3 en AHN4 DSM en DTM op voor Meijendel, op een werkresolutie van
2 meter. De werkelijke inwinningsdatum per plot komt uit de officiële
vlieglijnen. Rasters en grote tussenbestanden blijven buiten Git.
EOF
}

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ -x "$PYTHON_BIN" ]] || { printf 'BLOKKADE: Pythonomgeving ontbreekt: %s\n' "$PYTHON_BIN" >&2; exit 1; }
[[ -f "$PLOTS" ]] || { printf 'BLOKKADE: plotbestand ontbreekt: %s\n' "$PLOTS" >&2; exit 1; }

RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-ahn-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)"
RUN_DIR="${1:-$RESULTS_ROOT/$RUN_ID}"
mkdir -p "$RUN_DIR"

# Afgeronde RD-grenzen van de 55 bronplots; 3.440 x 3.018 pixels bij 2 meter.
MIN_X=79596
MIN_Y=458356
MAX_X=86476
MAX_Y=464392
WIDTH=3440
HEIGHT=3018
TILE_PIXELS=2048
PIXEL_SIZE=2

AHN3_DSM_SERVICE='https://api.ellipsis-drive.com/v3/ogc/wcs/94037eea-4196-48db-9f83-0ef330a7655e'
AHN3_DSM_COVERAGE='7daaa215-4cd0-48cd-9484-2eb5cec674e1'
AHN3_DTM_SERVICE='https://api.ellipsis-drive.com/v3/ogc/wcs/69f81443-c000-4479-b08f-2078e3570394'
AHN3_DTM_COVERAGE='393408cf-842d-4181-af87-94f6123bdff0'
AHN4_SERVICE='https://service.pdok.nl/rws/actueel-hoogtebestand-nederland/wcs/v1_0'

download_tiles() {
  local version="$1" service="$2" coverage="$3" output="$4"
  local tile_dir="${output%.tif}_tiles"
  mkdir -p "$tile_dir"
  local row=0 col=0 tile_width tile_height x0 x1 y0 y1 tile
  while (( row < HEIGHT )); do
    tile_height=$(( HEIGHT - row ))
    (( tile_height > TILE_PIXELS )) && tile_height=$TILE_PIXELS
    col=0
    while (( col < WIDTH )); do
      tile_width=$(( WIDTH - col ))
      (( tile_width > TILE_PIXELS )) && tile_width=$TILE_PIXELS
      x0=$(( MIN_X + col * PIXEL_SIZE ))
      x1=$(( x0 + tile_width * PIXEL_SIZE ))
      y0=$(( MIN_Y + row * PIXEL_SIZE ))
      y1=$(( y0 + tile_height * PIXEL_SIZE ))
      tile="$tile_dir/tile_${row}_${col}.tif"
      if [[ "$version" == "1.0.0" ]]; then
        curl -L --fail --silent --show-error \
          "${service}?SERVICE=WCS&VERSION=1.0.0&REQUEST=GetCoverage&COVERAGE=${coverage}&CRS=EPSG%3A28992&BBOX=${x0},${y0},${x1},${y1}&WIDTH=${tile_width}&HEIGHT=${tile_height}&FORMAT=GeoTIFF" \
          -o "$tile"
      else
        curl -L --fail --silent --show-error \
          "${service}?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=${coverage}&FORMAT=image%2Ftiff&SUBSET=x(${x0},${x1})&SUBSET=y(${y0},${y1})&SCALESIZE=x(${tile_width}),y(${tile_height})" \
          -o "$tile"
      fi
      col=$(( col + tile_width ))
    done
    row=$(( row + tile_height ))
  done
  gdalbuildvrt -q "$tile_dir/mosaic.vrt" "$tile_dir"/tile_*.tif
  gdal_translate -q -co COMPRESS=DEFLATE "$tile_dir/mosaic.vrt" "$output"
}

download_tiles 1.0.0 "$AHN3_DSM_SERVICE" "$AHN3_DSM_COVERAGE" "$RUN_DIR/ahn3_dsm_2m.tif"
download_tiles 1.0.0 "$AHN3_DTM_SERVICE" "$AHN3_DTM_COVERAGE" "$RUN_DIR/ahn3_dtm_2m.tif"
download_tiles 2.0.1 "$AHN4_SERVICE" dsm_05m "$RUN_DIR/ahn4_dsm_2m.tif"
download_tiles 2.0.1 "$AHN4_SERVICE" dtm_05m "$RUN_DIR/ahn4_dtm_2m.tif"
curl -L --fail --silent --show-error \
  'https://basisdata.nl/hwh-ahn/AUX/vlieglijnen/AHN3_clip.gpkg' \
  -o "$RUN_DIR/AHN3_clip.gpkg"
curl -L --fail --silent --show-error \
  'https://basisdata.nl/hwh-ahn/AUX/vlieglijnen/AHN4.gpkg' \
  -o "$RUN_DIR/AHN4.gpkg"

for raster in "$RUN_DIR"/*.tif; do
  gdalinfo "$raster" | grep -q "Size is $WIDTH, $HEIGHT" || {
    printf 'BLOKKADE: onverwachte rasterafmeting in %s\n' "$raster" >&2
    exit 1
  }
done

"$PYTHON_BIN" "$SCRIPT_DIR/ahn_vegetatiestructuur.py" \
  --plots "$PLOTS" --dsm "$RUN_DIR/ahn3_dsm_2m.tif" \
  --dtm "$RUN_DIR/ahn3_dtm_2m.tif" --cycle AHN3 \
  --flightlines "$RUN_DIR/AHN3_clip.gpkg" --date-field datum \
  --output "$RUN_DIR/ahn3_vegetatiestructuur.csv"
"$PYTHON_BIN" "$SCRIPT_DIR/ahn_vegetatiestructuur.py" \
  --plots "$PLOTS" --dsm "$RUN_DIR/ahn4_dsm_2m.tif" \
  --dtm "$RUN_DIR/ahn4_dtm_2m.tif" --cycle AHN4 \
  --flightlines "$RUN_DIR/AHN4.gpkg" --date-field datum \
  --output "$RUN_DIR/ahn4_vegetatiestructuur.csv"

awk 'FNR == 1 && NR != 1 { next } { print }' \
  "$RUN_DIR/ahn3_vegetatiestructuur.csv" \
  "$RUN_DIR/ahn4_vegetatiestructuur.csv" \
  > "$RUN_DIR/ahn_vegetatiestructuur.csv"

{
  printf 'bestand,sha256\n'
  for file in "$RUN_DIR"/*.tif "$RUN_DIR"/*.gpkg; do
    printf '%s,%s\n' "$(basename "$file")" "$(shasum -a 256 "$file" | awk '{print $1}')"
  done
} > "$RUN_DIR/ahn_bronbestanden.csv"

printf '%s\n' "$RUN_DIR/ahn_vegetatiestructuur.csv"
