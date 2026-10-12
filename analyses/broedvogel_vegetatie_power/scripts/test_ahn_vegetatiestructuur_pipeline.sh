#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE="$SCRIPT_DIR/run_ahn_vegetatiestructuur.sh"

[[ -x "$PIPELINE" ]]
HELP="$($PIPELINE --help)"
grep -q 'AHN3' <<<"$HELP"
grep -q 'AHN2' <<<"$HELP"
grep -q 'AHN4' <<<"$HELP"
grep -q 'AHN5' <<<"$HELP"
grep -q '1x1-km' <<<"$HELP"
grep -q 'dezelfde afleidingsmethode' <<<"$HELP"
grep -q '2 meter' <<<"$HELP"
grep -q 'for cycle in AHN2 AHN3 AHN4 AHN5' "$PIPELINE"
grep -q 'stem="${cycle}_KM_${product}05"' "$PIPELINE"
grep -q 'gdalbuildvrt' "$PIPELINE"
grep -q "AHN3_clip.gpkg" "$PIPELINE"
grep -q "AHN4.gpkg" "$PIPELINE"
grep -q "AHN5_clip.gpkg" "$PIPELINE"
if grep -Fq '${cycle,,}' "$PIPELINE" || grep -Fq '${product,,}' "$PIPELINE"; then
  printf 'FOUT: Bash-4-kleine-letternotatie werkt niet met macOS Bash 3.2.\n' >&2
  exit 1
fi

CYCLES="$(grep -Ec 'ahn[2345]_vegetatiestructuur.csv' "$PIPELINE")"
[[ "$CYCLES" -eq 4 ]]

printf 'OK: AHN-structuurpipeline harmoniseert AHN2, AHN3, AHN4 en AHN5.\n'
