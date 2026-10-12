#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv_ahn/bin/python}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Gebruik: %s AHN_RASTERMAP [UITVOERMAP]\n' "$0" >&2
  exit 2
fi

AHN_MAP="$1"
RUN_DIR="${2:-$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten/runs/$(date -u +%Y%m%dT%H%M%SZ)-luchtfoto-proef-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)}"
BEELD_DIR="$RUN_DIR/beelden"

[[ -x "$PYTHON_BIN" ]] || { printf 'Python-omgeving ontbreekt: %s\n' "$PYTHON_BIN" >&2; exit 1; }
"$PYTHON_BIN" -c 'import geopandas, numpy, rasterio, scipy, sklearn' 2>/dev/null || {
  printf 'Python-omgeving mist geopandas, numpy, rasterio, scipy of scikit-learn.\n' >&2
  exit 1
}
[[ -f "$AHN_MAP/ahn3_dsm_2m.tif" && -f "$AHN_MAP/ahn5_dtm_2m.tif" ]] || {
  printf 'AHN3-AHN5-rasters ontbreken in %s\n' "$AHN_MAP" >&2; exit 1;
}
"$REPO_DIR/scripts/check_local_workspace.sh"

"$PYTHON_BIN" "$SCRIPT_DIR/luchtfoto_download.py" "$BEELD_DIR"
for FEATURE_SET in raw genormaliseerd; do
  "$PYTHON_BIN" "$SCRIPT_DIR/luchtfoto_classificatie.py" \
    --beeldmap "$BEELD_DIR" \
    --ahn-map "$AHN_MAP" \
    --plots "$REPO_DIR/Plots_2025/avimap_252_diversen__gebieden.shp" \
    --uitvoer "$RUN_DIR/classificatie_$FEATURE_SET" \
    --kenmerken "$FEATURE_SET"
done
"$PYTHON_BIN" "$SCRIPT_DIR/vat_luchtfoto_proef_samen.py" \
  --raw "$RUN_DIR/classificatie_raw" \
  --genormaliseerd "$RUN_DIR/classificatie_genormaliseerd" \
  --landbedekking "$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten/vegetatiesamenstelling_laatste_landbedekking.csv" \
  --uitvoer "$RUN_DIR/luchtfoto_proef_samenvatting.csv"
printf 'OK: luchtfoto-classificatieproef voltooid in %s\n' "$RUN_DIR"
