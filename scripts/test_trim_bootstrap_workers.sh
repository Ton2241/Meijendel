#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
probe="$repo/scripts/probe_trim_bootstrap_worker.sh"
dispatch="$repo/scripts/dispatch_trim_bootstrap_batches.sh"
tmp="$(mktemp -d /tmp/trim-workers-test.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

write_status() {
  cat > "$tmp/status" <<EOF
architecture=arm64
cpu_count=4
memory_free_bytes=${1:-1000}
swap_used_bytes=0
load_1m=0.2
disk_free_bytes=1000000
docker_available=true
production_lock=${2:-false}
bootstrap_lock=false
shiny_healthy=${3:-true}
mysql_healthy=${4:-true}
http_healthy=true
heavy_storage_task=false
EOF
}

write_status
if "$probe" --worker vps --status-file "$tmp/status" --memory-limit 100 --reserve 200 >"$tmp/out" 2>&1; then
  echo "Probe zonder bronhash had moeten blokkeren." >&2
  exit 1
fi
grep -q 'missing_source_hash' "$tmp/out"

write_status 1000 true
"$probe" --worker vps --status-file "$tmp/status" --source-hash abc --memory-limit 100 --reserve 200 >"$tmp/out" || true
grep -q '|false|production_lock_active$' "$tmp/out"

write_status 1000 false false true
"$probe" --worker vps --status-file "$tmp/status" --source-hash abc --memory-limit 100 --reserve 200 >"$tmp/out" || true
grep -q '|false|service_unhealthy$' "$tmp/out"

write_status 250 false true true
"$probe" --worker vps --status-file "$tmp/status" --source-hash abc --memory-limit 100 --reserve 200 >"$tmp/out" || true
grep -q '|false|insufficient_memory$' "$tmp/out"

write_status 1000 false true true
"$probe" --worker vps --status-file "$tmp/status" --source-hash abc --memory-limit 100 --reserve 200 >"$tmp/out"
grep -q '|true|eligible$' "$tmp/out"

cat > "$tmp/assignments.csv" <<EOF
worker_id,replicate_from,replicate_to
imac,1,5
vps,5,10
EOF
if "$dispatch" --assignments "$tmp/assignments.csv" --dry-run >"$tmp/out" 2>&1; then
  echo "Overlappende toewijzingen hadden moeten blokkeren." >&2
  exit 1
fi
grep -qi 'overlap' "$tmp/out"

cat > "$tmp/assignments.csv" <<EOF
worker_id,replicate_from,replicate_to
imac,1,5
vps,6,10
EOF
"$dispatch" --assignments "$tmp/assignments.csv" --dry-run >"$tmp/out"
grep -q 'DRY_RUN_OK' "$tmp/out"

cat > "$tmp/workers.csv" <<EOF
worker_id,backend,ssh_target,remote_root,max_workers,enabled,role
imac,local,,,1,true,compute
nas,ssh,,,1,true,compute
EOF
if "$dispatch" --assignments "$tmp/assignments.csv" --config "$tmp/workers.csv" --dry-run >"$tmp/out" 2>&1; then
  echo "Ingeschakelde SSH-worker zonder doel had moeten blokkeren." >&2
  exit 1
fi
grep -qi 'ssh_target\|remote_root' "$tmp/out"

Rscript -e 'source("R/trim_bootstrap_core.R"); c <- data.frame(bootstrap_cluster_id=1:6,stratum=rep(c("h","l"),each=3),primary_bridge_plot=TRUE,strict_bridge_plot=FALSE); a<-make_stratified_cluster_draw(c,1L,99L); b<-make_stratified_cluster_draw(c,1L,99L); stopifnot(identical(a,b)); x<-c(1,2,3); y<-c(1+1e-10,2-1e-10,3); stopifnot(max(abs(x-y)) <= 1e-8)'

printf 'OK: externe workers blijven begrensd en overlappende dispatch wordt geweigerd.\n'
