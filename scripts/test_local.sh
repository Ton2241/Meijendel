#!/usr/bin/env bash
# Explicit test selections; no implicit model runs or database mutations.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -gt 0 ]] || { echo 'Gebruik: scripts/test_local.sh TESTBESTAND ...' >&2; exit 2; }
[[ -n "${TMPDIR:-}" ]] || { echo 'BLOKKADE: stel TMPDIR expliciet in onder Proefomgevingen op T7.' >&2; exit 2; }
physical_tmp="$(python3 "$HOME/Documents/GitHub/VWG_Project/scripts/trial_storage.py" "$TMPDIR")"
# R refuses spaces in TMPDIR; only this small reference is local.
alias_tmp="/tmp/t7-audit-run-$$"
ln -s "$physical_tmp" "$alias_tmp"
trap 'rm -f -- "$alias_tmp"' EXIT
export TMPDIR="$alias_tmp" TMP="$alias_tmp" TEMP="$alias_tmp" PYTHONDONTWRITEBYTECODE=1
cd "$repo"
for selection in "$@"; do
  [[ "$selection" != /* && "$selection" != *..* && -f "$selection" && "$selection" != scripts/test_local.sh ]] || { echo "Ongeldig testpad: $selection" >&2; exit 2; }
  case "$selection" in
    R/check_*.R|R/test_*.R) Rscript "$selection" ;;
    scripts/test_*.py|tests/test_*.py|gis/scripts/test_*.py) python3 "$selection" ;;
    scripts/test_*.sh) bash "$selection" ;;
    *) echo "Geen ondersteund testbestand: $selection" >&2; exit 2 ;;
  esac
done
