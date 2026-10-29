#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$REPO_DIR/.venv_ahn/bin/python}"
MYSQL_BIN="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
RESULTS_DIR="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten"
SOURCE_DIR="$REPO_DIR/Landgebruik/schmidt_tauscher_2025/bron"
CLASS_METRICS="$RESULTS_DIR/vegetatiesamenstelling_laatste_landbedekking.csv"

[[ -x "$PYTHON_BIN" ]] || { printf 'BLOKKADE: Pythonomgeving ontbreekt: %s\n' "$PYTHON_BIN" >&2; exit 1; }
[[ -x "$MYSQL_BIN" ]] || { printf 'BLOKKADE: MySQL-client ontbreekt: %s\n' "$MYSQL_BIN" >&2; exit 1; }
[[ -f "$CLASS_METRICS" ]] || { printf 'BLOKKADE: klassemetrics ontbreken: %s\n' "$CLASS_METRICS" >&2; exit 1; }
for raster in classification2001_25k_grove.tif classification2022_grove_25k.tif; do
  [[ -f "$SOURCE_DIR/$raster" ]] || { printf 'BLOKKADE: bronraster ontbreekt: %s\n' "$SOURCE_DIR/$raster" >&2; exit 1; }
done

"$REPO_DIR/scripts/check_local_workspace.sh"

EXTRACT_DIR="$(mktemp -d -t meijendel-pq-representativiteit.XXXXXX)"
trap 'rm -rf "$EXTRACT_DIR"' EXIT
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-pq-representativiteit"
GIT_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
  GIT_WERKBOOMSTATUS="onopgeslagen_wijzigingen"
else
  GIT_WERKBOOMSTATUS="schoon"
fi
MYSQL_VERSIE="$($MYSQL_BIN --version)"

"$MYSQL_BIN" --login-path=meijendel_root --protocol=tcp -h 127.0.0.1 -P 3306 \
  -D Meijendel --batch -e '
SELECT
  o.opname_id,
  o.pq_nummer,
  o.jaar,
  o.x_rd,
  o.y_rd,
  op.plot_id
FROM pq_vegetatie_opname o
JOIN pq_vegetatie_opname_plot op ON op.opname_id = o.opname_id
JOIN v_meijendel_analyseplot_actueel s ON s.plot_id = op.plot_id
ORDER BY o.pq_nummer, o.jaar, o.opname_id
' > "$EXTRACT_DIR/pq_opnamen.tsv"

"$MYSQL_BIN" --login-path=meijendel_root --protocol=tcp -h 127.0.0.1 -P 3306 \
  -D Meijendel --batch -e "
SELECT plot_id, gebied_code, gebied_naam
FROM v_plot_gebied_actueel
WHERE indeling_code = 'vogelplot-gebiedsindeling-v1'
  AND gebiedstype = 'meijendel_deelgebied'
ORDER BY plot_id
" > "$EXTRACT_DIR/deelgebieden.tsv"

"$PYTHON_BIN" "$SCRIPT_DIR/pq_representativiteit.py" \
  --opnamen "$EXTRACT_DIR/pq_opnamen.tsv" \
  --klassemetrics "$CLASS_METRICS" \
  --raster-2001 "$SOURCE_DIR/classification2001_25k_grove.tif" \
  --raster-2022 "$SOURCE_DIR/classification2022_grove_25k.tif" \
  --deelgebieden "$EXTRACT_DIR/deelgebieden.tsv" \
  --output-dir "$RESULTS_DIR" \
  --max-afstand 5 \
  --run-id "$RUN_ID" \
  --git-commit "$GIT_COMMIT" \
  --git-werkboomstatus "$GIT_WERKBOOMSTATUS" \
  --mysql-versie "$MYSQL_VERSIE"

printf 'OK: PQ-representativiteit berekend in %s\n' "$RESULTS_DIR"
