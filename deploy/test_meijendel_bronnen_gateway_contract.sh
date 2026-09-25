#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy_meijendel_bronnen_vps.sh"
RUNNER="$SCRIPT_DIR/run_bronnen_gateway_job_vps.sh"

fail() { printf 'FOUT: %s\n' "$*" >&2; exit 1; }

[[ -x "$DEPLOY" ]] || fail "bron-only deployscript ontbreekt of is niet uitvoerbaar"
[[ -x "$RUNNER" ]] || fail "bron-only gatewayrunner ontbreekt of is niet uitvoerbaar"
bash -n "$DEPLOY" "$RUNNER"

for fragment in \
  'meijendel-bronnen-manifest-v2' \
  'literature_total=' \
  'literature_active=' \
  'literature_removed=' \
  'literature_active_with_tags=' \
  'production.lock' \
  'Meijendel_bronnen.sql.candidate-' \
  'Meijendel_bronnen.release' \
  'DROP DATABASE IF EXISTS' \
  'trap cleanup EXIT INT TERM' \
  'GATEWAY_RUNNER='; do
  grep -Fq "$fragment" "$DEPLOY" || fail "lokaal bronpad mist contract: $fragment"
done

for forbidden in \
  'meijendel.sql' 'CACHE_' 'check_shiny' 'restart_shiny' \
  'docker compose' 'trim/' 'wintertellingen/' 'groepen_grafieken/'; do
  if grep -Fq "$forbidden" "$DEPLOY"; then
    fail "bron-only deploy noemt verboden ecologisch onderdeel: $forbidden"
  fi
done

grep -Fq 'meijendel-bronnen-release "$stage" "$commit" "$sha256"' "$RUNNER" ||
  fail "runner roept niet exact de begrensde bronactie aan"
grep -Fq '^[0-9a-f]{64}$' "$RUNNER" || fail "runner valideert geen exacte SHA-256"
grep -Fq 'GATEWAY_OPERATION_ID' "$RUNNER" || fail "runner is niet hervatbaar"

# De orchestrator moet volledig met vaste testdubbels kunnen dry-runnen zonder
# netwerk of een levende database. De fixture bevat alleen het minimale
# dumpcontract; de mysql-double levert de gecontroleerde kerngetallen.
mock_root="$(mktemp -d "${TMPDIR:-/tmp}/meijendel-bronnen-contract.XXXXXX")"
trap 'rm -rf "$mock_root"' EXIT INT TERM
mkdir -p "$mock_root/bin"
fixture="$mock_root/meijendel_bronnen.sql"
cat > "$fixture" <<'SQL'
CREATE TABLE `bron` (`bron_id` bigint);
CREATE TABLE `literatuur` (`bron_id` bigint);
CREATE OR REPLACE VIEW `v_bron_catalogus` AS SELECT 1;
CREATE OR REPLACE VIEW `v_literatuur_overzicht` AS SELECT 1;
CREATE OR REPLACE VIEW `v_contextdataset_overzicht` AS SELECT 1;
SQL

cat > "$mock_root/bin/mysql" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *'SELECT VERSION()'*) printf '9.7.1\n' ;;
  *'COUNT(*) AS total'*'zotero_status="actueel"'*'JSON_LENGTH(trefwoorden)>0'*'FROM literatuur'*) printf '522\t518\t4\t342\n' ;;
  *'REFERENTIAL_CONSTRAINTS'*) printf '1\n' ;;
  *'information_schema.VIEWS'*) printf '3\n' ;;
  *) : ;;
esac
MOCK
cat > "$mock_root/bin/rsync" <<'MOCK'
#!/usr/bin/env bash
printf '<f+++++++ Meijendel_bronnen.sql\n'
MOCK
cat > "$mock_root/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *'df -Pk'*) printf '99999999\n' ;;
  *'cat '*Meijendel_bronnen.release*) : ;;
  *) : ;;
esac
MOCK
cat > "$mock_root/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '303'
MOCK
cat > "$mock_root/gateway" <<'MOCK'
#!/usr/bin/env bash
printf 'MYSQL_VERSION=9.7.1\nPREFLIGHT_STATUS=ready\nGATEWAY_JOB_STATUS=ready\n'
MOCK
chmod +x "$mock_root/bin/"* "$mock_root/gateway"

PATH="$mock_root/bin:$PATH" \
SOURCES_SQL_LOCAL="$fixture" \
GATEWAY_RUNNER="$mock_root/gateway" \
MEIJENDEL_BRONNEN_TEST_MODE=1 \
  "$DEPLOY" > "$mock_root/output"
grep -Fq 'Preflight klaar; productie is niet aangepast.' "$mock_root/output" ||
  fail "mock-dry-run bereikte geen groene preflighteindstatus"

printf 'OK: zelfstandige Meijendel_bronnen-gateway is begrensd en ecologisch geïsoleerd.\n'
