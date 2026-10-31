#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OUTPUT_DIR="${1:-$REPO_ROOT/outputs/qfield_afscheidingen/meijendel_afscheidingen}"
PLOTS="${2:-$REPO_ROOT/Plots_2025/avimap_252_diversen__gebieden.shp}"
BUILDER="$SCRIPT_DIR/build_qfield_afscheidingen.py"
RASTER="$OUTPUT_DIR/luchtfoto_pdok_2025_25cm.tif"
PARTIAL="$OUTPUT_DIR/luchtfoto_pdok_2025_25cm.partial.tif"
PDOK_WMTS="WMTS:https://service.pdok.nl/hwh/luchtfotorgb/wmts/v1_0?request=GetCapabilities&service=WMTS,layer=2025_ortho25,tilematrixset=EPSG:28992,zoom_level=14"
CACHE_DIR="$(dirname "$OUTPUT_DIR")/.gdal_wmts_cache"
BUILD_DIR="$(dirname "$OUTPUT_DIR")/.raster_build"
RAW_RASTER="$BUILD_DIR/luchtfoto_pdok_2025_25cm_raw.tif"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$BUILD_DIR"

download_base_raster() {
  gdal_translate \
    --config GDAL_HTTP_MAX_RETRY 10 \
    --config GDAL_HTTP_RETRY_CODES 500,502,503,504 \
    --config GDAL_HTTP_RETRY_DELAY 2 \
    --config GDAL_HTTP_MULTIRANGE YES \
    --config GDAL_DEFAULT_WMS_CACHE_PATH "$CACHE_DIR" \
    -projwin 79497.0 464492.0 86575.0 458256.25 \
    -tr 0.25 0.25 \
    -r bilinear \
    -b 1 \
    -b 2 \
    -b 3 \
    -of GTiff \
    -co TILED=YES \
    -co COMPRESS=JPEG \
    -co JPEG_QUALITY=90 \
    -co BIGTIFF=YES \
    -co NUM_THREADS=1 \
    "$PDOK_WMTS" \
    "$RAW_RASTER"
}

DOWNLOAD_OK=0
for ATTEMPT in 1 2 3 4 5; do
  if download_base_raster; then
    DOWNLOAD_OK=1
    break
  fi
  printf 'PDOK-tegelonderbreking bij poging %s; hervatten vanuit cache.\n' "$ATTEMPT" >&2
  sleep 5
done

if [ "$DOWNLOAD_OK" -ne 1 ]; then
  printf 'FOUT: basisluchtfoto kon na vijf cachehervattingen niet worden voltooid.\n' >&2
  exit 1
fi

gdaladdo \
  --config COMPRESS_OVERVIEW JPEG \
  --config JPEG_QUALITY_OVERVIEW 85 \
  --config INTERLEAVE_OVERVIEW PIXEL \
  --config BIGTIFF_OVERVIEW YES \
  -r average \
  "$RAW_RASTER" \
  2 4 8 16 32

gdal_translate \
  -of COG \
  -co COMPRESS=JPEG \
  -co QUALITY=85 \
  -co BLOCKSIZE=512 \
  -co BIGTIFF=YES \
  -co NUM_THREADS=2 \
  -co OVERVIEWS=FORCE_USE_EXISTING \
  "$RAW_RASTER" \
  "$PARTIAL"

mv -f "$PARTIAL" "$RASTER"

QGIS_PREFIX_PATH=/Applications/QGIS.app \
  /Applications/QGIS.app/Contents/MacOS/qgis_process run "$BUILDER" -- \
  "PLOTS=$PLOTS" \
  "OUTPUT_DIR=$OUTPUT_DIR" \
  "RASTER=$RASTER"

gdalinfo -json "$RASTER"
