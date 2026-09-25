#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_gateway_job_vps.sh"
SOURCES_RUNNER="$SCRIPT_DIR/run_bronnen_gateway_job_vps.sh"
[[ -x "$RUNNER" ]] || { printf 'FOUT: gatewayrunner ontbreekt of is niet uitvoerbaar\n' >&2; exit 1; }
[[ -x "$SOURCES_RUNNER" ]] || { printf 'FOUT: bron-gatewayrunner ontbreekt of is niet uitvoerbaar\n' >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mock_ssh="$tmp/ssh"
calls="$tmp/calls"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\n" "$*" >> "$MOCK_CALLS"' \
  'body="$(cat)"' \
  'printf "%s\n" "$body" >> "$MOCK_CALLS"' \
  'operation_id="$(printf "%s\n" "$*" | grep -Eo ''[0-9a-f]{32}'' | head -n 1)"' \
  'if [[ "$*" == *"gateway-start"* ]]; then' \
  '  if [[ "${MOCK_INHERITED_CHILD:-0}" == "1" ]]; then sleep 2 >/dev/null 2>&1 & fi' \
  '  printf "GATEWAY_REMOTE_COMPLETED=%s\n" "$operation_id"' \
  '  exit 0' \
  'fi' \
  'if [[ "$*" == *"gateway-fetch"* ]]; then' \
  '  printf "%s\n" "${MOCK_LOG:-gatewaylog}"' \
  '  printf "GATEWAY_REMOTE_EXIT_CODE=%s\n" "${MOCK_EXIT_CODE:-0}"' \
  '  printf "GATEWAY_REMOTE_OPERATION_ID=%s\n" "$operation_id"' \
  '  exit 0' \
  'fi' \
  'if [[ "$*" == *"gateway-cleanup"* ]]; then exit 0; fi' \
  'exit 99' > "$mock_ssh"
chmod +x "$mock_ssh"

operation_id="0123456789abcdef0123456789abcdef"

run_case() {
  local scenario="$1" expected_rc="$2" expected_status="$3" log_text="${4:-gatewaylog}"
  local output rc
  : > "$calls"
  set +e
  output="$(MOCK_CALLS="$calls" MOCK_OPERATION_ID="$operation_id" \
    MOCK_EXIT_CODE="$expected_rc" MOCK_LOG="$log_text" \
    SSH_BIN="$mock_ssh" GATEWAY_OPERATION_ID="$operation_id" \
    "$RUNNER" apply 0123456789abcdef0123456789abcdef01234567 2>"$tmp/$scenario.err")"
  rc=$?
  set -e
  [[ "$rc" -eq "$expected_rc" ]] || { printf 'FOUT: %s gaf rc=%s, verwacht %s\n' "$scenario" "$rc" "$expected_rc" >&2; exit 1; }
  [[ "$(tail -n 1 <<<"$output")" == "$expected_status" ]] || {
    printf 'FOUT: %s mist eindstatus %s\n%s\n' "$scenario" "$expected_status" "$output" >&2
    exit 1
  }
}

run_case success 0 'GATEWAY_JOB_STATUS=ready'
run_case failure 23 'GATEWAY_JOB_STATUS=failed'
run_case timeout 124 'GATEWAY_JOB_STATUS=timeout' $'DATABASE_BACKUP=backup.sql.gz\nROLLBACK|meijendel-release|database=backup.sql.gz\nROLLBACK_STATUS=ready'

: > "$calls"
started="$(date +%s)"
MOCK_CALLS="$calls" MOCK_OPERATION_ID="$operation_id" MOCK_EXIT_CODE=0 \
  MOCK_INHERITED_CHILD=1 SSH_BIN="$mock_ssh" \
  "$RUNNER" preflight 0123456789abcdef0123456789abcdef01234567 >/dev/null
elapsed=$(( $(date +%s) - started ))
[[ "$elapsed" -lt 2 ]] || { printf 'FOUT: geërfde stdout hield de runner %ss open\n' "$elapsed" >&2; exit 1; }

: > "$calls"
MOCK_CALLS="$calls" MOCK_OPERATION_ID="$operation_id" MOCK_EXIT_CODE=0 \
  SSH_BIN="$mock_ssh" GATEWAY_OPERATION_ID="$operation_id" \
  "$RUNNER" preflight 0123456789abcdef0123456789abcdef01234567 >/dev/null
[[ "$(grep -c 'bash -s -- gateway-start' "$calls" || true)" -eq 0 ]] || { printf 'FOUT: hervatting startte een tweede gatewayjob\n' >&2; exit 1; }
[[ "$(grep -c 'bash -s -- gateway-fetch' "$calls" || true)" -eq 1 ]] || { printf 'FOUT: hervatting haalde de bestaande job niet op\n' >&2; exit 1; }

unset GATEWAY_OPERATION_ID
: > "$calls"
MOCK_CALLS="$calls" MOCK_OPERATION_ID="$operation_id" MOCK_EXIT_CODE=0 \
  MOCK_RANDOM_OPERATION_ID="$operation_id" SSH_BIN="$mock_ssh" \
  "$RUNNER" preflight 0123456789abcdef0123456789abcdef01234567 >/dev/null
first_start="$(grep -n 'bash -s -- gateway-start' "$calls" | head -n 1 | cut -d: -f1)"
first_fetch="$(grep -n 'bash -s -- gateway-fetch' "$calls" | head -n 1 | cut -d: -f1)"
[[ "$first_start" =~ ^[0-9]+$ && "$first_fetch" =~ ^[0-9]+$ && "$first_start" -lt "$first_fetch" ]] || \
  { printf 'FOUT: log werd niet pas na de startopdracht opgehaald\n' >&2; exit 1; }
grep -Fq '>"$log.next" 2>&1' "$calls" || { printf 'FOUT: gatewayuitvoer gaat niet naar het remote logbestand\n' >&2; exit 1; }
grep -Fq 'mv "$log.next" "$log"' "$calls" || { printf 'FOUT: remote logbestand wordt niet atomisch gepubliceerd\n' >&2; exit 1; }

: > "$calls"
set +e
sources_output="$(MOCK_CALLS="$calls" MOCK_EXIT_CODE=124 \
  MOCK_LOG=$'SOURCES_DATABASE_BACKUP=backup.sql.gz\nROLLBACK|meijendel-bronnen-release|database=backup.sql.gz\nROLLBACK_STATUS=ready' \
  SSH_BIN="$mock_ssh" GATEWAY_OPERATION_ID="$operation_id" \
  "$SOURCES_RUNNER" apply 0123456789abcdef0123456789abcdef01234567 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2>"$tmp/sources-timeout.err")"
sources_rc=$?
set -e
[[ "$sources_rc" -eq 124 ]] || { printf 'FOUT: bron-timeout gaf rc=%s\n' "$sources_rc" >&2; exit 1; }
[[ "$(tail -n 1 <<<"$sources_output")" == 'GATEWAY_JOB_STATUS=timeout' ]] || {
  printf 'FOUT: bron-timeout mist eindstatus\n' >&2; exit 1;
}

printf 'OK: gatewayrunner begrenst, bewaart en hervat uitvoer zonder geërfde stdout.\n'
