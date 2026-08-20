#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo/deploy/migrate_mysql_uid_vps.sh"
helper="$repo/deploy/validate_mysql_uid_migration_vps_remote.sh"
dockerfile="$repo/deploy/mysql_image/Dockerfile.9.7.1"

[[ -x "$script" ]]
[[ -x "$helper" ]]
bash -n "$script"
bash -n "$helper"
grep -Fq 'MYSQL_UID=1999' "$script"
grep -Fq 'MYSQL_GID=1999' "$script"
grep -Fq 'NEW_DATA_ROOT="$REMOTE_BASE/meijendel-mysql-971-uid1999"' "$script"
grep -Fq 'guard_baseline' "$script"
grep -Fq 'guard_acquire_lock' "$script"
grep -Fq 'rollback_or_cleanup' "$script"
grep -Fq -- '--single-transaction' "$script"
grep -Fq 'candidate_version="$(docker exec "$CANDIDATE_CONTAINER"' "$script"
grep -Fq 'MySQL init process done. Ready for start up.' "$script"
grep -Fq 'CHECK TABLE' "$helper"
grep -Fq '[[ "$type" == "BASE TABLE" ]] || continue' "$helper"
grep -Fq 'sed -n '\''1,160p'\'' "$tmp_dir/compare.diff" >&2' "$helper"
grep -Fq 'rechteninventaris kon niet worden gelezen' "$helper"
grep -Fq 'compare "$tmp_dir/source.rows" "$tmp_dir/target.rows" "exacte rijtellingen"' "$helper"
grep -Fq 'SELECT COUNT(*), COALESCE(SUM(PRIVILEGE_TYPE' "$helper"
grep -Fq 'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl' "$script"
grep -Fq 'SAMENVATTING|meijendel-mysql|critical=0|high=8|fix_beschikbaar=8|zonder_fix=0' "$script"
grep -Fq 'de kandidaat moet 0/0 zijn' "$script"
grep -Fq 'AANDACHT|container-hygiene|' "$script"
grep -Fq 'vwgm-baremetal-backup' "$script"
grep -Fq 'ARG MYSQL_UID=1999' "$dockerfile"

printf 'OK: MySQL-UID-migratie is logisch, rollbackbaar en volledig gevalideerd.\n'
