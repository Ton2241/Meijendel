#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/deploy_meijendel_bronnen_release_vps_remote.sh"
fail() { printf 'FOUT: %s\n' "$*" >&2; exit 1; }
[[ -x "$HELPER" ]] || fail "bronreleasehelper ontbreekt of is niet uitvoerbaar"
bash -n "$HELPER"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/bronnen-release-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT INT TERM
mkdir -p "$tmp/bin"
docker_log="$tmp/docker.log"

cat > "$tmp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"
all="$*"
if [[ "$1" == inspect ]]; then printf 'running\n'; exit 0; fi
if [[ "$all" == *'SELECT VERSION()'* ]]; then printf '9.7.1\n'; exit 0; fi
if [[ "$all" == *'printf %s "$MYSQL_USER"'* ]]; then printf 'website_user'; exit 0; fi
if [[ "$all" == *mysqldump* ]]; then
  [[ "${MOCK_EMPTY_BACKUP:-0}" == 1 ]] || printf '%s\n' 'CREATE DATABASE old_sources;' 'SELECT 1;'
  exit 0
fi
if [[ "$all" == *'SCHEMA_NAME = '*Meijendel_bronnen* ]]; then printf '%s\n' "${MOCK_EXISTING_DATABASE:-1}"; exit 0; fi
if [[ "$all" == *replication_connection_status* ]]; then printf '%s\n' "${MOCK_REPLICATION_CONNECTIONS:-0}"; exit 0; fi
if [[ "$all" == *'SHOW REPLICAS'* ]]; then printf '%s' "${MOCK_REGISTERED_REPLICAS:-}"; exit 0; fi
if [[ "$all" == *'Binlog Dump'* ]]; then printf '%s\n' "${MOCK_BINLOG_THREADS:-0}"; exit 0; fi
if [[ "$all" == *'SCHEMA_PRIVILEGES'* ]]; then printf '0\n'; exit 0; fi
if [[ "$all" == *'TABLE_PRIVILEGES'*'PRIVILEGE_TYPE = '* ]]; then printf '3\n'; exit 0; fi
if [[ "$all" == *'TABLE_PRIVILEGES'*'TABLE_NAME NOT IN'* ]]; then printf '0\n'; exit 0; fi
if [[ "$all" == *'SELECT DISTINCT TABLE_NAME'* ]]; then printf 'legacy_object\n'; exit 0; fi
if [[ "$all" == *'table_type = '*'BASE TABLE'* ]]; then printf 'bron\nliteratuur\n'; exit 0; fi
if [[ "$all" == *'CHECK TABLE'* ]]; then printf 'Meijendel_bronnen.bron\tcheck\tstatus\tOK\n'; exit 0; fi
if [[ "$all" == *REFERENTIAL_CONSTRAINTS* ]]; then printf '1\n'; exit 0; fi
if [[ "$all" == *'COUNT(*) AS total'*'zotero_status="actueel"'*'JSON_LENGTH(trefwoorden)>0'* ]]; then printf '%b\n' "${MOCK_CORE_COUNTS:-522\t518\t4\t342}"; exit 0; fi
if [[ "$all" == *'v_bron_catalogus'*'COUNT(*)'* || "$all" == *'COUNT(*) FROM `Meijendel_bronnen`.v_bron_catalogus'* ]]; then printf '522\n'; exit 0; fi
if [[ "$all" == *'v_literatuur_overzicht'*'COUNT(*)'* || "$all" == *'COUNT(*) FROM `Meijendel_bronnen`.v_literatuur_overzicht'* ]]; then printf '518\n'; exit 0; fi
if [[ "$all" == *'v_contextdataset_overzicht'*'COUNT(*)'* || "$all" == *'COUNT(*) FROM `Meijendel_bronnen`.v_contextdataset_overzicht'* ]]; then printf '4\n'; exit 0; fi
if [[ "$all" == *'exec mysql -uroot'*' Meijendel_bronnen'* ]]; then
  cat >/dev/null
  if [[ "${MOCK_IMPORT_FAIL:-0}" == 1 && ! -e "$MOCK_IMPORT_MARKER" ]]; then
    : > "$MOCK_IMPORT_MARKER"
    exit 47
  fi
  exit 0
fi
if [[ "$all" == *'exec mysql -uroot'* ]]; then cat >/dev/null || true; exit 0; fi
exit 0
MOCK
chmod +x "$tmp/bin/docker"

commit=0123456789abcdef0123456789abcdef01234567
fixture_sql="$tmp/source.sql"
cat > "$fixture_sql" <<'SQL'
CREATE TABLE `bron` (`bron_id` bigint primary key);
CREATE TABLE `literatuur` (`bron_id` bigint, CONSTRAINT `fk_lit_bron` FOREIGN KEY (`bron_id`) REFERENCES `bron` (`bron_id`));
CREATE OR REPLACE VIEW `v_bron_catalogus` AS SELECT 1;
CREATE OR REPLACE VIEW `v_literatuur_overzicht` AS SELECT 1;
CREATE OR REPLACE VIEW `v_contextdataset_overzicht` AS SELECT 1;
SQL
sha256="$(shasum -a 256 "$fixture_sql" | awk '{print $1}')"
bytes="$(stat -f '%z' "$fixture_sql")"

setup_case() {
  local name="$1" manifest_hash="${2:-$sha256}"
  case_base="$tmp/$name"
  mkdir -p "$case_base/data" "$case_base/deploy-state/production.lock" "$case_base/backups/meijendel-bronnen-mysql"
  candidate="$case_base/data/Meijendel_bronnen.sql.candidate-$commit-$sha256"
  manifest="$candidate.manifest"
  cp "$fixture_sql" "$candidate"
  cat > "$manifest" <<EOF
format=meijendel-bronnen-manifest-v2
commit=$commit
sql_sha256=$manifest_hash
sql_bytes=$bytes
literature_total=522
literature_active=518
literature_removed=4
literature_active_with_tags=342
EOF
  chmod 600 "$candidate" "$manifest"
  : > "$docker_log"
  import_marker="$case_base/import.failed"
}

run_helper() {
  PATH="$tmp/bin:$PATH" MOCK_DOCKER_LOG="$docker_log" MOCK_IMPORT_MARKER="$import_marker" \
    MEIJENDEL_REMOTE_BASE="$case_base" "$HELPER" "$@"
}

setup_case preflight
preflight_output="$(run_helper preflight "$commit" "$sha256")"
grep -Fqx 'PREFLIGHT_STATUS=ready' <<<"$preflight_output" || fail "preflight werd niet gereed"

setup_case replicated
if MOCK_REPLICATION_CONNECTIONS=1 run_helper preflight "$commit" "$sha256" >"$tmp/replicated.out" 2>&1; then
  fail "preflight accepteerde actieve replicatie"
fi

setup_case bad_hash "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
if run_helper apply "$commit" "$sha256" >"$tmp/bad-hash.out" 2>&1; then
  fail "manifest-hashmismatch werd geaccepteerd"
fi
[[ ! -e "$case_base/deploy-state/Meijendel_bronnen.release" ]] || fail "hashmismatch schreef toch status"

setup_case empty_backup
if MOCK_EMPTY_BACKUP=1 run_helper apply "$commit" "$sha256" >"$tmp/empty.out" 2>&1; then
  fail "lege back-up werd geaccepteerd"
fi
[[ ! -e "$import_marker" ]] || fail "import begon ondanks lege back-up"

setup_case import_failure
printf 'vorige bronexport\n' > "$case_base/data/Meijendel_bronnen.sql"
set +e
failure_output="$(MOCK_IMPORT_FAIL=1 run_helper apply "$commit" "$sha256" 2>&1)"
failure_rc=$?
set -e
[[ "$failure_rc" -eq 47 ]] || fail "importfout gaf rc=$failure_rc in plaats van 47"
grep -Fqx 'ROLLBACK_STATUS=ready' <<<"$failure_output" || fail "importfout werd niet teruggedraaid"
grep -Fq 'vorige bronexport' "$case_base/data/Meijendel_bronnen.sql" || fail "actieve export wijzigde bij importfout"
[[ ! -e "$case_base/deploy-state/Meijendel_bronnen.release" ]] || fail "importfout schreef toch status"

setup_case wrong_counts
set +e
counts_output="$(MOCK_CORE_COUNTS=$'521\t518\t3\t342' run_helper apply "$commit" "$sha256" 2>&1)"
counts_rc=$?
set -e
[[ "$counts_rc" -ne 0 ]] || fail "afwijkende geïmporteerde kerngetallen werden geaccepteerd"
grep -Fqx 'ROLLBACK_STATUS=ready' <<<"$counts_output" || fail "kerngetalafwijking werd niet teruggedraaid"

setup_case success
success_output="$(run_helper apply "$commit" "$sha256")"
grep -Fqx 'SOURCES_STATUS=ready' <<<"$success_output" || fail "succespad mist bronstatus"
state="$case_base/deploy-state/Meijendel_bronnen.release"
[[ -f "$state" ]] || fail "releasestatus ontbreekt"
grep -Fqx "commit=$commit" "$state" || fail "status mist commit"
grep -Fqx "sql_sha256=$sha256" "$state" || fail "status mist hash"
[[ "$(grep -c 'GRANT SELECT ON `Meijendel_bronnen`' "$docker_log")" -eq 3 ]] || fail "niet exact drie viewgrants toegepast"
grep -Fq 'GRANT SELECT ON `Meijendel_bronnen`.*' "$docker_log" && fail "brede schemagrant toegepast"
if grep -Eiq 'shiny|cache|restart|MYSQL_DATABASE' "$docker_log"; then
  fail "bron-only helper raakte een ecologisch of Shiny-onderdeel"
fi
cmp -s "$fixture_sql" "$case_base/data/Meijendel_bronnen.sql" || fail "actieve dump wijkt af van kandidaat"

printf 'OK: bronrelease valideert, begrenst grants en rolt een importfout terug.\n'
