#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
replicates=""
batch_size=""
run_root=""
sql_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --replicates) replicates="$2"; shift 2 ;;
    --batch-size) batch_size="$2"; shift 2 ;;
    --run-root) run_root="$2"; shift 2 ;;
    --sql) sql_path="$2"; shift 2 ;;
    *) printf 'Onbekend argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ "$replicates" =~ ^[1-9][0-9]*$ ]] || { echo "--replicates moet positief zijn" >&2; exit 2; }
[[ "$batch_size" =~ ^[1-9][0-9]*$ ]] || { echo "--batch-size moet positief zijn" >&2; exit 2; }
[[ -n "$run_root" && -n "$sql_path" ]] || { echo "--run-root en --sql zijn verplicht" >&2; exit 2; }
[[ -f "$sql_path" ]] || { echo "SQL-bron ontbreekt" >&2; exit 2; }
bundle="$run_root/input_bundle"
[[ -f "$bundle/context.rds" && -f "$bundle/identity.rds" ]] || {
  echo "Runbundle ontbreekt; maak eerst de gevalideerde input_bundle voor deze SQL-bron." >&2
  exit 3
}
Rscript "$repo/R/validate_trim_bootstrap_bundle.R" "$bundle" "$sql_path" "$replicates"
mkdir -p "$run_root/batches"
from=1
while (( from <= replicates )); do
  to=$((from + batch_size - 1))
  (( to > replicates )) && to=$replicates
  output=$(printf '%s/batches/batch-%06d-%06d.rds' "$run_root" "$from" "$to")
  Rscript "$repo/R/run_trim_bootstrap_batch.R" --bundle "$bundle" --replicate-from "$from" --replicate-to "$to" --output "$output"
  from=$((to + 1))
done
