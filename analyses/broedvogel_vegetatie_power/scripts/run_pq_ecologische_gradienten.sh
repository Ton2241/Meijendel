#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MYSQL_BIN="${MYSQL_BIN:-/usr/local/mysql/bin/mysql}"
DATABASE_NAME="${MEIJENDEL_DATABASE:-Meijendel}"
RESULTS_DIR="$REPO_DIR/analyses/broedvogel_vegetatie_power/resultaten"
OUTPUT_ROOT="${1:-$RESULTS_DIR/runs}"
ECODBASE_URL="https://www.synbiosys.alterra.nl/synbiosysnl/downloads/ecodbase.zip"
EXPECTED_ECODBASE_SHA256="993a934f55d3b4ceb6044040ec38d8e69f9f469b12de03e1044d2face30ca045"

die() { printf 'BLOKKADE: %s\n' "$*" >&2; exit 1; }
sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

[[ -x "$MYSQL_BIN" ]] || die "MySQL-client niet uitvoerbaar: $MYSQL_BIN"
command -v curl >/dev/null || die "curl ontbreekt."
command -v unzip >/dev/null || die "unzip ontbreekt."
"$REPO_DIR/scripts/check_local_workspace.sh"

MYSQL_ARGS=(
  --login-path=meijendel_root --protocol=tcp -h 127.0.0.1 -P 3306
  -D "$DATABASE_NAME" --batch
)
mysql_value() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" --skip-column-names -e "$1"; }
extract_table() { "$MYSQL_BIN" "${MYSQL_ARGS[@]}" -e "$2" > "$EXTRACT_DIR/$1.tsv"; }

MYSQL_VERSION="$(mysql_value 'SELECT VERSION()')"
[[ -n "$MYSQL_VERSION" ]] || die "MySQL-versie kon niet worden gelezen."
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')-$(git -C "$REPO_DIR" rev-parse --short=12 HEAD)"
GIT_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
EXTRACT_DIR="$(mktemp -d -t meijendel-pq-gradienten.XXXXXX)"
SOURCE_DIR="$(mktemp -d -t meijendel-synbiosys.XXXXXX)"
trap 'rm -rf "$EXTRACT_DIR" "$SOURCE_DIR"' EXIT

curl -fsSL "$ECODBASE_URL" -o "$SOURCE_DIR/ecodbase.zip"
SOURCE_SHA256="$(sha256_file "$SOURCE_DIR/ecodbase.zip")"
[[ "$SOURCE_SHA256" == "$EXPECTED_ECODBASE_SHA256" ]] || die \
  "SynBioSys-download is gewijzigd: verwacht $EXPECTED_ECODBASE_SHA256, gevonden $SOURCE_SHA256."
unzip -p "$SOURCE_DIR/ecodbase.zip" EcoDbase.xlsx > "$SOURCE_DIR/EcoDbase.xlsx"
[[ -s "$SOURCE_DIR/EcoDbase.xlsx" ]] || die "EcoDbase.xlsx ontbreekt in de download."

extract_table plots "SELECT p.plot_id, p.plot_naam, p.kavel_nummer FROM plots p JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=p.plot_id ORDER BY p.plot_id"
extract_table plot_analyse_scope "SELECT scope_code, plot_id, in_scope, reden FROM plot_analyse_scope ORDER BY scope_code, plot_id"
extract_table soorten "SELECT id, euring_code, soort_naam FROM soorten ORDER BY id"
extract_table plot_jaar_oppervlak "SELECT plot_id, jaar, oppervlakte_km2 FROM plot_jaar_oppervlak WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table plot_jaar_teller "SELECT plot_id, jaar, teller_id FROM plot_jaar_teller WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, teller_id"
extract_table territoria "SELECT plot_id, soort_id, jaar, territoria, bron_id FROM territoria WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar, soort_id"
extract_table bronnen "SELECT id, code FROM bronnen ORDER BY id"
extract_table sovon_bmp_plotjaar "SELECT plot_id, jaar, beoordelingsstatus FROM sovon_bmp_plotjaar WHERE jaar BETWEEN 1958 AND 2025 ORDER BY plot_id, jaar"
extract_table pq_vegetatie_opname "SELECT o.opname_id, o.pq_nummer, o.jaar, o.ipi_code, o.ipi_naam FROM pq_vegetatie_opname o JOIN pq_vegetatie_opname_plot op ON op.opname_id=o.opname_id JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id ORDER BY o.opname_id"
extract_table pq_vegetatie_opname_plot "SELECT op.opname_id, op.plot_id FROM pq_vegetatie_opname_plot op JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id ORDER BY op.opname_id"
extract_table pq_vegetatie_waarneming "SELECT w.opname_id, tb.taxon_id, w.abundantie_percentage FROM pq_vegetatie_waarneming w JOIN taxa_bronkoppeling tb ON tb.koppeling_id=w.taxon_bronkoppeling_id JOIN pq_vegetatie_opname_plot op ON op.opname_id=w.opname_id JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id ORDER BY w.opname_id, tb.taxon_id"
extract_table pq_taxa "SELECT DISTINCT t.taxon_id, t.wetenschappelijke_naam, t.naam_zonder_auteur, t.weergavenaam, g.groep_naam FROM pq_vegetatie_waarneming w JOIN taxa_bronkoppeling tb ON tb.koppeling_id=w.taxon_bronkoppeling_id JOIN taxa t ON t.taxon_id=tb.taxon_id LEFT JOIN taxon_groepen g ON g.groep_id=t.groep_id JOIN pq_vegetatie_opname_plot op ON op.opname_id=w.opname_id JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id ORDER BY t.taxon_id"
extract_table pq_taxon_aliases "SELECT DISTINCT tb.taxon_id, tb.bron_wetenschappelijke_naam FROM taxa_bronkoppeling tb JOIN (SELECT DISTINCT tb2.taxon_id FROM pq_vegetatie_waarneming w JOIN taxa_bronkoppeling tb2 ON tb2.koppeling_id=w.taxon_bronkoppeling_id JOIN pq_vegetatie_opname_plot op ON op.opname_id=w.opname_id JOIN v_meijendel_analyseplot_actueel s ON s.plot_id=op.plot_id) q ON q.taxon_id=tb.taxon_id WHERE tb.bron_wetenschappelijke_naam IS NOT NULL AND tb.bron_wetenschappelijke_naam<>'' ORDER BY tb.taxon_id, tb.bron_wetenschappelijke_naam"

mkdir -p "$RUN_DIR"
Rscript "$SCRIPT_DIR/pq_ecologische_gradienten.R" \
  "$EXTRACT_DIR" "$SOURCE_DIR/EcoDbase.xlsx" "$RUN_DIR" "$RUN_ID" \
  "$GIT_COMMIT" "$DATABASE_NAME" "$MYSQL_VERSION" "$RESULTS_DIR" \
  "$SOURCE_SHA256"

printf 'OK: ecologische PQ-gradiënten uitgevoerd in %s\n' "$RUN_DIR"
