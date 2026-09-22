#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_script="$repo/deploy/rebuild_mysql_image_vps.sh"
remote_script="$repo/deploy/rebuild_mysql_image_vps_remote.sh"

[[ -x "$local_script" && -x "$remote_script" ]]
bash -n "$local_script" "$remote_script"
for marker in \
  'guard_baseline' 'guard_acquire_lock' 'container-status' 'backup-status' \
  'critical=0|high=8|fix_beschikbaar=8|zonder_fix=0' \
  'libevent|installed=2.1.12-8.el9_4|fixed=2.1.13-1.el9_8' \
  'vulnerability-audit-root.*non-zero exit status 1' \
  '--finalize' 'FINALIZE_ONLY' \
  'ssh -tt' 'EXPECTED_OLD_IMAGE' 'check_caddy_mysql_isolation_vps.sh' \
  'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl'; do
  grep -Fq -- "$marker" "$local_script"
done
[[ "$(grep -Fc -- '--binlog-expire-logs-seconds=259200' "$remote_script")" -ge 2 ]]
[[ "$(grep -Fc -- '--innodb-redo-log-capacity=536870912' "$remote_script")" -ge 2 ]]
for marker in \
  '--pull --no-cache --load' 'vulnerability-audit-root --image' \
  'vwgm-baremetal-backup' 'restore_check_backup.sh' '--single-transaction' \
  'validate-mysql' 'PREVIOUS_CONTAINER' 'SWITCH_STARTED=1' \
  'SELECT VERSION()' 'smoke_status publieke-home' \
  'smoke_status mysql-soortpagina' 'smoke_status leden-afgeschermd' \
  'smoke_status shiny-afgeschermd' 'smoke_status app-redirect' \
  'smoke_status hoofddomein-redirect' \
  'critical=0|high=8|fix_beschikbaar=8|zonder_fix=0' \
  'critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' \
  'validate_image_inventory' 'vwgm-shiny:rollback-*' \
  'docker rm "$PREVIOUS_CONTAINER"' 'docker image rm "$EXPECTED_OLD_IMAGE"' \
  'Meijendel.commit'; do
  grep -Fq -- "$marker" "$remote_script"
done
grep -Fq 'finalize_current' "$remote_script"
grep -Fq 'docker image inspect "$EXPECTED_OLD_IMAGE"' "$remote_script"
grep -Fq 'CHECK TABLE' "$repo/deploy/validate_mysql_uid_migration_vps_remote.sh"
[[ "$(grep -Fc -- "--format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}'" "$remote_script")" -eq 3 ]]
! grep -Fq -- '\"/var/lib/mysql\"' "$remote_script"
! grep -Fq 'mysqladmin ping' "$remote_script"
! grep -Fq '"vwgm-mysql:9.7.1 vwgm-shiny:latest "' "$remote_script"
! grep -Fq '/srv/vwgm/vwg-m-linux-app/scripts/smoke_vps.sh' "$remote_script"
! grep -Fq 'high=18|fix_beschikbaar=18' "$local_script" "$remote_script"
! grep -Fq 'pakket=openssl|' "$local_script" "$remote_script"
! grep -Eq 'docker (system|builder|image|container) prune' "$local_script" "$remote_script"

printf 'OK: MySQL-imagerebuild is begrensd, scanverplicht en automatisch rollbackbaar.\n'
