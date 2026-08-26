#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_script="$repo/deploy/rebuild_mysql_image_vps.sh"
remote_script="$repo/deploy/rebuild_mysql_image_vps_remote.sh"

[[ -x "$local_script" && -x "$remote_script" ]]
bash -n "$local_script" "$remote_script"
for marker in \
  'guard_baseline' 'guard_acquire_lock' 'container-status' 'backup-status' \
  'critical=0|high=2|fix_beschikbaar=2|zonder_fix=0' \
  'sqlite-libs|installed=3.34.1-10.el9_8|fixed=3.34.1-11.el9_8' \
  'vulnerability-audit-root.*non-zero exit status 1' \
  '--finalize' 'FINALIZE_ONLY' \
  'ssh -tt' 'EXPECTED_OLD_IMAGE' 'check_caddy_mysql_isolation_vps.sh' \
  'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl'; do
  grep -Fq -- "$marker" "$local_script"
done
for marker in \
  '--pull --no-cache --load' 'vulnerability-audit-root --image' \
  'vwgm-baremetal-backup' 'restore_check_backup.sh' '--single-transaction' \
  'validate-mysql' 'PREVIOUS_CONTAINER' 'SWITCH_STARTED=1' \
  'SELECT VERSION()' 'smoke_status publieke-home' \
  'smoke_status mysql-soortpagina' 'smoke_status leden-afgeschermd' \
  'smoke_status shiny-afgeschermd' 'smoke_status app-redirect' \
  'smoke_status hoofddomein-redirect' \
  'critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' \
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
! grep -Fq '/srv/vwgm/vwg-m-linux-app/scripts/smoke_vps.sh' "$remote_script"
! grep -Eq 'docker (system|builder|image|container) prune' "$local_script" "$remote_script"

printf 'OK: MySQL-imagerebuild is begrensd, scanverplicht en automatisch rollbackbaar.\n'
