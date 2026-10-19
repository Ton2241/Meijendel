#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_script="$repo/deploy/rebuild_mysql_image_vps.sh"
remote_script="$repo/deploy/rebuild_mysql_image_vps_remote.sh"
dockerfile="$repo/deploy/mysql_image/Dockerfile.9.7.1"

python3 - "$local_script" "$remote_script" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

# Exercise the actual scan gates; only the external scanner is replaced.
# A stale baseline must reject the current pcre2 finding, and removing a
# safety check must make one of the negative cases fail.
local = Path(sys.argv[1]).read_text()
remote = Path(sys.argv[2]).read_text()
local_gate = local.split('if [[ "$FINALIZE" -eq 1 ]]; then', 1)[1].split(
    '\nif [[ "$APPLY" -ne 1 ]]; then', 1
)[0]
local_gate = 'if [[ "$FINALIZE" -eq 1 ]]; then' + local_gate
post_gate = local.split('set +e\npost_audit=', 1)[1].split(
    '\nremote_state=', 1
)[0]
post_gate = ('set +e\npost_audit=' + post_gate).replace(
    '"$AUDIT_SCRIPT" --containers-only',
    'test_scanner',
)
remote_gate = remote.split('audit_candidate() {', 1)[1].split(
    '\naudit_active_with_previous()', 1
)[0]
remote_gate = ('audit_candidate() {' + remote_gate).replace(
    '/usr/local/libexec/vwgm-admin/vulnerability-audit-root --image "$CANDIDATE_ID"',
    'test_scanner --image "$CANDIDATE_ID"',
)
mysql = 'SAMENVATTING|meijendel-mysql|critical=0|high=7|fix_beschikbaar=7|zonder_fix=0'
groups = 'GROEP|meijendel-mysql|HIGH|aantal=7|pakket=pcre2|installed=10.40-6.0.1.el9|fixed=10.40-7.0.1.el9_8|ids=CVE-2026-103111,CVE-2026-86145,CVE-2026-89156,CVE-2026-89157,CVE-2026-89158(+2)'
shiny = 'SAMENVATTING|shiny_meijendel|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'
attention = 'AANDACHT|container-image|meijendel-mysql|beoordeel beschikbare fix'
wrapper = "BLOKKADE|vwgm-admin|Command 'vulnerability-audit-root' returned non-zero exit status 1."
candidate = 'SAMENVATTING|kandidaat-aaaaaaaaaaaa|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0'
tag = 'AANDACHT|container-hygiene|onverwachte-imagetag=vwgm-mysql:candidate-test'
common = '\n'.join([mysql, groups, shiny, attention])
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
        ('current pcre2 scan', good, '1', True),
        ('old OpenSSL and Go baseline', good.replace('high=7|fix_beschikbaar=7', 'high=5|fix_beschikbaar=5'), '1', False),
        ('critical finding', good.replace('mysql|critical=0', 'mysql|critical=1'), '1', False),
        ('wrong installed version', good.replace('installed=10.40-6.0.1.el9', 'installed=10.40-5.0.1.el9'), '1', False),
        ('missing fixed version', good.replace('fixed=10.40-7.0.1.el9_8', 'fixed='), '1', False),
        ('missing pcre2 finding', good.replace('high=7|fix_beschikbaar=7', 'high=0|fix_beschikbaar=0').replace(groups, ''), '1', False),
        ('shiny vulnerable', good.replace('shiny_meijendel|critical=0|high=0', 'shiny_meijendel|critical=0|high=1'), '1', False),
        ('scanner error', good, '2', False),
        ('urgent scanner error', good + '\nURGENT|scanner|failure', '1', False),
    ]
    if mode == 'candidate':
        cases.append(('candidate vulnerable', good.replace('kandidaat-aaaaaaaaaaaa|critical=0|high=0', 'kandidaat-aaaaaaaaaaaa|critical=0|high=1'), '1', False))
        cases.append(('known Shiny rollback attention', good + '\nAANDACHT|container-image|vwgm-shiny-rollback-9bac5daf99e6|beoordeel beschikbare fix', '1', True))
        cases.append(('unexpected attention', good + '\nAANDACHT|container-image|unknown|unexpected', '1', False))
        cases.append(('unexpected blockade', good + '\nBLOKKADE|scanner|unexpected', '1', False))
    for name, audit, status, expected in cases:
        result = subprocess.run(['bash', '-c', prefix + gate], text=True, capture_output=True,
            env={**os.environ, 'TEST_AUDIT': audit, 'TEST_STATUS': status})
        assert (result.returncode == 0) == expected, f'{mode}: {name}: {result.stderr}'

rollback_label = 'meijendel-mysql-rollback-123456789abc'
finalize_audit = '\n'.join([
    'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0',
    shiny,
    mysql.replace('meijendel-mysql', rollback_label),
    groups.replace('meijendel-mysql', rollback_label),
    f'AANDACHT|container-image|{rollback_label}|beoordeel beschikbare fix',
    wrapper,
])
result = subprocess.run(
    ['bash', '-c', prefix.replace('FINALIZE=0', 'FINALIZE=1') + local_gate],
    text=True,
    capture_output=True,
    env={**os.environ, 'TEST_AUDIT': finalize_audit, 'TEST_STATUS': '1'},
)
assert result.returncode == 0, f'local finalize with exact rollback: {result.stderr}'

post_good = '\n'.join([
    'SAMENVATTING|meijendel-mysql|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0',
    shiny,
    f'AANDACHT|container-image|{rollback_label}|beoordeel beschikbare fix',
    wrapper,
])
for name, audit, status, expected in [
    ('known retained rollback', post_good, '1', True),
    ('unexpected attention', post_good + '\nAANDACHT|container-hygiene|unexpected', '1', False),
    ('urgent scanner error', post_good + '\nURGENT|scanner|failure', '1', False),
    ('technical scanner failure', post_good, '2', False),
]:
    result = subprocess.run(
        ['bash', '-c', prefix + post_gate],
        text=True,
        capture_output=True,
        env={**os.environ, 'TEST_AUDIT': audit, 'TEST_STATUS': status},
    )
    assert (result.returncode == 0) == expected, f'post: {name}: {result.stderr}'
print('OK: actuele pcre2-scan toegelaten; afwijkende en falende scans geblokkeerd.')
PY

[[ -x "$local_script" && -x "$remote_script" ]]
bash -n "$local_script" "$remote_script"
for marker in \
  'guard_baseline' 'guard_acquire_lock' 'container-status' 'backup-status' \
  'critical=0|high=7|fix_beschikbaar=7|zonder_fix=0' \
  'pcre2|installed=10.40-6.0.1.el9|fixed=10.40-7.0.1.el9_8' \
  'vulnerability-audit-root.*non-zero exit status 1' \
  '--finalize' 'FINALIZE_ONLY' \
  'ssh -tt' 'ServerAliveInterval=30' 'ServerAliveCountMax=20' \
  'EXPECTED_OLD_IMAGE' 'EXPECTED_DATA_COMMIT' \
  'check_caddy_mysql_isolation_vps.sh' \
  'VWG_APP_HOSTS=www.vwg-m.nl,app.vwg-m.nl,vwg-m.nl'; do
  grep -Fq -- "$marker" "$local_script"
done
grep -Fq 'golang@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c' "$dockerfile"
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
  'critical=0|high=7|fix_beschikbaar=7|zonder_fix=0' \
  'pcre2|installed=10.40-6.0.1.el9|fixed=10.40-7.0.1.el9_8' \
  'critical=0|high=0|fix_beschikbaar=0|zonder_fix=0' \
  'validate_image_inventory' 'vwgm-shiny:rollback-*' \
  'PREVIOUS_CONTAINER="meijendel-mysql-rollback-$SHORT_COMMIT"' \
  'PREVIOUS_TAG="vwgm-mysql:rollback-$SHORT_COMMIT"' \
  'GROEN|mysql-image-update|rollback=behouden' \
  'EXPECTED_DATA_COMMIT' 'Meijendel.commit'; do
  grep -Fq -- "$marker" "$remote_script"
done
! grep -Fq 'printf '\''%s\n'\'' "$NEW_COMMIT"' "$remote_script"
! grep -Fq 'mv "$tmp_state" "$STATE_FILE"' "$remote_script"
grep -Fq '[[ "$(cat "$STATE_FILE")" == "$EXPECTED_DATA_COMMIT" ]]' "$remote_script"
grep -Fq 'finalize_current' "$remote_script"
grep -Fq 'mapfile -t rollback_containers' "$remote_script"
grep -Fq '[[ "${#rollback_containers[@]}" -eq 1 ]]' "$remote_script"
grep -Fq 'docker rm "$rollback_container"' "$remote_script"
grep -Fq 'docker image rm "$rollback_tag"' "$remote_script"
grep -Fq 'CHECK TABLE' "$repo/deploy/validate_mysql_uid_migration_vps_remote.sh"
grep -Fq 'deploy/rebuild_mysql_image_vps.sh --finalize --yes' "$repo/deploy/README_DEPLOY.md"
[[ "$(grep -Fc -- "--format '{{range .Mounts}}{{if eq .Destination \"/var/lib/mysql\"}}{{.Source}}{{end}}{{end}}'" "$remote_script")" -eq 3 ]]
! grep -Fq -- '\"/var/lib/mysql\"' "$remote_script"
! grep -Fq 'mysqladmin ping' "$remote_script"
! grep -Fq '"vwgm-mysql:9.7.1 vwgm-shiny:latest "' "$remote_script"
! grep -Fq '/srv/vwgm/vwg-m-linux-app/scripts/smoke_vps.sh' "$remote_script"
grep -Fq 'docker image rm "$CANDIDATE_TAG" >/dev/null 2>&1 || true' "$remote_script"
! grep -Fq '[[ -z "$CANDIDATE_ID" ]] || docker image rm "$CANDIDATE_TAG"' "$remote_script"
! grep -Fq 'high=18|fix_beschikbaar=18' "$local_script" "$remote_script"
! grep -Fq 'pakket=libxml2|' "$local_script" "$remote_script"
! grep -Eq 'docker (system|builder|image|container) prune' "$local_script" "$remote_script"

python3 - "$remote_script" <<'PY'
from pathlib import Path
import sys

remote = Path(sys.argv[1]).read_text()
success_tail = remote.split('echo "== Verifieer de exact behouden rollback =="', 1)[1]
assert 'docker rm "$PREVIOUS_CONTAINER"' not in success_tail
assert 'docker image rm "$PREVIOUS_TAG"' not in success_tail
assert 'docker image rm "$EXPECTED_OLD_IMAGE"' not in success_tail
assert 'grep -Fq "$EXPECTED_OLD_IMAGE" "$BACKUP_DIR/vwg-m-baremetal-latest-manifest.json"' in success_tail
PY

printf 'OK: MySQL-imagerebuild is begrensd, scanverplicht en automatisch rollbackbaar.\n'
