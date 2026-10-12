#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MYSQL_BIN="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DATABASE_NAME="${MEIJENDEL_DATABASE:-Meijendel}"
RESULTS_DIR="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten"
OUTPUT_ROOT="$RESULTS_DIR/runs"
RESUME_DIR=""
if [[ "${1:-}" == "--resume" ]]; then
  [[ $# -eq 2 ]] || { printf 'Gebruik: %s --resume RUNMAP\n' "$0" >&2; exit 2; }
  RESUME_DIR="$2"
  [[ -d "$RESUME_DIR/modellen" ]] || { printf 'BLOKKADE: geen hervatbare runmap: %s\n' "$RESUME_DIR" >&2; exit 1; }
elif [[ $# -le 1 ]]; then
  [[ $# -eq 0 ]] || OUTPUT_ROOT="$1"
else
  printf 'Gebruik: %s [UITVOERMAP] of %s --resume RUNMAP\n' "$0" "$0" >&2
  exit 2
fi
[[ -x "$MYSQL_BIN" ]] || { printf 'BLOKKADE: MySQL-client ontbreekt.\n' >&2; exit 1; }
"$REPO_DIR/scripts/check_local_workspace.sh"

MYSQL_ARGS=(--login-path=meijendel_root --protocol=tcp -h 127.0.0.1 -P 3306 -D "$DATABASE_NAME" --batch)
mysql_value() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" --skip-column-names -e "$1"; }
extract_table() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" -e "$2" > "$EXTRACT_DIR/$1.tsv"; }

RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)"
GIT_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
MYSQL_VERSION="$(mysql_value 'SELECT VERSION()')"
if [[ -n "$RESUME_DIR" ]]; then
  RUN_DIR="$RESUME_DIR"
  RUN_ID="$(basename "$RESUME_DIR")"
else
  RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
fi
EXTRACT_DIR="$(mktemp -d /private/tmp/meijendel-omgeving-extract.XXXXXX)"
trap 'rm -rf "$EXTRACT_DIR"' EXIT

extract_table plots "SELECT p.plot_id,p.plot_naam,p.kavel_nummer FROM plots p JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=p.plot_id ORDER BY p.plot_id"
extract_table plot_analyse_scope "SELECT scope_code,plot_id,in_scope,reden FROM plot_analyse_scope ORDER BY scope_code,plot_id"
extract_table soorten "SELECT id,euring_code,soort_naam FROM soorten ORDER BY id"
extract_table plot_jaar_oppervlak "SELECT plot_id,jaar,oppervlakte_km2 FROM plot_jaar_oppervlak WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id,jaar"
extract_table plot_jaar_teller "SELECT plot_id,jaar,teller_id FROM plot_jaar_teller WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id,jaar,teller_id"
extract_table territoria "SELECT plot_id,soort_id,jaar,territoria,bron_id FROM territoria WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id,jaar,soort_id"
extract_table bronnen "SELECT id,code FROM bronnen ORDER BY id"
extract_table sovon_bmp_plotjaar "SELECT plot_id,jaar,beoordelingsstatus FROM sovon_bmp_plotjaar WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id,jaar"
extract_table dagbezoeken_bmp "SELECT plot_id,jaar,dagvanjaar,bezoekduur_min,gunstig FROM dagbezoeken_bmp WHERE jaar BETWEEN 1984 AND 2025 ORDER BY plot_id,jaar,dagvanjaar"
extract_table weer_analyse "SELECT datum,tg_c,tn_c,rh_mm FROM weer_analyse WHERE datum BETWEEN '1953-01-01' AND '2025-12-31' ORDER BY datum"
extract_table plot_jaar_stikstof "SELECT plot_id,jaar,bron,stikstof_mean,stikstof_median FROM plot_jaar_stikstof ORDER BY plot_id,jaar"
extract_table plot_jaar_landgebruik "SELECT plot_id,jaar,bron,klasse,area_m2,pct FROM plot_jaar_landgebruik ORDER BY plot_id,jaar,klasse"
extract_table evg_vogelgroepen "SELECT groepsnummer,landschap_groep FROM evg_vogelgroepen WHERE groepsnummer IN (100,200,300,400,500,600,700,800) ORDER BY groepsnummer"
extract_table evg_vogel_landschapgroep "SELECT groepsnummer,vogel_id FROM evg_vogel_landschapgroep WHERE groepsnummer IN (100,200,300,400,500,600,700,800) ORDER BY groepsnummer,vogel_id"
extract_table functional_group_definition "SELECT id,group_code,naam_nl,status FROM functional_group_definition WHERE status='approved' ORDER BY id"
extract_table functional_group_membership "SELECT functional_group_definition_id,soort_id,membership_weight,classification FROM functional_group_membership WHERE classification IN ('primary','secondary') ORDER BY functional_group_definition_id,soort_id"

mkdir -p "$RUN_DIR"
Rscript "$SCRIPT_DIR/run_broedvogel_omgeving.R" \
  "$EXTRACT_DIR" "$RUN_DIR" "$RUN_ID" "$GIT_COMMIT" "$DATABASE_NAME" "$MYSQL_VERSION" "$RESULTS_DIR"
printf 'OK: stikstof- en bodemgebruikanalyse uitgevoerd in %s\n' "$RUN_DIR"
