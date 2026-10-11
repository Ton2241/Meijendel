#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE="$SCRIPT_DIR/run_ahn_vegetatiestructuur.sh"

[[ -x "$PIPELINE" ]]
HELP="$($PIPELINE --help)"
grep -q 'AHN3' <<<"$HELP"
grep -q 'AHN4' <<<"$HELP"
grep -q '2 meter' <<<"$HELP"
grep -q '^TILE_PIXELS=2048$' "$PIPELINE"
grep -q 'gdalbuildvrt' "$PIPELINE"

printf 'OK: AHN-structuurpipeline heeft een uitvoerbaar en begrensd contract.\n'
