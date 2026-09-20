#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy_meijendel_vps.sh"

fail() {
  printf 'FOUT: %s\n' "$*" >&2
  exit 1
}

need_literal() {
  local literal="$1"
  grep -Fq -- "$literal" "$DEPLOY_SCRIPT" || fail "deployscript mist: $literal"
}

bash -n "$DEPLOY_SCRIPT"

required_outputs=(
  "trim/soorten/soorten_modelstatus.csv"
  "trim/soorten/soortindices_per_jaar.csv"
  "trim/soorten/soorten_trendoverzicht.csv"
  "trim/soorten/soorten_brugfactoren.csv"
  "trim/sandra/soorten/soorten_modelstatus.csv"
  "trim/sandra/soorten/soortindices_per_jaar.csv"
  "trim/sandra/soorten/soorten_trendoverzicht.csv"
  "trim/sandra/trim_msi_evg/trendoverzicht_msi_groepen.csv"
  "trim_msi_evg/trendoverzicht_msi_groepen.csv"
  "trim_msi_evg/functionele_trendoverzicht_msi_groepen.csv"
)

for relative_path in "${required_outputs[@]}"; do
  [[ -s "$REPO_DIR/$relative_path" ]] || fail "vereiste release-uitvoer ontbreekt of is leeg: $relative_path"
  need_literal "need_file \"\$LOCAL_REPO/$relative_path\""
done

need_literal "trim/soorten/ -> \$REMOTE_WWW/trim/soorten/"
need_literal "trim/sandra/ -> \$REMOTE_WWW/trim/sandra/"
need_literal 'run_rsync --delete-delay --exclude '\''.DS_Store'\'' "$LOCAL_REPO/trim/" "$VPS:$REMOTE_WWW/trim/"'
need_literal 'test -s "$REMOTE_WWW/trim/soorten/soorten_trendoverzicht.csv"'
need_literal 'test -s "$REMOTE_WWW/trim/sandra/soorten/soorten_trendoverzicht.csv"'
need_literal '/trim/soorten/soorten_trendoverzicht.csv'

printf 'TRIM-releasecontract: OK (%d verplichte uitvoerbestanden)\n' "${#required_outputs[@]}"
