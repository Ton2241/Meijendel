#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY="$SCRIPT_DIR/deploy_meijendel_bronnen_vps.sh"
RUNNER="$SCRIPT_DIR/run_bronnen_gateway_job_vps.sh"
RUNBOOK="$SCRIPT_DIR/README_DEPLOY.md"

fail() { printf 'FOUT: %s\n' "$*" >&2; exit 1; }

[[ -x "$DEPLOY" ]] || fail "bron-only deployscript ontbreekt of is niet uitvoerbaar"
[[ -x "$RUNNER" ]] || fail "bron-only gatewayrunner ontbreekt of is niet uitvoerbaar"
bash -n "$DEPLOY" "$RUNNER"

for fragment in \
  'meijendel-bronnen-manifest-v2' \
  '/usr/local/mysql/bin/mysql' \
  '-e "$SSH_BIN -i $SSH_KEY"' \
  'literature_total=' \
  'literature_active=' \
  'literature_removed=' \
  'literature_active_with_tags=' \
  'production.lock' \
  'Meijendel_bronnen.sql.candidate-' \
  'Meijendel_bronnen.release' \
  'DROP DATABASE IF EXISTS' \
  'trap cleanup EXIT INT TERM' \
  'CANDIDATE_STAGED=1' \
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
if [[ "${MOCK_GATEWAY_FAIL:-0}" == 1 ]]; then
  printf 'BLOKKADE|mock-gateway|zichtbare-fout\n'
  exit 47
fi
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

if PATH="$mock_root/bin:$PATH" \
  SOURCES_SQL_LOCAL="$fixture" \
  GATEWAY_RUNNER="$mock_root/gateway" \
  MEIJENDEL_BRONNEN_TEST_MODE=1 \
    "$DEPLOY" --apply --yes >"$mock_root/test-apply.out" 2>&1; then
  fail "testmodus mocht een apply-pad bereiken"
fi
grep -Fq 'testmodus staat geen --apply toe' "$mock_root/test-apply.out" ||
  fail "testmodus blokkeert apply niet expliciet"

if PATH="$mock_root/bin:$PATH" \
  SOURCES_SQL_LOCAL="$fixture" \
  GATEWAY_RUNNER="$mock_root/gateway" \
  MOCK_GATEWAY_FAIL=1 \
  MEIJENDEL_BRONNEN_TEST_MODE=1 \
    "$DEPLOY" >"$mock_root/gateway-failure.out" 2>&1; then
  fail "falende gateway werd als succesvol behandeld"
fi
grep -Fq 'BLOKKADE|mock-gateway|zichtbare-fout' "$mock_root/gateway-failure.out" ||
  fail "gatewayfout blijft onzichtbaar door set -e"

lock_line="$(grep -nF 'LOCK_HELD=1' "$DEPLOY" | tail -n 1 | cut -d: -f1)"
apply_sync_line="$(grep -nF 'sync_candidate apply' "$DEPLOY" | tail -n 1 | cut -d: -f1)"
[[ "$lock_line" =~ ^[0-9]+$ && "$apply_sync_line" =~ ^[0-9]+$ && "$lock_line" -lt "$apply_sync_line" ]] ||
  fail "kandidaatapply staat niet aantoonbaar na verwerving van de globale lock"
grep -Fq 'sha256sum' "$DEPLOY" || fail "remote kandidaat gebruikt niet het VPS-hashcommando sha256sum"
[[ "$(grep -c '^source_route_smoke$' "$DEPLOY")" -eq 2 ]] ||
  fail "afgeschermde bronroute wordt niet zowel vóór als na apply gecontroleerd"

for fragment in \
  'VWG_Project/scripts/install_vwgm_admin_gateway_vps.sh' \
  'VWG_Project/scripts/install_vwgm_admin_gateway_vps.sh --apply --yes' \
  'Meijendel/deploy/deploy_meijendel_bronnen_vps.sh' \
  'Meijendel/deploy/deploy_meijendel_bronnen_vps.sh --apply --yes' \
  '/srv/vwgm/deploy-state/Meijendel_bronnen.release' \
  '/srv/vwgm/backups/meijendel-bronnen-mysql/' \
  'herstart geen Shiny' \
  'afzonderlijke productiegoedkeuring'; do
  grep -Fq "$fragment" "$RUNBOOK" || fail "bronrunbook mist: $fragment"
done

install_line="$(grep -nF 'VWG_Project/scripts/install_vwgm_admin_gateway_vps.sh --apply --yes' "$RUNBOOK" | head -n 1 | cut -d: -f1)"
preflight_line="$(grep -nF 'Meijendel/deploy/deploy_meijendel_bronnen_vps.sh' "$RUNBOOK" | head -n 1 | cut -d: -f1)"
approval_line="$(grep -nF 'afzonderlijke productiegoedkeuring' "$RUNBOOK" | head -n 1 | cut -d: -f1)"
apply_line="$(grep -nF 'Meijendel/deploy/deploy_meijendel_bronnen_vps.sh --apply --yes' "$RUNBOOK" | head -n 1 | cut -d: -f1)"
[[ "$install_line" -lt "$preflight_line" && "$preflight_line" -lt "$approval_line" && "$approval_line" -lt "$apply_line" ]] ||
  fail "bronrunbook legt gateway-installatie, preflight, productiegoedkeuring en apply niet in vaste volgorde vast"

printf 'OK: zelfstandige Meijendel_bronnen-gateway is begrensd en ecologisch geïsoleerd.\n'
