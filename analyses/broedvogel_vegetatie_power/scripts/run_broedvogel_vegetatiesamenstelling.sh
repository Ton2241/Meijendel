#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MYSQL_BIN="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DATABASE_NAME="${MEIJENDEL_DATABASE:-Meijendel}"
RESULTS_DIR="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten"
OUTPUT_ROOT="$RESULTS_DIR/runs"
SUPPLEMENT_URL='https://media.springernature.com/original/springer-static/esm/art%3A10.1007%2Fs10531-025-03175-x/MediaObjects/10531_2025_3175_MOESM1_ESM.zip'

die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "--resume" ]]; then
  [[ $# -eq 2 ]] || die "Gebruik: $0 --resume RUNMAP"
  RUN_DIR="$2"
  [[ -f "$RUN_DIR/vegetatiesamenstelling_state.rds" ]] || die "Geen hervatbare runmap: $RUN_DIR"
  Rscript "$SCRIPT_DIR/run_broedvogel_vegetatiesamenstelling.R" resume "$RUN_DIR" "$RESULTS_DIR"
  printf 'OK: vegetatiesamenstellingsanalyse hervat in %s\n' "$RUN_DIR"
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
EXTRACT_DIR="$(mktemp -d -t meijendel-vegetatiesamenstelling-extract.XXXXXX)"
SOURCE_DIR="$(mktemp -d -t meijendel-landbedekking-bron.XXXXXX)"
trap 'rm -rf "$EXTRACT_DIR" "$SOURCE_DIR"' EXIT

extract_table plots "SELECT p.plot_id, p.plot_naam, p.kavel_nummer FROM plots p JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=p.plot_id ORDER BY p.plot_id"
extract_table plot_analyse_scope "SELECT scope_code, plot_id, in_scope, reden FROM plot_analyse_scope ORDER BY scope_code, plot_id"
extract_table soorten "SELECT id, euring_code, soort_naam FROM soorten ORDER BY id"
extract_table plot_jaar_oppervlak "SELECT plot_id, jaar, oppervlakte_km2 FROM plot_jaar_oppervlak WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table plot_jaar_teller "SELECT plot_id, jaar, teller_id FROM plot_jaar_teller WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, teller_id"
extract_table territoria "SELECT plot_id, soort_id, jaar, territoria, bron_id FROM territoria WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, soort_id"
extract_table bronnen "SELECT id, code FROM bronnen ORDER BY id"
extract_table sovon_bmp_plotjaar "SELECT plot_id, jaar, beoordelingsstatus FROM sovon_bmp_plotjaar WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table dagbezoeken_bmp "SELECT plot_id, jaar, dagvanjaar, bezoekduur_min, gunstig FROM dagbezoeken_bmp WHERE jaar BETWEEN 1984 AND 2025 ORDER BY plot_id, jaar, dagvanjaar"
extract_table pq_vegetatie_opname "SELECT opname_id, pq_nummer, jaar, ipi_code, ipi_naam FROM pq_vegetatie_opname ORDER BY opname_id"
extract_table pq_vegetatie_opname_plot "SELECT op.opname_id, op.plot_id FROM pq_vegetatie_opname_plot op JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id ORDER BY op.opname_id"
extract_table pq_vegetatie_waarneming "SELECT w.opname_id, tb.taxon_id, t.weergavenaam AS taxon_naam, COALESCE(t.taxonrang, 'NULL') AS taxonrang, t.taxonvorm, w.abundantie_percentage FROM pq_vegetatie_waarneming w JOIN taxa_bronkoppeling tb ON tb.koppeling_id=w.taxon_bronkoppeling_id JOIN taxa t ON t.taxon_id=tb.taxon_id ORDER BY w.opname_id, tb.taxon_id"
extract_table evg_vogel_landschapgroep "SELECT groepsnummer, vogel_id FROM evg_vogel_landschapgroep WHERE groepsnummer IN (100,200,300,600,700,800) ORDER BY groepsnummer, vogel_id"

curl -L --fail --silent --show-error -o "$SOURCE_DIR/supplement.zip" "$SUPPLEMENT_URL"
unzip -q "$SOURCE_DIR/supplement.zip" 'SI_resub/OR2.xlsx' -d "$SOURCE_DIR"
SUPPLEMENT_SHA256="$(shasum -a 256 "$SOURCE_DIR/supplement.zip" | awk '{print $1}')"
Rscript -e '
  args <- commandArgs(trailingOnly=TRUE)
  source(args[[1]])
  raw <- readxl::read_excel(args[[2]], col_names=FALSE)
  clean <- parse_landcover_or2(raw)
  utils::write.table(clean, args[[3]], sep="\t", quote=FALSE, row.names=FALSE, na="NULL")
' "$SCRIPT_DIR/broedvogel_model_vegetatiesamenstelling.R" "$SOURCE_DIR/SI_resub/OR2.xlsx" "$EXTRACT_DIR/landbedekking_schmidt_2025.tsv"
Rscript -e '
  args <- commandArgs(trailingOnly=TRUE)
  data <- data.frame(
    doi="10.1007/s10531-025-03175-x",
    bestand="10531_2025_3175_MOESM1_ESM.zip",
    sha256=args[[1]],
    licentie="CC BY 4.0",
    opgehaald_op_utc=format(Sys.time(), tz="UTC", "%Y-%m-%dT%H:%M:%SZ"),
    stringsAsFactors=FALSE
  )
  utils::write.table(data, args[[2]], sep="\t", quote=FALSE, row.names=FALSE)
' "$SUPPLEMENT_SHA256" "$EXTRACT_DIR/landbedekking_schmidt_2025_bron.tsv"

mkdir -p "$RUN_DIR"
Rscript "$SCRIPT_DIR/run_broedvogel_vegetatiesamenstelling.R" new \
  "$EXTRACT_DIR" "$RUN_DIR" "$RUN_ID" "$GIT_COMMIT" "$DATABASE_NAME" "$MYSQL_VERSION" "$RESULTS_DIR"

printf 'OK: vegetatiesamenstellingsanalyse uitgevoerd in %s\n' "$RUN_DIR"
