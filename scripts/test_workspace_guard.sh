#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_DIR/scripts/check_local_workspace.sh"
MYSQL_GUARD="$REPO_DIR/scripts/check_mysql_version.sh"
DEPLOY="$REPO_DIR/deploy/deploy_meijendel_vps.sh"
PRODUCTION_GUARD="$REPO_DIR/deploy/production_guard.sh"
UPDATE="$REPO_DIR/deploy/update_en_deploy_meijendel.sh"
ARCHIVE="$REPO_DIR/deploy/Archivering_en_Dump_Meijendel.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

assert_before() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local first_line second_line

  first_line="$(grep -nF "$first_pattern" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -nF "$second_pattern" "$file" | head -n 1 | cut -d: -f1)"
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] ||
    fail "$first_pattern moet in $file vóór $second_pattern staan."
}

if output="$(
  VWG_LOCAL_CHECK_FORCE_DATALLESS="/tmp/voorbeeld-placeholder" \
    "$GUARD" 2>&1
)"; then
  fail "de geforceerde dataless-controle gaf ten onrechte exitcode 0."
fi
[[ "$output" == *"BLOKKADE: bestand is niet lokaal beschikbaar:"* ]] ||
  fail "de geforceerde dataless-controle blokkeerde niet."
[[ "$output" == *"/tmp/voorbeeld-placeholder"* ]] ||
  fail "de blokkerende bestandsnaam ontbreekt in de foutmelding."

(cd / && "$GUARD") ||
  fail "de controle werkt niet vanuit een andere huidige werkmap."

assert_before "$DEPLOY" 'PATH="/usr/local/mysql/bin:$PATH"' 'check_mysql_version.sh'
assert_before "$DEPLOY" 'check_local_workspace.sh' 'git status --porcelain'
assert_before "$DEPLOY" 'check_mysql_version.sh' 'git status --porcelain'
assert_before "$PRODUCTION_GUARD" 'check_local_workspace.sh' 'git status --porcelain'
assert_before "$UPDATE" 'PATH="/usr/local/mysql/bin:$PATH"' 'check_mysql_version.sh'
assert_before "$UPDATE" 'check_local_workspace.sh' 'mysqldump --no-defaults'
assert_before "$UPDATE" 'check_mysql_version.sh' 'mysqldump --no-defaults'
assert_before "$ARCHIVE" 'PATH="/usr/local/mysql/bin:$PATH"' 'check_mysql_version.sh'
assert_before "$ARCHIVE" 'check_mysql_version.sh' 'mysqldump --no-defaults'

grep -qF 'REMOTE_MYSQL_VERSION=' "$DEPLOY" ||
  fail "de deploypreflight controleert de MySQL-versie op de VPS niet."
grep -qF 'REQUIRED_MYSQL_VERSION=' "$DEPLOY" ||
  fail "de deploypreflight gebruikt de vereiste MySQL-versie niet."
[[ -x "$MYSQL_GUARD" ]] || fail "de MySQL-versieguard is niet uitvoerbaar."

printf 'OK: lokale-bestands- en MySQL-versiecontroles zijn fail-fast gekoppeld aan generatie en deploy.\n'
