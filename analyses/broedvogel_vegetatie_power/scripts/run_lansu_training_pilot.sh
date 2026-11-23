#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK_ROOT="${1:?Gebruik: run_lansu_training_pilot.sh GEREGISTREERDE_T7_MAP DATASET_ROOT}"
DATASET_ROOT="${2:?Gebruik: run_lansu_training_pilot.sh GEREGISTREERDE_T7_MAP DATASET_ROOT}"
SAMPLE_NAME="${3:-01CZ2_2020_17_4.tiff}"
PYTHON="$WORK_ROOT/runtime/venv/bin/python"
SCRIPT="$REPO_DIR/analyses/broedvogel_vegetatie_power/scripts/lansu_training_pilot.py"
TEST="$REPO_DIR/analyses/broedvogel_vegetatie_power/scripts/test_lansu_training_pilot.py"

python3 /Users/ton/.codex/bin/t7_work.py check "$WORK_ROOT/outputs" >/dev/null

if [[ ! -x "$PYTHON" ]]; then
  echo "Trainingsruntime ontbreekt: $PYTHON" >&2
  exit 1
fi

"$PYTHON" -m pip check
"$PYTHON" "$TEST"
"$PYTHON" "$SCRIPT" audit "$DATASET_ROOT" --inspect-rasters \
  --output "$WORK_ROOT/outputs/trainingsdata_audit.json"
"$PYTHON" "$SCRIPT" smoke --device auto \
  --output "$WORK_ROOT/outputs/synthetische_smoke.json"
"$PYTHON" "$SCRIPT" dataset-smoke "$DATASET_ROOT" --name "$SAMPLE_NAME" \
  --device auto --input-size 316 \
  --output "$WORK_ROOT/outputs/trainingsdata_smoke.json"
"$PYTHON" -m pip freeze > "$WORK_ROOT/outputs/python_packages.txt"
