#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE="$SCRIPT_DIR/run_broedvogel_habitatgericht.sh"
[[ -x "$PIPELINE" ]]
HELP="$($PIPELINE --help)"
grep -q 'AHN_CSV' <<<"$HELP"
grep -q 'geen VPS' <<<"$HELP"
grep -q 'mktemp -d /private/tmp/' "$PIPELINE"
printf 'OK: gerichte habitatpipeline heeft een lokaal contract.\n'
