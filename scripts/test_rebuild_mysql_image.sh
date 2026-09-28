#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_script="$repo/deploy/rebuild_mysql_image_vps.sh"
remote_script="$repo/deploy/rebuild_mysql_image_vps_remote.sh"

python3 - "$local_script" "$remote_script" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

# Exercise the actual scan gates; only the external scanner is replaced.
# A stale baseline must reject the current libxml2 finding, and removing a
# safety check must make one of the negative cases fail.
local = Path(sys.argv[1]).read_text()
remote = Path(sys.argv[2]).read_text()
local_gate = local.split('if [[ "$FINALIZE" -eq 1 ]]; then', 1)[1].split(
    '\nif [[ "$APPLY" -ne 1 ]]; then', 1
)[0]
local_gate = 'if [[ "$FINALIZE" -eq 1 ]]; then' + local_gate
remote_gate = remote.split('audit_candidate() {', 1)[1].split(
    '\naudit_active_with_previous()', 1
)[0]
remote_gate = ('audit_candidate() {' + remote_gate).replace(
    '/usr/local/libexec/vwgm-admin/vulnerability-audit-root --image "$CANDIDATE_ID"',
    'test_scanner --image "$CANDIDATE_ID"',
)
mysql = 'SAMENVATTING|meijendel-mysql|critical=0|high=6|fix_beschikbaar=6|zonder_fix=0'
group = 'GROEP|meijendel-mysql|HIGH|aantal=6|pakket=libxml2|installed=2.9.13-14.el9_8.4|fixed=2.9.13-14.el9_8.5|ids=example'
shiny = 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'
attention = 'AANDACHT|container-image|meijendel-mysql|beoordeel beschikbare fix'
wrapper = "BLOKKADE|vwgm-admin|Command 'vulnerability-audit-root' returned non-zero exit status 1."
candidate = 'SAMENVATTING|kandidaat-aaaaaaaaaaaa|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'
tag = 'AANDACHT|container-hygiene|onverwachte-imagetag=vwgm-mysql:candidate-test'
common = '\n'.join([mysql, group, shiny, attention])
prefix = '''set -euo pipefail
guard_die() { printf '%s\\n' "$*" >&2; exit 1; }
fail() { guard_die "$@"; }
FINALIZE=0
baseline_status="$TEST_STATUS"
baseline_audit="$TEST_AUDIT"
CANDIDATE_ID=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
CANDIDATE_TAG=vwgm-mysql:candidate-test
test_scanner() { printf '%s\\n' "$TEST_AUDIT"; return "$TEST_STATUS"; }
'''
for mode, gate, good in [
    ('local', local_gate, common + '\n' + wrapper),
    ('candidate', remote_gate + '\naudit_candidate', common + '\n' + candidate + '\n' + tag),
]:
    cases = [
        ('current libxml2 scan', good, '1', True),
        ('old curl baseline', good.replace('high=6|fix_beschikbaar=6', 'high=4|fix_beschikbaar=4'), '1', False),
        ('critical finding', good.replace('mysql|critical=0', 'mysql|critical=1'), '1', False),
        ('wrong installed version', good.replace('installed=2.9.13-14.el9_8.4', 'installed=2.9.13-14.el9_8.3'), '1', False),
        ('missing fixed version', good.replace('fixed=2.9.13-14.el9_8.5', 'fixed='), '1', False),
        ('shiny vulnerable', good.replace('shiny_meijendel|critical=0|high=0', 'shiny_meijendel|critical=0|high=1'), '1', False),
        ('scanner error', good, '2', False),
        ('urgent scanner error', good + '\nURGENT|scanner|failure', '1', False),
    ]
    if mode == 'candidate':
        cases.append(('candidate vulnerable', good.replace('kandidaat-aaaaaaaaaaaa|critical=0|high=0', 'kandidaat-aaaaaaaaaaaa|critical=0|high=1'), '1', False))
    for name, audit, status, expected in cases:
        result = subprocess.run(['bash', '-c', prefix + gate], text=True, capture_output=True,
            env={**os.environ, 'TEST_AUDIT': audit, 'TEST_STATUS': status})
        assert (result.returncode == 0) == expected, f'{mode}: {name}: {result.stderr}'
print('OK: actuele libxml2-scan toegelaten; afwijkende en falende scans geblokkeerd.')
PY

[[ -x "$local_script" && -x "$remote_script" ]]
bash -n "$local_script" "$remote_script"
for marker in \
  'guard_baseline' 'guard_acquire_lock' 'container-status' 'backup-status' \
  'critical=0|high=6|fix_beschikbaar=6|zonder_fix=0' \
  'libxml2|installed=2.9.13-14.el9_8.4|fixed=2.9.13-14.el9_8.5' \
  'vulnerability-audit-root.*non-zero exit status 1' \
  '--finalize' 'FINALIZE_ONLY' \
  'ssh -tt' 'ServerAliveInterval=30' 'ServerAliveCountMax=20' \
  'EXPECTED_OLD_IMAGE' 'check_caddy_mysql_isolation_vps.sh' \
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
  'critical=0|high=6|fix_beschikbaar=6|zonder_fix=0' \
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
grep -Fq 'docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true' "$remote_script"
! grep -Fq '[[ -z "$CANDIDATE_ID" ]] || docker image rm "$CANDIDATE_TAG"' "$remote_script"
! grep -Fq 'high=18|fix_beschikbaar=18' "$local_script" "$remote_script"
! grep -Fq 'pakket=openssl|' "$local_script" "$remote_script"
! grep -Eq 'docker (system|builder|image|container) prune' "$local_script" "$remote_script"

printf 'OK: MySQL-imagerebuild is begrensd, scanverplicht en automatisch rollbackbaar.\n'
