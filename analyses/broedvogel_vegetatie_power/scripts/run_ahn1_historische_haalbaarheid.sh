#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PYTHON_BIN="${AHN_PYTHON_BIN:-$REPO_DIR/.venv_ahn/bin/python}"
PLOTS="${AHN_PLOTS:-$REPO_DIR/Plots_2025/avimap_252_diversen__gebieden.shp}"

usage() {
  cat <<'EOF'
Gebruik: run_ahn1_historische_haalbaarheid.sh UITVOERMAP

Downloadt de oorspronkelijke AHN1-grond- en niet-grondpunten voor de vijf
Meijendelkaartbladen via de TU Delft GeoTiles-spiegel, controleert de MD5 van
de oorspronkelijke levering en vergelijkt twee 5-meterafleidingen. AHN1 blijft
een experimentele historische laag en wordt niet stilzwijgend aan de
geharmoniseerde AHN2-AHN5-hoofdreeks toegevoegd.
EOF
}

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
[[ $# -eq 1 ]] || { usage >&2; exit 2; }
OUTPUT="$1"
mkdir -p "$OUTPUT/bron/g" "$OUTPUT/bron/u"

checksum_for() {
  case "$1" in
    g/30dn2.laz) printf '81641998d78715babb4395f04e78ec26' ;;
    g/30ez1.laz) printf 'abf0163a957f054825307c60cd4a8e49' ;;
    g/30ez2.laz) printf '2545703cce742485508a90443906ae5b' ;;
    g/30gn1.laz) printf '4491231eb6e61f6913a49e222638994a' ;;
    g/30gn2.laz) printf '32cdfd935104ddfbbebfe37a7ef506b8' ;;
    u/30dn2.laz) printf 'ba07b9f45d42db8b114e81452dcb2235' ;;
    u/30ez1.laz) printf 'f7247db1052497d744a05d994d1b4852' ;;
    u/30ez2.laz) printf 'ccb9ee9a096d5923fc5e6489fa406f2e' ;;
    u/30gn1.laz) printf '14c25bdca9dd8709a9fb96d79e4ab8fd' ;;
    u/30gn2.laz) printf '666f88db2ebc04722cce93b5609c09d4' ;;
    *) return 1 ;;
  esac
}

printf 'klasse,kaartblad,url,verwachte_md5,feitelijke_md5,omvang_bytes\n' \
  > "$OUTPUT/ahn1_bronbestanden.csv"
for class in g u; do
  for tile in 30dn2 30ez1 30ez2 30gn1 30gn2; do
    relative="$class/$tile.laz"
    url="https://geotiles.citg.tudelft.nl/AHN1/$relative"
    target="$OUTPUT/bron/$relative"
    expected="$(checksum_for "$relative")"
    if [[ ! -f "$target" ]] || [[ "$(md5 -q "$target")" != "$expected" ]]; then
      curl -L --fail --silent --show-error "$url" -o "$target"
    fi
    actual="$(md5 -q "$target")"
    [[ "$actual" == "$expected" ]] || {
      printf 'BLOKKADE: AHN1-MD5 wijkt af voor %s\n' "$target" >&2
      exit 1
    }
    bytes="$(stat -f '%z' "$target")"
    printf '%s,%s,%s,%s,%s,%s\n' "$class" "$tile" "$url" "$expected" "$actual" "$bytes" \
      >> "$OUTPUT/ahn1_bronbestanden.csv"
  done
done

"$PYTHON_BIN" "$SCRIPT_DIR/ahn1_historische_rasters.py" \
  --ground "$OUTPUT"/bron/g/*.laz --nonground "$OUTPUT"/bron/u/*.laz \
  --bounds 79595 458355 86480 464395 --resolution 5 \
  --output-dir "$OUTPUT"

for method in mean max; do
  "$PYTHON_BIN" "$SCRIPT_DIR/ahn_vegetatiestructuur.py" \
    --plots "$PLOTS" --dsm "$OUTPUT/ahn1_dsm_${method}_all_5m.tif" \
    --dtm "$OUTPUT/ahn1_dtm_mean_ground_5m.tif" --cycle AHN1 \
    --acquisition-year 1998 --acquisition-period 1997-1998 \
    --structure-moment 1998 --response-start-year 1999 \
    --bronproduct 'GeoTiles_spiegel_oorspronkelijke_AHN1_grond_en_niet_grond' \
    --harmonisatie "experimenteel_AHN1_5m_${method}_all_minus_mean_ground" \
    --output "$OUTPUT/ahn1_vegetatiestructuur_${method}.csv"
done

"$PYTHON_BIN" "$SCRIPT_DIR/analyseer_ahn1_gevoeligheid.py" \
  --mean "$OUTPUT/ahn1_vegetatiestructuur_mean.csv" \
  --max "$OUTPUT/ahn1_vegetatiestructuur_max.csv" \
  --output-detail "$OUTPUT/ahn1_methodegevoeligheid_per_plot.csv" \
  --output-summary "$OUTPUT/ahn1_methodegevoeligheid_samenvatting.csv"

printf 'OK: AHN1-haalbaarheidsanalyse uitgevoerd in %s\n' "$OUTPUT"
