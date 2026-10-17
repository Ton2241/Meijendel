#!/usr/bin/env bash
set -euo pipefail

worker=""
status_file=""
source_hash=""
memory_limit=""
reserve=""
config=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worker) worker="$2"; shift 2 ;;
    --status-file) status_file="$2"; shift 2 ;;
    --source-hash) source_hash="$2"; shift 2 ;;
    --memory-limit) memory_limit="$2"; shift 2 ;;
    --reserve) reserve="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    *) echo "Onbekend argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$worker" ]] || { echo "--worker ontbreekt" >&2; exit 2; }

value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$status_file"
}

if [[ -z "$source_hash" ]]; then
  echo "$worker|unknown|0|0|0|0|0|false|false|missing_source_hash"
  exit 1
fi

if [[ -n "$status_file" ]]; then
  [[ -f "$status_file" ]] || { echo "statusbestand ontbreekt" >&2; exit 2; }
  architecture="$(value architecture)"
  cpu_count="$(value cpu_count)"
  memory_free="$(value memory_free_bytes)"
  swap_used="$(value swap_used_bytes)"
  load_1m="$(value load_1m)"
  disk_free="$(value disk_free_bytes)"
  docker_available="$(value docker_available)"
  production_lock="$(value production_lock)"
  bootstrap_lock="$(value bootstrap_lock)"
  shiny_healthy="$(value shiny_healthy)"
  mysql_healthy="$(value mysql_healthy)"
  http_healthy="$(value http_healthy)"
  heavy_storage_task="$(value heavy_storage_task)"
else
  architecture="$(uname -m)"
  cpu_count="$(sysctl -n hw.logicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN)"
  memory_free="$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub("\\.","",$3); print $3*4096}' || echo 0)"
  swap_used="$(sysctl -n vm.swapusage 2>/dev/null | awk '{gsub("M", "", $7); printf "%.0f", $7*1048576}' || echo 0)"
  load_1m="$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')"
  disk_free="$(df -Pk . | awk 'NR==2 {print $4*1024}')"
  docker_available="$([[ -x "$(command -v docker 2>/dev/null || true)" ]] && echo true || echo false)"
  production_lock=false
  bootstrap_lock=false
  shiny_healthy=true
  mysql_healthy=true
  http_healthy=true
  heavy_storage_task=false
fi

memory_limit="${memory_limit:-0}"
reserve="${reserve:-0}"
eligible=true
reason=eligible
if [[ "$production_lock" == true ]]; then eligible=false; reason=production_lock_active
elif [[ "$bootstrap_lock" == true ]]; then eligible=false; reason=bootstrap_lock_active
elif [[ "$worker" == vps && ( "$shiny_healthy" != true || "$mysql_healthy" != true || "$http_healthy" != true ) ]]; then eligible=false; reason=service_unhealthy
elif [[ "$worker" == nas && "$heavy_storage_task" == true ]]; then eligible=false; reason=storage_task_active
elif (( memory_free < memory_limit + reserve )); then eligible=false; reason=insufficient_memory
fi
echo "$worker|$architecture|$cpu_count|$memory_free|$swap_used|$load_1m|$disk_free|$docker_available|$eligible|$reason"
[[ "$eligible" == true ]]
