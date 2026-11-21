#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_script="$repo/deploy/rebuild_mysql_974_security_vps.sh"
remote_script="$repo/deploy/rebuild_mysql_974_security_vps_remote.sh"
dockerfile="$repo/deploy/mysql_image/Dockerfile.9.7.4"

fail() { printf 'FOUT: %s\n' "$*" >&2; exit 1; }

[[ -x "$local_script" ]] || fail "lokale 9.7.4-beveiligingsroute ontbreekt of is niet uitvoerbaar"
[[ -x "$remote_script" ]] || fail "remote 9.7.4-beveiligingsroute ontbreekt of is niet uitvoerbaar"
bash -n "$local_script" "$remote_script"

# Bron het echte remote contract; main mag bij sourcen niet draaien.
source "$remote_script"

version_ge '2.9.13-18.el9_9.1' '2.9.13-18.el9_9.1' || fail "gelijke RPM-versie werd afgewezen"
version_ge '2.9.13-18.el9_9.2' '2.9.13-18.el9_9.1' || fail "nieuwere RPM-versie werd afgewezen"
! version_ge '2.9.13-14.el9_8.5' '2.9.13-18.el9_9.1' || fail "oude RPM-versie werd toegelaten"

fake_libxml2='2.9.13-18.el9_9.1'
fake_curl='7.76.1-44.el9_9.1'
fake_libcurl='7.76.1-44.el9_9.1'
fake_krb5_libs='1.21.1-10.0.1.el9_9.2'
docker() {
  local package="${*: -1}"
  case "$package" in
    libxml2) printf '%s\n' "$fake_libxml2" ;;
    curl) printf '%s\n' "$fake_curl" ;;
    libcurl) printf '%s\n' "$fake_libcurl" ;;
    krb5-libs) printf '%s\n' "$fake_krb5_libs" ;;
    *) return 1 ;;
  esac
}
require_candidate_packages sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
fake_libxml2='2.9.13-14.el9_8.5'
if (require_candidate_packages sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >/dev/null 2>&1); then
  fail "verouderde libxml2-versie werd toegelaten"
fi
fake_libxml2='2.9.13-18.el9_9.1'
fake_krb5_libs='1.21.1-10.0.1.el9_8'
if (require_candidate_packages sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >/dev/null 2>&1); then
  fail "verouderde krb5-libs-versie werd toegelaten"
fi
unset -f docker

candidate_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
candidate_good=$'SAMENVATTING|kandidaat-aaaaaaaaaaaa|critical=0|high=0|fix_beschikbaar=0|zonder_fix=0\nAANDACHT|container-hygiene|onverwachte-imagetag=vwgm-mysql:candidate-test\nAANDACHT|container-image|meijendel-mysql|beoordeel beschikbare fix'
audit_candidate_output "$candidate_good" 1 "$candidate_id" 'vwgm-mysql:candidate-test'
if (audit_candidate_output "${candidate_good/critical=0/critical=1}" 1 "$candidate_id" 'vwgm-mysql:candidate-test' >/dev/null 2>&1); then
  fail "CRITICAL-kandidaat werd toegelaten"
fi
if (audit_candidate_output "$candidate_good" 2 "$candidate_id" 'vwgm-mysql:candidate-test' >/dev/null 2>&1); then
  fail "technisch mislukte scan werd toegelaten"
fi
if (audit_candidate_output "$candidate_good"$'\nURGENT|scanner|onvolledig' 1 "$candidate_id" 'vwgm-mysql:candidate-test' >/dev/null 2>&1); then
  fail "URGENT-scanneruitvoer werd toegelaten"
fi

[[ "$(single_rollback_name $'meijendel-mysql-rollback-123456789abc\n')" == 'meijendel-mysql-rollback-123456789abc' ]] ||
  fail "exact één rollback werd niet geselecteerd"
if (single_rollback_name $'meijendel-mysql-rollback-123456789abc\nmeijendel-mysql-rollback-abcdefabcdef\n' >/dev/null 2>&1); then
  fail "meerdere rollbacks werden toegelaten"
fi

# Een fout tussen stop en rename laat de oude container onder de actieve naam
# staan. De terugval moet die container dan expliciet opnieuw starten.
rollback_log="$(mktemp -t vwgm-mysql974-rollback.XXXXXX)"
(
  set +e
  ACTIVE_CONTAINER=meijendel-mysql
  PREVIOUS_CONTAINER=meijendel-mysql-rollback-123456789abc
  CANDIDATE_CONTAINER=meijendel-mysql-candidate-123456789abc
  CANDIDATE_TAG=vwgm-mysql:candidate-123456789abc
  PREVIOUS_TAG=vwgm-mysql:rollback-123456789abc
  EXPECTED_OLD_IMAGE=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  CANONICAL_TAG=vwgm-mysql:9.7.4
  CANDIDATE_ID=''
  TASK_ROOT=''
  SWITCH_STARTED=1
  SUCCESS=0
  docker() {
    printf '%s\n' "$*" >> "$rollback_log"
    if [[ "$1 $2" == "inspect $PREVIOUS_CONTAINER" ]]; then return 1; fi
    if [[ "$1 $2" == "inspect --format" && "${*: -1}" == "$ACTIVE_CONTAINER" ]]; then
      printf '%s\n' "$EXPECTED_OLD_IMAGE"
      return 0
    fi
    if [[ "$1 $2" == "inspect $ACTIVE_CONTAINER" ]]; then return 0; fi
    return 0
  }
  wait_mysql() { printf 'wait %s\n' "$1" >> "$rollback_log"; }
  false
  rollback_or_cleanup
) >/dev/null 2>&1 || true
grep -Fxq 'start meijendel-mysql' "$rollback_log" ||
  fail "oude container wordt na een mislukte rename niet opnieuw gestart"
rm -f "$rollback_log"

ensure_no_maintenance_artifacts '' ''
if (ensure_no_maintenance_artifacts 'meijendel-mysql-rollback-123456789abc' '' >/dev/null 2>&1); then
  fail "bestaande MySQL-rollback werd vóór een nieuwe rebuild toegelaten"
fi
if (ensure_no_maintenance_artifacts '' 'vwgm-mysql:candidate-123456789abc' >/dev/null 2>&1); then
  fail "bestaande MySQL-kandidaattag werd vóór een nieuwe rebuild toegelaten"
fi

state_file="$(mktemp "${TMPDIR:-/tmp}/vwgm-mysql974-state.XXXXXX")"
cat > "$state_file" <<'JSON'
{
  "status": "rollback-retained",
  "source_commit": "1111111111111111111111111111111111111111",
  "data_commit": "2222222222222222222222222222222222222222",
  "active_image": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "rollback_container": "meijendel-mysql-rollback-111111111111",
  "rollback_image": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "rollback_tag": "vwgm-mysql:rollback-111111111111",
  "data_mount": "/srv/vwgm/mysql974-candidate-47d133641833/data"
}
JSON
expected_state='1111111111111111111111111111111111111111|2222222222222222222222222222222222222222|sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|meijendel-mysql-rollback-111111111111|sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|vwgm-mysql:rollback-111111111111|/srv/vwgm/mysql974-candidate-47d133641833/data'
[[ "$(maintenance_state_line "$state_file")" == "$expected_state" ]] || fail "onderhoudsstatus werd niet exact gebonden"
sed -i.bak 's/rollback-retained/unknown/' "$state_file"
if (maintenance_state_line "$state_file" >/dev/null 2>&1); then
  fail "ongeldige onderhoudsstatus werd voor finalisatie toegelaten"
fi
rm -f "$state_file" "$state_file.bak"

for marker in \
  'guard_baseline' 'guard_acquire_lock' 'container-status' 'mysql-health' \
  'backup-status' 'VPS_QUEUE=legacy' '--apply --yes' '--finalize --yes' \
  'Dockerfile.9.7.4' 'ssh -tt' 'REMOTE_EXECUTION_STARTED' 'REMOTE_EXECUTION_COMPLETE' \
  'ServerAliveInterval=30' 'ServerAliveCountMax=20'; do
  grep -Fq -- "$marker" "$local_script" || fail "lokale contractmarker ontbreekt: $marker"
done

for marker in \
  'CANONICAL_TAG="vwgm-mysql:9.7.4"' 'SELECT VERSION()' \
  '9.7.4' '1999' '--pull --no-cache --load' \
  'EXPECTED_OLD_IMAGE' 'EXPECTED_DATA_COMMIT' 'EXPECTED_DATA_MOUNT' \
  'vulnerability-audit-root --image' 'require_candidate_packages' \
  'validate-mysql' '9.7.4 9.7.4' 'SWITCH_STARTED=1' \
  'vwgm-baremetal-backup' 'restore_check_backup.sh' \
  'mysql-974-security-rebuild.json' 'write_maintenance_state' 'EXPECTED_ROLLBACK_IMAGE' \
  'check-caddy-mysql-isolation' 'GROEN|mysql-974-security-rebuild' \
  'GROEN|mysql-974-security-finalisatie'; do
  grep -Fq -- "$marker" "$remote_script" || fail "remote contractmarker ontbreekt: $marker"
done

grep -Fq 'FROM mysql@sha256:' "$dockerfile" || fail "MySQL 9.7.4-basisimage is niet per digest gepind"
! grep -Eq 'docker (system|builder|image|container) prune' "$local_script" "$remote_script" ||
  fail "ongerichte Docker-prune aangetroffen"
! grep -Fq '9.7.1' "$local_script" "$remote_script" ||
  fail "historische 9.7.1-route lekt in de 9.7.4-beveiligingsroute"
! grep -Fq '\"/var/lib/mysql\"' "$remote_script" ||
  fail "Docker inspect-sjabloon bevat ongeldige geescape-te aanhalingstekens"

printf 'OK: MySQL 9.7.4-beveiligingsroute blokkeert oude pakketten en onveilige scans.\n'
