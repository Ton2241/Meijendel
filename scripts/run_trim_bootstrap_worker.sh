#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backend=""
input_dir=""
output_dir=""
image_id=""
memory_limit=""
remote_root=""
shifted=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend) backend="$2"; shift 2 ;;
    --input-dir) input_dir="$2"; shift 2 ;;
    --output-dir) output_dir="$2"; shift 2 ;;
    --image-id) image_id="$2"; shift 2 ;;
    --memory-limit) memory_limit="$2"; shift 2 ;;
    --remote-root) remote_root="$2"; shift 2 ;;
    --) shift; shifted=("$@"); break ;;
    *) echo "Onbekend argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$backend" && -d "$input_dir" && -n "$output_dir" ]] || { echo "Onvolledige workerconfiguratie" >&2; exit 2; }
[[ "$backend" == local || "$backend" == docker ]] || { echo "Onbekende backend" >&2; exit 2; }
output_dir="$(python3 "$repo/scripts/check_trim_t7_output.py" "$output_dir" --worker-backend "$backend" -- "${shifted[@]}")"

if [[ "$backend" == local ]]; then
  mkdir -p "$output_dir"
  exec nice -n 15 Rscript "$input_dir/R/run_trim_bootstrap_batch.R" "${shifted[@]}"
fi
[[ "$image_id" =~ ^[^[:space:]]+@sha256:[0-9a-f]{64}$ || "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "Containerimage is niet digestvast" >&2; exit 2; }
[[ "$memory_limit" =~ ^[1-9][0-9]*[mMgG]$ ]] || { echo "Ongeldige geheugenlimiet" >&2; exit 2; }
[[ -n "$remote_root" ]] || { echo "remote_root ontbreekt" >&2; exit 2; }

mkdir -p "$output_dir"
lock="$remote_root/bootstrap.lock"
production_lock="/srv/vwgm/deploy-state/production.lock"
mkdir "$lock" 2>/dev/null || { echo "bootstraplock actief" >&2; exit 3; }
trap 'rmdir "$lock" 2>/dev/null || true' EXIT
[[ ! -e "$production_lock" ]] || { echo "productiedeploylock actief" >&2; exit 4; }

docker run --rm --read-only --cpus 0.5 --cpu-shares 128 --pids-limit 256 \
  --memory "$memory_limit" --memory-swap "$memory_limit" \
  --mount "type=bind,src=$input_dir,dst=/work/input,readonly" \
  --mount "type=bind,src=$output_dir,dst=/work/output" \
  "$image_id" Rscript /work/input/R/run_trim_bootstrap_batch.R "${shifted[@]}"
