#!/usr/bin/env bash
set -euo pipefail

stage="${1:-}"
commit="${2:-}"
sha256="${3:-}"
VPS="${VPS:-ton@45.87.43.90}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/vwgm_spectraip_ed25519}"
GATEWAY="${GATEWAY:-/usr/local/sbin/vwgm-admin}"
SSH_BIN="${SSH_BIN:-ssh}"
operation_id="${GATEWAY_OPERATION_ID:-}"

die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 2; }
validate_integer_range() {
  local value="$1" minimum="$2" maximum="$3" name="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$name moet een geheel getal zijn."
  (( value >= minimum && value <= maximum )) || die "$name valt buiten het toegestane bereik."
}

case "$stage" in
  preflight) limit="${GATEWAY_PREFLIGHT_TIMEOUT:-300}"; validate_integer_range "$limit" 60 900 GATEWAY_PREFLIGHT_TIMEOUT ;;
  apply) limit="${GATEWAY_APPLY_TIMEOUT:-10800}"; validate_integer_range "$limit" 1800 14400 GATEWAY_APPLY_TIMEOUT ;;
  *) die "fase moet preflight of apply zijn." ;;
esac
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "commit vereist exact 40 lowercase hextekens."
[[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || die "SHA-256 vereist exact 64 lowercase hextekens."
kill_after="${GATEWAY_KILL_AFTER:-3600}"
validate_integer_range "$kill_after" 600 7200 GATEWAY_KILL_AFTER
[[ "$GATEWAY" == /* && "$GATEWAY" != *$'\n'* ]] || die "GATEWAY moet een absoluut pad zijn."

resume=0
if [[ -n "$operation_id" ]]; then
  resume=1
  [[ "$operation_id" =~ ^[0-9a-f]{32}$ ]] || die "GATEWAY_OPERATION_ID vereist exact 32 lowercase hextekens."
else
  operation_id="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  [[ "$operation_id" =~ ^[0-9a-f]{32}$ ]] || die "operatie-id kon niet veilig worden gemaakt."
fi
ssh_args=(-i "$SSH_KEY" -o ServerAliveInterval=15 -o ServerAliveCountMax=4 "$VPS")

if [[ "$resume" -eq 0 ]]; then
  set +e
  start_output="$("$SSH_BIN" "${ssh_args[@]}" bash -s -- gateway-start \
    "$operation_id" "$stage" "$commit" "$sha256" "$limit" "$kill_after" "$GATEWAY" <<'REMOTE'
set -euo pipefail
mode="$1"; operation_id="$2"; stage="$3"; commit="$4"; sha256="$5"; limit="$6"; kill_after="$7"; gateway="$8"
[[ "$mode" == gateway-start ]]
root="/srv/vwgm/deploy-state/gateway-jobs"
job="$root/$operation_id"; log="$job/gateway.log"; status="$job/status"; runner="$job/run"
umask 077
mkdir -p "$root"
[[ ! -L "$root" ]] || exit 70
if [[ -e "$job" ]]; then
  [[ -d "$job" && ! -L "$job" && -f "$status" && ! -L "$status" ]] || exit 71
else
  mkdir "$job"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -uo pipefail' \
    'operation_id="$1"; stage="$2"; commit="$3"; sha256="$4"; limit="$5"; kill_after="$6"; gateway="$7"; job="$8"' \
    'log="$job/gateway.log"; status="$job/status"; rc=125' \
    'finish() { trap - EXIT INT TERM; [[ ! -f "$log.next" ]] || mv "$log.next" "$log"; printf "operation_id=%s\nexit_code=%s\n" "$operation_id" "$rc" > "$status.next"; mv "$status.next" "$status"; }' \
    'trap finish EXIT INT TERM' \
    'set +e' \
    'timeout --foreground --signal=TERM --kill-after="${kill_after}s" "${limit}s" sudo -n "$gateway" meijendel-bronnen-release "$stage" "$commit" "$sha256" >"$log.next" 2>&1' \
    'rc=$?' \
    'set -e' \
    'mv "$log.next" "$log"' \
    'exit "$rc"' > "$runner"
  chmod 700 "$runner"
  nohup "$runner" "$operation_id" "$stage" "$commit" "$sha256" "$limit" "$kill_after" "$gateway" "$job" </dev/null >/dev/null 2>&1 &
fi
while [[ ! -f "$status" ]]; do sleep 1; done
printf 'GATEWAY_REMOTE_COMPLETED=%s\n' "$operation_id"
REMOTE
)"
  start_rc=$?
  set -e
  if [[ "$start_rc" -ne 0 ]]; then printf 'GATEWAY_OPERATION_ID=%s\n' "$operation_id" >&2; exit "$start_rc"; fi
  [[ "$start_output" == "GATEWAY_REMOTE_COMPLETED=$operation_id" ]] || die "onverwachte startbevestiging."
fi

set +e
fetch_output="$("$SSH_BIN" "${ssh_args[@]}" bash -s -- gateway-fetch "$operation_id" <<'REMOTE'
set -euo pipefail
mode="$1"; operation_id="$2"; [[ "$mode" == gateway-fetch ]]
job="/srv/vwgm/deploy-state/gateway-jobs/$operation_id"; log="$job/gateway.log"; status="$job/status"
[[ -d "$job" && ! -L "$job" && -f "$status" && ! -L "$status" && -f "$log" && ! -L "$log" ]] || exit 73
status_operation_id="$(awk -F= '$1 == "operation_id" {print $2}' "$status")"
exit_code="$(awk -F= '$1 == "exit_code" {print $2}' "$status")"
[[ "$status_operation_id" == "$operation_id" && "$exit_code" =~ ^[0-9]+$ && "$exit_code" -le 255 ]] || exit 76
cat "$log"
printf '\nGATEWAY_REMOTE_EXIT_CODE=%s\nGATEWAY_REMOTE_OPERATION_ID=%s\n' "$exit_code" "$operation_id"
REMOTE
)"
fetch_rc=$?
set -e
if [[ "$fetch_rc" -ne 0 ]]; then printf 'GATEWAY_OPERATION_ID=%s\n' "$operation_id" >&2; exit "$fetch_rc"; fi
remote_operation_id="$(tail -n 1 <<<"$fetch_output" | sed -n 's/^GATEWAY_REMOTE_OPERATION_ID=//p')"
remote_exit_code="$(tail -n 2 <<<"$fetch_output" | head -n 1 | sed -n 's/^GATEWAY_REMOTE_EXIT_CODE=//p')"
[[ "$remote_operation_id" == "$operation_id" ]] || die "opgehaalde operatie-id wijkt af."
[[ "$remote_exit_code" =~ ^[0-9]+$ && "$remote_exit_code" -le 255 ]] || die "opgehaalde exitcode is ongeldig."
gateway_log="$(sed '$d' <<<"$fetch_output" | sed '$d')"
printf '%s\n' "$gateway_log"

if [[ "$remote_exit_code" -eq 124 || "$remote_exit_code" -eq 137 ]]; then
  if grep -Fq 'SOURCES_DATABASE_BACKUP=' <<<"$gateway_log"; then
    grep -Fq 'ROLLBACK|' <<<"$gateway_log" || die "timeout na importstart mist rollbackmelding."
    grep -Fqx 'ROLLBACK_STATUS=ready' <<<"$gateway_log" || die "timeout na importstart mist geslaagde herstelstatus."
  fi
  final_status=timeout
elif [[ "$remote_exit_code" -eq 0 ]]; then final_status=ready
else final_status=failed
fi

"$SSH_BIN" "${ssh_args[@]}" bash -s -- gateway-cleanup "$operation_id" <<'REMOTE' || \
  printf 'WAARSCHUWING: gatewayjob kon niet worden verwijderd: %s\n' "$operation_id" >&2
set -euo pipefail
mode="$1"; operation_id="$2"; [[ "$mode" == gateway-cleanup ]]
job="/srv/vwgm/deploy-state/gateway-jobs/$operation_id"
[[ -d "$job" && ! -L "$job" ]] || exit 78
rm -f "$job/gateway.log" "$job/status" "$job/run"
rmdir "$job"
REMOTE

printf 'GATEWAY_JOB_STATUS=%s\n' "$final_status"
exit "$remote_exit_code"
