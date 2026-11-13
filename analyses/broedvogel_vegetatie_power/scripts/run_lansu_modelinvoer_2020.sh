#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK_ROOT="${1:?Gebruik: run_lansu_modelinvoer_2020.sh ABSOLUTE_GEREGISTREERDE_T7_MAP [AHN_RUNMAP]}"
AHN_ROOT="${2:-/Volumes/T7 Data/Home_Ton/Proefomgevingen/broedvogel-vegetatie-power-archief-20261107/runs/20261012T081631Z-ahn-harmonized-3a43bb218f8a}"
PYTHON="${MEIJENDEL_AHN_PYTHON:-/Users/ton/Documents/GitHub/Meijendel/.venv_ahn/bin/python}"

python3 /Users/ton/.codex/bin/t7_work.py check "$WORK_ROOT" >/dev/null
python3 /Users/ton/.codex/bin/t7_work.py check "$WORK_ROOT/outputs" >/dev/null

PLOTS="$WORK_ROOT/outputs/pilotplots.gpkg"
ogr2ogr -f GPKG "$PLOTS" \
  "$REPO_DIR/Plots_2025/avimap_252_diversen__gebieden.shp" \
  -where "naam IN ('Meijendel k 13s','Meijendel k 13','Meijendel k 14','Meijendel k 15','Meijendel k 16')" \
  -nln pilotplots -overwrite

TMPDIR="$WORK_ROOT/tmp" "$PYTHON" \
  "$REPO_DIR/analyses/broedvogel_vegetatie_power/scripts/lansu_modelinvoer.py" \
  --plots "$PLOTS" \
  --rgb "$WORK_ROOT/downloads/RGB_30EZ1_2020.tiff" \
  --rgb "$WORK_ROOT/downloads/RGB_30GN1_2020.tiff" \
  --cir "$WORK_ROOT/downloads/CIR_30EZ1_2020.tiff" \
  --cir "$WORK_ROOT/downloads/CIR_30GN1_2020.tiff" \
  --dsm "$AHN_ROOT/AHN4_KM_DSM05_tiles/mosaic.vrt" \
  --dtm "$AHN_ROOT/AHN4_KM_DTM05_tiles/mosaic.vrt" \
  --coast "$REPO_DIR/gis/vectors/meijendel_bereik/meijendel_ruimtelijke_lagen.gpkg" \
  --output "$WORK_ROOT/outputs/lansu_modelinvoer_2020_m13s_m16.tif" \
  --manifest "$WORK_ROOT/outputs/lansu_modelinvoer_2020_m13s_m16_manifest.json"

"$PYTHON" \
  "$REPO_DIR/analyses/broedvogel_vegetatie_power/scripts/controleer_lansu_modelinvoer.py" \
  --stack "$WORK_ROOT/outputs/lansu_modelinvoer_2020_m13s_m16.tif" \
  --plots "$PLOTS" \
  --output "$WORK_ROOT/outputs/lansu_modelinvoer_2020_m13s_m16_controle.json"
