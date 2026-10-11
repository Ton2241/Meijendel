#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MYSQL_BIN="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DATABASE_NAME="${MEIJENDEL_DATABASE:-Meijendel}"
RESULTS_DIR="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten"
OUTPUT_ROOT="$RESULTS_DIR/runs"

die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "--resume" ]]; then
  [[ $# -eq 2 ]] || die "Gebruik: $0 --resume RUNMAP"
  RUN_DIR="$2"
  [[ -f "$RUN_DIR/vegetatie_model_state.rds" ]] || die "Geen hervatbare runmap: $RUN_DIR"
  Rscript "$SCRIPT_DIR/run_broedvogel_vegetatie_model.R" resume "$RUN_DIR" "$RESULTS_DIR"
  printf 'OK: vegetatieanalyse hervat in %s\n' "$RUN_DIR"
  exit 0
fi

[[ $# -le 1 ]] || die "Gebruik: $0 [UITVOERMAP] of $0 --resume RUNMAP"
[[ $# -eq 0 ]] || OUTPUT_ROOT="$1"
[[ -x "$MYSQL_BIN" ]] || die "MySQL-client niet uitvoerbaar: $MYSQL_BIN"
"$REPO_DIR/scripts/check_local_workspace.sh"

MYSQL_ARGS=(--login-path=meijendel_root --protocol=tcp -h 127.0.0.1 -P 3306 -D "$DATABASE_NAME" --batch)
mysql_value() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" --skip-column-names -e "$1"; }
extract_table() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" -e "$2" > "$EXTRACT_DIR/$1.tsv"; }

MYSQL_VERSION="$(mysql_value 'SELECT VERSION()')"
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)"
GIT_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
EXTRACT_DIR="$(mktemp -d -t meijendel-vegetatiemodel-extract.XXXXXX)"
trap 'rm -rf "$EXTRACT_DIR"' EXIT

extract_table plots "SELECT plot_id, plot_naam, kavel_nummer FROM plots ORDER BY plot_id"
extract_table plot_analyse_scope "SELECT scope_code, plot_id, in_scope, reden FROM plot_analyse_scope ORDER BY scope_code, plot_id"
extract_table soorten "SELECT id, euring_code, soort_naam FROM soorten ORDER BY id"
extract_table plot_jaar_oppervlak "SELECT plot_id, jaar, oppervlakte_km2 FROM plot_jaar_oppervlak WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table plot_jaar_teller "SELECT plot_id, jaar, teller_id FROM plot_jaar_teller WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, teller_id"
extract_table territoria "SELECT plot_id, soort_id, jaar, territoria, bron_id FROM territoria WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, soort_id"
extract_table bronnen "SELECT id, code FROM bronnen ORDER BY id"
extract_table sovon_bmp_plotjaar "SELECT plot_id, jaar, beoordelingsstatus FROM sovon_bmp_plotjaar WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table dagbezoeken_bmp "SELECT plot_id, jaar, dagvanjaar, bezoekduur_min, gunstig FROM dagbezoeken_bmp WHERE jaar BETWEEN 1984 AND 2025 ORDER BY plot_id, jaar, dagvanjaar"
extract_table pq_plot_jaar_vegetatie "SELECT plot_id, jaar, n_pq, n_opnamen, taxa_aantal, soortenrijkdom_gem, bedekking_som_gem, shannon_gem, dekking_kwaliteit, bronstatus, bronbestand, importversie, taxonlijst_versie FROM pq_plot_jaar_vegetatie ORDER BY plot_id, jaar"

mkdir -p "$RUN_DIR"
Rscript "$SCRIPT_DIR/run_broedvogel_vegetatie_model.R" new \
  "$EXTRACT_DIR" "$RUN_DIR" "$RUN_ID" "$GIT_COMMIT" "$DATABASE_NAME" "$MYSQL_VERSION" "$RESULTS_DIR"

printf 'OK: vegetatieanalyse uitgevoerd in %s\n' "$RUN_DIR"
